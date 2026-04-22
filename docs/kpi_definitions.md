# KPI Definitions

---

## 1. Revenue Leakage

**Definition:**  
The difference between total contracted revenue and realized (recognized or collected) revenue.

**Formula (Conceptual):**  
Revenue Leakage = Contracted Revenue - Realized Revenue

**Implementation (Project):**  
Revenue Leakage ≈  
churned_revenue + contraction_revenue + leakage_amount

**Business Meaning:**  
Represents revenue that was expected but not fully realized due to:
- customer churn  
- contract downgrades  
- billing and collection inefficiencies  

**Note:**  
Due to data model constraints, leakage is approximated using component-level revenue loss metrics rather than a direct contracted vs realized comparison. This provides a realistic and actionable proxy for revenue loss.

---

## 2. Net Revenue Retention (NRR)

**Definition:**  
Measures the ability to retain and grow revenue from existing customers over time.

**Formula:**  
NRR = (Starting Revenue + Expansion - Churn - Downgrade) / Starting Revenue

**Implementation (Project):**  
NRR = (recognized_revenue + expansion_revenue - contraction_revenue - churned_revenue) / recognized_revenue

**Business Meaning:**  
Indicates overall health of the customer base. Values above 100% indicate growth within existing accounts.

---

## 3. Gross Renewal Rate

**Definition:**  
Percentage of renewable revenue that is successfully renewed.

**Formula:**  
Gross Renewal Rate = Renewed Revenue / Renewable Revenue

**Implementation (Project):**  
Gross Renewal Rate = SUM(renewed_contract_value) / SUM(previous_contract_value)

**Business Meaning:**  
Measures effectiveness of retention efforts without accounting for expansion.

---

## 4. Churn Rate

**Definition:**  
Percentage of revenue lost during a given period.

**Formula (Project):**  
Churn Rate = churned_revenue / recognized_revenue

**Business Meaning:**  
Measures direct revenue loss from customer attrition. High churn indicates:
- customer dissatisfaction  
- poor product fit  
- weak retention strategy  

**Note:**  
This project uses **revenue churn** (not customer count churn), which provides a more financially meaningful view of business impact.

---

## 5. At-Risk Revenue

**Definition:**  
Revenue associated with customers exhibiting risk indicators.

**Risk Indicators May Include:**
- low product usage  
- high support ticket volume or severity  
- overdue invoices or delayed payments  
- upcoming renewal within defined window (e.g., 90 days)  
- declining engagement or activity  

**Implementation (Project):**  
Customers are classified as "at risk" when multiple risk signals are present (e.g., low utilization, payment issues, support escalation, upcoming renewal).  
At-Risk Revenue = SUM(recognized_revenue for at-risk customers)

**Business Meaning:**  
Represents revenue that is likely to be lost without proactive intervention.

---

## 6. Average Discount Rate

**Definition:**  
Average percentage discount applied to contracts or renewals.

**Formula:**  
Average Discount = Total Discount Amount / Total Contract Value

**Implementation (Project):**  
- Simple Average = AVG(discount_percent)  
- Weighted Average = SUM(contract_value × discount_percent) / SUM(contract_value)

**Business Meaning:**  
Helps identify excessive discounting that reduces realized revenue and impacts profitability.

---

## 7. Days Sales Outstanding (DSO)

**Definition:**  
Average number of days it takes to collect payment after a sale.

**Formula (Conceptual):**  
DSO = (Accounts Receivable / Total Credit Sales) × Number of Days

**Implementation (Project):**  
DSO ≈ weighted average of days_to_pay  

DSO = SUM(payment_amount × days_to_pay) / SUM(payment_amount)

**Business Meaning:**  
Indicates efficiency of the billing and collections process and directly impacts cash flow.

**Note:**  
This implementation uses transaction-level payment timing as a proxy for traditional DSO, enabling a more granular and realistic simulation of collection efficiency.

---

## 8. Customer Health Score (Derived Metric)

**Definition:**  
Composite score indicating likelihood of retention or churn.

**Components May Include:**
- usage level  
- support activity  
- payment behavior  
- renewal timing  
- discounting patterns  

**Implementation (Project):**  
Customer Health Score is calculated as a weighted combination of:
- utilization (positive signal)  
- support activity (negative signal)  
- payment behavior (negative signal)  
- renewal proximity (risk signal)  

Scores are normalized to a 0–100 scale.

**Business Meaning:**  
Used to prioritize customer success efforts and identify accounts requiring proactive intervention.
