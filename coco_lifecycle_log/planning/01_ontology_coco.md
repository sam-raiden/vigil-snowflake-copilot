# CoCo planning prompt 1 (Snowsight CoCo, hackathon account UA33749), 2026-10-01

Run through: Snowsight CoCo panel (blue star), model "Auto", approvals "Default" (two read-only searches were approved by hand).
CoCo ran: `cortex search object "vigil risk fraud customers..."` (no existing Vigil objects found) and `cortex search docs "semantic model YAML relation..."`.

## Prompt (sent as typed)
I am building Vigil, a Risk, Fraud and Regulatory Intelligence Copilot for banking/NBFC compliance. Data model: CUSTOMERS, ACCOUNTS, TRANSACTIONS, ALERTS, LIQUIDITY_SNAPSHOTS, CREDIT_PROFILES, plus graph tables RING_EDGES and RINGS built as Dynamic Tables. Draft a semantic ontology, the relationships, and canonical risk metrics (structuring, high-risk country, velocity, fraud ring, LCR, NPA). PLANNING ONLY, do not create objects yet.

## CoCo response (captured from the page; tables flattened to text)

### Vigil: Semantic Ontology Plan
**1. Entity (logical table) inventory.** Customers (CUSTOMERS, customer_id), Accounts (ACCOUNTS, account_id), Transactions (TRANSACTIONS, txn_id), Alerts (ALERTS, alert_id), Liquidity Snapshots (LIQUIDITY_SNAPSHOTS, snapshot_id), Credit Profiles (CREDIT_PROFILES, profile_id), Ring Edges (dynamic table), Rings (dynamic table).

**2. Relationships.**
- Customers 1:N Accounts on customer_id
- Accounts 1:N Transactions on account_id
- Customers 1:N Alerts on customer_id; Accounts 1:N Alerts on account_id
- Accounts 1:N Credit_Profiles on account_id (ASOF on snapshot_date)
- Accounts 1:N Liquidity_Snapshots on entity_id (ASOF on snapshot_date)
- Accounts 1:N Ring_Edges on account_id = source_account; Rings 1:N Ring_Edges on ring_id
Notes: ASOF joins for point-in-time questions; Ring_Edges is a bridge table so Accounts to Rings is many-to-many; Transactions reach Customers only through Accounts (using_relationships).

**3. Dimensions.** Customers: risk_category, pep_flag, country_code, customer_type. Accounts: account_type, account_status, branch_code. Transactions: txn_type, channel, counterparty_country. Alerts: alert_type (STRUCTURING / VELOCITY / HIGH_RISK_COUNTRY / FRAUD_RING / MANUAL), alert_status. Credit_Profiles: asset_class (STANDARD / SMA / SUB_STANDARD / DOUBTFUL / LOSS), dpd_bucket (0-30 / 31-60 / 61-90 / 90+). Time dimensions: txn_date, created_at, snapshot_date, as_of_date, opened_date.

**4. Facts.** txn_amount, is_cash (channel in BRANCH/ATM), is_high_risk_country, hqla, net_cash_outflow_30d, outstanding_principal, provision_amount, edge_weight, ring_score, ring_size.

**5. Canonical risk metrics.**
- AML/fraud (Transactions): structuring_indicator, structuring_ratio, high_risk_country_volume, high_risk_country_count, velocity_24h, cash_intensity_ratio.
- Rings: active_rings (ring_score > 0.7), avg_ring_size, max_ring_score; derived fraud_ring_exposure via accounts_to_ring_edges and ring_edges_to_rings.
- LCR: lcr = hqla / net_cash_outflow_30d, lcr_breach (lcr < 1.0), hqla_total; lcr should use non_additive_dimensions on snapshot_date so the latest snapshot is used, never summed across dates.
- NPA: gross_npa (SUB_STANDARD, DOUBTFUL, LOSS), total_advances, npa_ratio, provision_coverage_ratio.
- Alert operations: open_alerts, sar_filing_rate, false_positive_rate.

**6. Starter verified queries.** structuring alerts this month; today's LCR; customers transacting to high-risk countries; top 5 fraud rings by score; NPA ratio trend.

**7. Custom instructions for Cortex Analyst.** CTR threshold, structuring band, FATF list, LCR must not be summed across dates, NPA = 90+ DPD, velocity = 24-hour window, fraud-ring queries traverse Accounts to Ring_Edges to Rings; plus question categories (AML, fraud, regulatory, operational).

**8. Implementation sequence.** Base tables; Dynamic Tables for the graph; one semantic-view YAML; dry-run with SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML(..., TRUE); deploy and run verified queries through Cortex Analyst; attach to a Cortex Agent.

## Our notes on CoCo's output
- CoCo's metric definitions assume a US-style $9,000 to $9,999 structuring band and a generic schema (e.g. PEP flags, branch codes). The PRD's policy is INR 1.8L to 1.99L within 10 days, so those thresholds must be overridden in the semantic view and instructions.
- It invented columns we do not have (profile_id, txn_id, pep_flag, ring_score). We keep the PRD's data model and treat these as ideas, not requirements.
