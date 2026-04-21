-- ============================================================
-- Data Generation Script
-- Step 1: Populate dim_date
-- ============================================================

SET search_path TO analytics;

-- Clear existing data (safe for repeatable runs)
DELETE FROM dim_date;

-- Populate date dimension (5-year range)
INSERT INTO dim_date (
    date_id,
    full_date,
    day_of_month,
    month_number,
    month_name,
    quarter_number,
    year_number,
    week_number,
    is_month_end
)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT AS date_id,
    d AS full_date,
    EXTRACT(DAY FROM d)::INT,
    EXTRACT(MONTH FROM d)::INT,
    TO_CHAR(d, 'Month'),
    EXTRACT(QUARTER FROM d)::INT,
    EXTRACT(YEAR FROM d)::INT,
    EXTRACT(WEEK FROM d)::INT,
    CASE 
        WHEN d = (DATE_TRUNC('month', d) + INTERVAL '1 month - 1 day')::DATE
        THEN TRUE ELSE FALSE
    END AS is_month_end
FROM generate_series(
    DATE '2021-01-01',
    DATE '2025-12-31',
    INTERVAL '1 day'
) AS d;

-- Optional validation
SELECT COUNT(*) AS total_rows FROM dim_date;

-- ============================================================
-- Step 2: Populate dim_region
-- ============================================================

DELETE FROM dim_region;

INSERT INTO dim_region (
    region_name,
    country,
    market_segment
)
VALUES
    ('North America - Enterprise', 'United States', 'Enterprise'),
    ('North America - Mid-Market', 'United States', 'Mid-Market'),
    ('Europe - Enterprise', 'United Kingdom', 'Enterprise'),
    ('Europe - Mid-Market', 'Germany', 'Mid-Market'),
    ('APAC - Enterprise', 'Australia', 'Enterprise'),
    ('APAC - Mid-Market', 'Singapore', 'Mid-Market'),
    ('Latin America - Mid-Market', 'Brazil', 'Mid-Market');

-- Validation
SELECT *
FROM dim_region
ORDER BY region_id;

-- ============================================================
-- Step 3: Populate dim_product
-- ============================================================

DELETE FROM dim_product;

INSERT INTO dim_product (
    product_name,
    product_category,
    pricing_model,
    list_price,
    active_flag
)
VALUES
    ('Core Analytics Platform', 'Platform', 'Subscription', 12000.00, TRUE),
    ('Advanced Reporting Suite', 'Analytics Add-On', 'Subscription', 6000.00, TRUE),
    ('AI Forecasting Module', 'AI Add-On', 'Subscription', 9000.00, TRUE),
    ('Data Integration Package', 'Services', 'Annual License', 15000.00, TRUE),
    ('Executive Dashboard Pack', 'Analytics Add-On', 'Subscription', 4500.00, TRUE),
    ('Customer Health Monitor', 'Retention Add-On', 'Subscription', 7000.00, TRUE),
    ('Usage Intelligence Engine', 'Product Intelligence', 'Subscription', 8000.00, TRUE);

-- Validation
SELECT *
FROM dim_product
ORDER BY product_id;

-- ============================================================
-- Step 4: Populate dim_account_manager
-- ============================================================

DELETE FROM dim_account_manager;

WITH regions AS (
    SELECT region_id,
           ROW_NUMBER() OVER (ORDER BY region_id) AS rn
    FROM dim_region
)
INSERT INTO dim_account_manager (
    manager_name,
    manager_email,
    team_name,
    region_id,
    hire_date,
    active_flag
)
SELECT
    'Manager ' || gs AS manager_name,
    'manager' || gs || '@company.com' AS manager_email,
    CASE 
        WHEN gs % 3 = 0 THEN 'Enterprise Team'
        WHEN gs % 3 = 1 THEN 'Mid-Market Team'
        ELSE 'Expansion Team'
    END AS team_name,
    r.region_id,
    DATE '2018-01-01' + (gs * 30) AS hire_date,
    TRUE
FROM generate_series(1, 20) AS gs
JOIN regions r
    ON r.rn = ((gs - 1) % (SELECT COUNT(*) FROM regions)) + 1;

