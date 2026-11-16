{{
    config(
        materialized = 'table'
    )
}}

-- Conformed channel dimension for sales (Online / Store) and interactions channel_group puts both on one level: Online or In-Store.

WITH channels AS (

    SELECT DISTINCT sales_channel AS channel_name
    FROM {{ ref('stg_transactions') }}
    WHERE sales_channel IS NOT NULL

    UNION

    SELECT DISTINCT channel
    FROM {{ ref('stg_interactions') }}
    WHERE channel IS NOT NULL

)

SELECT
    {{ dbt_utils.generate_surrogate_key(['channel_name']) }} AS channel_sk,
    channel_name,

    CASE
        WHEN channel_name IN ('Online', 'Web', 'Mobile App')  THEN 'Online'
        WHEN channel_name IN ('Store', 'In-Store Kiosk')      THEN 'In-Store'
        ELSE 'Other'
    END AS channel_group

FROM channels

UNION ALL
SELECT '-1', 'Unknown', 'Unknown'