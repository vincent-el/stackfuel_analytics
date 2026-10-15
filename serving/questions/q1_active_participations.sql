-- Q1 · Aktive Teilnehmende: Wie viele Teilnahmen sind am Stichtag aktiv – je Training?
--
-- Counts from mart.report_active_participations; pausiert stands beside aktiv, never inside it.
--
-- Function arguments: $reference_date.

with cells as (
    select * from mart.report_active_participations($reference_date)
)

select
    trainings.training_id,
    trainings.training_name,
    trainings.variant,
    sum(cells.enrollment_count) filter (where cells.status = 'aktiv') as active,
    sum(cells.enrollment_count) filter (where cells.status = 'pausiert') as paused
from cells
left join mart.dim_trainings as trainings
    on cells.training_id = trainings.training_id
group by all
order by trainings.training_id
