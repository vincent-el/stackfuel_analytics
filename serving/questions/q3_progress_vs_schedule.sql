-- Q3 · Lernfortschritt vs. Zeitfortschritt: Für aktive Teilnahmen: Wie weit sind die Teilnehmenden
-- im Curriculum im Vergleich dazu, wie viel der geplanten Trainingsdauer bereits verstrichen ist?
-- Welcher Anteil liegt mindestens 15 Prozentpunkte hinter dem Zeitplan („im Verzug")?
--
-- One row per Teilnahme from mart.report_progress_vs_schedule; per training n, the share flagged
-- im Verzug and the two percentages as the average over its Teilnahmen: each Teilnahme counts
-- once, however many modules its training has. Inside a training this is the same number as
-- "all modules done ÷ all modules planned", because every Teilnahme there has the same plan.
-- Across trainings it is not: pooling would let a 12-module training outweigh a 5-module one
-- (at the Stichtag, all 172 aktiv: average 45.9 % of modules, pooled 45.7 %; time 54.2 % vs
-- 51.6 %). The Brief asks "welcher Anteil" of Teilnahmen, so the table has no total row; only
-- Anteil im Verzug, a count over a count, may be summed across trainings.
--
-- Function arguments: $reference_date, $behind_schedule_pp.

with enrollments as (
    select * from mart.report_progress_vs_schedule($reference_date, $behind_schedule_pp)
)

select
    trainings.training_id,
    trainings.training_name,
    trainings.variant,
    count(*) as n,
    round(avg(enrollments.modules_completed_pct), 1) as modules_completed_pct,
    round(avg(enrollments.time_elapsed_within_plan_pct), 1) as time_elapsed_within_plan_pct,
    count(*) filter (where enrollments.is_behind_schedule) as behind_schedule,
    round(100.0 * count(*) filter (where enrollments.is_behind_schedule) / count(*), 1)
        as behind_schedule_pct
from enrollments
left join mart.dim_trainings as trainings
    on enrollments.training_id = trainings.training_id
group by all
order by trainings.training_id
