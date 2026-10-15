-- One row per line of the coach list, with the enrollment it was matched to, or none.
--
-- The sheet has no key. Each line looks for the enrollments it could mean, on one of two paths;
-- whether the line has an email decides which:
--
--   sheet line ─┬─ email ──── email path: email + training ────────────────┐
--               └─ no email ─ name path:  name + cohort month + training ──┴─► candidates
--
--   candidates per line:  1 → matched · 0 → unmatched · 2+ → ambiguous (never forced)
--   several lines matched to one enrollment: the latest Letzter Kontakt counts (ties by sheet
--   row), the others are duplicate rows
--
-- The training comes from the spellings seed on both paths; names are compared lower case
-- with umlauts spelled out (Böhm = Boehm). fct_coach_assignments keeps the counted line of
-- each enrollment.

with coach_assignments as (
    select * from {{ ref('stg_coach_list__assignments') }}
),

training_spellings as (
    select * from {{ ref('coach_list_training_spellings') }}
),

coaches as (
    select * from {{ ref('dim_coaches') }}
),

enrollments as (
    select * from {{ ref('crm__enrollments') }}
),

cohorts as (
    select * from {{ ref('dim_cohorts') }}
),

participants as (
    select * from {{ ref('dim_participants') }}
),

sheet_lines as (
    select
        coach_assignments.*,
        training_spellings.training_id,
        -- lower case, umlauts spelled out: Böhm = Boehm
        replace(replace(replace(replace(
            lower(coach_assignments.participant_name), 'ä', 'ae'
        ), 'ö', 'oe'), 'ü', 'ue'), 'ß', 'ss') as name_key
    from coach_assignments
    left join training_spellings
        on coach_assignments.training_spelling = training_spellings.training_spelling
),

enrollment_keys as (
    select
        enrollments.enrollment_id,
        enrollments.participant_id,
        enrollments.cohort_key,
        enrollments.training_id,
        cohorts.cohort_month,
        participants.email,
        -- folded like sheet_lines.name_key
        replace(replace(replace(replace(
            lower(participants.first_name || ' ' || participants.last_name), 'ä', 'ae'
        ), 'ö', 'oe'), 'ü', 'ue'), 'ß', 'ss') as name_key
    from enrollments
    inner join cohorts
        on enrollments.cohort_key = cohorts.cohort_key
    left join participants
        on enrollments.participant_id = participants.participant_id
),

email_candidates as (
    select
        sheet_lines.sheet_row_number,
        enrollment_keys.enrollment_id,
        'email' as matched_by
    from sheet_lines
    inner join enrollment_keys
        on
            sheet_lines.email = enrollment_keys.email
            and sheet_lines.training_id = enrollment_keys.training_id
),

name_candidates as (
    select
        sheet_lines.sheet_row_number,
        enrollment_keys.enrollment_id,
        'name' as matched_by
    from sheet_lines
    inner join enrollment_keys
        on
            sheet_lines.name_key = enrollment_keys.name_key
            and sheet_lines.cohort_month = enrollment_keys.cohort_month
            and sheet_lines.training_id = enrollment_keys.training_id
    where sheet_lines.email is null
),

candidates as (
    select * from email_candidates
    union all
    select * from name_candidates
),

candidate_counts as (
    select
        sheet_row_number,
        any_value(matched_by) as matched_by,  -- one path per line
        count(*) as candidate_count,
        min(enrollment_id) as only_enrollment_id  -- meaningful when candidate_count = 1
    from candidates
    group by sheet_row_number
),

-- A line with no candidate is missing from candidate_counts: the left join brings it back with
-- a null count.
match_results as (
    select
        sheet_lines.*,
        candidate_counts.candidate_count,
        case when candidate_counts.candidate_count = 1 then candidate_counts.matched_by end
            as matched_by,
        case when candidate_counts.candidate_count = 1 then candidate_counts.only_enrollment_id end
            as enrollment_id,
        sheet_lines.training_id is null as is_training_spelling_unmapped,
        coalesce(candidate_counts.candidate_count > 1, false) as is_match_ambiguous,
        candidate_counts.candidate_count is null as is_unmatched
    from sheet_lines
    left join candidate_counts
        on sheet_lines.sheet_row_number = candidate_counts.sheet_row_number
),

duplicate_lines as (
    select
        *,
        enrollment_id is not null
        and row_number() over (
            partition by enrollment_id
            order by last_contact_date desc, sheet_row_number asc
        ) > 1 as is_duplicate_row
    from match_results
),

transformed as (
    select
        -- Primary Key
        duplicate_lines.sheet_row_number,

        -- Foreign Keys
        coaches.coach_key,
        duplicate_lines.enrollment_id,
        enrollment_keys.participant_id,
        enrollment_keys.cohort_key,
        duplicate_lines.training_id,

        -- Dates
        duplicate_lines.cohort_start_date,
        duplicate_lines.cohort_month,
        duplicate_lines.last_contact_date,

        -- Dimensions
        duplicate_lines.participant_name,
        duplicate_lines.email,
        duplicate_lines.training_spelling,
        duplicate_lines.ampel,
        duplicate_lines.matched_by,

        -- Data-quality flags
        duplicate_lines.is_email_missing,
        duplicate_lines.is_name_reversed,
        duplicate_lines.is_cohort_month_only,
        duplicate_lines.is_ampel_ambiguous,
        duplicate_lines.is_training_spelling_unmapped,
        duplicate_lines.is_match_ambiguous,
        duplicate_lines.is_unmatched,
        duplicate_lines.is_duplicate_row,
        list_concat(
            duplicate_lines.data_quality_issues,  -- staging's four
            list_filter([
                case
                    when duplicate_lines.is_training_spelling_unmapped
                        then 'training_spelling_unmapped'
                end,
                case when duplicate_lines.is_match_ambiguous then 'match_ambiguous' end,
                case when duplicate_lines.is_unmatched then 'unmatched' end,
                case when duplicate_lines.is_duplicate_row then 'duplicate_row' end
            ], issue -> issue is not null)
        ) as data_quality_issues,

        -- Metadata
        duplicate_lines._loaded_at

    from duplicate_lines
    left join coaches
        on duplicate_lines.coach_name = coaches.coach_name
    left join enrollment_keys
        on duplicate_lines.enrollment_id = enrollment_keys.enrollment_id
)

select * from transformed
