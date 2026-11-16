{{
    config(
        unique_key = 'campaign_id'
    )
}}

-- Grain: one row per campaign (totals over the whole campaign).

SELECT
    c.campaign_id,

    COALESCE(k.campaign_sk, '-1') AS campaign_sk,
    COALESCE(ds.date_sk, '-1')    AS start_date_sk,
    COALESCE(de.date_sk, '-1')    AS end_date_sk,

    c.budget,
    c.impressions,
    c.clicks,
    c.conversions,
    c.conversion_rate,                                  -- not additive
    c.roi                                               -- not additive

FROM {{ ref('stg_campaigns') }} AS c

LEFT JOIN {{ ref('dim_campaign') }} AS k
    ON c.campaign_id = k.campaign_id

LEFT JOIN {{ ref('dim_date') }} AS ds
    ON c.start_date = ds.date_day

LEFT JOIN {{ ref('dim_date') }} AS de
    ON c.end_date = de.date_day