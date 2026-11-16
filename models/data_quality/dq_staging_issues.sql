-- Data quality after cleaning: what is still wrong in staging.
-- Same checks as dq_raw_issues, with the staging column names.
-- Duplicates are not checked here: the unique tests on staging guarantee 0.

WITH customers AS (

    SELECT 'customers' AS source_table, customer_id AS record_id, c.*
    FROM {{ ref('stg_customers') }}
    CROSS JOIN LATERAL (VALUES
        ('customer_id', 'missing',        customer_id IS NULL,                       'Critical'),
        ('age',         'out of range',   age NOT BETWEEN 18 AND 120,                'High'),
        -- missing text is 'Unknown' in staging: that is not a format problem
        ('email',       'invalid format', email <> 'Unknown'
                                          AND email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$', 'Medium'),
        ('phone',       'invalid format', phone <> 'Unknown'
                                          AND phone !~ '^\+1[2-9][0-9]{2}[2-9][0-9]{6}(x[0-9]+)?$', 'Medium'),
        ('state_code',  'missing',        state_code IS NULL,                        'Medium')
    ) AS c (column_name, issue, has_issue, severity)

),

transactions AS (

    SELECT 'transactions', transaction_id, c.*
    FROM {{ ref('stg_transactions') }}
    CROSS JOIN LATERAL (VALUES
        ('transaction_date', 'missing',      transaction_date IS NULL,            'Critical'),
        ('net_revenue',      'missing',      net_revenue IS NULL,                 'Critical'),
        ('quantity',         'out of range', quantity <= 0,                       'High'),
        ('unit_price',       'out of range', unit_price <= 0,                     'High'),
        ('discount_pct',     'out of range', discount_pct NOT BETWEEN 0 AND 100,  'High'),
        ('quantity',         'outlier',      quantity > 5,                        'Medium'),
        ('customer_id',      'missing',      customer_id IS NULL,                 'Medium'),
        ('product_name',     'missing',      product_name IS NULL,                'Medium'),
        ('product_category', 'missing',      product_category = 'Unknown',        'Medium'),
        ('sales_channel',    'missing',      sales_channel IS NULL,               'Medium'),
        ('payment_method',   'missing',      payment_method IS NULL,              'Medium')
    ) AS c (column_name, issue, has_issue, severity)

),

interactions AS (

    SELECT 'interactions', interaction_id, c.*
    FROM {{ ref('stg_interactions') }}
    CROSS JOIN LATERAL (VALUES
        ('interaction_date', 'missing',      interaction_date IS NULL,  'Critical'),
        ('duration',         'out of range', duration < 0,              'High'),
        ('customer_id',      'missing',      customer_id IS NULL,       'Medium')
    ) AS c (column_name, issue, has_issue, severity)

),

customer_reviews AS (

    SELECT 'customer_reviews', review_id, c.*
    FROM {{ ref('stg_customer_reviews') }}
    CROSS JOIN LATERAL (VALUES
        ('rating',         'out of range',    rating NOT BETWEEN 1 AND 5,  'High'),
        ('days_to_review', 'before purchase', days_to_review < 0,          'High'),
        ('rating',         'missing',         rating IS NULL,              'Medium'),
        ('customer_id',    'missing',         customer_id IS NULL,         'Medium'),
        ('product_name',   'missing',         product_name IS NULL,        'Medium')
    ) AS c (column_name, issue, has_issue, severity)

),

support_tickets AS (

    SELECT 'support_tickets', ticket_id, c.*
    FROM {{ ref('stg_support_tickets') }}
    CROSS JOIN LATERAL (VALUES
        ('submission_date',    'missing',           submission_date IS NULL,                'Critical'),
        ('resolution_date',    'before submission', resolution_date < submission_date,      'High'),
        ('satisfaction_score', 'out of range',      satisfaction_score NOT BETWEEN 1 AND 5, 'High'),
        ('customer_id',        'missing',           customer_id IS NULL,                    'Medium'),
        -- a closed ticket must have a resolution date, an open one must not
        ('resolution_status',  'status mismatch',   (resolution_status IN ('Resolved', 'Closed without Resolution')
                                                     AND resolution_date IS NULL)
                                                    OR (resolution_status IN ('Pending', 'Escalated')
                                                     AND resolution_date IS NOT NULL),      'Medium'),
        -- staging only has dates, so allow one day of difference
        ('resolution_hours',   'inconsistent',      ABS(resolution_hours
                                                        - (resolution_date - submission_date) * 24) > 24, 'Medium'),
        -- only closed tickets can have a score
        ('satisfaction_score', 'missing',           resolution_date IS NOT NULL
                                                    AND satisfaction_score IS NULL,         'Medium')
    ) AS c (column_name, issue, has_issue, severity)

),

campaigns AS (

    SELECT 'campaigns', campaign_id, c.*
    FROM {{ ref('stg_campaigns') }}
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
        ('roi_pct',     'missing',               roi_pct IS NULL,        'Medium')
    ) AS c (column_name, issue, has_issue, severity)

),

all_checks AS (

    SELECT * FROM customers
    UNION ALL SELECT * FROM transactions
    UNION ALL SELECT * FROM interactions
    UNION ALL SELECT * FROM customer_reviews
    UNION ALL SELECT * FROM support_tickets
    UNION ALL SELECT * FROM campaigns

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