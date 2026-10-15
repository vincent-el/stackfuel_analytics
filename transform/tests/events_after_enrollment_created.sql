-- Finding, tolerated: an enrollment whose first LXP event precedes its CRM created_at. The
-- events stay; the inferred aktiv period starts at created_at.

{{ config(severity = 'warn', tags = ['finding'], group = 'engineering') }}

with first_events as (
    select
        enrollment_id,
        min(event_at) as first_event_at
    from {{ ref('fct_module_progress_events') }}
    group by enrollment_id
)

select
    first_events.enrollment_id,
    first_events.first_event_at,
    enrollments.created_at
from first_events
inner join {{ ref('crm__enrollments') }} as enrollments
    on first_events.enrollment_id = enrollments.enrollment_id
where first_events.first_event_at < enrollments.created_at
