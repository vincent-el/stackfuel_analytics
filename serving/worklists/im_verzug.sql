-- Im Verzug: Welche aktiven Teilnahmen liegen am Stichtag hinter dem Zeitplan – wer zuerst?
-- Rows of mart.report_progress_vs_schedule flagged is_behind_schedule (the function owns the
-- threshold and the gap); names from the dimensions. Sorted by schedule_gap_pp, the largest first.
--
-- Function arguments: $reference_date, $behind_schedule_pp.

with enrollments as (
    select * from mart.report_progress_vs_schedule($reference_date, $behind_schedule_pp)
)

select
    enrollments.enrollment_id,
    participants.first_name || ' ' || participants.last_name as name,
    participants.email,
    enrollments.training_id,
    trainings.training_name,
    enrollments.cohort_key,
    round(enrollments.modules_completed_pct, 1) as modules_completed_pct,
    round(enrollments.time_elapsed_within_plan_pct, 1) as time_elapsed_within_plan_pct,
    round(enrollments.schedule_gap_pp, 1) as schedule_gap_pp
from enrollments
left join mart.dim_participants as participants
    on enrollments.participant_id = participants.participant_id
left join mart.dim_trainings as trainings
    on enrollments.training_id = trainings.training_id
where enrollments.is_behind_schedule
order by enrollments.schedule_gap_pp desc
