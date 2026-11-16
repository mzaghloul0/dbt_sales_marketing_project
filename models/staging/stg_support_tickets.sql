WITH source AS (

    SELECT *
    FROM {{ ref('support_tickets') }}

),

cleaned AS (

    SELECT
        TRIM(ticket_id)                                             AS ticket_id,
        TRIM(customer_id)                                           AS customer_id,
        COALESCE(NULLIF(TRIM(issue_category), ''), 'Unknown')       AS issue_category,
        COALESCE(NULLIF(TRIM(priority), ''), 'Unknown')             AS priority,
        COALESCE(NULLIF(TRIM(resolution_status), ''), 'Unknown')    AS resolution_status,
        submission_date::TIMESTAMP                                  AS submitted_at,
        resolution_date::TIMESTAMP                                  AS resolved_at,
        resolution_time_hours::NUMERIC                              AS resolution_hours,
        customer_satisfaction_score::INTEGER                        AS satisfaction_score,
        COALESCE(NULLIF(TRIM(notes), ''), 'Unknown')                AS notes

    FROM source

),

-- a ticket can arrive again with a newer state: keep the latest one
deduplicated AS (

    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY ticket_id
            ORDER BY resolved_at DESC NULLS LAST
        ) AS rn

    FROM cleaned

)

SELECT
    ticket_id,
    customer_id,
    issue_category,
    priority,
    resolution_status,
    submitted_at::DATE  AS submission_date,
    resolved_at::DATE   AS resolution_date,

    -- missing hours are calculated from the full timestamps
    COALESCE(
        resolution_hours,
        ROUND(EXTRACT(EPOCH FROM resolved_at - submitted_at) / 3600)
    ) AS resolution_hours,

    satisfaction_score,
    notes

FROM deduplicated
WHERE rn = 1