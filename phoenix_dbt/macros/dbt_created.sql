{#
    dbt_created
    -----------
    חותמת זמן אחידה לכל המודלים שנבנו באותה הרצה.
    משתמשת ב-run_started_at (זמן תחילת ההרצה) ולא ב-current_timestamp(),
    כדי שכל השכבות באותו `dbt build` יישאו בדיוק את אותו ערך.

    שימוש:  {{ dbt_created() }} as dbt_created
#}

{% macro dbt_created() -%}
    cast('{{ run_started_at.strftime("%Y-%m-%d %H:%M:%S") }}' as timestamp_ntz)
{%- endmacro %}
