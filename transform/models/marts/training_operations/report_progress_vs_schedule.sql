-- One row per enrollment aktiv at the end of reference_date (Q1's population): the modules
-- completed against the planned time elapsed, both as counts and in percent, their gap in
-- percentage points, and the flag im Verzug: the gap is at least behind_schedule_pp. Q3.
--
-- Three enrollments at the Stichtag (31.08.2026), threshold 15:
-- enrollment | start      | plan end    | modules | days      | time % | modules % | gap  | behind
-- 50036 T03  | 06.07.2026 | 23.11.2026  | 4 of 12 | 56 / 140  | 40.0   | 33.3      | 6.7  | no
-- 50443 T04  | 11.05.2026 | 15.02.2027  | 3 of 12 | 112 / 280 | 40.0   | 25.0      | 15.0 | yes
-- 50034 T06  | 12.05.2025 | 04.08.2025  | 6 of 6  | 84 / 84   | 100.0  | 100.0     | 0.0  | no
-- The third is past its planned end: the days elapsed are held at the plan's length.

{{ config(parameters=["reference_date := date '2026-08-31'", "behind_schedule_pp := 15"]) }}

with status_periods as (
    select * from {{ ref('fct_enrollment_status_periods') }}
),

progress_events as (
    select * from {{ ref('fct_module_progress_events') }}
),

trainings as (
    select * from {{ ref('dim_trainings') }}
),

as_of as (
    select
        cast(reference_date as date) as reference_day,
        cast(concat(cast(reference_date as date), ' 23:59:59') as timestamp) as reference_ts
),

active_enrollments as (
    select
        status_periods.enrollment_id,
        status_periods.training_id,
        status_periods.cohort_key,
        status_periods.participant_id,
        status_periods.cohort_start_date,
        status_periods.planned_end_date
    from status_periods
    -- one row: puts reference_ts beside every row, multiplies nothing
    cross join as_of
    where
        -- aktiv only: paused learners are not behind, they are paused
        status_periods.status = 'aktiv'
        -- the period holds at the end of reference_date
        and status_periods.valid_from <= as_of.reference_ts
        and status_periods.valid_to > as_of.reference_ts
),

latest_progress as (
    select
        progress_events.enrollment_id,
        progress_events.modules_completed_so_far
    from progress_events
    cross join as_of
    where progress_events.event_at <= as_of.reference_ts
    -- the last event per enrollment; event_id breaks a tie at the same moment
    qualify
        row_number() over (
            partition by progress_events.enrollment_id
            order by progress_events.event_at desc, progress_events.event_id desc
        ) = 1
),

-- The counts behind the two percentages: modules completed of modules planned, days elapsed of
-- days planned.
counts as (
    select
        active_enrollments.enrollment_id,
        active_enrollments.training_id,
        active_enrollments.cohort_key,
        active_enrollments.participant_id,
        -- no event yet means nothing completed
        coalesce(latest_progress.modules_completed_so_far, 0) as modules_completed,
        trainings.module_count as modules_in_training,
        -- the plan's length: calendar days from the cohort start to the planned end
        datediff('day', active_enrollments.cohort_start_date, active_enrollments.planned_end_date)
            as planned_duration_days,
        -- where reference_day lies in the plan: negative before the start, beyond the length when
        -- overdue
        datediff('day', active_enrollments.cohort_start_date, as_of.reference_day)
            as days_since_cohort_start,
        -- the same, held within the plan, so that time progress runs from 0 to 100 %:
        --   before the start (days_since_cohort_start < 0)        -> 0
        --   inside the plan                                        -> days_since_cohort_start
        --   past the end (days_since_cohort_start > plan length)  -> planned_duration_days
        least(greatest(days_since_cohort_start, 0), planned_duration_days)
            as days_elapsed_within_plan
    from active_enrollments
    -- one row: puts reference_day beside every row, multiplies nothing
    cross join as_of
    -- every enrollment's training exists in the dimension (relationships test)
    left join trainings
        on active_enrollments.training_id = trainings.training_id
    -- an enrollment without an event keeps its row, with 0 modules completed
    left join latest_progress
        on active_enrollments.enrollment_id = latest_progress.enrollment_id
),

-- The two percentages, their gap, and the flag: the definition of im Verzug.
transformed as (
    select
        -- Primary Key
        enrollment_id,

        -- Foreign Keys
        training_id,
        cohort_key,
        participant_id,

        -- Measures
        modules_completed,
        modules_in_training,
        100.0 * modules_completed / modules_in_training as modules_completed_pct,
        planned_duration_days,
        days_elapsed_within_plan,
        100.0 * days_elapsed_within_plan / planned_duration_days as time_elapsed_within_plan_pct,
        -- how far the planned time has run ahead of the modules completed, in percentage points
        time_elapsed_within_plan_pct - modules_completed_pct as schedule_gap_pp,

        -- Dimensions
        -- im Verzug: the gap reaches the threshold; the one place the threshold is applied
        schedule_gap_pp >= behind_schedule_pp as is_behind_schedule

    from counts
)

select * from transformed
