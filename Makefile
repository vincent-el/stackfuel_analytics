# One command: make run. Needs uv (https://docs.astral.sh/uv/); starts the fixture API itself.
# The fixture's credentials are defaults; the environment overrides them (make run API_BASE_URL=...).
DBT = cd transform && uv run dbt
API_PASSWORD ?= learn-data-2026
API_BASE_URL ?= http://127.0.0.1:8000
export API_PASSWORD API_BASE_URL
# http://127.0.0.1:8000 -> 8000
API_PORT = $(lastword $(subst :, ,$(API_BASE_URL)))
API_PID_FILE = storage/.api.pid

.PHONY: run api-start api-stop extract load build check answers dashboard lint fmt clean

run: api-start extract load build api-stop

# A take-home convenience: the fixture API is started when nothing answers at API_BASE_URL and
# stopped at the end. The probe keeps it off a real server, and api-stop only kills the pid it
# wrote itself, so an API you started stays up.
api-start:
	@if curl -sf $(API_BASE_URL)/docs > /dev/null; then echo "API already running at $(API_BASE_URL)"; exit 0; fi; \
	mkdir -p storage/logs; \
	uv run python -u _brief/api/server.py --port $(API_PORT) > storage/logs/api.log 2>&1 & echo $$! > $(API_PID_FILE); \
	for i in $$(seq 1 30); do curl -sf $(API_BASE_URL)/docs > /dev/null && exit 0; sleep 0.5; done; \
	echo "API did not answer at $(API_BASE_URL)/docs within 15 s (see storage/logs/api.log)" >&2; \
	kill $$(cat $(API_PID_FILE)) 2> /dev/null; rm -f $(API_PID_FILE); exit 1

api-stop:
	@if [ -f $(API_PID_FILE) ]; then kill $$(cat $(API_PID_FILE)) 2> /dev/null && echo "API stopped"; rm -f $(API_PID_FILE); fi

# API and Excel -> storage/bucket/ files (extract.py); needs the API running.
extract:
	uv run python ingestion/extract.py

# storage/bucket/ files -> schema raw, rebuilt from all files (load.py runs load.sql).
load:
	uv run python ingestion/load.py

# Seeds, models and tests: raw -> staging (-> prep -> marts).
build:
	$(DBT) deps --profiles-dir .
	$(DBT) build --profiles-dir .

# Brief § 3.3, a second run creates no duplicates: run twice, the row count of every table must match.
# raw.load_history is left out: it grows by one row per run by design (the run record).
COUNTS = uv run python -c "import duckdb; db = duckdb.connect('storage/warehouse.duckdb', read_only=True); \
	[print(s, t, db.sql(f'select count(*) from {s}.{t}').fetchone()[0]) \
	for s, t in db.sql('select table_schema, table_name from information_schema.tables \
	where not (table_schema = \'raw\' and table_name = \'load_history\') order by all').fetchall()]"
check:
	$(MAKE) run && $(COUNTS) > storage/counts_first_run.txt
	$(MAKE) run && $(COUNTS) > storage/counts_second_run.txt
	diff storage/counts_first_run.txt storage/counts_second_run.txt && echo "second run: same row counts"

# The five answers at the defaults: serving/questions/q<n>_*.sql -> .csv beside each, Markdown on stdout.
answers:
	uv run python serving/answers.py

# The dashboard on the warehouse, read-only (serving/dashboard.py); needs a finished build.
dashboard:
	uv run streamlit run serving/dashboard.py

# Checks SQL (sqlfluff, rules in transform/.sqlfluff) and Python (ruff); changes nothing.
lint:
	uv run ruff check .
	cd transform && uv run sqlfluff lint models tests macros

# Rewrites SQL and Python to the conventions.
fmt:
	uv run ruff check --fix .
	uv run ruff format .
	cd transform && uv run sqlfluff fix models tests macros

# Back to a fresh clone: landed files and watermarks, the warehouse, dbt artefacts.
clean:
	rm -rf storage
	rm -rf transform/target transform/logs transform/dbt_packages