-- Validation
SELECT *
FROM dim_account_manager
ORDER BY account_manager_id;

-- ============================================================
-- Step 5: Populate dim_customer
-- ============================================================

DELETE FROM dim_customer;

WITH managers AS (
    SELECT
        account_manager_id,
        region_id,
        ROW_NUMBER() OVER (ORDER BY account_manager_id) AS rn,
        COUNT(*) OVER () AS total_managers
    FROM dim_account_manager
)
INSERT INTO dim_customer (
    customer_name,
    customer_segment,
    industry,
    employee_count,
    annual_revenue_band,
    region_id,
    account_manager_id,
    signup_date,
    status,
    health_score
)
SELECT
    'Customer ' || gs AS customer_name,
    CASE
        WHEN gs % 3 = 0 THEN 'Enterprise'
        WHEN gs % 3 = 1 THEN 'Mid-Market'
        ELSE 'SMB'
    END AS customer_segment,
    CASE
        WHEN gs % 5 = 0 THEN 'Financial Services'
        WHEN gs % 5 = 1 THEN 'Healthcare'
        WHEN gs % 5 = 2 THEN 'Technology'
        WHEN gs % 5 = 3 THEN 'Retail'
        ELSE 'Manufacturing'
    END AS industry,
    (50 + (gs * 17) % 5000) AS employee_count,
    CASE
        WHEN gs % 4 = 0 THEN '$1M-$10M'
        WHEN gs % 4 = 1 THEN '$10M-$50M'
        WHEN gs % 4 = 2 THEN '$50M-$250M'
        ELSE '$250M+'
    END AS annual_revenue_band,
    m.region_id,
    m.account_manager_id,
    DATE '2021-01-01' + ((gs * 11) % 1460) AS signup_date,
    CASE
        WHEN gs % 12 = 0 THEN 'At Risk'
        WHEN gs % 20 = 0 THEN 'Churned'
        WHEN gs % 15 = 0 THEN 'Inactive'
        ELSE 'Active'
    END AS status,
    ROUND(
        CASE
            WHEN gs % 20 = 0 THEN 35 + ((gs * 3) % 20)
            WHEN gs % 12 = 0 THEN 45 + ((gs * 5) % 20)
            WHEN gs % 15 = 0 THEN 40 + ((gs * 4) % 15)
            ELSE 70 + ((gs * 7) % 31)
        END
    , 2) AS health_score
FROM generate_series(1, 200) AS gs
JOIN managers m
    ON m.rn = ((gs - 1) % m.total_managers) + 1;

-- Validation
SELECT *
FROM dim_customer
ORDER BY customer_id;

-- ============================================================
-- Step 6: Populate fact_contracts
-- ============================================================

DELETE FROM fact_contracts;

WITH customer_base AS (
    SELECT
        c.customer_id,
        c.account_manager_id,
        c.signup_date,
        ROW_NUMBER() OVER (ORDER BY c.customer_id) AS rn,
        COUNT(*) OVER () AS total_customers
    FROM dim_customer c
),
product_base AS (
    SELECT
        p.product_id,
        p.list_price,
        ROW_NUMBER() OVER (ORDER BY p.product_id) AS rn,
        COUNT(*) OVER () AS total_products
    FROM dim_product p
)
INSERT INTO fact_contracts (
    customer_id,
    product_id,
    account_manager_id,
    contract_start_date,
    contract_end_date,
    contract_term_months,
    contract_value,
    discount_percent,
    net_contract_value,
    billing_frequency,
    auto_renew_flag,
    contract_status,
    created_at
)
SELECT
    c.customer_id,
    p.product_id,
    c.account_manager_id,
    contract_start_date,
    (contract_start_date + (c.term_months || ' months')::INTERVAL)::DATE,
    c.term_months,
    contract_value,
    c.discount_percent,
    ROUND(contract_value * (1 - c.discount_percent / 100.0), 2) AS net_contract_value,
    c.billing_frequency,
    c.auto_renew_flag,
    c.contract_status,
    contract_start_date::TIMESTAMP + INTERVAL '9 hours'
