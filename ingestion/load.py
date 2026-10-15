"""Load: rebuild schema raw from the landed files, load.sql against the warehouse in sources.yaml.

    uv run python ingestion/load.py

Raw is rebuilt from every landed file on each run; nothing is appended.
"""

from pathlib import Path

import duckdb
import yaml

INGESTION_DIR = Path(__file__).parent

config = yaml.safe_load((INGESTION_DIR / "sources.yaml").read_text())
duckdb.connect(config["storage"]["warehouse"]).execute((INGESTION_DIR / "load.sql").read_text())
