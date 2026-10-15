# transform

The dbt project `stackfuel_analytics`: conventions and rules, for people and agents alike.

## Layers

| Layer | Schema | Rule | Named |
|:--|:--|:--|:--|
| **raw** | `raw` | As landed; the contract in `models/staging/_sources.yml` | `raw.crm__enrollments` |
| **staging** | `stg` | 1:1 with a raw table: rename, cast, reporting timezone, normalised spellings, data-quality flags. No joins, dedup, filtering, business logic | `stg_<source>__<entity>` |
| **prep** | `prep` | Within one source: latest version per key, dedup, unnesting, constructed keys. Optional | `<source>__<entity>` |
| **marts** | `mart` | Across sources: the star (`dim_`, `fct_`), entity resolution as `int_` models read by the fact that needs it (the coach match). department reports as table functions, one `{department}/` subfolder each | `fct_enrollment_status_periods` |
| **seeds** | `seeds` | Hand-kept mapping tables as CSV; joined in marts, never read in staging | `coach_list_training_spellings` |
| **tests** | `dbt_test__audit` | Not a layer: every test's failing rows, replaced per build (`store_failures`) | `dbt_test__audit.<test name>` |

## Model template

```sql
-- One row per <grain>.

with <table or process> as (          -- `source` only in staging
    select * from {{ ref('upstream') }}
),

transformed as (
    select
        -- Primary Key
        -- Foreign Keys
        -- Dates
        -- Timestamps
        -- Dimensions
        -- Measures
        -- Data-quality flags
        -- Metadata
    from <table or process>
)

select * from transformed
```

- **Comments:** the first line is one line of grain; the yml carries the description. A header paragraph beyond it only where the model encodes a significant ruling (the status periods, the coach match). A body comment where a line of logic needs one (a regex, a union case, a join that drops or multiplies), never a pattern the README explains, never another model.
- **Sections** in the order above; the model ends with `select * from` its last CTE.
- **CTEs:** every `ref()` (`source()` in staging) sits in an import CTE at the top of the file, one per upstream model, `select * from` and nothing else, named after what it reads (`enrollments`, `progress_events`); no `ref()` anywhere below. Logic CTEs follow, named after the process or the result (`periods`, `active_enrollments`), the function's `as_of` first among them.
- **Joins:** left by default. Any inner, right, full or cross join carries a one-line comment saying what it drops or multiplies and why. Relationships tests, not joins, guarantee keys.
- **Timezone:** timestamps are converted once, in staging, with `to_reporting_time(column, source_system)`; the zone is the var `reporting_timezone`.
- **Cleaning is visible:** a bad value becomes null or a canonical value in one `nullif` or `case when`; nothing is filtered.
- **Unknown members** of a dimension carry `unbekannt` in every categorical column, null in names, email, dates and timestamps.
- **Open-ended periods** end at `9999-12-31`; `is_current` marks them.

## Naming

Full words, no abbreviations beyond the layer prefixes.

| Element | Convention | Example |
|:--|:--|:--|
| Models | snake_case, layer prefix | `stg_crm__enrollments` |
| Source keys | `_id`, as the source names them | `enrollment_id` |
| Built keys | `_key`, computed once in the earliest model that has the inputs | `cohort_key`, `person_key` |
| Timestamps | `_at`, reporting timezone | `created_at` |
| Dates | `_date` | `planned_end_date` |
| Booleans | `is_`, `has_`, `was_` | `is_current` |
| Data-quality flags | `is_<issue>`, true = issue present; `data_quality_issues` lists the codes of the set flags | `is_email_missing` |
| Metadata | leading `_` | `_loaded_at` |

Names promise types; `check_column_names_match_types` fails the build on a mismatch.

## Descriptions

A description says what a thing is, never what the data is today: no counts, no "for some", no pointer to the README or another model, no general pattern, no tool names. Enumerate values only where an `accepted_values` test exists on the column; otherwise at most two examples. Drop a description that only restates the column name or an obvious join. A data-quality flag's description starts with "Data-quality flag:".

## Tests

A test says what must be true; dbt's test config says how much we tolerate.

- **Kinds:** every test is tagged with one of three kinds; a singular test opens with its kind as the first word. Untagged yml tests are the column invariants of the model they sit on.

| Kind | Says | Run |
|:--|:--|:--|
| `contract` | what must hold for the star to be the star: keys, no overlapping periods, Q3's population is Q1's aktiv | every build |
| `pinned` | a README number read through its function at the Stichtag. A pin proves nothing about the number; it notices when a definition or the delivery changes it, so README and test move together | `dbt test --select tag:pinned` after a live edit shows which numbers moved |
| `finding` | one tolerated data-quality defect, named after it | `dbt test --select tag:finding` runs the registry |

- **Where:** a yml test carries one column's invariant (`unique`, `not_null`, `accepted_values`, `relationships`, a range); a singular test in `tests/` carries anything across rows or models, and every pinned KPI. One file per finding, named after it; a finding that is one column's invariant may stay a named yml test (`participants_have_a_birth_date`) as long as its owner is the model's.
- **Once:** a column's invariant is tested where the column is produced. Exception: every dim and fact tests its keys (primary `unique` + `not_null`, foreign `not_null` + `relationships`), the star's contract.
- **No tautologies:** nothing tests what the model's SQL makes true by construction (`not_null` on a `coalesce`, a window function or a literal; `unique` after `qualify row_number() = 1`; `relationships` to a model the same model built its rows from; a `where` clause restated).
- **Findings:** every tolerated data-quality finding has exactly one test, named after the finding:

```
Does the problem occur in today's data?
├─ no  → test, severity error
└─ yes → fixed by one line in staging?
         ├─ yes → that line; no test
         └─ no  → would a KPI be wrong if it grew?
                  ├─ yes → test with a ceiling, error_if: ">n"
                  └─ no  → test, severity warn
```

- **Numbers:** a number inside a test is a ceiling on a finding (`error_if`) or a pinned README reading. No finding test asserts today's count; the warn prints it.
- **Rows:** `store_failures` is on for every test; the failing rows sit in `dbt_test__audit.<test name>`.
- **Owners:** every model and test has a `group` (`models/_groups.yml`, the departments as the careers page names them; assigned in `dbt_project.yml`): staging belongs to the source's department, everything after to Data. A yml test belongs to its model's group and cannot be moved; a singular finding test carries the group of the source it checks, so `dbt ls --select tag:finding --output-keys name group` is the routing table. The alert path is production (Elementary).
- One yml per layer folder plus `seeds/_seeds.yml`.

## Materialization

Staging and prep are views, marts are tables; `marts/{department}/` are table functions: parameterised SQL over the star with no data of their own.

## Tooling

- **Packages:** `dbt_date` (timezone conversion, `dim_date`). Add a package only when it replaces code we would otherwise write.
- **Macros:** `generate_schema_name` (schemas `raw`, `stg`, `prep`, `mart` as named), `to_reporting_time` (the one timezone conversion), `check_column_names_match_types` (on-run-end).
- **Layout:** `.sqlfluff` (indent, casing, lines). `make lint` checks, `make fmt` rewrites.
