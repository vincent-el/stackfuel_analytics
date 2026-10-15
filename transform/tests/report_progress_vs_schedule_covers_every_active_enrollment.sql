-- Contract: Q3's population is Q1's aktiv. At the Stichtag, report_progress_vs_schedule returns
-- one row per enrollment that report_active_participations counts as aktiv, no more and no fewer.

{{ config(tags = ['contract']) }}

with active_count as (
    select sum(enrollment_count) as enrollments
    from {{ ref('report_active_participations') }}(date '2026-08-31')
    where status = 'aktiv'
),

progress_rows as (
    select
        count(*) as enrollments,
        count(distinct enrollment_id) as distinct_enrollments
    from {{ ref('report_progress_vs_schedule') }}(date '2026-08-31', 15)
)

select
    active_count.enrollments as active_enrollments,
    progress_rows.enrollments as progress_rows,
    progress_rows.distinct_enrollments
from active_count
cross join progress_rows
where
    active_count.enrollments <> progress_rows.enrollments
    or progress_rows.enrollments <> progress_rows.distinct_enrollments
