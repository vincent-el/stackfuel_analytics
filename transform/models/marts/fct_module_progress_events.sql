-- One row per LXP progress event.

with progress_events as (
    select * from {{ ref('lxp__progress_events') }}
),

enrollments as (
    select * from {{ ref('crm__enrollments') }}
),

modules as (
    select * from {{ ref('dim_modules') }}
),

trainings as (
    select * from {{ ref('dim_trainings') }}
),

joined as (
    select
        progress_events.event_id,
        progress_events.enrollment_id,
        progress_events.module_id,
        enrollments.training_id,
        enrollments.cohort_key,
        enrollments.participant_id,
        progress_events.event_at,
        progress_events.event_type,
        modules.module_order,
        trainings.module_count as modules_in_training,
        -- An unknown module counts as foreign.
        coalesce(modules.training_id <> enrollments.training_id, true)
            as is_module_of_other_training,
        progress_events._loaded_at
    from progress_events
    left join enrollments
        on progress_events.enrollment_id = enrollments.enrollment_id
    left join trainings
        on enrollments.training_id = trainings.training_id
    left join modules
        on progress_events.module_id = modules.module_id
),

transformed as (
    select
        -- Primary Key
        event_id,

        -- Foreign Keys
        enrollment_id,
        module_id,
        training_id,
        cohort_key,
        participant_id,

        -- Timestamps
        event_at,

        -- Dimensions
        event_type,
        case when not is_module_of_other_training then module_order end as module_order,

        -- Measures: running per enrollment, by event time (ties by event id)
        row_number() over (
            partition by enrollment_id order by event_at, event_id
        ) as event_number,
        -- A module of another training does not count towards the enrollment's progress.
        count(*) filter (
            where event_type = 'module_completed' and not is_module_of_other_training
        ) over (
            partition by enrollment_id
            order by event_at, event_id
            rows between unbounded preceding and current row
        ) as modules_completed_so_far,
        modules_in_training,

        -- Data-quality flags
        is_module_of_other_training,

        -- Metadata
        _loaded_at

    from joined
)

select * from transformed
