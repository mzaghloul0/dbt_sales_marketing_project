{{
    config(
        unique_key = 'product_sk'
    )
}}

-- One row per product. Products come from sales, reviews and interactions;
-- the category comes from sales and reviews. '-1' = unknown product, '-2' = not a product (an interaction on a page).

WITH products AS (

    SELECT product_name, product_category
    FROM {{ ref('stg_transactions') }}
    WHERE product_name IS NOT NULL

    UNION

    SELECT product_name, product_category
    FROM {{ ref('stg_customer_reviews') }}
    WHERE product_name IS NOT NULL

    UNION

    SELECT interaction_target, 'Unknown'
    FROM {{ ref('stg_interactions') }}
    WHERE target_type = 'Product'

)

SELECT
    {{ dbt_utils.generate_surrogate_key(['product_name']) }}       AS product_sk,
    product_name,
    COALESCE(MAX(NULLIF(product_category, 'Unknown')), 'Unknown') AS product_category

FROM products
GROUP BY product_name

UNION ALL
SELECT '-1', 'Unknown', 'Unknown'

UNION ALL
SELECT '-2', 'N/A', 'N/A'