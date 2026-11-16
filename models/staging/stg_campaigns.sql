WITH source AS (

    SELECT *
    FROM {{ ref('campaigns') }}

),

cleaned AS (

    SELECT
        TRIM(campaign_id)                                     AS campaign_id,
        COALESCE(NULLIF(TRIM(campaign_name), ''), 'Unknown')  AS campaign_name,
        COALESCE(NULLIF(TRIM(campaign_type), ''), 'Unknown')  AS campaign_type,
        start_date::DATE                                      AS start_date,
        end_date::DATE                                        AS end_date,
        COALESCE(NULLIF(TRIM(target_segment), ''), 'Unknown') AS target_segment,
        budget::NUMERIC(12, 2)                                AS budget,
        impressions::BIGINT                                   AS impressions,
        clicks::BIGINT                                        AS clicks,
        conversions::BIGINT                                   AS conversions,
        conversion_rate::NUMERIC(5, 2)                        AS conversion_rate,
        roi::NUMERIC(10, 2)                                   AS roi

    FROM source

),

deduplicated AS (

    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY campaign_id
            ORDER BY end_date DESC NULLS LAST
        ) AS rn

    FROM cleaned

)

SELECT
    campaign_id,
    campaign_name,
    campaign_type,
    start_date,
    end_date,
    CASE
        WHEN end_date >= start_date THEN end_date - start_date + 1
    END AS duration_days,
    target_segment,
    budget,
    impressions,
    clicks,
    conversions,
    conversion_rate,
    roi

FROM deduplicated
WHERE rn = 1