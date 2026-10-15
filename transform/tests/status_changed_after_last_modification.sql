-- Finding, tolerated: a status change stamped after the record's last modification. Kept as
-- delivered; the incremental cursor (modified_at) would miss such a change.

{{ config(severity = 'warn', tags = ['finding'], group = 'operations') }}

select
    enrollment_id,
    status,
    status_changed_at,
    modified_at
from {{ ref('crm__enrollments') }}
where status_changed_at > modified_at
