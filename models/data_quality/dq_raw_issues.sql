-- Data quality checks on the raw seeds. One row per problem.
-- Only problems that break a key, a KPI or a dimension are checked.
-- Every check is one line: (column, issue, true when there is a problem, severity)

WITH customers AS (

    SELECT 'customers' AS source_table, customer_id AS record_id, c.*
    FROM {{ ref('customers') }}
    CROSS JOIN LATERAL (VALUES
        ('customer_id', 'missing',        customer_id IS NULL,                      'Critical'),
        ('age',         'out of range',   age NOT BETWEEN 18 AND 120,               'High'),
        ('email',       'invalid format', email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$',    'Medium'),
        ('phone',       'invalid format', phone <> 'Unknown'
                                          AND phone !~ '^\+1[2-9][0-9]{2}[2-9][0-9]{6}(x[0-9]+)?$', 'Medium'),
        ('state',       'missing',        state IS NULL,                            'Medium')
    ) AS c (column_name, issue, has_issue, severity)

),

transactions AS (

    SELECT 'transactions', transaction_id, c.*
    FROM {{ ref('transactions') }}
    CROSS JOIN LATERAL (VALUES
        ('transaction_id',   'missing',        transaction_id IS NULL,                  'Critical'),
        ('transaction_date', 'missing',        transaction_date IS NULL,                'Critical'),
        ('quantity',         'missing',        quantity IS NULL,                        'Critical'),
        ('price',            'missing',        price IS NULL,                           'Critical'),
        ('quantity',         'out of range',   quantity <= 0,                           'High'),
        ('price',            'out of range',   price <= 0,                              'High'),
        ('discount_applied', 'out of range',   discount_applied NOT BETWEEN 0 AND 100,  'High'),
        ('quantity',         'outlier',        quantity > 5,                            'Medium'),
        ('customer_id',      'missing',        customer_id IS NULL,                     'Medium'),
        ('product_name',     'missing',        product_name IS NULL,                    'Medium'),
        ('product_category', 'missing',        product_category IS NULL,                'Medium'),
        ('store_location',   'missing',        store_location IS NULL,                  'Medium'),
        -- "Online" or "City, ST"
        ('store_location',   'invalid format', store_location <> 'Online'
                                               AND store_location !~ '^[^,]+, [A-Z]{2}$', 'Medium'),
        ('payment_method',   'missing',        payment_method IS NULL,                  'Medium')
    ) AS c (column_name, issue, has_issue, severity)

),

interactions AS (

    SELECT 'interactions', interaction_id, c.*
    FROM {{ ref('interactions') }}
    CROSS JOIN LATERAL (VALUES
        ('interaction_date', 'missing',      interaction_date IS NULL,  'Critical'),
        ('duration',         'out of range', duration < 0,              'High'),
        ('customer_id',      'missing',      customer_id IS NULL,       'Medium')
    ) AS c (column_name, issue, has_issue, severity)

),

customer_reviews AS (

    SELECT 'customer_reviews', review_id, c.*
    FROM {{ ref('customer_reviews_complete') }}
    CROSS JOIN LATERAL (VALUES
        ('rating',       'out of range',    rating NOT BETWEEN 1 AND 5,      'High'),
        ('review_date',  'before purchase', review_date < transaction_date,  'High'),
        ('rating',       'missing',         rating IS NULL,                  'Medium'),
        ('customer_id',  'missing',         customer_id IS NULL,             'Medium'),
        ('product_name', 'missing',         product_name IS NULL,            'Medium')
    ) AS c (column_name, issue, has_issue, severity)

),

support_tickets AS (

    SELECT 'support_tickets', ticket_id, c.*
    FROM {{ ref('support_tickets') }}
    CROSS JOIN LATERAL (VALUES
        ('submission_date',             'missing',           submission_date IS NULL,                         'Critical'),
        ('resolution_date',             'before submission', resolution_date < submission_date,               'High'),
        ('customer_satisfaction_score', 'out of range',      customer_satisfaction_score NOT BETWEEN 1 AND 5, 'High'),
        ('customer_id',                 'missing',           customer_id IS NULL,                             'Medium'),
        -- a closed ticket must have a resolution date, an open one must not
        ('resolution_status',           'status mismatch',   (resolution_status IN ('Resolved', 'Closed without Resolution')
                                                              AND resolution_date IS NULL)
                                                             OR (resolution_status IN ('Pending', 'Escalated')
                                                              AND resolution_date IS NOT NULL),               'Medium'),
        ('resolution_time_hours',       'inconsistent',      ABS(resolution_time_hours - EXTRACT(EPOCH FROM
                                                                 resolution_date - submission_date) / 3600) > 1, 'Medium'),
        -- only closed tickets can have a score
        ('customer_satisfaction_score', 'missing',           resolution_date IS NOT NULL
                                                             AND customer_satisfaction_score IS NULL,         'Medium')
    ) AS c (column_name, issue, has_issue, severity)

),

campaigns AS (

    SELECT 'campaigns', campaign_id, c.*
    FROM {{ ref('campaigns') }}
    CROSS JOIN LATERAL (VALUES
        ('end_date',    'before start',          end_date < start_date,  'High'),
        ('budget',      'out of range',          budget <= 0,            'High'),
        ('clicks',      'more than impressions', clicks > impressions,   'High'),
        ('conversions', 'more than clicks',      conversions > clicks,   'High'),
        ('start_date',  'missing',               start_date IS NULL,     'Medium'),
        ('end_date',    'missing',               end_date IS NULL,       'Medium'),
        ('budget',      'missing',               budget IS NULL,         'Medium'),
        ('impressions', 'missing',               impressions IS NULL,    'Medium'),
        ('clicks',      'missing',               clicks IS NULL,         'Medium'),
        ('conversions', 'missing',               conversions IS NULL,    'Medium'),
        ('roi',         'missing',               roi IS NULL,            'Medium')
    ) AS c (column_name, issue, has_issue, severity)

),

-- primary keys that appear more than once
duplicates AS (

    SELECT 'customers', customer_id, 'customer_id', 'duplicate', TRUE, 'Critical'
    FROM {{ ref('customers') }} GROUP BY customer_id HAVING COUNT(*) > 1
    UNION ALL
    SELECT 'transactions', transaction_id, 'transaction_id', 'duplicate', TRUE, 'Critical'
    FROM {{ ref('transactions') }} GROUP BY transaction_id HAVING COUNT(*) > 1
    UNION ALL
    SELECT 'interactions', interaction_id, 'interaction_id', 'duplicate', TRUE, 'Critical'
    FROM {{ ref('interactions') }} GROUP BY interaction_id HAVING COUNT(*) > 1
    UNION ALL
    SELECT 'customer_reviews', review_id, 'review_id', 'duplicate', TRUE, 'Critical'
    FROM {{ ref('customer_reviews_complete') }} GROUP BY review_id HAVING COUNT(*) > 1
    UNION ALL
    SELECT 'support_tickets', ticket_id, 'ticket_id', 'duplicate', TRUE, 'Critical'
    FROM {{ ref('support_tickets') }} GROUP BY ticket_id HAVING COUNT(*) > 1
    UNION ALL
    SELECT 'campaigns', campaign_id, 'campaign_id', 'duplicate', TRUE, 'Critical'
    FROM {{ ref('campaigns') }} GROUP BY campaign_id HAVING COUNT(*) > 1

),

all_checks AS (

    SELECT * FROM customers
    UNION ALL SELECT * FROM transactions
    UNION ALL SELECT * FROM interactions
    UNION ALL SELECT * FROM customer_reviews
    UNION ALL SELECT * FROM support_tickets
    UNION ALL SELECT * FROM campaigns
    UNION ALL SELECT * FROM duplicates

)

SELECT
    source_table,
    record_id,
    column_name,
    issue,
    severity,
    CASE severity
        WHEN 'Critical' THEN 1
        WHEN 'High'     THEN 2
        ELSE 3
    END AS severity_rank

FROM all_checks
WHERE has_issue