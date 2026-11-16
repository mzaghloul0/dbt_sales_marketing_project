{{
    config(
        materialized = 'table'
    )
}}

WITH payment_methods AS (

    SELECT DISTINCT payment_method
    FROM {{ ref('stg_transactions') }}
    WHERE payment_method IS NOT NULL

)

SELECT
    {{ dbt_utils.generate_surrogate_key(['payment_method']) }} AS payment_method_sk,
    payment_method,

    CASE
        WHEN payment_method IN ('Credit Card', 'Debit Card')            THEN 'Card'
        WHEN payment_method IN ('PayPal', 'Apple Pay', 'Google Pay')    THEN 'Digital Wallet'
        WHEN payment_method IN ('Cash', 'Gift Card')                    THEN payment_method
        ELSE 'Other'
    END AS payment_type

FROM payment_methods

UNION ALL
SELECT '-1', 'Unknown', 'Unknown'