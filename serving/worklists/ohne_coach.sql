-- Ohne Coach: Welche aktiven oder pausierten Teilnahmen haben keinen Coach auf der Betreuungsliste?
-- Rows of mart.report_coach_load without a coach_key; names from the dimensions.
--
-- Function arguments: $reference_date.

with enrollments as (
    select * from mart.report_coach_load($reference_date)
)

select
    enrollments.enrollment_id,
    participants.first_name || ' ' || participants.last_name as name,
    participants.email,
    enrollments.training_id,
    trainings.training_name,
    enrollments.cohort_key,
    enrollments.status
from enrollments
left join mart.dim_participants as participants
    on enrollments.participant_id = participants.participant_id
left join mart.dim_trainings as trainings
    on enrollments.training_id = trainings.training_id
where enrollments.coach_key is null
order by enrollments.training_id, enrollments.cohort_key
