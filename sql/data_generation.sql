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
