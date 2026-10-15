-- One row per training.

with source as (
    select * from {{ source('catalog', 'trainings') }}
),

transformed as (
    select
        -- Primary Key
        training_id,

        -- Dimensions
        training_name,
        track,
        variant,
        is_active,
        modules,  -- JSON array

        -- Measures
        cast(duration_weeks as integer) as duration_weeks,
        cast(list_price_eur as integer) as list_price_eur,

        -- Metadata
        {{ to_reporting_time('_loaded_at', 'loader') }} as _loaded_at

    from source
)

select * from transformed
