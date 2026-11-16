WITH source AS (

    SELECT *
    FROM {{ ref('interactions') }}

),

cleaned AS (

    SELECT
        TRIM(interaction_id)                                    AS interaction_id,
        TRIM(customer_id)                                       AS customer_id,
        INITCAP(NULLIF(TRIM(channel), ''))                      AS channel,

        -- "product_view" -> "Product View"
        COALESCE(INITCAP(REPLACE(NULLIF(TRIM(interaction_type), ''), '_', ' ')), 'Unknown') AS interaction_type,

        interaction_date::TIMESTAMP                             AS interacted_at,
        duration::INTEGER                                       AS duration,
        NULLIF(TRIM(page_or_product), '')                       AS page_or_product,
        COALESCE(NULLIF(TRIM(session_id), ''), 'Unknown')       AS session_id

    FROM source

),

-- the same interaction can arrive again in a later batch: keep the latest version
deduplicated AS (

    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY interaction_id
            ORDER BY
                interacted_at DESC NULLS LAST,
                duration DESC NULLS LAST
        ) AS rn

    FROM cleaned

)

SELECT
    interaction_id,
    customer_id,

    channel,
    CASE
        WHEN channel IN ('Web', 'Mobile App') THEN 'Online'
        WHEN channel = 'In-Store Kiosk'       THEN 'Store'
        WHEN channel IS NULL                  THEN 'Unknown'
        ELSE 'Other'
    END                                  AS channel_group,

    interaction_type,

    interacted_at::DATE                  AS interaction_date,
    interacted_at::TIME(0)               AS interaction_time,

    duration,

    COALESCE(page_or_product, 'Unknown') AS interaction_target,

    -- pages are lowercase with underscores ("checkout", "category_tvs"),
    -- everything else is a product name ("iPhone 13")
    CASE
        WHEN page_or_product IS NULL       THEN 'Unknown'
        WHEN page_or_product ~ '^[a-z_]+$' THEN 'Page'
        ELSE 'Product'
    END                                  AS target_type,

    session_id

FROM deduplicated
WHERE rn = 1