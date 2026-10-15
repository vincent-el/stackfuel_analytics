-- Pinned: Q2 as README § Results states it, through the function at the Stichtag, over all
-- trainings, funding types and plan-end quarters: n and the three outcomes that add to it. A
-- failure means a definition or the delivery changed the number; README and test move together.

{{ config(tags = ['pinned']) }}

with as_of_stichtag as (
    select
        sum(enrollment_count) filter (where outcome is not null) as n,
        sum(enrollment_count) filter (where outcome = 'abgeschlossen') as completed,
        sum(enrollment_count) filter (where outcome = 'abgebrochen') as dropped_out,
        sum(enrollment_count) filter (where outcome = 'offen') as still_open
    from {{ ref('report_completion_rates') }}(date '2026-08-31')
)

select *
from as_of_stichtag
where not (n = 498 and completed = 353 and dropped_out = 88 and still_open = 57)
