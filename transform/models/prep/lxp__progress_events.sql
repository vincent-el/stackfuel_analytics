-- One row per event, delivered copies removed.

with progress_events as (
    select * from {{ ref('stg_lxp__progress_events') }}
),

deduplicated as (
    select *
    from progress_events
    qualify row_number() over (partition by event_id order by _loaded_at) = 1
)

select * from deduplicated
