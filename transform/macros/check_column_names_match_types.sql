{#- Column names promise a type: `_at` is a timestamp, `_date` a date,
    `is_` / `has_` / `was_` a boolean. Runs once after the whole build (on-run-end in
    dbt_project.yml), so it sees every model; any column that breaks the promise fails the run. -#}
{% macro check_column_names_match_types() %}
    {% if execute %}
        {% set mismatches = run_query("
            select table_schema || '.' || table_name || '.' || column_name || ' (' || data_type || ')'
            from information_schema.columns
            where
                table_schema in ('stg', 'prep', 'mart')
                and (
                    (column_name like '%\_at' escape '\\' and data_type not like 'TIMESTAMP%')
                    or (column_name like '%\_date' escape '\\' and data_type <> 'DATE')
                    or (regexp_matches(column_name, '^(is|has|was)_') and data_type <> 'BOOLEAN')
                )
        ") %}
        {% if mismatches | length > 0 %}
            {{ exceptions.raise_compiler_error(
                "Column names do not match their types: " ~ mismatches.columns[0].values() | join(', ')
            ) }}
        {% endif %}
    {% endif %}
{% endmacro %}
