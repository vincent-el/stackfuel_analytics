-- Pinned: Q4 as README § Results states it, through the function at the Stichtag, over all
-- trainings, quarters and respondents: the answers, promoters and detractors behind NPS 17. A
-- failure means a definition or the delivery changed the number; README and test move together.

{{ config(tags = ['pinned']) }}

with as_of_stichtag as (
    select
        sum(responses) as responses,
        sum(promoters) as promoters,
        sum(detractors) as detractors
    from {{ ref('report_nps_by_quarter') }}(date '2026-08-31')
)

select *
from as_of_stichtag
where not (responses = 339 and promoters = 138 and detractors = 82)
