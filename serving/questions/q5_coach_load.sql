-- Q5 · Coach-Auslastung: Wie viele aktive oder pausierte Teilnahmen betreut jeder Coach laut
-- Betreuungsliste, und wie viele davon stehen auf rot? Wie viele Teilnahmen konntest du keinem
-- Coach zuordnen?
--
-- One row per Teilnahme from mart.report_coach_load, counted per coach and per Ampel (the Brief
-- asks for rot; grün and gelb stand beside it, ampel_missing is a counted line whose Ampel is
-- empty or the ambiguous "g"). A Teilnahme without a coach_key is ohne Coach, the last row: no
-- line, so no Ampel, its Ampel cells empty rather than 0. The Ampel is the sheet's as delivered,
-- whatever the Stichtag. A coach's load spans trainings, so no training selection applies here.
--
-- Function arguments: $reference_date.

with enrollments as (
    select * from mart.report_coach_load($reference_date)
)

select
    coalesce(coaches.coach_name, 'ohne Coach') as coach_name,
    count(*) as enrollments,
    if(coaches.coach_name is null, null, count(*) filter (where enrollments.ampel = 'grün'))
        as green,
    if(coaches.coach_name is null, null, count(*) filter (where enrollments.ampel = 'gelb'))
        as yellow,
    if(coaches.coach_name is null, null, count(*) filter (where enrollments.ampel = 'rot'))
        as red,
    if(coaches.coach_name is null, null, count(*) filter (where enrollments.ampel is null))
        as ampel_missing
from enrollments
left join mart.dim_coaches as coaches
    on enrollments.coach_key = coaches.coach_key
group by coaches.coach_name
order by coaches.coach_name is null, coaches.coach_name
