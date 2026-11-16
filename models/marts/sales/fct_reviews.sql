{{
    config(
        unique_key = 'review_id'
    )
}}

-- Transaction fact. Grain: one row per review.

WITH reviews AS (

    SELECT * FROM {{ ref('stg_customer_reviews') }}

    {% if is_incremental() %}
    WHERE review_date >= (SELECT MAX(review_date) - 3 FROM {{ this }})
    {% endif %}

)

SELECT
    r.review_id,

    COALESCE(dr.date_sk, '-1')         AS review_date_sk,
    COALESCE(dp.date_sk, '-1')         AS purchase_date_sk,
    COALESCE(c.customer_sk, '-1')      AS customer_sk,
    COALESCE(c.home_location_sk, '-1') AS customer_location_sk,
    COALESCE(p.product_sk, '-1')       AS product_sk,

    r.review_date,
    r.review_title,
    r.review_text,

    r.rating,                                           -- not additive
    r.days_to_review

FROM reviews AS r

LEFT JOIN {{ ref('dim_date') }} AS dr
    ON r.review_date = dr.date_day

LEFT JOIN {{ ref('dim_date') }} AS dp
    ON r.purchase_date = dp.date_day

LEFT JOIN {{ ref('dim_customer') }} AS c
    ON r.customer_id = c.customer_id

LEFT JOIN {{ ref('dim_product') }} AS p
    ON r.product_name = p.product_name