{{
    config(
        unique_key = 'location_sk'
    )
}}

WITH store_locations AS (

    SELECT DISTINCT
        store_city       AS city,
        store_state_code AS state_code

    FROM {{ ref('stg_transactions') }}
    WHERE store_city IS NOT NULL

),

customer_locations AS (

    SELECT DISTINCT
        city,
        state_code

    FROM {{ ref('stg_customers') }}
    WHERE state_code IS NOT NULL

),

locations AS (

    SELECT city, state_code FROM store_locations
    UNION
    SELECT city, state_code FROM customer_locations

)

SELECT
    {{ dbt_utils.generate_surrogate_key(['l.city', 'l.state_code']) }} AS location_sk,
    l.city,
    l.state_code,
    s.state_name,
    s.region,
    s.division,
    sl.city IS NOT NULL AS has_store

FROM locations AS l

INNER JOIN {{ ref('stg_states') }} AS s
    ON l.state_code = s.state_code

LEFT JOIN store_locations AS sl
    ON  l.city = sl.city
    AND l.state_code = sl.state_code

-- as customer location. '-1' = unknown, '-2' = online (no physical place for a store).

UNION ALL
SELECT '-1', 'Unknown', 'Unknown', 'Unknown', 'Unknown', 'Unknown', FALSE

UNION ALL
SELECT '-2', 'Online', 'N/A', 'N/A', 'N/A', 'N/A', FALSE