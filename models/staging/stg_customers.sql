
WITH source AS (

    SELECT *
    FROM {{ ref('customers') }}

),

basic_cleaned AS (

    SELECT
        TRIM(customer_id) AS customer_id,

        COALESCE(NULLIF(TRIM(full_name), ''), 'Unknown') AS full_name,

        CASE
            WHEN age >= 0 AND age = TRUNC(age)
                THEN age::INTEGER
            ELSE NULL
        END AS age,

        CASE TRIM(gender)
            WHEN 'Male'   THEN 'M'
            WHEN 'Female' THEN 'F'
            ELSE 'D'
        END AS gender,

        COALESCE(NULLIF(LOWER(TRIM(email)), ''), 'Unknown') AS email,
               CASE
            WHEN phone IS NULL THEN 'Unknown'
            WHEN REGEXP_REPLACE(SPLIT_PART(phone, 'x', 1), '[^0-9]', '', 'g') ~ '^(1|001)?[0-9]{10}$'
                THEN '+1' || RIGHT(REGEXP_REPLACE(SPLIT_PART(phone, 'x', 1), '[^0-9]', '', 'g'), 10)
                     || COALESCE('x' || NULLIF(SPLIT_PART(phone, 'x', 2), ''), '')
            ELSE phone
        END AS phone,
        COALESCE(NULLIF(TRIM(street_address), ''), 'Unknown') AS street_address,
        COALESCE(NULLIF(TRIM(city), ''), 'Unknown') AS city,

        NULLIF(TRIM(state), '') AS state,

        zip_code,

        registration_date,

        CASE LOWER(TRIM(preferred_channel))
            WHEN 'online'   THEN 'Online'
            WHEN 'in-store' THEN 'In-Store'
            WHEN 'both'     THEN 'Both'
            ELSE 'Unknown'
        END AS preferred_channel

    FROM source

),

state_corrected AS (

    SELECT
        p.*,
        COALESCE(p.state, cs.state) AS corrected_state

    FROM basic_cleaned AS p

    LEFT JOIN (
        SELECT
            city,
            MIN(state) AS state
        FROM basic_cleaned
        WHERE state IS NOT NULL
          AND city <> 'Unknown'
        GROUP BY city
        HAVING COUNT(DISTINCT state) = 1
    ) AS cs
        ON p.city = cs.city

),

division_assigned AS (

    SELECT
        c.*,
        s.state_code,
        COALESCE(s.state_name, 'Unknown') AS state_name,
        COALESCE(s.division, 'Unknown') AS division

    FROM state_corrected AS c

    LEFT JOIN {{ ref('stg_states') }} AS s
        ON c.corrected_state = s.state_name
        OR UPPER(c.corrected_state) = s.state_code

),

deduplicated AS (

    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY
                registration_date DESC NULLS LAST,
                full_name,
                email
        ) AS rn

    FROM division_assigned

)

SELECT
    customer_id,
    full_name,
    age,
    gender,
    email,
    phone,
    street_address,
    city,
    state_name AS state,
    state_code,
    division,
    zip_code,
    registration_date,
    preferred_channel

FROM deduplicated
WHERE rn = 1
