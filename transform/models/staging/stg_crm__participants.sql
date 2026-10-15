-- One row per landed version of a CRM participant.

with source as (
    select * from {{ source('crm', 'participants') }}
),

transformed as (
    select
        -- Primary Key
        participant_id,

        -- Dates
        cast(birth_date as date) as birth_date,

        -- Timestamps
        {{ to_reporting_time('created_at', 'crm') }} as created_at,
        {{ to_reporting_time('modified_at', 'crm') }} as modified_at,

        -- Dimensions
        trim(first_name) as first_name,
        trim(last_name) as last_name,
        lower(trim(email)) as email,
        city,
        federal_state,
        funding_type,
        acquisition_channel,

        -- Metadata
        {{ to_reporting_time('_loaded_at', 'loader') }} as _loaded_at

    from source
)

select * from transformed
