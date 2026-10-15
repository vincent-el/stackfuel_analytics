-- One row per enrollment aktiv or pausiert at the end of reference_date, with the coach and the
-- Ampel of its counted line in the coach list. Q5. coach_key null is a Teilnahme without a coach;
-- the sheet has no history, so the Ampel is as delivered whatever the reference_date.

{{ config(parameters=["reference_date := date '2026-08-31'"]) }}

with status_periods as (
    select * from {{ ref('fct_enrollment_status_periods') }}
),

coach_assignments as (
    select * from {{ ref('fct_coach_assignments') }}
),

as_of as (
    select cast(concat(cast(reference_date as date), ' 23:59:59') as timestamp) as reference_ts
),

population as (
    select
        status_periods.enrollment_id,
        status_periods.training_id,
        status_periods.cohort_key,
        status_periods.participant_id,
        status_periods.status
    from status_periods
    -- one row: puts reference_ts beside every row, multiplies nothing
    cross join as_of
    where
        status_periods.status in ('aktiv', 'pausiert')
        and status_periods.valid_from <= as_of.reference_ts
        and status_periods.valid_to > as_of.reference_ts
),

transformed as (
    select
        -- Primary Key
        population.enrollment_id,

        -- Foreign Keys
        population.training_id,
        population.cohort_key,
        population.participant_id,
        coach_assignments.coach_key,

        -- Dimensions
        population.status,
        coach_assignments.ampel

    from population
    left join coach_assignments
        on population.enrollment_id = coach_assignments.enrollment_id
)

select * from transformed