FROM (
    SELECT
        cb.customer_id,
        cb.account_manager_id,
        cb.signup_date,
        ((cb.rn - 1) % 7) + 1 AS product_rn,
        (DATE_TRUNC('month', cb.signup_date)::DATE + (((cb.rn * 13) % 90)::INT))::DATE AS contract_start_date,
        CASE
            WHEN cb.rn % 5 = 0 THEN 24
            WHEN cb.rn % 3 = 0 THEN 6
            ELSE 12
        END AS term_months,
        CASE
            WHEN cb.rn % 4 = 0 THEN 'Annual'
            WHEN cb.rn % 4 = 1 THEN 'Quarterly'
            ELSE 'Monthly'
        END AS billing_frequency,
        CASE
            WHEN cb.rn % 2 = 0 THEN TRUE
            ELSE FALSE
        END AS auto_renew_flag,
        CASE
            WHEN cb.rn % 20 = 0 THEN 'Cancelled'
            WHEN cb.rn % 9 = 0 THEN 'Expired'
            WHEN cb.rn % 7 = 0 THEN 'Pending Renewal'
            ELSE 'Active'
        END AS contract_status,
        CASE
            WHEN cb.rn % 10 = 0 THEN 20.00
            WHEN cb.rn % 6 = 0 THEN 12.50
            WHEN cb.rn % 4 = 0 THEN 7.50
            ELSE 0.00
        END AS discount_percent
    FROM customer_base cb
) c
JOIN product_base p
    ON p.rn = c.product_rn
CROSS JOIN LATERAL (
    SELECT ROUND(
        p.list_price *
        CASE
            WHEN c.term_months = 24 THEN 2.00
            WHEN c.term_months = 12 THEN 1.00
            ELSE 0.60
        END *
        CASE
            WHEN c.customer_id % 5 = 0 THEN 1.35
            WHEN c.customer_id % 5 = 1 THEN 1.15
            WHEN c.customer_id % 5 = 2 THEN 1.00
            WHEN c.customer_id % 5 = 3 THEN 0.85
            ELSE 0.70
        END
    , 2) AS contract_value
) cv;

-- Validation
SELECT *
FROM fact_contracts
ORDER BY contract_id;

-- ============================================================
-- Step 7: Populate fact_revenue_monthly
-- ============================================================

DELETE FROM fact_revenue_monthly;

WITH contract_months AS (
    SELECT
        fc.contract_id,
        fc.customer_id,
        fc.product_id,
        fc.account_manager_id,
        fc.contract_start_date,
        fc.contract_end_date,
        fc.net_contract_value,
        fc.contract_status,
        generate_series(
            DATE_TRUNC('month', fc.contract_start_date)::DATE,
            DATE_TRUNC('month', fc.contract_end_date)::DATE,
            INTERVAL '1 month'
        )::DATE AS revenue_month
    FROM fact_contracts fc
),
contract_metrics AS (
    SELECT
        cm.contract_id,
        cm.customer_id,
        cm.product_id,
        cm.account_manager_id,
        cm.revenue_month,
        cm.contract_status,
        ROUND(
            cm.net_contract_value
            / NULLIF(
                (
                    (EXTRACT(YEAR FROM AGE(cm.contract_end_date, cm.contract_start_date)) * 12)
                    + EXTRACT(MONTH FROM AGE(cm.contract_end_date, cm.contract_start_date))
                    + 1
                ),
                0
            ),
            2
        ) AS monthly_revenue
    FROM contract_months cm
)
INSERT INTO fact_revenue_monthly (
    customer_id,
    product_id,
    account_manager_id,
    date_id,
    contract_id,
    recognized_revenue,
    expansion_revenue,
    contraction_revenue,
    churned_revenue,
    leakage_amount
)
SELECT
    m.customer_id,
    m.product_id,
    m.account_manager_id,
    dd.date_id,
    m.contract_id,
    CASE
        WHEN m.contract_status IN ('Cancelled', 'Expired') AND EXTRACT(MONTH FROM m.revenue_month) % 5 = 0 THEN 0
        ELSE m.monthly_revenue
    END AS recognized_revenue,
    CASE
        WHEN m.customer_id % 11 = 0 AND EXTRACT(MONTH FROM m.revenue_month) IN (3, 6, 9, 12)
            THEN ROUND(m.monthly_revenue * 0.18, 2)
        ELSE 0
    END AS expansion_revenue,
    CASE
        WHEN m.customer_id % 9 = 0 AND EXTRACT(MONTH FROM m.revenue_month) IN (4, 8, 12)
            THEN ROUND(m.monthly_revenue * 0.12, 2)
        ELSE 0
    END AS contraction_revenue,
    CASE
        WHEN m.contract_status = 'Cancelled' AND m.revenue_month >= DATE_TRUNC('month', CURRENT_DATE)::DATE - INTERVAL '12 months'
            THEN ROUND(m.monthly_revenue, 2)
        ELSE 0
    END AS churned_revenue,
    CASE
        WHEN m.customer_id % 10 = 0
            THEN ROUND(m.monthly_revenue * 0.08, 2)
        WHEN m.customer_id % 6 = 0
            THEN ROUND(m.monthly_revenue * 0.04, 2)
        ELSE 0
    END AS leakage_amount
