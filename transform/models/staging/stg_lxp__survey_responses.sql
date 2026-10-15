-- One row per answered question.

with source as (
    select * from {{ source('lxp', 'survey_responses') }}
),

transformed as (
    select
        -- Primary Key
        response_id,

        -- Foreign Keys
        enrollment_id,

        -- Timestamps
        {{ to_reporting_time('submitted_at', 'lxp') }} as submitted_at,

        -- Dimensions
        survey_type,
        cast(survey_week as integer) as survey_week,
        question_key,
        nullif(trim(source.answer_value), '') as answer_value,  -- empty answers become null

        -- Measures
        -- "8" and "10/10" read as 8 and 10; free text has no score
        try_cast(regexp_extract(trim(source.answer_value), '^(\d+)(/\d+)?$', 1) as integer)
            as answer_score,

        -- Metadata
        {{ to_reporting_time('_loaded_at', 'loader') }} as _loaded_at

    from source
)

select * from transformed
