-- ============================================================
-- Revenue Leakage & Retention Command Center
-- Physical Data Model - PostgreSQL
--
-- Purpose:
-- This script creates the core dimensional and fact tables for
-- the Revenue Leakage & Retention Command Center analytics model.
--
-- Notes:
-- - Intended for a local development / portfolio environment
-- - Creates objects in the analytics schema
-- - Rebuilds tables from scratch for repeatable development
-- - In production, schema changes would typically be managed
--   through controlled migration processes
-- ============================================================

CREATE SCHEMA IF NOT EXISTS analytics;
SET search_path TO analytics;

-- ============================================================
-- Table Rebuild Sequence
-- ============================================================

DROP TABLE IF EXISTS fact_renewals CASCADE;
DROP TABLE IF EXISTS fact_tickets CASCADE;
DROP TABLE IF EXISTS fact_usage CASCADE;
DROP TABLE IF EXISTS fact_payments CASCADE;
DROP TABLE IF EXISTS fact_invoices CASCADE;
DROP TABLE IF EXISTS fact_revenue_monthly CASCADE;
DROP TABLE IF EXISTS fact_contracts CASCADE;
DROP TABLE IF EXISTS dim_date CASCADE;
DROP TABLE IF EXISTS dim_customer CASCADE;
DROP TABLE IF EXISTS dim_product CASCADE;
DROP TABLE IF EXISTS dim_account_manager CASCADE;
DROP TABLE IF EXISTS dim_region CASCADE;

-- ============================================================
-- Dimension Tables
-- ============================================================

CREATE TABLE dim_region (
    region_id            SERIAL PRIMARY KEY,
    region_name          VARCHAR(50)  NOT NULL,
    country              VARCHAR(50)  NOT NULL,
    market_segment       VARCHAR(50),

    CONSTRAINT uq_dim_region_region_name UNIQUE (region_name)
);

CREATE TABLE dim_account_manager (
    account_manager_id   SERIAL PRIMARY KEY,
    manager_name         VARCHAR(100) NOT NULL,
    manager_email        VARCHAR(150) NOT NULL,
    team_name            VARCHAR(100),
    region_id            INT,
    hire_date            DATE,
    active_flag          BOOLEAN      NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_dim_account_manager_email UNIQUE (manager_email),
    CONSTRAINT fk_dim_account_manager_region
        FOREIGN KEY (region_id)
        REFERENCES dim_region(region_id)
);

CREATE TABLE dim_product (
    product_id           SERIAL PRIMARY KEY,
    product_name         VARCHAR(100) NOT NULL,
    product_category     VARCHAR(50)  NOT NULL,
    pricing_model        VARCHAR(50),
    list_price           NUMERIC(12,2) NOT NULL,
    active_flag          BOOLEAN       NOT NULL DEFAULT TRUE,

    CONSTRAINT ck_dim_product_list_price_nonnegative
        CHECK (list_price >= 0)
);

CREATE TABLE dim_customer (
    customer_id          SERIAL PRIMARY KEY,
    customer_name        VARCHAR(150) NOT NULL,
    customer_segment     VARCHAR(50)  NOT NULL,
    industry             VARCHAR(100),
    employee_count       INT,
    annual_revenue_band  VARCHAR(50),
    region_id            INT          NOT NULL,
    account_manager_id   INT,
    signup_date          DATE         NOT NULL,
    status               VARCHAR(30)  NOT NULL,
    health_score         NUMERIC(5,2),

    CONSTRAINT ck_dim_customer_employee_count_nonnegative
        CHECK (employee_count IS NULL OR employee_count >= 0),

    CONSTRAINT ck_dim_customer_status
        CHECK (status IN ('Active', 'Churned', 'At Risk', 'Inactive')),

    CONSTRAINT ck_dim_customer_health_score
        CHECK (health_score IS NULL OR health_score BETWEEN 0 AND 100),

    CONSTRAINT fk_dim_customer_region
        FOREIGN KEY (region_id)
        REFERENCES dim_region(region_id),

    CONSTRAINT fk_dim_customer_account_manager
        FOREIGN KEY (account_manager_id)
        REFERENCES dim_account_manager(account_manager_id)
);

