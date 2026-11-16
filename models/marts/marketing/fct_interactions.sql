{{
    config(
        unique_key = 'interaction_id'
    )
}}

-- Grain: one row per interaction.
-- An interaction on a page has no product: product_sk = '-2'.

WITH interactions AS (

    SELECT * FROM {{ ref('stg_interactions') }}

    {% if is_incremental() %}
    WHERE interaction_date >= (SELECT MAX(interaction_date) - 3 FROM {{ this }})
    {% endif %}

)

SELECT
    i.interaction_id,

    COALESCE(d.date_sk, '-1')          AS date_sk,
    COALESCE(c.customer_sk, '-1')      AS customer_sk,
    COALESCE(c.home_location_sk, '-1') AS customer_location_sk,
    COALESCE(ch.channel_sk, '-1')      AS channel_sk,

    CASE
        WHEN i.target_type = 'Product' THEN COALESCE(p.product_sk, '-1')
        WHEN i.target_type = 'Page'    THEN '-2'
        ELSE '-1'
    END                                AS product_sk,

    i.session_id,
    i.interaction_type,
    i.interaction_target,
    i.target_type,
    i.interaction_date,
    i.interaction_time,

    i.duration

FROM interactions AS i

LEFT JOIN {{ ref('dim_date') }} AS d
    ON i.interaction_date = d.date_day

LEFT JOIN {{ ref('dim_customer') }} AS c
    ON i.customer_id = c.customer_id

LEFT JOIN {{ ref('dim_channel') }} AS ch
    ON i.channel = ch.channel_name

LEFT JOIN {{ ref('dim_product') }} AS p
    ON i.interaction_target = p.product_name