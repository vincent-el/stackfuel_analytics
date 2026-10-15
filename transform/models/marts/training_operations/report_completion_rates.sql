-- One cell per training × funding type × quarter of the planned end × status: the enrollments
-- whose planned end lies before reference_date, by their status at the end of reference_date. Q2.
-- The ruling travels as outcome: abgeschlossen, abgebrochen or offen, the three shares that add to
-- n; a cancelled booking (storniert) has no outcome and is counted beside them, never inside n.
-- A window of planned-end quarters narrows the population; null on both ends is every quarter,
-- the Brief's answer.

{{ config(parameters=[
    "reference_date := date '2026-08-31'",
    "planned_end_from := null",
    "planned_end_to := null"
]) }}

with status_periods as (
    select * from {{ ref('fct_enrollment_status_periods') }}
),

-- Funding type sits on the participant record, not on the enrollment.
participants as (
    select * from {{ ref('dim_participants') }}
),

dates as (
    select * from {{ ref('dim_date') }}
),

-- The reading is "at the end of reference_date": the last second of that day. A period holds at
-- reference_ts when valid_from <= reference_ts < valid_to. reference_day compares with dates. The
-- window's bounds ride along, so every parameter is read from this one row.
as_of as (
    select
        cast(reference_date as date) as reference_day,
        cast(concat(cast(reference_date as date), ' 23:59:59') as timestamp) as reference_ts,
        -- cast and alias, so a null default still yields a column of this name and type
        cast(planned_end_from as varchar) as planned_end_from,
        cast(planned_end_to as varchar) as planned_end_to
),

-- The population and each enrollment's status at the end of reference_date.
population as (
    select
        status_periods.enrollment_id,
        status_periods.training_id,
        participants.funding_type,
        dates.quarter_label as planned_end_quarter,
        status_periods.status
    from status_periods
    -- one row: puts reference_day and reference_ts beside every row, multiplies nothing
    cross join as_of
    -- every participant id has a row in the dimension, an unknown one with 'unbekannt'
    left join participants
        on status_periods.participant_id = participants.participant_id
    left join dates
        on status_periods.planned_end_date = dates.date_day
    where
        -- the Brief's population: the planned end lies before reference_date
        status_periods.planned_end_date < as_of.reference_day
        -- the window of planned-end quarters, by dim_date's label (2026-Q2); null is no bound
        and (as_of.planned_end_from is null or dates.quarter_label >= as_of.planned_end_from)
        and (as_of.planned_end_to is null or dates.quarter_label <= as_of.planned_end_to)
        -- the period holds at the end of reference_date
        and status_periods.valid_from <= as_of.reference_ts
        and status_periods.valid_to > as_of.reference_ts
),

transformed as (
    select
        -- Foreign Keys
        training_id,

        -- Dimensions
        funding_type,
        planned_end_quarter,
        status,
        -- the ruling: a cancelled booking has no outcome; finished and dropped keep their status;
        -- every other status past the plan (aktiv, pausiert, angemeldet, unbekannt) is offen
        case
            when status = 'storniert' then null
            when status in ('abgeschlossen', 'abgebrochen') then status
            else 'offen'
        end as outcome,

        -- Measures
        count(*) as enrollment_count

    from population
    group by all
)

select * from transformed
