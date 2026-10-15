-- Pinned: Q3 as README § Results states it, through the function at the Stichtag and 15 pp, over
-- all trainings: the aktiv Teilnahmen and those im Verzug. A failure means a definition or the
-- delivery changed the number; README and test move together.

{{ config(tags = ['pinned']) }}

with as_of_stichtag as (
    select
        count(*) as enrollments,
        count(*) filter (where is_behind_schedule) as behind_schedule
    from {{ ref('report_progress_vs_schedule') }}(date '2026-08-31', 15)
)

select *
from as_of_stichtag
where not (enrollments = 172 and behind_schedule = 61)
