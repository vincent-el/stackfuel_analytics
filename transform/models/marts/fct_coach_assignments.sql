-- One row per enrollment on the coach list: its coach and Ampel, from the line that counts.
-- The match, and the lines that do not count: int_coach_list__matches.

with coach_list_matches as (
    select * from {{ ref('int_coach_list__matches') }}
),

legend as (
    select * from {{ ref('stg_coach_list__legend') }}
),

transformed as (
    select
        -- Primary Key
        coach_list_matches.enrollment_id,

        -- Foreign Keys
        coach_list_matches.coach_key,
        coach_list_matches.participant_id,
        coach_list_matches.cohort_key,
        coach_list_matches.training_id,
        coach_list_matches.sheet_row_number,

        -- Dates
        coach_list_matches.last_contact_date,

        -- Dimensions
        coach_list_matches.ampel,
        legend.meaning as ampel_meaning,
        coach_list_matches.matched_by

    from coach_list_matches
    left join legend
        on coach_list_matches.ampel = legend.ampel and legend.is_ampel_value
    where
        coach_list_matches.enrollment_id is not null
        and not coach_list_matches.is_duplicate_row
)

select * from transformed