CREATE TABLE dim_date (
    date_id              INT PRIMARY KEY,
    full_date            DATE        NOT NULL,
    day_of_month         INT         NOT NULL,
    month_number         INT         NOT NULL,
    month_name           VARCHAR(20) NOT NULL,
    quarter_number       INT         NOT NULL,
    year_number          INT         NOT NULL,
    week_number          INT,
    is_month_end         BOOLEAN     NOT NULL DEFAULT FALSE,

    CONSTRAINT uq_dim_date_full_date UNIQUE (full_date),

    CONSTRAINT ck_dim_date_day_of_month
        CHECK (day_of_month BETWEEN 1 AND 31),

    CONSTRAINT ck_dim_date_month_number
        CHECK (month_number BETWEEN 1 AND 12),

    CONSTRAINT ck_dim_date_quarter_number
        CHECK (quarter_number BETWEEN 1 AND 4)
);

-- ============================================================
-- Fact Tables
-- ============================================================

CREATE TABLE fact_contracts (
    contract_id             SERIAL PRIMARY KEY,
    customer_id             INT           NOT NULL,
    product_id              INT           NOT NULL,
    account_manager_id      INT,
    contract_start_date     DATE          NOT NULL,
    contract_end_date       DATE          NOT NULL,
    contract_term_months    INT           NOT NULL,
    contract_value          NUMERIC(14,2) NOT NULL,
    discount_percent        NUMERIC(5,2)  NOT NULL DEFAULT 0,
    net_contract_value      NUMERIC(14,2) NOT NULL,
    billing_frequency       VARCHAR(30)   NOT NULL,
    auto_renew_flag         BOOLEAN       NOT NULL DEFAULT FALSE,
    contract_status         VARCHAR(30)   NOT NULL,
    created_at              TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT ck_fact_contracts_term_months_positive
        CHECK (contract_term_months > 0),

    CONSTRAINT ck_fact_contracts_contract_value_nonnegative
        CHECK (contract_value >= 0),

    CONSTRAINT ck_fact_contracts_discount_percent
        CHECK (discount_percent BETWEEN 0 AND 100),

    CONSTRAINT ck_fact_contracts_net_contract_value_nonnegative
        CHECK (net_contract_value >= 0),

    CONSTRAINT ck_fact_contracts_billing_frequency
        CHECK (billing_frequency IN ('Monthly', 'Quarterly', 'Annual')),

    CONSTRAINT ck_fact_contracts_status
        CHECK (contract_status IN ('Active', 'Expired', 'Cancelled', 'Pending Renewal')),

    CONSTRAINT ck_fact_contracts_date_range
        CHECK (contract_end_date > contract_start_date),

    CONSTRAINT fk_fact_contracts_customer
        FOREIGN KEY (customer_id)
        REFERENCES dim_customer(customer_id),

    CONSTRAINT fk_fact_contracts_product
        FOREIGN KEY (product_id)
        REFERENCES dim_product(product_id),

    CONSTRAINT fk_fact_contracts_account_manager
        FOREIGN KEY (account_manager_id)
        REFERENCES dim_account_manager(account_manager_id)
);

CREATE TABLE fact_revenue_monthly (
    revenue_monthly_id      SERIAL PRIMARY KEY,
    customer_id             INT           NOT NULL,
    product_id              INT           NOT NULL,
    account_manager_id      INT,
    date_id                 INT           NOT NULL,
    contract_id             INT,
    recognized_revenue      NUMERIC(14,2) NOT NULL DEFAULT 0,
    expansion_revenue       NUMERIC(14,2) NOT NULL DEFAULT 0,
    contraction_revenue     NUMERIC(14,2) NOT NULL DEFAULT 0,
    churned_revenue         NUMERIC(14,2) NOT NULL DEFAULT 0,
    leakage_amount          NUMERIC(14,2) NOT NULL DEFAULT 0,

    CONSTRAINT ck_fact_revenue_monthly_recognized_revenue_nonnegative
        CHECK (recognized_revenue >= 0),

    CONSTRAINT ck_fact_revenue_monthly_expansion_revenue_nonnegative
        CHECK (expansion_revenue >= 0),

    CONSTRAINT ck_fact_revenue_monthly_contraction_revenue_nonnegative
        CHECK (contraction_revenue >= 0),

    CONSTRAINT ck_fact_revenue_monthly_churned_revenue_nonnegative
        CHECK (churned_revenue >= 0),

    CONSTRAINT ck_fact_revenue_monthly_leakage_amount_nonnegative
        CHECK (leakage_amount >= 0),

    CONSTRAINT fk_fact_revenue_monthly_customer
        FOREIGN KEY (customer_id)
        REFERENCES dim_customer(customer_id),

    CONSTRAINT fk_fact_revenue_monthly_product
        FOREIGN KEY (product_id)
        REFERENCES dim_product(product_id),

    CONSTRAINT fk_fact_revenue_monthly_account_manager
        FOREIGN KEY (account_manager_id)
        REFERENCES dim_account_manager(account_manager_id),

    CONSTRAINT fk_fact_revenue_monthly_date
        FOREIGN KEY (date_id)
        REFERENCES dim_date(date_id),

    CONSTRAINT fk_fact_revenue_monthly_contract
        FOREIGN KEY (contract_id)
        REFERENCES fact_contracts(contract_id)
);

