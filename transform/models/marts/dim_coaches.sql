-- One row per coach named in the coach list.

with coach_assignments as (
    select * from {{ ref('stg_coach_list__assignments') }}
),

transformed as (
    select
        -- Primary Key: the name as a slug (daniel_brandt)
        lower(regexp_replace(strip_accents(coach_name), '[^A-Za-z0-9]+', '_', 'g')) as coach_key,

        -- Dimensions
        coach_name,

        -- Metadata
        max(_loaded_at) as _loaded_at

    from coach_assignments
    group by coach_name
)

select * from transformed
