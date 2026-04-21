-- ============================================================
-- KPI 1: Revenue Leakage (Monthly)
-- ============================================================

CREATE OR REPLACE VIEW analytics.v_kpi_revenue_leakage AS
SELECT
    dd.year_number,
    dd.month_number,

    -- Core revenue components
    SUM(frm.recognized_revenue) AS recognized_revenue,
    SUM(frm.expansion_revenue) AS expansion_revenue,
    SUM(frm.contraction_revenue) AS contraction_revenue,
    SUM(frm.churned_revenue) AS churned_revenue,
    SUM(frm.leakage_amount) AS leakage_amount,

    -- Total leakage (key KPI)
    SUM(frm.contraction_revenue + frm.churned_revenue + frm.leakage_amount) AS total_leakage,

    -- Total revenue base (for % calculations later)
    SUM(frm.recognized_revenue + frm.expansion_revenue) AS total_revenue

FROM analytics.fact_revenue_monthly frm
JOIN analytics.dim_date dd
    ON frm.date_id = dd.date_id

GROUP BY
    dd.year_number,
    dd.month_number

ORDER BY
    dd.year_number,
    dd.month_number;

-- ============================================================
-- Validation
-- ============================================================

SELECT *
FROM analytics.v_kpi_revenue_leakage
ORDER BY year_number, month_number;

-- ============================================================
-- KPI 2: Net Revenue Retention (NRR)
-- ============================================================

CREATE OR REPLACE VIEW analytics.v_kpi_nrr AS
SELECT
    dd.year_number,
    dd.month_number,

    SUM(frm.recognized_revenue) AS base_revenue,
    SUM(frm.expansion_revenue) AS expansion_revenue,
    SUM(frm.contraction_revenue) AS contraction_revenue,
    SUM(frm.churned_revenue) AS churned_revenue,

    -- NRR calculation
    ROUND(
        CASE 
            WHEN SUM(frm.recognized_revenue) = 0 THEN NULL
            ELSE
                (
                    SUM(frm.recognized_revenue)
                    + SUM(frm.expansion_revenue)
                    - SUM(frm.contraction_revenue)
                    - SUM(frm.churned_revenue)
                )
                / SUM(frm.recognized_revenue)
        END
    , 4) AS nrr

FROM analytics.fact_revenue_monthly frm
JOIN analytics.dim_date dd
    ON frm.date_id = dd.date_id

GROUP BY
    dd.year_number,
    dd.month_number

ORDER BY
    dd.year_number,
    dd.month_number;

-- ============================================================
-- Validation
-- ============================================================

SELECT *
FROM analytics.v_kpi_nrr
ORDER BY year_number, month_number;

-- ============================================================
-- KPI 3: Gross Renewal Rate
-- ============================================================

CREATE OR REPLACE VIEW analytics.v_kpi_gross_renewal_rate AS
SELECT
    EXTRACT(YEAR FROM fr.renewal_date) AS year_number,
    EXTRACT(MONTH FROM fr.renewal_date) AS month_number,

    SUM(fr.previous_contract_value) AS renewable_revenue,
    SUM(COALESCE(fr.renewed_contract_value, 0)) AS renewed_revenue,

    -- Gross Renewal Rate
    ROUND(
        CASE 
            WHEN SUM(fr.previous_contract_value) = 0 THEN NULL
            ELSE
                SUM(COALESCE(fr.renewed_contract_value, 0))
                / SUM(fr.previous_contract_value)
        END
    , 4) AS gross_renewal_rate

FROM analytics.fact_renewals fr

GROUP BY
    EXTRACT(YEAR FROM fr.renewal_date),
    EXTRACT(MONTH FROM fr.renewal_date)

ORDER BY
    year_number,
    month_number;

-- ============================================================
-- Validation
-- ============================================================

SELECT *
FROM analytics.v_kpi_gross_renewal_rate
ORDER BY year_number, month_number;

-- ============================================================
-- KPI 4: Revenue Churn Rate
-- ============================================================

CREATE OR REPLACE VIEW analytics.v_kpi_churn_rate AS
SELECT
    dd.year_number,
    dd.month_number,

    SUM(frm.recognized_revenue) AS base_revenue,
    SUM(frm.churned_revenue) AS churned_revenue,

    -- Churn Rate
    ROUND(
        CASE 
            WHEN SUM(frm.recognized_revenue) = 0 THEN NULL
            ELSE SUM(frm.churned_revenue) / SUM(frm.recognized_revenue)
        END
    , 4) AS churn_rate

FROM analytics.fact_revenue_monthly frm
JOIN analytics.dim_date dd
    ON frm.date_id = dd.date_id

GROUP BY
    dd.year_number,
    dd.month_number

ORDER BY
    dd.year_number,
    dd.month_number;

-- ============================================================
-- Validation
-- ============================================================

SELECT *
FROM analytics.v_kpi_churn_rate
ORDER BY year_number, month_number;
