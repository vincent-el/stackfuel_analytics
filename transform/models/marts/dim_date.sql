-- One row per calendar day, covering every cohort start and planned end.

with calendar as (
    -- sqlfluff sees a package macro only as a placeholder, which is not SQL; dbt checks it.
    {{ dbt_date.get_date_dimension('2024-01-01', '2028-01-01') }}  -- noqa: PRS
)

select
    *,
    -- The calendar quarter as a label for time axes, e.g. 2026-Q3.
    year_number || '-Q' || quarter_of_year as quarter_label,
    -- Fiscal quarters: Germany starts the year in January, the UK parent in April.
    quarter_of_year as fiscal_quarter_de,
    ((month_of_year + 8) % 12) // 3 + 1 as fiscal_quarter_uk
from calendar
