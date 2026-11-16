{{
    config(
        unique_key = 'customer_sk'
    )
}}

-- One row per customer (SCD type 1: changes overwrite the row).
-- home_location_sk links to dim_location; the facts copy it as customer_location_sk.

SELECT
    {{ dbt_utils.generate_surrogate_key(['customer_id']) }} AS customer_sk,
    customer_id,
    full_name,
    age,

    CASE
        WHEN age IS NULL THEN 'Unknown'
        WHEN age <= 25   THEN '18-25'
        WHEN age <= 40   THEN '26-40'
        WHEN age <= 60   THEN '41-60'
        ELSE '60+'
    END AS age_group,

    gender,
    email,
    phone,
    street_address,
    city,
    state,
    state_code,
    division,
    zip_code,
    registration_date,
    preferred_channel,

    CASE
        WHEN state_code IS NULL THEN '-1'
        ELSE {{ dbt_utils.generate_surrogate_key(['city', 'state_code']) }}
    END AS home_location_sk

FROM {{ ref('stg_customers') }}

-- unknown member: text 'Unknown', numbers and dates NULL
UNION ALL
SELECT
    '-1', 'Unknown', 'Unknown', NULL, 'Unknown', 'Unknown', 'Unknown', 'Unknown', 'Unknown',
    'Unknown', 'Unknown', NULL, 'Unknown', NULL, NULL, 'Unknown', '-1'