FROM contract_metrics m
JOIN dim_date dd
    ON dd.full_date = m.revenue_month
ORDER BY m.contract_id, m.revenue_month;

-- Validation
SELECT *
FROM fact_revenue_monthly
ORDER BY revenue_monthly_id;

-- ============================================================
-- Step 8: Populate fact_invoices
-- ============================================================

DELETE FROM fact_invoices;

WITH billing_schedule AS (
    SELECT
        fc.contract_id,
        fc.customer_id,
        fc.contract_start_date,
        fc.contract_end_date,
        fc.billing_frequency,
        fc.discount_percent,
        fc.net_contract_value,
        generate_series(
            DATE_TRUNC('month', fc.contract_start_date)::DATE,
            DATE_TRUNC('month', fc.contract_end_date)::DATE,
            CASE
                WHEN fc.billing_frequency = 'Monthly' THEN INTERVAL '1 month'
                WHEN fc.billing_frequency = 'Quarterly' THEN INTERVAL '3 months'
                ELSE INTERVAL '12 months'
            END
        )::DATE AS invoice_date
    FROM fact_contracts fc
),
invoice_base AS (
    SELECT
        bs.contract_id,
        bs.customer_id,
        bs.invoice_date,
        (bs.invoice_date + INTERVAL '30 days')::DATE AS due_date,
        bs.discount_percent,
        CASE
            WHEN bs.billing_frequency = 'Monthly' THEN ROUND(bs.net_contract_value / 12.0, 2)
            WHEN bs.billing_frequency = 'Quarterly' THEN ROUND(bs.net_contract_value / 4.0, 2)
            ELSE ROUND(bs.net_contract_value, 2)
        END AS invoice_amount
    FROM billing_schedule bs
)
INSERT INTO fact_invoices (
    contract_id,
    customer_id,
    date_id,
    invoice_date,
    due_date,
    invoice_amount,
    billed_discount_amount,
    invoice_status
)
SELECT
    ib.contract_id,
    ib.customer_id,
    dd.date_id,
    ib.invoice_date,
    ib.due_date,
    ib.invoice_amount,
    ROUND(ib.invoice_amount * (ib.discount_percent / 100.0), 2) AS billed_discount_amount,
    CASE
        WHEN ib.customer_id % 13 = 0 THEN 'Overdue'
        WHEN ib.customer_id % 11 = 0 THEN 'Open'
        WHEN ib.customer_id % 29 = 0 THEN 'Cancelled'
        ELSE 'Paid'
    END AS invoice_status
FROM invoice_base ib
JOIN dim_date dd
    ON dd.full_date = ib.invoice_date
ORDER BY ib.contract_id, ib.invoice_date;

-- Validation
SELECT *
FROM fact_invoices
ORDER BY invoice_id;

-- ============================================================
-- Step 9: Populate fact_payments
-- ============================================================

DELETE FROM fact_payments;

