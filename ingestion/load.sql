-- Raw = as delivered: every table rebuilt from all landed files. No dedup, no typing.
-- dateformat/timestampformat 'none': otherwise DuckDB types '…T10:15:00' as a timestamp and
-- silently drops the Z of '…T09:15:00Z'. Raw keeps the strings; staging decides time zones.
create schema if not exists raw;
create or replace macro landed(files) as table
  select *, current_timestamp at time zone 'UTC' as _loaded_at  -- UTC on any machine
  from read_json(files, filename = '_source', union_by_name = true, dateformat = 'none', timestampformat = 'none');
create or replace table raw.catalog__trainings        as from landed('storage/bucket/catalog__trainings/*.json');
create or replace table raw.crm__participants         as from landed('storage/bucket/crm__participants/*.json');
create or replace table raw.crm__enrollments          as from landed('storage/bucket/crm__enrollments/*.json');
create or replace table raw.lxp__progress_events      as from landed('storage/bucket/lxp__progress_events/*.json');
create or replace table raw.lxp__survey_responses     as from landed('storage/bucket/lxp__survey_responses/*.json');
create or replace table raw.coach_list__betreuung     as from landed('storage/bucket/coach_list__betreuung/*.json');
create or replace table raw.coach_list__legende       as from landed('storage/bucket/coach_list__legende/*.json');
-- The run record: one row per load, the per-table detail nested (extract.py). No dbt source reads it.
create or replace table raw.load_history              as from landed('storage/bucket/_load_history/*.json');
