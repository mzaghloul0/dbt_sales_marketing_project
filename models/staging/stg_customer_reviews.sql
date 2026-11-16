WITH source AS (

    SELECT *
    FROM {{ ref('customer_reviews_complete') }}

),

cleaned AS (

    SELECT
        TRIM(review_id)                                         AS review_id,
        TRIM(customer_id)                                       AS customer_id,
        NULLIF(TRIM(product_name), '')                          AS product_name,
        NULLIF(TRIM(product_category), '')                      AS product_category,
        transaction_date::DATE                                  AS purchase_date,
        review_date::DATE                                       AS review_date,
        rating::INTEGER                                         AS rating,
        COALESCE(NULLIF(TRIM(review_title), ''), 'Unknown')     AS review_title,
        COALESCE(NULLIF(TRIM(review_text), ''), 'Unknown')      AS review_text

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
            PARTITION BY review_id
            ORDER BY review_date DESC
        ) AS rn

    FROM cleaned

)

SELECT
    r.review_id,
    r.customer_id,
    r.product_name,
    COALESCE(r.product_category, p.product_category, 'Unknown') AS product_category,
    r.purchase_date,
    r.review_date,
    r.review_date - r.purchase_date                             AS days_to_review,
    r.rating,
    r.review_title,
    r.review_text

FROM deduplicated AS r

LEFT JOIN product_categories AS p
    ON r.product_name = p.product_name

WHERE r.rn = 1