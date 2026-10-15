-- Contract: a period ends no later than the next one of the same enrollment begins, so at any
-- moment an enrollment has at most one status. Gaps are allowed (unknown status).

{{ config(tags = ['contract']) }}

with ordered as (
    select
        enrollment_id,
        valid_from,
        valid_to,
        lead(valid_from) over (partition by enrollment_id order by valid_from) as next_valid_from
    from {{ ref('fct_enrollment_status_periods') }}
)

select *
from ordered
where next_valid_from < valid_to
