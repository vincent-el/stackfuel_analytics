-- One row per cohort: a training and a start date.

with enrollments as (
    select * from {{ ref('crm__enrollments') }}
),

transformed as (
    select
        -- Primary Key
        cohort_key,

        -- Foreign Keys
        training_id,

        -- Dates
        cohort_start_date,
        cast(date_trunc('month', cohort_start_date) as date) as cohort_month,

        -- Measures
        count(*) as enrollment_count,

        -- Metadata
        max(_loaded_at) as _loaded_at

    from enrollments
    group by cohort_key, training_id, cohort_start_date
)

select * from transformed
