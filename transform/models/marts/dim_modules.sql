-- One row per module of a training.

with modules as (
    select * from {{ ref('catalog__training_modules') }}
),

transformed as (
    select
        -- Primary Key
        module_id,

        -- Foreign Keys
        training_id,

        -- Dimensions
        module_order,
        module_name,

        -- Measures
        estimated_hours,

        -- Metadata
        _loaded_at

    from modules
)

select * from transformed
