-- One row per training in the catalog.

with trainings as (
    select * from {{ ref('stg_catalog__trainings') }}
),

training_modules as (
    select * from {{ ref('catalog__training_modules') }}
),

module_counts as (
    select
        training_id,
        count(*) as module_count
    from training_modules
    group by training_id
),

transformed as (
    select
        -- Primary Key
        trainings.training_id,

        -- Dimensions
        trainings.training_name,
        trainings.track,
        trainings.variant,
        trainings.is_active,

        -- Measures
        trainings.duration_weeks,
        trainings.list_price_eur,
        coalesce(module_counts.module_count, 0) as module_count,

        -- Metadata
        trainings._loaded_at

    from trainings
    left join module_counts
        on trainings.training_id = module_counts.training_id
)

select * from transformed
