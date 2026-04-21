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
    ('North America', 'United States', 'Enterprise'),
    ('North America', 'United States', 'Mid-Market'),
    ('Europe', 'United Kingdom', 'Enterprise'),
    ('Europe', 'Germany', 'Mid-Market'),
    ('APAC', 'Australia', 'Enterprise'),
    ('APAC', 'Singapore', 'Mid-Market'),
    ('Latin America', 'Brazil', 'Mid-Market');

-- Optional validation
SELECT *
FROM dim_region
ORDER BY region_id;
