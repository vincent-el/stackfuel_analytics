-- One row per CRM participant, the latest landed version.

with participants as (
    select * from {{ ref('stg_crm__participants') }}
),

latest_version as (
    select *
    from participants
    qualify row_number() over (partition by participant_id order by modified_at desc) = 1
)

select * from latest_version
