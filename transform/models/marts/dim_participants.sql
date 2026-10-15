-- One row per participant id: a CRM intake record, or an id known only from an enrollment.

with participants as (
    select * from {{ ref('crm__participants') }}
),

enrollments as (
    select * from {{ ref('crm__enrollments') }}
),

-- The ids that enrollments carry but the CRM does not have.
enrollment_only as (
    select distinct enrollments.participant_id
    from enrollments
    left join participants
        on enrollments.participant_id = participants.participant_id
    where participants.participant_id is null
),

unioned as (
    select
        participant_id,
        birth_date,
        created_at,
        modified_at,
        first_name,
        last_name,
        email,
        city,
        federal_state,
        funding_type,
        acquisition_channel,
        true as is_in_crm,
        _loaded_at
    from participants

    union all

    -- Unknown members: 'unbekannt' in every categorical column, null elsewhere.
    select
        participant_id,
        cast(null as date) as birth_date,
        cast(null as timestamp) as created_at,
        cast(null as timestamp) as modified_at,
        cast(null as varchar) as first_name,
        cast(null as varchar) as last_name,
        cast(null as varchar) as email,
        'unbekannt' as city,
        'unbekannt' as federal_state,
        'unbekannt' as funding_type,
        'unbekannt' as acquisition_channel,
        false as is_in_crm,
        cast(null as timestamp) as _loaded_at
    from enrollment_only
),

transformed as (
    select
        -- Primary Key
        participant_id,

        -- Foreign Keys
        -- The first participant id per email, so one person registered twice shares one key.
        case
            when email is not null then min(participant_id) over (partition by email)
            else participant_id
        end as person_key,

        -- Dates
        birth_date,

        -- Timestamps
        created_at,
        modified_at,

        -- Dimensions
        first_name,
        last_name,
        email,
        city,
        federal_state,
        funding_type,
        acquisition_channel,
        is_in_crm,

        -- Metadata
        _loaded_at

    from unioned
)

select * from transformed
