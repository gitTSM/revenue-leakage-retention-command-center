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

-- ============================================================
-- KPI 5: At-Risk Revenue
-- ============================================================

CREATE OR REPLACE VIEW analytics.v_kpi_at_risk_revenue AS
WITH usage_signals AS (
    SELECT
        fu.customer_id,
        fu.date_id,
        AVG(fu.utilization_score) AS avg_utilization_score
    FROM analytics.fact_usage fu
    GROUP BY
        fu.customer_id,
        fu.date_id
),
payment_signals AS (
    SELECT
        fp.customer_id,
        fi.date_id,
        MAX(
            CASE
                WHEN fp.payment_status IN ('Pending', 'Failed')
                     OR fi.invoice_status = 'Overdue'
                THEN 1
                ELSE 0
            END
        ) AS payment_risk_flag
    FROM analytics.fact_payments fp
    JOIN analytics.fact_invoices fi
        ON fp.invoice_id = fi.invoice_id
    GROUP BY
        fp.customer_id,
        fi.date_id
),
ticket_signals AS (
    SELECT
        ft.customer_id,
        ft.date_id,
        COUNT(*) AS ticket_count,
        MAX(
            CASE
                WHEN ft.ticket_priority IN ('High', 'Critical')
                     OR ft.escalation_flag = TRUE
                THEN 1
                ELSE 0
            END
        ) AS support_risk_flag
    FROM analytics.fact_tickets ft
    GROUP BY
        ft.customer_id,
        ft.date_id
),
renewal_signals AS (
    SELECT
        fr.customer_id,
        dd.date_id,
        MAX(
            CASE
                WHEN fr.renewal_date BETWEEN dd.full_date AND dd.full_date + INTERVAL '90 days'
                THEN 1
                ELSE 0
            END
        ) AS upcoming_renewal_flag
    FROM analytics.fact_renewals fr
    JOIN analytics.dim_date dd
        ON dd.full_date <= fr.renewal_date
    GROUP BY
        fr.customer_id,
        dd.date_id
),
customer_month_risk AS (
    SELECT
        frm.customer_id,
        frm.date_id,
        frm.recognized_revenue,

        CASE
            WHEN COALESCE(us.avg_utilization_score, 100) < 50 THEN 1
            ELSE 0
        END AS low_usage_flag,

        COALESCE(ps.payment_risk_flag, 0) AS payment_risk_flag,

        CASE
            WHEN COALESCE(ts.ticket_count, 0) >= 2
                 OR COALESCE(ts.support_risk_flag, 0) = 1
            THEN 1
            ELSE 0
        END AS support_risk_flag,

        COALESCE(rs.upcoming_renewal_flag, 0) AS upcoming_renewal_flag

    FROM analytics.fact_revenue_monthly frm
    LEFT JOIN usage_signals us
        ON frm.customer_id = us.customer_id
       AND frm.date_id = us.date_id
    LEFT JOIN payment_signals ps
        ON frm.customer_id = ps.customer_id
       AND frm.date_id = ps.date_id
    LEFT JOIN ticket_signals ts
        ON frm.customer_id = ts.customer_id
       AND frm.date_id = ts.date_id
    LEFT JOIN renewal_signals rs
        ON frm.customer_id = rs.customer_id
       AND frm.date_id = rs.date_id
)
SELECT
    dd.year_number,
    dd.month_number,

    SUM(cmr.recognized_revenue) AS total_revenue,

    SUM(
        CASE
            WHEN (
                cmr.low_usage_flag
                + cmr.payment_risk_flag
                + cmr.support_risk_flag
                + cmr.upcoming_renewal_flag
            ) >= 2
            THEN cmr.recognized_revenue
            ELSE 0
        END
    ) AS at_risk_revenue,

    ROUND(
        CASE
            WHEN SUM(cmr.recognized_revenue) = 0 THEN NULL
            ELSE
                SUM(
                    CASE
                        WHEN (
                            cmr.low_usage_flag
                            + cmr.payment_risk_flag
                            + cmr.support_risk_flag
                            + cmr.upcoming_renewal_flag
                        ) >= 2
                        THEN cmr.recognized_revenue
                        ELSE 0
                    END
                ) / SUM(cmr.recognized_revenue)
        END
    , 4) AS at_risk_revenue_pct

FROM customer_month_risk cmr
JOIN analytics.dim_date dd
    ON cmr.date_id = dd.date_id

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
FROM analytics.v_kpi_at_risk_revenue
ORDER BY year_number, month_number;

-- ============================================================
-- KPI 6: Average Discount Rate
-- ============================================================

CREATE OR REPLACE VIEW analytics.v_kpi_discount_rate AS
SELECT
    EXTRACT(YEAR FROM fc.contract_start_date) AS year_number,
    EXTRACT(MONTH FROM fc.contract_start_date) AS month_number,

    -- Simple average discount
    ROUND(AVG(fc.discount_percent), 2) AS avg_discount_percent,

    -- Weighted discount (more accurate)
    ROUND(
        CASE 
            WHEN SUM(fc.contract_value) = 0 THEN NULL
            ELSE
                SUM(fc.contract_value * fc.discount_percent)
                / SUM(fc.contract_value)
        END
    , 2) AS weighted_discount_percent,

    SUM(fc.contract_value) AS total_contract_value

FROM analytics.fact_contracts fc

