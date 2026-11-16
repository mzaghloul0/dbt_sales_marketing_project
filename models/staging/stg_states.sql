WITH source AS (

    SELECT *
    FROM {{ ref('states') }}

),

cleaned AS (

    SELECT
        UPPER(TRIM(state_code))                         AS state_code,
        TRIM(state)                                     AS state_name,
        COALESCE(NULLIF(TRIM(region), ''), 'Unknown')   AS region,
        COALESCE(NULLIF(TRIM(division), ''), 'Unknown') AS division

    FROM source

),

deduplicated AS (

    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY state_code
            ORDER BY state_name
        ) AS rn

    FROM cleaned

)

SELECT
    state_code,
    state_name,
    region,
    division

FROM deduplicated
WHERE rn = 1