INSERT INTO fact_payments (
    invoice_id,
    customer_id,
    payment_date,
    payment_amount,
    payment_status,
    days_to_pay
)
SELECT
    fi.invoice_id,
    fi.customer_id,
    CASE
        WHEN fi.invoice_status = 'Paid' THEN fi.invoice_date + ((fi.customer_id % 25) + 5)
        WHEN fi.invoice_status = 'Overdue' THEN fi.due_date + ((fi.customer_id % 20) + 10)
        WHEN fi.invoice_status = 'Open' THEN NULL
        WHEN fi.invoice_status = 'Cancelled' THEN NULL
        ELSE NULL
    END AS payment_date,
    CASE
        WHEN fi.invoice_status = 'Paid' THEN fi.invoice_amount
        WHEN fi.invoice_status = 'Overdue' THEN ROUND(fi.invoice_amount * 0.65, 2)
        WHEN fi.invoice_status = 'Open' THEN 0.00
        WHEN fi.invoice_status = 'Cancelled' THEN 0.00
        ELSE 0.00
    END AS payment_amount,
    CASE
        WHEN fi.invoice_status = 'Paid' THEN 'Paid'
        WHEN fi.invoice_status = 'Overdue' THEN 'Partial'
        WHEN fi.invoice_status = 'Open' THEN 'Pending'
        WHEN fi.invoice_status = 'Cancelled' THEN 'Failed'
        ELSE 'Pending'
    END AS payment_status,
    CASE
        WHEN fi.invoice_status = 'Paid' THEN ((fi.customer_id % 25) + 5)
        WHEN fi.invoice_status = 'Overdue' THEN ((fi.due_date + ((fi.customer_id % 20) + 10)) - fi.invoice_date)
        ELSE NULL
    END AS days_to_pay
FROM fact_invoices fi
ORDER BY fi.invoice_id;

-- Validation
SELECT *
FROM fact_payments
ORDER BY payment_id;

-- ============================================================
-- Step 10: Populate fact_usage
-- ============================================================

DELETE FROM analytics.fact_usage;

INSERT INTO analytics.fact_usage (
    customer_id,
    product_id,
    date_id,
    usage_date,
    active_users,
    login_count,
    feature_adoption_rate,
    utilization_score
)
SELECT
    frm.customer_id,
    frm.product_id,
    frm.date_id,
    dd.full_date,

    -- Active users (varies across time)
    GREATEST(
        1,
        (10 + (frm.customer_id % 30)) + (EXTRACT(MONTH FROM dd.full_date)::INT % 6)
    ),

    -- Login count (time-varying)
    GREATEST(
        1,
        ((10 + (frm.customer_id % 30)) + (EXTRACT(MONTH FROM dd.full_date)::INT % 6))
        * (4 + (frm.product_id % 5))
    ),

    -- Feature adoption
    ROUND(
        LEAST(100,
            40 + dc.health_score * 0.5
        )::NUMERIC,
        2
    ),

    -- Utilization
    ROUND(
        LEAST(100,
            35 + dc.health_score * 0.55
        )::NUMERIC,
        2
    )

FROM analytics.fact_revenue_monthly frm
JOIN analytics.dim_customer dc
    ON frm.customer_id = dc.customer_id
JOIN analytics.dim_date dd
    ON frm.date_id = dd.date_id;

-- Validation
SELECT *
FROM analytics.fact_usage
ORDER BY usage_id
LIMIT 20;

-- ============================================================
-- Step 11: Populate fact_tickets
-- ============================================================

DELETE FROM analytics.fact_tickets;

