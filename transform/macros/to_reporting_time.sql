{#- One reporting timezone for the whole project. Converts a source timestamp
    from its source's zone (var source_timezones) to the reporting zone (var reporting_timezone);
    the result is a naive timestamp in reporting wall-clock time. Used once, in staging. -#}
{% macro to_reporting_time(column, source_system) -%}
    {{ dbt_date.convert_timezone(
        column,
        target_tz=var('reporting_timezone'),
        source_tz=var('source_timezones')[source_system]
    ) }}
{%- endmacro %}
