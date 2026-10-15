-- Finding, tolerated: an enrollment on more than one coach-list line. The line with the latest
-- Letzter Kontakt counts; the others stay, flagged is_duplicate_row.

{{ config(severity = 'warn', tags = ['finding'], group = 'delivery') }}

select
    sheet_row_number,
    enrollment_id,
    coach_key,
    ampel,
    last_contact_date
from {{ ref('int_coach_list__matches') }}
where is_duplicate_row
