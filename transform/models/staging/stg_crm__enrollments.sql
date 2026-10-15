-- One row per landed version of an enrollment (Teilnahme).

with source as (
    select * from {{ source('crm', 'enrollments') }}
),

transformed as (
    select
        -- Primary Key
        enrollment_id,

        -- Foreign Keys
        participant_id,
        training_id,

        -- Dates
        cast(cohort_start_date as date) as cohort_start_date,
        cast(planned_end_date as date) as planned_end_date,

        -- Timestamps
        {{ to_reporting_time('status_changed_at', 'crm') }} as status_changed_at,
        {{ to_reporting_time('created_at', 'crm') }} as created_at,
        {{ to_reporting_time('modified_at', 'crm') }} as modified_at,

        -- Dimensions
        lower(trim(status)) as status,

        -- Metadata
        {{ to_reporting_time('_loaded_at', 'loader') }} as _loaded_at

    from source
)

select * from transformed