CREATE TABLE fact_invoices (
    invoice_id                 SERIAL PRIMARY KEY,
    contract_id                INT           NOT NULL,
    customer_id                INT           NOT NULL,
    date_id                    INT           NOT NULL,
    invoice_date               DATE          NOT NULL,
    due_date                   DATE          NOT NULL,
    invoice_amount             NUMERIC(14,2) NOT NULL,
    billed_discount_amount     NUMERIC(14,2) NOT NULL DEFAULT 0,
    invoice_status             VARCHAR(30)   NOT NULL,

    CONSTRAINT ck_fact_invoices_invoice_amount_nonnegative
        CHECK (invoice_amount >= 0),

    CONSTRAINT ck_fact_invoices_billed_discount_amount_nonnegative
        CHECK (billed_discount_amount >= 0),

    CONSTRAINT ck_fact_invoices_status
        CHECK (invoice_status IN ('Paid', 'Open', 'Overdue', 'Cancelled')),

    CONSTRAINT ck_fact_invoices_due_date
        CHECK (due_date >= invoice_date),

    CONSTRAINT fk_fact_invoices_contract
        FOREIGN KEY (contract_id)
        REFERENCES fact_contracts(contract_id),

    CONSTRAINT fk_fact_invoices_customer
        FOREIGN KEY (customer_id)
        REFERENCES dim_customer(customer_id),

    CONSTRAINT fk_fact_invoices_date
        FOREIGN KEY (date_id)
        REFERENCES dim_date(date_id)
);

CREATE TABLE fact_payments (
    payment_id              SERIAL PRIMARY KEY,
    invoice_id              INT           NOT NULL,
    customer_id             INT           NOT NULL,
    payment_date            DATE,
    payment_amount          NUMERIC(14,2) NOT NULL,
    payment_status          VARCHAR(30)   NOT NULL,
    days_to_pay             INT,

    CONSTRAINT ck_fact_payments_payment_amount_nonnegative
        CHECK (payment_amount >= 0),

    CONSTRAINT ck_fact_payments_status
        CHECK (payment_status IN ('Paid', 'Partial', 'Pending', 'Failed')),

    CONSTRAINT ck_fact_payments_days_to_pay_nonnegative
        CHECK (days_to_pay IS NULL OR days_to_pay >= 0),

    CONSTRAINT fk_fact_payments_invoice
        FOREIGN KEY (invoice_id)
        REFERENCES fact_invoices(invoice_id),

    CONSTRAINT fk_fact_payments_customer
        FOREIGN KEY (customer_id)
        REFERENCES dim_customer(customer_id)
);

CREATE TABLE fact_usage (
    usage_id                 SERIAL PRIMARY KEY,
    customer_id              INT           NOT NULL,
    product_id               INT           NOT NULL,
    date_id                  INT           NOT NULL,
    usage_date               DATE          NOT NULL,
    active_users             INT           NOT NULL DEFAULT 0,
    login_count              INT           NOT NULL DEFAULT 0,
    feature_adoption_rate    NUMERIC(5,2),
    utilization_score        NUMERIC(5,2),

    CONSTRAINT ck_fact_usage_active_users_nonnegative
        CHECK (active_users >= 0),

    CONSTRAINT ck_fact_usage_login_count_nonnegative
        CHECK (login_count >= 0),

    CONSTRAINT ck_fact_usage_feature_adoption_rate
        CHECK (feature_adoption_rate IS NULL OR feature_adoption_rate BETWEEN 0 AND 100),

    CONSTRAINT ck_fact_usage_utilization_score
        CHECK (utilization_score IS NULL OR utilization_score BETWEEN 0 AND 100),

    CONSTRAINT fk_fact_usage_customer
        FOREIGN KEY (customer_id)
        REFERENCES dim_customer(customer_id),

    CONSTRAINT fk_fact_usage_product
        FOREIGN KEY (product_id)
        REFERENCES dim_product(product_id),

    CONSTRAINT fk_fact_usage_date
        FOREIGN KEY (date_id)
        REFERENCES dim_date(date_id)
);

