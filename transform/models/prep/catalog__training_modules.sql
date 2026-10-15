-- One row per module, unnested from the trainings' modules array.

with trainings as (
    select * from {{ ref('stg_catalog__trainings') }}
),

unnested as (
    select
        training_id,
        unnest(cast(modules as json[])) as module,
        _loaded_at
    from trainings
),

transformed as (
    select
        -- Primary Key
        module ->> 'module_id' as module_id,

        -- Foreign Keys
        training_id,

        -- Dimensions
        module ->> 'module_name' as module_name,
        cast(module ->> 'module_order' as integer) as module_order,

        -- Measures
        cast(module ->> 'estimated_hours' as integer) as estimated_hours,

        -- Metadata
        _loaded_at

    from unnested
)

select * from transformed
