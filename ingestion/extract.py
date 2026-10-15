"""Extract: fetch every source declared in sources.yaml and land it as files in the bucket.

    uv run python ingestion/extract.py            # every source
    uv run python ingestion/extract.py crm lxp    # a selection

API sources are fetched from their watermark on, the newest cursor value the source delivered
last time, never our clock; the Excel is always a full snapshot. Each run lands its own record
beside the files. Loading the files into the warehouse is load.py.
"""

import argparse
import json
import os
import re
import time
from datetime import UTC, datetime
from pathlib import Path

import httpx
import openpyxl
import yaml

CONFIG_FILE = Path(__file__).parent / "sources.yaml"


def load_config():
    """sources.yaml with every ${VAR} replaced from the environment; a missing one stops the run."""
    text = os.path.expandvars(CONFIG_FILE.read_text())
    if unresolved := re.findall(r"\$\{(\w+)\}", text):
        raise SystemExit(f"not set in the environment: {', '.join(unresolved)} (defaults in the Makefile; run through make)")
    return yaml.safe_load(text)


def utc_now():
    """The loader's clock, ISO in UTC. Only the run record uses it; a watermark is the source's."""
    return datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def write_json(folder, name, content):
    """One file per page. The same name overwrites, so a repeated window never duplicates."""
    folder.mkdir(parents=True, exist_ok=True)
    (folder / name).write_text(json.dumps(content, ensure_ascii=False, indent=1))


def run_record(source, table, **counts):
    """One row of the run record per table: what was fetched, retried and advanced to."""
    return {
        "source": source,
        "table": table,
        "pages": 0,
        "rows": 0,
        "files_written": 0,
        "retries_503": 0,
        "watermark_before": None,
        "watermark_after": None,
        **counts,
    }


class ApiClient:
    """The Brief's client behaviour in one place: bearer login, 503 retries honouring
    Retry-After, a new login on 401, pages followed by next_token."""

    def __init__(self, api):
        self.api = api
        self.http = httpx.Client(base_url=api["base_url"], timeout=30)
        self.retries_503 = 0
        self.login()

    def login(self):
        login = self.api["login"]
        credentials = {"username": login["username"], "password": login["password"]}
        token = self.http.post(login["path"], data=credentials).raise_for_status().json()
        self.http.headers["Authorization"] = f"Bearer {token['access_token']}"

    def get(self, path, params):
        """One GET as JSON. A 503 waits as told and retries, a 401 means the token expired: log in
        again and retry; five attempts in all. Any other error status raises."""
        for _ in range(5):
            response = self.http.get(path, params=params)
            if response.status_code == 503:
                self.retries_503 += 1
                time.sleep(float(response.headers.get("Retry-After", 1)))
            elif response.status_code == 401:
                self.login()
            else:
                return response.raise_for_status().json()
        raise RuntimeError(f"GET {path}: gave up after 5 attempts, last {response.status_code}")

    def pages(self, path, params):
        """Every page of an endpoint; a next_token of null is the last page."""
        page = self.get(path, params)
        yield page
        while token := page.get("pagination", {}).get("next_token"):
            page = self.get(path, {**params, "page_token": token})
            yield page


def fetch_api(source, spec, bucket, watermarks):
    """Each endpoint from its table's watermark on: land the rows newer than it, one file per
    page, then advance the watermark. Returns one run-record row per endpoint."""
    client = ApiClient(spec["api"])
    records = []
    for endpoint in spec["endpoints"]:
        table = f"{source}__{endpoint['table']}"
        cursor = endpoint.get("cursor")  # absent: the endpoint has no incremental filter
        watermark = watermarks.get(table)
        client.retries_503 = 0
        params = {"page_size": spec["api"]["page_size"]}
        if watermark:
            params[endpoint["param"]] = watermark
        pages = [page["data"] for page in client.pages(endpoint["path"], params)]
        # The filter is inclusive (>=): the rows at the watermark landed with the last window.
        if watermark:
            pages = [[row for row in page if row[cursor] != watermark] for page in pages]
        rows = [row for page in pages for row in page]
        record = run_record(
            source,
            endpoint["table"],
            pages=len(pages),
            rows=len(rows),
            retries_503=client.retries_503,
            watermark_before=watermark,
            watermark_after=watermark,
        )
        # A first run lands even an empty table; a window with nothing newer lands nothing.
        if rows or not watermark:
            prefix = f"since_{watermark.replace(':', '')}_" if watermark else ""
            for number, page in enumerate(pages, 1):
                write_json(bucket / table, f"{prefix}page_{number:04d}.json", page)
            record["files_written"] = len(pages)
        if cursor and rows:  # advance only once every page of the window is on disk
            record["watermark_after"] = max(row[cursor] for row in rows)
            watermarks[table] = record["watermark_after"]
        records.append(record)
    return records


def fetch_excel(source, spec, bucket):
    """Each sheet as one file, always a full snapshot, the sheet row number as the key. Every cell
    lands as text: a date Excel typed as ISO ("2026-04-13T00:00:00"), the rest as typed."""
    workbook = openpyxl.load_workbook(spec["file"], read_only=True)
    records = []
    for sheet, table in spec["sheets"].items():
        header, *sheet_rows = workbook[sheet].iter_rows(values_only=True)
        columns = [re.sub(r"[^a-z0-9äöüß]+", "_", name.lower()).strip("_") for name in header]
        rows = [
            {
                "_row_number": number,
                **{
                    column: value.isoformat() if isinstance(value, datetime) else str(value)
                    for column, value in zip(columns, sheet_row)
                    if value is not None
                },
            }
            for number, sheet_row in enumerate(sheet_rows, 2)  # row 1 is the header
            if any(value is not None for value in sheet_row)
        ]
        write_json(bucket / f"{source}__{table}", f"{table}.json", rows)
        records.append(run_record(source, table, pages=1, rows=len(rows), files_written=1))
    return records


def main():
    config = load_config()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sources", nargs="*", default=list(config["sources"]), help="default: all")
    bucket = Path(config["storage"]["bucket"])
    watermarks_file = bucket / "_watermarks.json"  # per table: the newest cursor value delivered
    watermarks = json.loads(watermarks_file.read_text()) if watermarks_file.exists() else {}
    started_at = utc_now()
    records = []
    for source in parser.parse_args().sources:
        spec = config["sources"][source]
        match spec["type"]:
            case "api":
                records += fetch_api(source, spec, bucket, watermarks)
            case "excel":
                records += fetch_excel(source, spec, bucket)
    write_json(bucket, watermarks_file.name, watermarks)
    for record in records:
        print(
            f"{record['source']}__{record['table']}: {record['rows']} rows in "
            f"{record['files_written']} files, watermark {record['watermark_before']} "
            f"-> {record['watermark_after']}"
        )
    load_id = started_at.replace("-", "").replace(":", "")  # 20260901T040000Z
    run = {"load_id": load_id, "started_at": started_at, "finished_at": utc_now()}
    write_json(bucket / "_load_history", f"{load_id}.json", {**run, "tables": records})


if __name__ == "__main__":
    main()
