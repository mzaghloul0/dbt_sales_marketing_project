WITH source AS (

    SELECT * FROM {{ ref('campaigns') }}

),

cleaned AS (

    SELECT
        NULLIF(TRIM(campaign_id), '')                         AS campaign_id,
        COALESCE(NULLIF(TRIM(campaign_name), ''), 'Unknown')  AS campaign_name,
        COALESCE(NULLIF(TRIM(campaign_type), ''), 'Unknown')  AS campaign_type,
        COALESCE(NULLIF(TRIM(target_segment), ''), 'Unknown') AS target_segment,
        start_date::DATE                                      AS start_date,
        end_date::DATE                                        AS end_date,
        budget::NUMERIC                                       AS budget,
        impressions::BIGINT                                   AS impressions,
        clicks::BIGINT                                        AS clicks,
        conversions::BIGINT                                   AS conversions,
        conversion_rate::NUMERIC                              AS conversion_rate_pct,
        roi::NUMERIC                                          AS roi_pct

    FROM source

),

deduplicated AS (

    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY campaign_id
            ORDER BY
                end_date DESC NULLS LAST,
                start_date DESC NULLS LAST,
                budget DESC NULLS LAST,
                campaign_name
        ) AS rn

    FROM cleaned

)

SELECT
    campaign_id,
    campaign_name,
    campaign_type,

    CASE
        WHEN campaign_type IN ('Online Display Ads', 'Social Media', 'Email Marketing',
                               'Search Engine Marketing', 'Influencer Marketing', 'SMS Marketing')
            THEN 'Online'
        WHEN campaign_type IN ('Print Advertisement', 'Radio Advertisement',
                               'TV Advertisement', 'In-Store Promotion')
            THEN 'Offline'
        WHEN campaign_type = 'Unknown'
            THEN 'Unknown'
        ELSE 'Other'
    END AS media_type,

    target_segment,

    CASE
        WHEN target_segment IN ('East Coast', 'West Coast', 'Southern States', 'Midwest')
            THEN 'Geographic'
        WHEN target_segment IN ('Young Adults (18-25)', 'Adults (26-40)', 'Middle-aged (41-60)', 'Seniors (60+)')
            THEN 'Age Group'
        WHEN target_segment IN ('Online Shoppers', 'In-Store Shoppers')
            THEN 'Shopping Channel'
        WHEN target_segment IN ('Kitchen Enthusiasts', 'Technology Enthusiasts', 'Home Improvement')
            THEN 'Product Interest'
        WHEN target_segment IN ('New Customers', 'Loyal Customers', 'Inactive Customers',
                                'High-Value Customers', 'All Customers')
            THEN 'Customer Lifecycle'
        WHEN target_segment = 'Unknown'
            THEN 'Unknown'
        ELSE 'Other'
    END AS segment_category,

    start_date,
    end_date,

    CASE
        WHEN end_date >= start_date THEN end_date - start_date + 1
    END AS duration_days,

    budget,
    impressions,

    -- conversion_rate_pct = conversions / clicks * 100,
    -- so one missing value of the three can be recalculated
    COALESCE(clicks, ROUND(conversions * 100 / NULLIF(conversion_rate_pct, 0)))      AS clicks,
    COALESCE(conversions, ROUND(clicks * conversion_rate_pct / 100))                 AS conversions,
    COALESCE(conversion_rate_pct, ROUND(conversions * 100.0 / NULLIF(clicks, 0), 2)) AS conversion_rate_pct,
    roi_pct,

    CASE
        WHEN budget > 0 THEN ROUND(budget * (1 + roi_pct / 100), 2)
    END AS revenue

FROM deduplicated
WHERE rn = 1