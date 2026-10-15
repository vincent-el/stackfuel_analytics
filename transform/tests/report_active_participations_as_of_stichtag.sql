-- Pinned: Q1 as README § Results states it, through the function at the Stichtag, over all
-- trainings (the same numbers as enrollment_status_as_of_stichtag). A failure means a definition or
-- the delivery changed the number; README and test move together.

{{ config(tags = ['pinned']) }}

with as_of_stichtag as (
    select
        status,
        sum(enrollment_count) as enrollments
    from {{ ref('report_active_participations') }}(date '2026-08-31')
    group by status
),

expected as (
    select
        'aktiv' as status,
        172 as enrollments
    union all
    select
        'pausiert' as status,
        25 as enrollments
)

select
    expected.status,
    expected.enrollments as expected_enrollments,
    as_of_stichtag.enrollments as actual_enrollments
from expected
left join as_of_stichtag
    on expected.status = as_of_stichtag.status
where
    as_of_stichtag.status is null
    or expected.enrollments <> as_of_stichtag.enrollments