INSERT INTO analytics.fact_tickets (
    customer_id,
    date_id,
    ticket_created_date,
    ticket_closed_date,
    ticket_priority,
    ticket_status,
    issue_category,
    resolution_time_hours,
    escalation_flag,
    satisfaction_score
)
SELECT
    dc.customer_id,
    dd.date_id,
    dd.full_date AS ticket_created_date,

    CASE
        WHEN (dc.customer_id % 4) = 0 THEN dd.full_date + ((dc.customer_id % 5) + 1)
        ELSE NULL
    END AS ticket_closed_date,

    CASE
        WHEN dc.customer_id % 10 = 0 THEN 'Critical'
        WHEN dc.customer_id % 7 = 0 THEN 'High'
        WHEN dc.customer_id % 3 = 0 THEN 'Medium'
        ELSE 'Low'
    END AS ticket_priority,

    CASE
        WHEN (dc.customer_id % 4) = 0 THEN 'Closed'
        WHEN (dc.customer_id % 3) = 0 THEN 'Resolved'
        WHEN (dc.customer_id % 5) = 0 THEN 'In Progress'
        ELSE 'Open'
    END AS ticket_status,

    CASE
        WHEN dc.customer_id % 5 = 0 THEN 'Billing Issue'
        WHEN dc.customer_id % 4 = 0 THEN 'Product Bug'
        WHEN dc.customer_id % 3 = 0 THEN 'Integration Issue'
        ELSE 'General Inquiry'
    END AS issue_category,

    CASE
        WHEN (dc.customer_id % 4) = 0 THEN ROUND((dc.customer_id % 24 + 1)::NUMERIC, 2)
        ELSE NULL
    END AS resolution_time_hours,

    CASE
        WHEN dc.customer_id % 8 = 0 THEN TRUE
        ELSE FALSE
    END AS escalation_flag,

    ROUND(
        CASE
            WHEN dc.status = 'Churned' THEN 4 + (dc.customer_id % 3)
            WHEN dc.status = 'At Risk' THEN 5 + (dc.customer_id % 3)
            WHEN dc.status = 'Inactive' THEN 6 + (dc.customer_id % 3)
            ELSE 7 + (dc.customer_id % 3)
        END
    , 2) AS satisfaction_score

FROM analytics.dim_customer dc
JOIN analytics.dim_date dd
    ON dd.full_date BETWEEN DATE '2022-01-01' AND DATE '2023-12-31'
WHERE (dc.customer_id + dd.date_id) % 20 = 0;

-- Validation
SELECT *
FROM analytics.fact_tickets
ORDER BY ticket_id
LIMIT 25;

-- ============================================================
-- Step 12: Populate fact_renewals
-- ============================================================

DELETE FROM analytics.fact_renewals;

WITH contract_pairs AS (
    SELECT
        fc.contract_id AS previous_contract_id,
        fc.customer_id,
        fc.contract_end_date,
        fc.net_contract_value AS previous_value,
        LEAD(fc.contract_id) OVER (
            PARTITION BY fc.customer_id
            ORDER BY fc.contract_start_date
        ) AS renewed_contract_id,
        LEAD(fc.net_contract_value) OVER (
            PARTITION BY fc.customer_id
            ORDER BY fc.contract_start_date
        ) AS renewed_value
    FROM analytics.fact_contracts fc
),
renewal_base AS (
    SELECT
        previous_contract_id,
        renewed_contract_id,
        customer_id,
        contract_end_date AS renewal_date,
        previous_value,
        renewed_value
    FROM contract_pairs
)
INSERT INTO analytics.fact_renewals (
    previous_contract_id,
    renewed_contract_id,
    customer_id,
    renewal_date,
    renewal_status,
    renewal_amount,
    previous_contract_value,
    renewed_contract_value,
    renewal_term_months
)
SELECT
    rb.previous_contract_id,
    rb.renewed_contract_id,
    rb.customer_id,
    rb.renewal_date,

    CASE
        WHEN rb.renewed_contract_id IS NULL THEN 'Churned'
        WHEN rb.renewed_value > rb.previous_value * 1.1 THEN 'Upsold'
        WHEN rb.renewed_value < rb.previous_value * 0.9 THEN 'Downgraded'
        ELSE 'Renewed'
    END AS renewal_status,

    COALESCE(rb.renewed_value, 0) AS renewal_amount,
    rb.previous_value AS previous_contract_value,
    rb.renewed_value AS renewed_contract_value,

    CASE
        WHEN rb.renewed_contract_id IS NULL THEN NULL
        ELSE 12 + (rb.customer_id % 12)
    END AS renewal_term_months

FROM renewal_base rb;

-- Validation
SELECT *
FROM analytics.fact_renewals
ORDER BY renewal_id
LIMIT 25;
