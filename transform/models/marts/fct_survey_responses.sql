-- One row per answered survey question.

with survey_responses as (
    select * from {{ ref('stg_lxp__survey_responses') }}
),

enrollments as (
    select * from {{ ref('crm__enrollments') }}
),

transformed as (
    select
        -- Primary Key
        survey_responses.response_id,

        -- Foreign Keys
        survey_responses.enrollment_id,
        enrollments.training_id,
        enrollments.cohort_key,
        enrollments.participant_id,

        -- Timestamps
        survey_responses.submitted_at,

        -- Dimensions
        survey_responses.survey_type,
        survey_responses.survey_week,
        survey_responses.question_key,
        survey_responses.answer_value,

        -- Measures
        survey_responses.answer_score,

        -- Metadata
        survey_responses._loaded_at

    from survey_responses
    left join enrollments
        on survey_responses.enrollment_id = enrollments.enrollment_id
)

select * from transformed
