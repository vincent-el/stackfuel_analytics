-- Finding, tolerated: a coach-list line that fits no enrollment, or two. The line stays, flagged,
-- and counts for no coach; the Coaching Team Lead corrects it in the sheet.

{{ config(severity = 'warn', tags = ['finding'], group = 'delivery') }}

select
    sheet_row_number,
    coach_key,
    participant_name,
    email,
    training_spelling,
    cohort_month,
    data_quality_issues
from {{ ref('int_coach_list__matches') }}
where is_unmatched or is_match_ambiguous
