{{
    config(
        unique_key = 'campaign_sk'
    )
}}

-- One row per campaign. media_type and segment_category are grouping
-- attributes: defined once here, so every report groups the same way.

SELECT
    {{ dbt_utils.generate_surrogate_key(['campaign_id']) }} AS campaign_sk,
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

    duration_days

FROM {{ ref('stg_campaigns') }}

UNION ALL
SELECT '-1', 'Unknown', 'Unknown', 'Unknown', 'Unknown', 'Unknown', 'Unknown', NULL