WITH source AS (

    SELECT *
    FROM {{ ref('transactions') }}

),

cleaned AS (

    SELECT
        TRIM(transaction_id)                            AS transaction_id,
        TRIM(customer_id)                               AS customer_id,
        NULLIF(TRIM(product_name), '')                  AS product_name,
        NULLIF(TRIM(product_category), '')              AS product_category,
        quantity::INTEGER                               AS quantity,
        ROUND(price::NUMERIC, 2)                        AS unit_price,
        discount_applied::NUMERIC                       AS discount_pct,
        transaction_date::DATE                          AS transaction_date,
        NULLIF(TRIM(store_location), '')                AS store_location,
        NULLIF(TRIM(payment_method), '')                AS payment_method

    FROM source

),

-- each product has one category; used to fill a missing one
product_categories AS (

    SELECT
        product_name,
        MIN(product_category) AS product_category

    FROM cleaned
    WHERE product_name IS NOT NULL
      AND product_category IS NOT NULL
    GROUP BY product_name

),

deduplicated AS (

    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY transaction_id
            ORDER BY transaction_date DESC
        ) AS rn

    FROM cleaned

)

SELECT
    t.transaction_id,
    t.customer_id,
    t.transaction_date,
    t.product_name,
    COALESCE(t.product_category, p.product_category, 'Unknown') AS product_category,

    -- store_location is "Online" or "City, ST"
    CASE
        WHEN t.store_location = 'Online' THEN 'Online'
        WHEN t.store_location LIKE '%,%' THEN 'Store'
    END                                                         AS sales_channel,

    CASE
        WHEN t.store_location LIKE '%,%' THEN TRIM(SPLIT_PART(t.store_location, ',', 1))
    END                                                         AS store_city,

    CASE
        WHEN t.store_location LIKE '%,%' THEN TRIM(SPLIT_PART(t.store_location, ',', 2))
    END                                                         AS store_state_code,

    t.payment_method,
    t.quantity,
    t.unit_price,
    t.discount_pct,

    -- revenue: price is a unit price, discount is in percent (missing = 0 %)
    t.quantity * t.unit_price                                                    AS gross_revenue,
    ROUND(t.quantity * t.unit_price * (1 - COALESCE(t.discount_pct, 0) / 100), 2) AS net_revenue

FROM deduplicated AS t

LEFT JOIN product_categories AS p
    ON t.product_name = p.product_name

WHERE t.rn = 1