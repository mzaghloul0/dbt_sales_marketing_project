-- One table for the Tableau data quality dashboard:
-- raw = quality of the data we receive, staging = what is left after cleaning.

SELECT 'raw' AS layer, *
FROM {{ ref('dq_raw_issues') }}

UNION ALL

SELECT 'staging' AS layer, *
FROM {{ ref('dq_staging_issues') }}