"""The five answers of Brief § 3.4 at the defaults (Stichtag 31.08.2026, im Verzug ab 15 pp).

Runs each serving/questions/q<n>_<function>.sql against the warehouse, writes the result beside it
as CSV and prints each table as Markdown under its file name (README § Results, pasted once; the
question, Stichtag and Datenstand are stated there).

A serving query reads a function in schema mart and does nothing else: a dimension joined for a
name, a pivot, sums of cells and a division. No population predicate, no date, no threshold, no
join between facts; that logic belongs in the function (transform/models/marts/training_operations/).
Every $name in a query is a function argument, named in the query's header line.
The dashboard imports run() and DEFAULTS, so every surface runs the same SQL.
"""

import csv
import sys
from datetime import date
from pathlib import Path

import duckdb

WAREHOUSE = Path(__file__).parents[1] / "storage" / "warehouse.duckdb"
QUESTIONS = Path(__file__).parent / "questions"
DEFAULTS = {
    "reference_date": date(2026, 8, 31),
    "behind_schedule_pp": 15,
    "planned_end_from": None,  # no window of planned-end quarters: every quarter, the Brief's Q2
    "planned_end_to": None,
}


def run(sql_file: Path, **parameters) -> tuple[list[str], list[tuple]]:
    """Column names and rows of one query. One read-only connection per call, closed after it,
    so a build is never blocked. DuckDB rejects a parameter the SQL does not name, so only the
    ones the file uses are passed."""
    sql = sql_file.read_text()
    used = {name: value for name, value in parameters.items() if f"${name}" in sql}
    with duckdb.connect(str(WAREHOUSE), read_only=True) as con:
        cursor = con.execute(sql, used)
        return [column[0] for column in cursor.description], cursor.fetchall()


def data_as_of() -> str:
    """Datenstand: the newest source timestamp the loader has seen (raw.load_history)."""
    with duckdb.connect(str(WAREHOUSE), read_only=True) as con:
        return con.execute(
            "select left(max(t.watermark_after), 10) from raw.load_history, unnest(tables) as u(t)"
        ).fetchone()[0]


def to_markdown(columns: list[str], rows: list[tuple]) -> str:
    align = ["--:" if isinstance(value, int | float) else ":--" for value in rows[0]]
    lines = [
        "| " + " | ".join(columns) + " |",
        "|" + "|".join(align) + "|",
        *("| " + " | ".join("" if v is None else str(v) for v in row) + " |" for row in rows),
    ]
    return "\n".join(lines)


def main() -> None:
    for sql_file in sorted(QUESTIONS.glob("q*.sql")):
        columns, rows = run(sql_file, **DEFAULTS)
        with sql_file.with_suffix(".csv").open("w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(columns)
            writer.writerows(rows)
        print(f"`{sql_file.name}`", to_markdown(columns, rows), sep="\n\n", end="\n\n")


if __name__ == "__main__":
    sys.exit(main())
