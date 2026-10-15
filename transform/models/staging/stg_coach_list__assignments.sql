-- One row per line of the sheet "Betreuung": a coach assigned to a participant.

with source as (
    select * from {{ source('coach_list', 'coach_list_betreuung') }}
),

parsed as (
    select
        source.*,

        -- Date-typed cells arrive as ISO text (2026-04-13T00:00:00); text cells as typed.
        -- Kohorte: ISO | dd.mm.yyyy | month label mm/yyyy
        case
            when regexp_full_match(kohorte, '\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}:\d{2})?')
                then cast(cast(kohorte as timestamp) as date)
            when regexp_full_match(kohorte, '\d{2}\.\d{2}\.\d{4}')
                then cast(strptime(kohorte, '%d.%m.%Y') as date)
        end as parsed_cohort_date,
        case
            when regexp_full_match(kohorte, '\d{2}/\d{4}')
                then cast(strptime('01/' || kohorte, '%d/%m/%Y') as date)
        end as parsed_cohort_month,

        -- Letzter Kontakt: ISO | dd.mm.yy
        case
            when regexp_full_match(letzter_kontakt, '\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}:\d{2})?')
                then cast(cast(letzter_kontakt as timestamp) as date)
            when regexp_full_match(letzter_kontakt, '\d{2}\.\d{2}\.\d{2}')
                then cast(strptime(letzter_kontakt, '%d.%m.%y') as date)
        end as parsed_last_contact_date,

        lower(trim(ampel)) as ampel_lower,
        trim(regexp_replace(teilnehmer_in, '\s+', ' ', 'g')) as name_as_typed

    from source
),

transformed as (
    select
        -- Primary Key
        _row_number as sheet_row_number,

        -- Dates
        parsed_cohort_date as cohort_start_date,
        cast(coalesce(parsed_cohort_month, date_trunc('month', parsed_cohort_date)) as date)
            as cohort_month,
        parsed_last_contact_date as last_contact_date,

        -- Dimensions
        -- "Nachname, Vorname" turned into "Vorname Nachname"
        case
            when name_as_typed like '%,%'
                then trim(split_part(name_as_typed, ',', 2)) || ' ' || trim(split_part(name_as_typed, ',', 1))
            else name_as_typed
        end as participant_name,
        lower(trim(e_mail)) as email,
        training as training_spelling,
        trim(coach) as coach_name,
        case ampel_lower
            when 'r' then 'rot'
            when 'g' then null  -- grün or gelb: ambiguous, not guessed
            else nullif(ampel_lower, '')
        end as ampel,
        notizen as note,

        -- Data-quality flags
        coalesce(trim(e_mail), '') = '' as is_email_missing,
        coalesce(teilnehmer_in like '%,%', false) as is_name_reversed,
        parsed_cohort_month is not null as is_cohort_month_only,
        coalesce(ampel_lower = 'g', false) as is_ampel_ambiguous,
        list_filter([
            case when is_email_missing then 'email_missing' end,
            case when is_name_reversed then 'name_reversed' end,
            case when is_cohort_month_only then 'cohort_month_only' end,
            case when is_ampel_ambiguous then 'ampel_ambiguous' end
        ], issue -> issue is not null) as data_quality_issues,

        -- Metadata
        {{ to_reporting_time('_loaded_at', 'loader') }} as _loaded_at

    from parsed
)

select * from transformed
