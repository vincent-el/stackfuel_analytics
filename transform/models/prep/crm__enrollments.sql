-- One row per enrollment (Teilnahme), the latest landed version.

with enrollments as (
    select * from {{ ref('stg_crm__enrollments') }}
),

latest_version as (
    select *
    from enrollments
    qualify row_number() over (partition by enrollment_id order by modified_at desc) = 1
),

transformed as (
    select
        -- Primary Key
        enrollment_id,

        -- Foreign Keys
        participant_id,
        training_id,
        training_id || '@' || cast(cohort_start_date as varchar) as cohort_key,

        -- Dates
        cohort_start_date,
        planned_end_date,

        -- Timestamps
        status_changed_at,
        created_at,
        modified_at,

        -- Dimensions
        status,

        -- Metadata
        _loaded_at

    from latest_version
)

select * from transformed
