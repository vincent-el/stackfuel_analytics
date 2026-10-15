-- One row per line of the sheet "Legende": the Ampel values and their meaning, plus a free note.

with source as (
    select * from {{ source('coach_list', 'coach_list_legende') }}
),

transformed as (
    select
        -- Primary Key
        _row_number as sheet_row_number,

        -- Dimensions
        lower(trim(ampel)) as ampel,
        bedeutung as meaning,
        lower(trim(ampel)) in ('grün', 'gelb', 'rot') as is_ampel_value,

        -- Metadata
        {{ to_reporting_time('_loaded_at', 'loader') }} as _loaded_at

    from source
    -- exclude the free note
    where is_ampel_value is true
)

select * from transformed
