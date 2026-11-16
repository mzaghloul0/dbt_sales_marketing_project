{{
    config(
        materialized = 'table'
    )
}}

-- Junk dimension: the three low-cardinality ticket attributes in one table,
-- with every combination, so the fact needs only one key.

WITH categories AS (SELECT DISTINCT issue_category    FROM {{ ref('stg_support_tickets') }}),
     priorities AS (SELECT DISTINCT priority          FROM {{ ref('stg_support_tickets') }}),
     statuses   AS (SELECT DISTINCT resolution_status FROM {{ ref('stg_support_tickets') }})

SELECT
    {{ dbt_utils.generate_surrogate_key(['issue_category', 'priority', 'resolution_status']) }} AS ticket_profile_sk,
    issue_category,
    priority,
    resolution_status

FROM categories
CROSS JOIN priorities
CROSS JOIN statuses