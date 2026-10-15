-- One cell per training × quarter of submission × respondent status: the final-feedback NPS
-- answers by the end of reference_date, as promoters (9-10), passives (7-8), detractors (0-6) and
-- their sum. Q4. The quarter is the exit quarter; the status at the end of reference_date says
-- whether a completer or a dropout answered, so the reader scores all answers or completers only.

{{ config(parameters=["reference_date := date '2026-08-31'"]) }}

with survey_responses as (
    select * from {{ ref('fct_survey_responses') }}
),

status_periods as (
    select * from {{ ref('fct_enrollment_status_periods') }}
),

dates as (
    select * from {{ ref('dim_date') }}
),

-- The reading is "at the end of reference_date": the last second of that day. An answer counts
-- when submitted_at <= reference_ts; the respondent's status is the period that holds then.
as_of as (
    select cast(concat(cast(reference_date as date), ' 23:59:59') as timestamp) as reference_ts
),

-- The NPS answers submitted by reference_ts, each with its quarter and its respondent's status.
answers as (
    select
        survey_responses.training_id,
        dates.quarter_start_date,
        dates.quarter_label,
        status_periods.status as respondent_status,
        survey_responses.answer_score
    from survey_responses
    -- one row: puts reference_ts beside every row, multiplies nothing
    cross join as_of
    -- a day outside the calendar's range would keep its answer with a null quarter
    left join dates
        on cast(survey_responses.submitted_at as date) = dates.date_day
    -- exactly one period holds at reference_ts (the periods do not overlap), so nothing multiplies
    left join status_periods
        on
            survey_responses.enrollment_id = status_periods.enrollment_id
            and as_of.reference_ts >= status_periods.valid_from
            and as_of.reference_ts < status_periods.valid_to
    where
        -- the Brief's question: the NPS item of the final feedback
        survey_responses.survey_type = 'abschlussfeedback'
        and survey_responses.question_key = 'nps'
        -- an empty answer is not a response
        and survey_responses.answer_score is not null
        -- submitted by the end of reference_date
        and survey_responses.submitted_at <= as_of.reference_ts
),

transformed as (
    select
        -- Foreign Keys
        training_id,

        -- Dates
        quarter_start_date,

        -- Dimensions
        quarter_label,
        respondent_status,

        -- Measures
        count(*) filter (where answer_score >= 9) as promoters,
        count(*) filter (where answer_score between 7 and 8) as passives,
        count(*) filter (where answer_score <= 6) as detractors,
        count(*) as responses

    from answers
    group by all
)

select * from transformed
