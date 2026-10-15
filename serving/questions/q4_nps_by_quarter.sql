-- Q4 · NPS: Wie hoch ist der Net Promoter Score (Promotoren 9–10 minus Detraktoren 0–6, in
-- Prozent) aus dem Abschlussfeedback – je Training und Quartal?
--
-- Cells from mart.report_nps_by_quarter, summed over respondent_status per training × quarter:
-- nps = 100 * (promoters - detractors) / n over all answers, then the same per status, because
-- the final feedback is answered after completion and after a dropout (README findings).
--
-- Function arguments: $reference_date.

with cells as (
    select * from mart.report_nps_by_quarter($reference_date)
),

by_training_and_quarter as (
    select
        training_id,
        quarter_label,
        quarter_start_date,
        sum(responses) as n,
        sum(promoters) as promoters,
        sum(passives) as passives,
        sum(detractors) as detractors,
        sum(responses) filter (where respondent_status = 'abgeschlossen') as n_completed,
        sum(promoters - detractors) filter (where respondent_status = 'abgeschlossen')
            as net_completed,
        sum(responses) filter (where respondent_status = 'abgebrochen') as n_dropped_out,
        sum(promoters - detractors) filter (where respondent_status = 'abgebrochen')
            as net_dropped_out
    from cells
    group by all
)

select
    trainings.training_id,
    trainings.training_name,
    counts.quarter_label as quarter,
    counts.n,
    counts.promoters,
    counts.passives,
    counts.detractors,
    cast(round(100.0 * (counts.promoters - counts.detractors) / counts.n) as integer) as nps,
    coalesce(counts.n_completed, 0) as n_completed,
    cast(round(100.0 * counts.net_completed / counts.n_completed) as integer) as nps_completed,
    coalesce(counts.n_dropped_out, 0) as n_dropped_out,
    cast(round(100.0 * counts.net_dropped_out / counts.n_dropped_out) as integer) as nps_dropped_out
from by_training_and_quarter as counts
left join mart.dim_trainings as trainings
    on counts.training_id = trainings.training_id
order by trainings.training_id, counts.quarter_start_date
