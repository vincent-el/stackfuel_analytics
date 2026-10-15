-- Finding, tolerated: an enrollment abgeschlossen in the CRM that keeps LXP events after the
-- stamp. Kept as delivered; the abgeschlossen period starts at the stamp, so Q1 and Q3 on a date
-- inside that span miss a learner who was still working.

{{ config(severity = 'warn', tags = ['finding'], group = 'operations') }}

with completions as (
    select * from {{ ref('crm__enrollments') }}
    where status = 'abgeschlossen'
),

progress_events as (
    select * from {{ ref('fct_module_progress_events') }}
)

select
    completions.enrollment_id,
    completions.status_changed_at,
    completions.planned_end_date,
    max(progress_events.event_at) as last_event_at
from completions
-- keeps only the completions with an event after the stamp
inner join progress_events
    on
        completions.enrollment_id = progress_events.enrollment_id
        and completions.status_changed_at < progress_events.event_at
group by all
