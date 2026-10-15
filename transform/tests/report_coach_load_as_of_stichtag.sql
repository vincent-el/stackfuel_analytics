-- Pinned: Q5 as README § Results states it, through the function at the Stichtag, over all
-- coaches: the Teilnahmen aktiv or pausiert, with a coach, on rot, without a coach. A failure means
-- a definition or the delivery changed the number; README and test move together.

{{ config(tags = ['pinned']) }}

with as_of_stichtag as (
    select
        count(*) as enrollments,
        count(coach_key) as with_coach,
        count(*) filter (where ampel = 'rot') as on_red,
        count(*) filter (where coach_key is null) as without_coach
    from {{ ref('report_coach_load') }}(date '2026-08-31')
)

select *
from as_of_stichtag
where not (enrollments = 197 and with_coach = 180 and on_red = 31 and without_coach = 17)
