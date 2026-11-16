{{
    config(
        unique_key = 'transaction_id'
    )
}}

-- Transaction fact. Grain: one row per transaction.
-- Measures stay NULL when unknown, never 0.

WITH transactions AS (

    SELECT * FROM {{ ref('stg_transactions') }}

    {% if is_incremental() %}
    -- reload the last 3 days, so late rows of a batch are not missed
    WHERE transaction_date >= (SELECT MAX(transaction_date) - 3 FROM {{ this }})
    {% endif %}

)

SELECT
    t.transaction_id,

    COALESCE(d.date_sk, '-1')            AS date_sk,
    COALESCE(c.customer_sk, '-1')        AS customer_sk,
    COALESCE(c.home_location_sk, '-1')   AS customer_location_sk,
    COALESCE(p.product_sk, '-1')         AS product_sk,
    COALESCE(ch.channel_sk, '-1')        AS channel_sk,
    COALESCE(pm.payment_method_sk, '-1') AS payment_method_sk,

    CASE
        WHEN t.sales_channel = 'Online' THEN '-2'
        ELSE COALESCE(l.location_sk, '-1')
    END                                  AS store_location_sk,

    t.transaction_date,

    t.quantity,
    t.unit_price,                                       -- not additive
    t.discount_pct,                                     -- not additive
    t.gross_revenue,
    t.net_revenue

FROM transactions AS t

LEFT JOIN {{ ref('dim_date') }} AS d
    ON t.transaction_date = d.date_day

LEFT JOIN {{ ref('dim_customer') }} AS c
    ON t.customer_id = c.customer_id

LEFT JOIN {{ ref('dim_product') }} AS p
    ON t.product_name = p.product_name

LEFT JOIN {{ ref('dim_channel') }} AS ch
    ON t.sales_channel = ch.channel_name

LEFT JOIN {{ ref('dim_payment_method') }} AS pm
    ON t.payment_method = pm.payment_method

LEFT JOIN {{ ref('dim_location') }} AS l
    ON  t.store_city = l.city
    AND t.store_state_code = l.state_code