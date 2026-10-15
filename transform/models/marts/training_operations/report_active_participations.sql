-- One cell per training × status (aktiv, pausiert): the enrollments in that status at the end of
-- reference_date. Q1. Every training gets both cells, 0 when empty; inferred periods count.

{{ config(parameters=["reference_date := date '2026-08-31'"]) }}

with status_periods as (
    select * from {{ ref('fct_enrollment_status_periods') }}
),

trainings as (
    select * from {{ ref('dim_trainings') }}
),

-- The reading is "at the end of reference_date": the last second of that day. A period holds at
-- reference_ts when valid_from <= reference_ts < valid_to.
as_of as (
    select cast(concat(cast(reference_date as date), ' 23:59:59') as timestamp) as reference_ts
),

-- Every training × both statuses, so a training with nobody paused still shows a 0 cell instead
-- of a missing row:
--   training_id | status   | enrollment_count
--   T01         | aktiv    | 47
--   T01         | pausiert | 5
--   T02         | aktiv    | 25
--   T02         | pausiert | 0      <- the row the grid adds
cells as (
    select
        trainings.training_id,
        statuses.status
    from trainings
    -- two rows, one per status the question asks about; every training gets both
    cross join (values ('aktiv'), ('pausiert')) as statuses (status)
),

-- The periods that hold at reference_ts, counted per training and status.
counted as (
    select
        status_periods.training_id,
        status_periods.status,
        count(*) as enrollment_count
    from status_periods
    cross join as_of
    where
        -- Q1 asks for aktiv; pausiert is reported beside it, never inside
        status_periods.status in ('aktiv', 'pausiert')
        -- the period holds at the end of reference_date
        and status_periods.valid_from <= as_of.reference_ts
        and status_periods.valid_to > as_of.reference_ts
    group by all
),

transformed as (
    select
        -- Foreign Keys
        cells.training_id,

        -- Dimensions
        cells.status,

        -- Measures
        coalesce(counted.enrollment_count, 0) as enrollment_count

    from cells
    left join counted
        on cells.training_id = counted.training_id and cells.status = counted.status
)

select * from transformed
