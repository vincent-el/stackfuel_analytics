-- Contract: no email holds two enrollments in the same training. One person can hold two
-- participant ids; the coach match joins on email and training and relies on this.

{{ config(tags = ['contract']) }}

select
    participants.email,
    enrollments.training_id,
    count(*) as enrollments
from {{ ref('crm__enrollments') }} as enrollments
inner join {{ ref('crm__participants') }} as participants
    on enrollments.participant_id = participants.participant_id
where participants.email is not null
group by all
having count(*) > 1