CREATE TABLE fact_tickets (
    ticket_id                 SERIAL PRIMARY KEY,
    customer_id               INT           NOT NULL,
    date_id                   INT           NOT NULL,
    ticket_created_date       DATE          NOT NULL,
    ticket_closed_date        DATE,
    ticket_priority           VARCHAR(20)   NOT NULL,
    ticket_status             VARCHAR(20)   NOT NULL,
    issue_category            VARCHAR(50)   NOT NULL,
    resolution_time_hours     NUMERIC(10,2),
    escalation_flag           BOOLEAN       NOT NULL DEFAULT FALSE,
    satisfaction_score        NUMERIC(4,2),

    CONSTRAINT ck_fact_tickets_priority
        CHECK (ticket_priority IN ('Low', 'Medium', 'High', 'Critical')),

    CONSTRAINT ck_fact_tickets_status
        CHECK (ticket_status IN ('Open', 'In Progress', 'Resolved', 'Closed')),

    CONSTRAINT ck_fact_tickets_resolution_time_nonnegative
        CHECK (resolution_time_hours IS NULL OR resolution_time_hours >= 0),

    CONSTRAINT ck_fact_tickets_satisfaction_score
        CHECK (satisfaction_score IS NULL OR satisfaction_score BETWEEN 0 AND 10),

    CONSTRAINT ck_fact_tickets_closed_date
        CHECK (ticket_closed_date IS NULL OR ticket_closed_date >= ticket_created_date),

    CONSTRAINT fk_fact_tickets_customer
        FOREIGN KEY (customer_id)
        REFERENCES dim_customer(customer_id),

    CONSTRAINT fk_fact_tickets_date
        FOREIGN KEY (date_id)
        REFERENCES dim_date(date_id)
);

CREATE TABLE fact_renewals (
    renewal_id                SERIAL PRIMARY KEY,
    previous_contract_id      INT           NOT NULL,
    renewed_contract_id       INT,
    customer_id               INT           NOT NULL,
    renewal_date              DATE          NOT NULL,
    renewal_status            VARCHAR(30)   NOT NULL,
    renewal_amount            NUMERIC(14,2),
    previous_contract_value   NUMERIC(14,2),
    renewed_contract_value    NUMERIC(14,2),
    renewal_term_months       INT,

    CONSTRAINT ck_fact_renewals_status
        CHECK (renewal_status IN ('Renewed', 'Churned', 'Downgraded', 'Upsold', 'Pending')),

    CONSTRAINT ck_fact_renewals_renewal_amount_nonnegative
        CHECK (renewal_amount IS NULL OR renewal_amount >= 0),

    CONSTRAINT ck_fact_renewals_previous_contract_value_nonnegative
        CHECK (previous_contract_value IS NULL OR previous_contract_value >= 0),

    CONSTRAINT ck_fact_renewals_renewed_contract_value_nonnegative
        CHECK (renewed_contract_value IS NULL OR renewed_contract_value >= 0),

    CONSTRAINT ck_fact_renewals_term_months_positive
        CHECK (renewal_term_months IS NULL OR renewal_term_months > 0),

    CONSTRAINT fk_fact_renewals_previous_contract
        FOREIGN KEY (previous_contract_id)
        REFERENCES fact_contracts(contract_id),

    CONSTRAINT fk_fact_renewals_renewed_contract
        FOREIGN KEY (renewed_contract_id)
        REFERENCES fact_contracts(contract_id),

    CONSTRAINT fk_fact_renewals_customer
        FOREIGN KEY (customer_id)
        REFERENCES dim_customer(customer_id)
);

-- ============================================================
-- Optional Indexes for Analytical Workloads
-- ============================================================

CREATE INDEX idx_dim_customer_region_id
    ON dim_customer (region_id);

CREATE INDEX idx_dim_customer_account_manager_id
    ON dim_customer (account_manager_id);

CREATE INDEX idx_fact_contracts_customer_id
    ON fact_contracts (customer_id);

CREATE INDEX idx_fact_contracts_product_id
    ON fact_contracts (product_id);

CREATE INDEX idx_fact_revenue_monthly_date_id
    ON fact_revenue_monthly (date_id);

CREATE INDEX idx_fact_revenue_monthly_customer_id
    ON fact_revenue_monthly (customer_id);

CREATE INDEX idx_fact_invoices_customer_id
    ON fact_invoices (customer_id);

CREATE INDEX idx_fact_invoices_contract_id
    ON fact_invoices (contract_id);

CREATE INDEX idx_fact_payments_invoice_id
    ON fact_payments (invoice_id);

CREATE INDEX idx_fact_usage_customer_id
    ON fact_usage (customer_id);

CREATE INDEX idx_fact_tickets_customer_id
    ON fact_tickets (customer_id);

CREATE INDEX idx_fact_renewals_customer_id
    ON fact_renewals (customer_id);
