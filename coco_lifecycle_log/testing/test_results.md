# Test results, 2026-09-30 (deployed app VIGIL.CORE.VIGIL_APP, Streamlit in Snowflake, trial account)

Method: each question was submitted in the deployed app (button or typed); output read from the audit panel.
Timings are the app's own `time.perf_counter()` around routing plus SQL evidence queries (server side, excludes browser rendering). One run each, so treat as indicative, not a benchmark.

| # | Scenario | Question | Result | Cited records | Cited clauses | Time |
|---|----------|----------|--------|---------------|---------------|------|
| 1 | Structuring | Why was TXN-ST-01 flagged for structuring? | STRUCTURING PATTERN CONFIRMED: 4 deposits, Rs 7,60,000, 2026-09-03..09-10 | TXN-ST-01..04, ACC-0007 | POL-AML-001 3.1, 4.1, 4.2; POL-AML-004 2.1 | 0.68 s |
| 2 | High-risk country | Was the remittance TXN-HR-01 to the high risk country compliant? | NOT SHOWN COMPLIANT: Rs 6,50,000 to Myanmar, no EDD record; 12h escalation (HIGH-risk customer) | TXN-HR-01 | POL-AML-002 2.1, 3.1, 4.1, 4.2; POL-AML-004 3.2 | not captured |
| 3 | Velocity | Show me the velocity pattern on account ACC-0019 | VELOCITY PATTERN CONFIRMED: Rs 6,50,000 of Rs 7,50,000 (86.7%) out in 21.2 h | TXN-VE-01/02/03 | POL-AML-003 2.1, 3.1, 4.1, 4.2 | 0.17 s |
| 4 | Ring | Is account ACC-0031 connected to anything else? | RING DETECTED (RING-001): ACC-0031..0035 paid Zenith Global Ventures within 45 h; 0 of 5 transactions individually flagged; graph rendered | TXN-RG-01..05 | POL-AML-001 4.5, 4.1, 4.2 | 0.40 s |
| 5 | Liquidity | Are we compliant with our liquidity coverage ratio? | CURRENTLY COMPLIANT (112.80% on 2026-09-29), 1 breach in window (94.00% on 2026-09-17) | snapshot dates 2026-09-29, 2026-09-17 | POL-LIQ-001 2.1, 3.1, 3.2, 4.1, 4.2 | 0.18 s |
| 6 | Credit | Which loan accounts are NPA and what provisioning is required? | 1 NPA: LN-0025, 120 DPD, Substandard 15% provision; watch list LN-0033 (88 DPD) | LN-0025 | POL-CR-001 2.1, 3.1, 3.2, 4.1 | 0.26 s |

## Guardrail tests
| Test | Result |
|------|--------|
| Ambiguous question, fresh session ("Why was this transaction flagged for structuring?") | PASS: "Which transaction or account do you mean? I will not assume the most recent alert." No answer given. |
| Same question after an earlier ACC-0031 question (context leak) | FOUND A BUG: app reused ACC-0031 silently. FIXED (context only reused when the question says "this/that/the account"); re-tested in a fresh session. The post-fix behaviour in a session with prior context was not re-tested. |
| Noise control: ACC-0040 (pays Bangalore Electricity Board with 24 other accounts) | PASS: NO RING LINKS FOUND. Database check: 0 rings mention the utility; RING_EDGES has only Zenith edges. |
| Slack on request | PARTIAL: "Post this finding to Slack" only drafts the message ("DRAFT ONLY: SLACK NOT CONNECTED"); nothing is posted anywhere. Real Slack posting is NOT built. |
| Off-topic question ("What is the weather in Mumbai today") | Typed; result not observed before the session ended. Code path returns "LOW CONFIDENCE, NO ANSWER". Untested in the live app. |

## Data-layer checks (sql/02_verify.sql)
638 transactions, 60 accounts, 8 alerts; RING_EDGES 10 rows (5 choose 2), all via Zenith Global Ventures; RINGS 1; LCR breach 2026-09-17 = 94.00; NPA = LN-0025; structuring deposits total 760,000.

## Not tested
Scenario 2 timing; concurrency; any data volume beyond 638 rows; the app from a logged-out browser (Streamlit in Snowflake requires a Snowflake login).
