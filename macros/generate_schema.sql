-- macro for adding schema if not exists  & abd add it without a concat schema from profiles + target schema in modules.

{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is not none and custom_schema_name | trim != "" -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ target.schema }}
    {%- endif -%}
{%- endmacro %}