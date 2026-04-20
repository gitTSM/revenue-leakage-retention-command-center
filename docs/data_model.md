# Data Model

## Overview
This document defines the conceptual data model for the Revenue Leakage & Retention Command Center.

The objective of the data model is to support executive reporting, revenue leakage analysis, retention monitoring, customer risk identification, and account-level drilldown.

The model is designed using a star-schema-oriented approach, with business events captured in fact tables and descriptive attributes stored in dimension tables.

---

## Modeling Approach

The data model is designed to:

- support consistent KPI calculation across the project
- enable flexible slicing by customer, product, region, account manager, and time
- separate measurable business events from descriptive business attributes
- provide a scalable structure for SQL analysis and Tableau dashboard development

---

## Core Business Entities

The following business entities are required to support the solution:

- customers
- products
- contracts
- renewals
- monthly revenue
- invoices
- payments
- support tickets
- product usage
- account managers
- regions
- dates

---

## Dimension Tables

### 1. dim_customers
**Purpose:** Stores descriptive information about each customer.

**Example Attributes:**
- customer_id
- customer_name
- industry
- segment
- company_size
- annual_revenue_band
- region_id
- start_date

---

### 2. dim_products
**Purpose:** Stores descriptive information about each product or service offering.

**Example Attributes:**
- product_id
- product_name
- product_category
- pricing_model

---

### 3. dim_account_managers
**Purpose:** Stores account ownership and portfolio assignment details.

**Example Attributes:**
- account_manager_id
- account_manager_name
- team_name
- region_id

---

### 4. dim_regions
**Purpose:** Stores geographic hierarchy used for reporting.

**Example Attributes:**
- region_id
- region_name
- country
- market

---

### 5. dim_dates
**Purpose:** Standard calendar dimension used for time-based analysis.

**Example Attributes:**
- date_id
- full_date
- month
- quarter
- year
- month_name
- fiscal_year

---

## Fact Tables

### 1. fact_contracts
**Purpose:** Stores customer contract information and booked revenue commitments.

**Grain:** One row per contract

**Example Attributes:**
- contract_id
- customer_id
- product_id
- account_manager_id
- contract_start_date
- contract_end_date
- contract_value
- billing_frequency
- renewal_type
- auto_renew_flag
- contract_status

---

### 2. fact_revenue_monthly
**Purpose:** Stores realized revenue at the monthly level.

**Grain:** One row per customer per product per month

**Example Attributes:**
- revenue_monthly_id
- customer_id
- product_id
- account_manager_id
- date_id
- contracted_revenue
- realized_revenue
- expansion_revenue
- downgrade_amount
- churn_amount

---

### 3. fact_invoices
**Purpose:** Stores invoiced amounts issued to customers.

**Grain:** One row per invoice

**Example Attributes:**
- invoice_id
- customer_id
- contract_id
- invoice_date
- due_date
- invoiced_amount
- discount_amount
- invoice_status

---

### 4. fact_payments
**Purpose:** Stores payment activity related to invoices.

**Grain:** One row per payment transaction

**Example Attributes:**
- payment_id
- invoice_id
- customer_id
- payment_date
- payment_amount
- payment_status
- days_to_pay
- write_off_amount

---

### 5. fact_support_tickets
**Purpose:** Stores customer support interactions used as potential risk indicators.

**Grain:** One row per support ticket

**Example Attributes:**
- ticket_id
- customer_id
- product_id
- opened_date
- closed_date
- severity
- issue_category
- resolution_days
- csat_score

---

### 6. fact_usage_monthly
**Purpose:** Stores customer product usage metrics over time.

**Grain:** One row per customer per product per month

**Example Attributes:**
- usage_monthly_id
- customer_id
- product_id
- date_id
- active_users
- licensed_users
- usage_rate
- feature_adoption_rate
- login_count

---

### 7. fact_renewals
**Purpose:** Stores contract renewal events and outcomes.

**Grain:** One row per renewal event

**Example Attributes:**
- renewal_id
- contract_id
- customer_id
- renewal_due_date
- renewal_date
- renewable_amount
- renewed_amount
- renewed_flag
- churn_flag
- downgrade_flag
- renewal_status

---

## Table Relationship Summary

The model is centered around the customer and product dimensions, with time-based analysis enabled through the date dimension.

### Primary Relationships
- dim_customers joins to all major fact tables through customer_id
- dim_products joins to revenue, usage, contracts, and tickets through product_id
- dim_account_managers joins to contracts and monthly revenue through account_manager_id
- dim_regions joins through customer or account manager region assignment
- dim_dates joins to monthly fact tables and event dates for trend analysis

### Relationship Notes
- contracts represent booked commitments
- revenue_monthly represents actual realized performance over time
- renewals capture retention outcomes
- invoices and payments support billing and collection analysis
- usage and support tickets provide behavioral and operational context for risk scoring

---

## Grain Definitions

Clearly defining table grain is critical to avoid incorrect joins and inaccurate KPI calculations.

| Table | Grain |
|---|---|
| dim_customers | One row per customer |
| dim_products | One row per product |
| dim_account_managers | One row per account manager |
| dim_regions | One row per region |
| dim_dates | One row per calendar date |
| fact_contracts | One row per contract |
| fact_revenue_monthly | One row per customer per product per month |
| fact_invoices | One row per invoice |
| fact_payments | One row per payment transaction |
| fact_support_tickets | One row per support ticket |
| fact_usage_monthly | One row per customer per product per month |
| fact_renewals | One row per renewal event |

---

## KPI-to-Data Mapping

| KPI | Primary Tables Required |
|---|---|
| Revenue Leakage | fact_revenue_monthly, fact_contracts |
| Net Revenue Retention | fact_revenue_monthly |
| Gross Renewal Rate | fact_renewals |
| Churn Rate | fact_renewals, dim_customers |
| At-Risk Revenue | fact_usage_monthly, fact_support_tickets, fact_payments, fact_renewals |
| Average Discount Rate | fact_invoices, fact_contracts |
| Days Sales Outstanding | fact_invoices, fact_payments |
| Customer Health Score | fact_usage_monthly, fact_support_tickets, fact_payments, fact_renewals |

---

## Design Considerations

### 1. Separation of Booked vs Realized Revenue
A key requirement of this project is distinguishing contracted revenue from realized revenue to support leakage analysis.

### 2. Monthly Analytical Layer
Revenue and usage are modeled monthly to support trend analysis, retention monitoring, and executive dashboards.

### 3. Customer Risk Inputs
Customer risk is not based on a single source. It is derived from a combination of usage, support, billing, and renewal behavior.

### 4. Tableau Readiness
The model is structured to support Tableau dashboards with minimal ambiguity in joins and metric definitions.

---

## Future Implementation Notes

In the implementation phase, this conceptual model will be translated into:

- PostgreSQL table creation scripts
- synthetic data generation logic
- cleaned analytical views for dashboard consumption

A visual ERD will also be added to the project in a later phase.
