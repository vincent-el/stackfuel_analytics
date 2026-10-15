-- One row per delivered event row.

with source as (
    select * from {{ source('lxp', 'progress_events') }}
),

transformed as (
    select
        -- Primary Key
        event_id,

        -- Foreign Keys
        enrollment_id,
        module_id,

        -- Timestamps
        {{ to_reporting_time('event_time', 'lxp') }} as event_at,

        -- Dimensions
        event_type,

        -- Metadata
        {{ to_reporting_time('_loaded_at', 'loader') }} as _loaded_at

    from source
)

select * from transformed
