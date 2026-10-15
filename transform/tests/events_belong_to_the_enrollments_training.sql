-- Finding, tolerated: an LXP event under a module of another training. The row stays, flagged,
-- and the running count skips it.

{{ config(severity = 'warn', tags = ['finding'], group = 'engineering') }}

select
    event_id,
    enrollment_id,
    training_id,
    module_id,
    event_type,
    event_at
from {{ ref('fct_module_progress_events') }}
where is_module_of_other_training
