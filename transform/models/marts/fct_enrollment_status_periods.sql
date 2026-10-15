-- One row per enrollment per status period, valid_from <= t < valid_to.
--
-- State transitions assumed from the data; the CRM documents none:
--   angemeldet ──► aktiv ──┬──► abgeschlossen
--       │          ▲  │    ├──► abgebrochen
--       │          │  ▼    │
--       │        pausiert ─┘
--       └──► storniert
--

with enrollments as (
    select * from {{ ref('crm__enrollments') }}
),

progress_events as (
    select * from {{ ref('lxp__progress_events') }}
),

first_progress_events as (
    select
        enrollment_id,
        min(event_at) as first_progress_event_at
    from progress_events
    group by enrollment_id
),

enrollments_with_start as (
    select
        enrollments.*,
        first_progress_events.first_progress_event_at,
        -- The CRM record is the enrollment: an event before created_at starts no
        -- status before the record exists (see (events_after_enrollment_created))
        case
            when first_progress_events.first_progress_event_at is not null
                then greatest(first_progress_events.first_progress_event_at, enrollments.created_at)
        end as learning_started_at
    from enrollments
    left join first_progress_events
        on enrollments.enrollment_id = first_progress_events.enrollment_id
),

periods as (
    -- Here we are inferring the enrollment's status history.
    -- This diagram illustrates the possible status transitions:
    --                          created_at    learning_started_at    status_changed_at
    --                              │                 │                     │
    --   finished or paused now     ├─ angemeldet ────┼─────── aktiv ───────┼─ abgeschlossen ──►
    --   aktiv now, changed later   ├─ angemeldet ────┼───── unbekannt ─────┼─ aktiv ──────────►
    --   aktiv since the start      ├─ angemeldet ────┤ aktiv ───────────────────────────────────►
    --   angemeldet or storniert    ├ angemeldet ─────────────────────────────────────────────────►
    --                                 inferred           inferred              observed

    -- Observed: the current status, every enrollment, from the last change, open-ended.
    select
        enrollment_id,
        status,
        status_changed_at as valid_from,
        cast('9999-12-31' as timestamp) as valid_to,
        false as is_inferred,
        'crm_current_status' as evidence
    from enrollments_with_start

    union all

    -- Middle slot, inferred: from the start of learning to the last change. aktiv where the
    -- current status follows aktiv in the graph; unbekannt where the enrollment is aktiv again.
    select
        enrollment_id,
        case when status = 'aktiv' then 'unbekannt' else 'aktiv' end as status,
        learning_started_at as valid_from,
        status_changed_at as valid_to,
        true as is_inferred,
        'lxp_first_event' as evidence
    from enrollments_with_start
    where learning_started_at < status_changed_at

    union all

    -- First slot, inferred: angemeldet from creation until learning started, or until the last
    -- change when learning had not started by then. Were the CRM to re-stamp a still-angemeldet
    -- row, this slot and the observed one would be two contiguous angemeldet periods; a count
    -- at any moment still sees one.
    select
        enrollment_id,
        'angemeldet' as status,
        created_at as valid_from,
        case
            when learning_started_at < status_changed_at then learning_started_at
            else status_changed_at
        end as valid_to,
        true as is_inferred,
        'crm_created_at' as evidence
    from enrollments_with_start
    where created_at < valid_to
),

-- The enrollment's own keys and dates, repeated on every period.
transformed as (
    select
        -- Primary Key (with valid_from)
        periods.enrollment_id,

        -- Foreign Keys
        enrollments.training_id,
        enrollments.cohort_key,
        enrollments.participant_id,

        -- Dates
        enrollments.cohort_start_date,
        enrollments.planned_end_date,

        -- Timestamps
        periods.valid_from,
        periods.valid_to,
        enrollments.created_at,

        -- Dimensions
        periods.status,
        periods.valid_to = cast('9999-12-31' as timestamp) as is_current,
        periods.is_inferred,
        periods.evidence,

        -- Metadata
        enrollments._loaded_at

    from periods
    left join enrollments
        on periods.enrollment_id = enrollments.enrollment_id
)

select * from transformed
