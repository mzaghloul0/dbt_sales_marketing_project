{{
    config(
        unique_key = 'ticket_id'
    )
}}

-- Grain: one row per ticket, updated when it gets resolved.
-- resolution_date_sk = '-2' while the ticket is open (no resolution date yet).

WITH tickets AS (

    SELECT * FROM {{ ref('stg_support_tickets') }}

    {% if is_incremental() %}
    -- recent tickets and all open ones are reloaded and overwritten
    WHERE submission_date >= (SELECT MAX(submission_date) - 30 FROM {{ this }})
       OR resolution_date IS NULL
    {% endif %}

)

SELECT
    t.ticket_id,

    COALESCE(ds.date_sk, '-1')           AS submission_date_sk,

    CASE
        WHEN t.resolution_date IS NULL THEN '-2'
        ELSE COALESCE(dr.date_sk, '-1')
    END                                  AS resolution_date_sk,

    COALESCE(c.customer_sk, '-1')        AS customer_sk,
    COALESCE(c.home_location_sk, '-1')   AS customer_location_sk,
    tp.ticket_profile_sk,

    t.submission_date,
    t.notes,

    t.resolution_hours,
    t.satisfaction_score                                -- not additive

FROM tickets AS t

LEFT JOIN {{ ref('dim_date') }} AS ds
    ON t.submission_date = ds.date_day

LEFT JOIN {{ ref('dim_date') }} AS dr
    ON t.resolution_date = dr.date_day

LEFT JOIN {{ ref('dim_customer') }} AS c
    ON t.customer_id = c.customer_id

LEFT JOIN {{ ref('dim_ticket_profile') }} AS tp
    ON  t.issue_category    = tp.issue_category
    AND t.priority          = tp.priority
    AND t.resolution_status = tp.resolution_status