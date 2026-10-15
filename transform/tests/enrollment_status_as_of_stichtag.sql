-- Pinned: the readings of README § Status at a date, aktiv and pausiert at the Stichtag (end of
-- 31.08.2026 = ts 2026-09-01 00:00), observed only and with inferred periods. A failure means a
-- definition or the delivery changed the number; README and test move together.

{{ config(tags = ['pinned']) }}

with as_of_stichtag as (
    select
        status,
        count(*) filter (where not is_inferred) as observed_enrollments,
        count(*) as enrollments_with_inferred
    from {{ ref('fct_enrollment_status_periods') }}
    where
        valid_from <= cast('2026-09-01 00:00:00' as timestamp)
        and valid_to > cast('2026-09-01 00:00:00' as timestamp)
    group by status
),

expected as (
    select
        'aktiv' as status,
        159 as observed_enrollments,
        172 as enrollments_with_inferred
    union all
    select
        'pausiert' as status,
        25 as observed_enrollments,
        25 as enrollments_with_inferred
)

select
    expected.status,
    expected.observed_enrollments as expected_observed,
    as_of_stichtag.observed_enrollments as actual_observed,
    expected.enrollments_with_inferred as expected_with_inferred,
    as_of_stichtag.enrollments_with_inferred as actual_with_inferred
from expected
left join as_of_stichtag
    on expected.status = as_of_stichtag.status
where
    as_of_stichtag.status is null
    or expected.observed_enrollments <> as_of_stichtag.observed_enrollments
    or expected.enrollments_with_inferred <> as_of_stichtag.enrollments_with_inferred