GROUP BY
    EXTRACT(YEAR FROM fc.contract_start_date),
    EXTRACT(MONTH FROM fc.contract_start_date)

ORDER BY
    year_number,
    month_number;

-- ============================================================
-- Validation
-- ============================================================

SELECT *
FROM analytics.v_kpi_discount_rate
ORDER BY year_number, month_number;

-- ============================================================
-- KPI 7: Days Sales Outstanding (DSO)
-- ============================================================

CREATE OR REPLACE VIEW analytics.v_kpi_dso AS
SELECT
    EXTRACT(YEAR FROM fp.payment_date) AS year_number,
    EXTRACT(MONTH FROM fp.payment_date) AS month_number,

    SUM(fp.payment_amount) AS total_collected,

    -- Weighted DSO
    ROUND(
        CASE 
            WHEN SUM(fp.payment_amount) = 0 THEN NULL
            ELSE
                SUM(fp.payment_amount * fp.days_to_pay)
                / SUM(fp.payment_amount)
        END
    , 2) AS dso_days

FROM analytics.fact_payments fp
WHERE fp.payment_status = 'Paid'
  AND fp.payment_date IS NOT NULL

GROUP BY
    EXTRACT(YEAR FROM fp.payment_date),
    EXTRACT(MONTH FROM fp.payment_date)

ORDER BY
    year_number,
    month_number;

-- ============================================================
-- Validation
-- ============================================================

SELECT *
FROM analytics.v_kpi_dso
ORDER BY year_number, month_number;

-- ============================================================
-- KPI 8: Customer Health Score (Monthly)
-- ============================================================

CREATE OR REPLACE VIEW analytics.v_kpi_customer_health AS
WITH usage_comp AS (
    SELECT
        fu.customer_id,
        fu.date_id,
        AVG(COALESCE(fu.utilization_score, 0)) AS utilization_score
    FROM analytics.fact_usage fu
    GROUP BY fu.customer_id, fu.date_id
),
support_comp AS (
    SELECT
        ft.customer_id,
        ft.date_id,
        COUNT(*) AS ticket_count,
        MAX(CASE WHEN ft.escalation_flag THEN 1 ELSE 0 END) AS escalation_flag
    FROM analytics.fact_tickets ft
    GROUP BY ft.customer_id, ft.date_id
),
payment_comp AS (
    SELECT
        fp.customer_id,
        fi.date_id,
        AVG(COALESCE(fp.days_to_pay, 0)) AS avg_days_to_pay,
        MAX(CASE
                WHEN fp.payment_status IN ('Pending','Failed')
                     OR fi.invoice_status = 'Overdue'
                THEN 1 ELSE 0
            END) AS payment_issue_flag
    FROM analytics.fact_payments fp
    JOIN analytics.fact_invoices fi
      ON fp.invoice_id = fi.invoice_id
    GROUP BY fp.customer_id, fi.date_id
),
renewal_comp AS (
    SELECT
        fr.customer_id,
        dd.date_id,
        MAX(
            CASE
                WHEN fr.renewal_date BETWEEN dd.full_date AND dd.full_date + INTERVAL '90 days'
                THEN 1 ELSE 0
            END
        ) AS upcoming_renewal_flag
    FROM analytics.fact_renewals fr
    JOIN analytics.dim_date dd
      ON dd.full_date <= fr.renewal_date
    GROUP BY fr.customer_id, dd.date_id
),
base AS (
    SELECT
        frm.customer_id,
        frm.date_id,

        COALESCE(u.utilization_score, 50) AS util_score,

        -- invert support: more tickets/escalations → lower score
        GREATEST(0, 100 - (COALESCE(s.ticket_count,0) * 5) - (COALESCE(s.escalation_flag,0) * 15)) AS support_score,

        -- invert payments: more days/flags → lower score
        GREATEST(0, 100 - (COALESCE(p.avg_days_to_pay,0) * 2) - (COALESCE(p.payment_issue_flag,0) * 20)) AS payment_score,

        -- renewal risk: upcoming renewal lowers score slightly
        CASE WHEN COALESCE(r.upcoming_renewal_flag,0) = 1 THEN 70 ELSE 100 END AS renewal_score

    FROM analytics.fact_revenue_monthly frm
    LEFT JOIN usage_comp u
        ON frm.customer_id = u.customer_id AND frm.date_id = u.date_id
    LEFT JOIN support_comp s
        ON frm.customer_id = s.customer_id AND frm.date_id = s.date_id
    LEFT JOIN payment_comp p
        ON frm.customer_id = p.customer_id AND frm.date_id = p.date_id
    LEFT JOIN renewal_comp r
        ON frm.customer_id = r.customer_id AND frm.date_id = r.date_id
)
SELECT
    dd.year_number,
    dd.month_number,
    b.customer_id,

    ROUND(
          (b.util_score * 0.35)
        + (b.support_score * 0.20)
        + (b.payment_score * 0.25)
        + (b.renewal_score * 0.20)
    , 2) AS customer_health_score

FROM base b
JOIN analytics.dim_date dd
    ON b.date_id = dd.date_id

ORDER BY
    b.customer_id,
    dd.year_number,
    dd.month_number;

-- ============================================================
-- Validation
-- ============================================================

SELECT *
FROM analytics.v_kpi_customer_health
ORDER BY customer_id, year_number, month_number
LIMIT 25;
