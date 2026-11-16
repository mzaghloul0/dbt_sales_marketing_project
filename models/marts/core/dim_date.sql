{{
    config(
        materialized = 'table'
    )
}}

WITH spine AS (

    {{ dbt_utils.date_spine(
        datepart   = "day",
        start_date = "CAST('" ~ var('date_spine_start') ~ "' AS DATE)",
        end_date   = "CAST('" ~ var('date_spine_end') ~ "' AS DATE)"
    ) }}

)

SELECT
    {{ dbt_utils.generate_surrogate_key(['date_day']) }} AS date_sk,
    date_day::DATE                                   AS date_day,
    EXTRACT(YEAR FROM date_day)::INTEGER             AS year,
    EXTRACT(QUARTER FROM date_day)::INTEGER          AS quarter,
    EXTRACT(MONTH FROM date_day)::INTEGER            AS month,
    TRIM(TO_CHAR(date_day, 'Month'))                 AS month_name,
    TO_CHAR(date_day, 'YYYY-MM')                     AS year_month,
    EXTRACT(WEEK FROM date_day)::INTEGER             AS iso_week,
    EXTRACT(ISODOW FROM date_day)::INTEGER           AS day_of_week,
    TRIM(TO_CHAR(date_day, 'Day'))                   AS day_name,
    EXTRACT(ISODOW FROM date_day) IN (6, 7)          AS is_weekend

FROM spine

-- One row per day and '-1' = unknown date, '-2' = not applicable
-- those are special members text says what they are, numbers and the date stay NULL

UNION ALL
SELECT '-1', NULL, NULL, NULL, NULL, 'Unknown', 'Unknown', NULL, NULL, 'Unknown', NULL

UNION ALL
SELECT '-2', NULL, NULL, NULL, NULL, 'N/A', 'N/A', NULL, NULL, 'N/A', NULL