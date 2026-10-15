-- Finding, tolerated: an enrollment whose participant_id is not in the CRM (ids outside the CRM's
-- range). Kept, with funding type unbekannt; red above the six known today, because Q2 would
-- count more enrollments under unbekannt than the finding explains.

{{ config(severity = 'error', error_if = '>6', tags = ['finding'], group = 'operations') }}

select
    enrollments.enrollment_id,
    enrollments.participant_id
from {{ ref('crm__enrollments') }} as enrollments
left join {{ ref('crm__participants') }} as participants
    on enrollments.participant_id = participants.participant_id
where participants.participant_id is null
