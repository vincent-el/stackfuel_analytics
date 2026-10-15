-- Q2 · Abschluss- und Abbruchquote: Für Teilnahmen, deren geplantes Ende vor dem Stichtag liegt:
-- Welcher Anteil ist abgeschlossen, welcher abgebrochen – je Training und Förderart?
--
-- Counts from mart.report_completion_rates. The function rules what counts: outcome folds the
-- statuses into abgeschlossen, abgebrochen or offen, and a Storno has no outcome. n is the sum
-- where outcome is not null; the three shares divide by n, storniert is counted beside them. The
-- window of planned-end quarters is the function's (null = no bound; the default, every quarter).
--
-- Function arguments: $reference_date, $planned_end_from, $planned_end_to.

with cells as (
    select * from mart.report_completion_rates($reference_date, $planned_end_from, $planned_end_to)
),

by_training_and_funding as (
    select
        training_id,
        funding_type,
        sum(enrollment_count) filter (where outcome is not null) as n,
        sum(enrollment_count) filter (where outcome = 'abgeschlossen') as completed,
        sum(enrollment_count) filter (where outcome = 'abgebrochen') as dropped_out,
        sum(enrollment_count) filter (where outcome = 'offen') as still_open,
        sum(enrollment_count) filter (where status = 'storniert') as cancelled
    from cells
    group by all
)

select
    trainings.training_id,
    trainings.training_name,
    counts.funding_type,
    coalesce(counts.n, 0) as n,
    coalesce(counts.completed, 0) as completed,
    coalesce(counts.dropped_out, 0) as dropped_out,
    coalesce(counts.still_open, 0) as still_open,
    round(100.0 * coalesce(counts.completed, 0) / nullif(counts.n, 0), 1) as completion_rate_pct,
    round(100.0 * coalesce(counts.dropped_out, 0) / nullif(counts.n, 0), 1) as dropout_rate_pct,
    round(100.0 * coalesce(counts.still_open, 0) / nullif(counts.n, 0), 1) as open_rate_pct,
    coalesce(counts.cancelled, 0) as cancelled
from by_training_and_funding as counts
left join mart.dim_trainings as trainings
    on counts.training_id = trainings.training_id
order by trainings.training_id, counts.funding_type
