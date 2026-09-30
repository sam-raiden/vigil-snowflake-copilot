USE SCHEMA VIGIL.CORE;
CREATE OR REPLACE SEMANTIC VIEW VIGIL_SV
  TABLES (
    customers AS VIGIL.CORE.CUSTOMERS PRIMARY KEY (CUSTOMER_ID) COMMENT='Bank customers with risk segment and KYC status',
    accounts AS VIGIL.CORE.ACCOUNTS PRIMARY KEY (ACCOUNT_ID),
    transactions AS VIGIL.CORE.TRANSACTIONS PRIMARY KEY (TRANSACTION_ID) COMMENT='Account transactions; IS_FLAGGED and FLAG_REASON come from the upstream fraud engine',
    alerts AS VIGIL.CORE.ALERTS PRIMARY KEY (ALERT_ID),
    liquidity AS VIGIL.CORE.LIQUIDITY_SNAPSHOTS PRIMARY KEY (SNAPSHOT_DATE) COMMENT='Daily LCR snapshots; LCR must be 100 or more (POL-LIQ-001)',
    credit AS VIGIL.CORE.CREDIT_PROFILES PRIMARY KEY (LOAN_ACCOUNT_ID) COMMENT='Loans; more than 90 days past due is an NPA (POL-CR-001)'
  )
  RELATIONSHIPS (
    accounts_to_customers AS accounts (CUSTOMER_ID) REFERENCES customers,
    transactions_to_accounts AS transactions (ACCOUNT_ID) REFERENCES accounts,
    alerts_to_transactions AS alerts (TRANSACTION_ID) REFERENCES transactions,
    credit_to_customers AS credit (CUSTOMER_ID) REFERENCES customers
  )
  FACTS (
    transactions.amount_f AS AMOUNT,
    liquidity.lcr_f AS LCR_RATIO,
    credit.outstanding_f AS OUTSTANDING_AMOUNT,
    credit.dpd_f AS DAYS_PAST_DUE
  )
  DIMENSIONS (
    customers.risk_segment AS RISK_SEGMENT,
    customers.kyc_status AS KYC_STATUS,
    accounts.account_id AS ACCOUNT_ID,
    transactions.transaction_id AS TRANSACTION_ID,
    transactions.transaction_type AS TRANSACTION_TYPE,
    transactions.transaction_date AS TRANSACTION_DATE,
    transactions.counterparty_name AS COUNTERPARTY_NAME,
    transactions.counterparty_country AS COUNTERPARTY_COUNTRY,
    transactions.is_flagged AS IS_FLAGGED,
    transactions.flag_reason AS FLAG_REASON,
    alerts.alert_type AS ALERT_TYPE,
    alerts.severity AS SEVERITY,
    liquidity.snapshot_date AS SNAPSHOT_DATE,
    liquidity.lcr_status AS STATUS,
    credit.loan_account_id AS LOAN_ACCOUNT_ID,
    credit.npa_flag AS NPA_FLAG
  )
  METRICS (
    transactions.total_amount AS SUM(transactions.amount_f),
    transactions.transaction_count AS COUNT(transactions.transaction_id),
    liquidity.max_lcr AS MAX(liquidity.lcr_f),
    credit.outstanding AS SUM(credit.outstanding_f),
    credit.max_days_past_due AS MAX(credit.dpd_f)
  )
  COMMENT='Vigil governed model over transactions, alerts, liquidity and credit';

SELECT 'q1 structuring' q, TRANSACTION_ID, TO_VARCHAR(TOTAL_AMOUNT) v FROM SEMANTIC_VIEW(VIGIL_SV DIMENSIONS transactions.transaction_id, transactions.flag_reason METRICS transactions.total_amount WHERE transactions.flag_reason = 'STRUCTURING_SUSPECTED')
UNION ALL SELECT 'q2 high-risk remittance', TRANSACTION_ID, TO_VARCHAR(TOTAL_AMOUNT) FROM SEMANTIC_VIEW(VIGIL_SV DIMENSIONS transactions.transaction_id METRICS transactions.total_amount WHERE transactions.counterparty_country = 'Myanmar')
UNION ALL SELECT 'q3 velocity', TRANSACTION_ID, TO_VARCHAR(TOTAL_AMOUNT) FROM SEMANTIC_VIEW(VIGIL_SV DIMENSIONS transactions.transaction_id METRICS transactions.total_amount WHERE transactions.flag_reason = 'VELOCITY')
UNION ALL SELECT 'q5 lcr breach', TO_VARCHAR(SNAPSHOT_DATE), TO_VARCHAR(MAX_LCR) FROM SEMANTIC_VIEW(VIGIL_SV DIMENSIONS liquidity.snapshot_date, liquidity.lcr_status METRICS liquidity.max_lcr WHERE liquidity.lcr_status = 'BREACH')
UNION ALL SELECT 'q6 npa', LOAN_ACCOUNT_ID, TO_VARCHAR(OUTSTANDING*0.15) FROM SEMANTIC_VIEW(VIGIL_SV DIMENSIONS credit.loan_account_id, credit.npa_flag METRICS credit.outstanding WHERE credit.npa_flag = TRUE);
