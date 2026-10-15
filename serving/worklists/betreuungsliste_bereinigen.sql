-- Betreuungsliste bereinigen: Welche Zeilen der Betreuungsliste muss das Coaching korrigieren?
-- Lines of mart.int_coach_list__matches with at least one hint: the sheet's own dirt and the
-- match's (a second line for a Teilnahme already listed, no or two Teilnahmen found).
--
-- Function arguments: none; the list has no history, so no Stichtag applies.

select
    matches.sheet_row_number,
    coaches.coach_name,
    matches.participant_name,
    matches.email,
    matches.training_id,
    matches.training_spelling,
    matches.cohort_month,
    matches.ampel,
    matches.data_quality_issues
from mart.int_coach_list__matches as matches
left join mart.dim_coaches as coaches
    on matches.coach_key = coaches.coach_key
where len(matches.data_quality_issues) > 0
order by matches.sheet_row_number
