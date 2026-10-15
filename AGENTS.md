# AGENTS.md

Weekly Training Operations KPIs on DuckDB and dbt. Read the target before you edit.

| Working on | Read first |
|:--|:--|
| setup, layout | [README.md](README.md) |
| a command | § Commands below |
| a KPI, a number | the five functions in schema `mart`: `report_active_participations`, `report_completion_rates`, `report_progress_vs_schedule`, `report_nps_by_quarter`, `report_coach_load`. Call them with the reference date (and the threshold); do not re-derive a KPI from the star |
| business words | [wiki/general/glossary.md](wiki/general/glossary.md) |
| why a number is asked for, who acts on it | [wiki/teams/training_operations/](wiki/teams/training_operations/) |
| anything under `transform/` | [transform/README.md](transform/README.md): layers, model template, naming, tests |

## Commands

| Command | Does |
|:--|:--|
| `make run` | the pipeline: start API · extract · load · build · stop API |
| `make check` | runs it twice and compares every table's row count: no duplicates |
| `make answers` | the five answers at the defaults, printed and written as CSV beside each query |
| `make dashboard` | the dashboard on the built warehouse, read-only |
| `make lint` | ruff and sqlfluff; changes nothing |

The single steps (`extract`, `load`, `build`), `fmt` and `clean` are in the `Makefile`. After a live change, `make build && make answers && git diff` shows which numbers moved; `cd transform && uv run dbt test --select tag:pinned` shows which pin.

## Editor

Open the folder in VS Code or Cursor and accept the recommended extensions (`.vscode/extensions.json`): dbt (lineage, go to definition, compiled SQL, preview), DuckDB (browse `storage/warehouse.duckdb` read-only; detach before `make build`, one writer per file), sqlfluff and ruff (rules in `transform/.sqlfluff` and `pyproject.toml`).

## Rules

What the tree does not show:

- Builds go through `make` (`make build`, `make run`); `dbt` on its own needs `--profiles-dir .` inside `transform/`.
- One writer per warehouse file. Read `storage/warehouse.duckdb` read-only, one connection per query (`.mcp.json` does); a held connection makes `make build` fail with `Could not set lock on file`.
- No model reads a reference date. The Stichtag and the threshold are function arguments.
- A number in a test is a ceiling on a known finding or a pinned README reading (`tag:pinned`); no finding test asserts today's count. A new finding gets a row in README § Data-quality findings and a test.
- Names: descriptive over short (`data_quality_issues`, not `dq_issues`); the allowed abbreviations are in transform/README.md § Naming.
