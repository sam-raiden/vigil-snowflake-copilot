# VIGIL: Product Requirements (v2)

A cited risk, fraud and regulatory copilot for banking and NBFC compliance teams. A user asks a plain-English question and gets an audit-ready finding: a verdict, the evidence records, and the exact policy clause behind it. All data is synthetic.

## 1. Problem
Compliance teams receive an alert, then assemble the evidence and the matching policy clause by hand. Fraud rings are harder still: each account looks ordinary on its own, so per-transaction rules never fire.

## 2. Goals
- Answer fraud/AML, liquidity and credit questions in natural language, with evidence.
- Find fraud rings that no single transaction reveals, using a relationship graph.
- Never answer without a citation: a record ID and a policy document plus clause.
- Say so plainly when confidence is low, and ask when the question does not name a transaction, account or loan.
- Stay a copilot: a human signs off on every filing, and nothing acts unasked.

## 3. Users and flow
A compliance analyst asks a question. The copilot gathers the signal and evidence, quotes the policy clause, and produces a downloadable finding.

Signal → Evidence → Documented finding.

## 4. Scope
**In scope**
- Fraud/AML: structuring, high-risk-jurisdiction remittances, velocity, and ring detection (the novel piece).
- Liquidity: LCR calculation and breach history, with the Basel III clause.
- Credit: NPA classification and provisioning, with the RBI IRAC clause.
- One agent (analytics + policy search + ring lookup), one chat and audit-panel app, six clickable example questions.

**Out of scope**
- A second agent or a second external connector.
- Anything scheduled that acts without being asked.
- Real production data.
- Graph detection for liquidity or credit (calculation and citation only).
- A live external regulatory feed.
- Any invented accuracy or efficiency percentage. Any number shown is measured, with its method stated.

## 5. Data model
Eight entities in one schema.
- CUSTOMERS(CUSTOMER_ID, FULL_NAME, RISK_SEGMENT, KYC_STATUS, ONBOARDED_DATE, COUNTRY)
- ACCOUNTS(ACCOUNT_ID, CUSTOMER_ID, ACCOUNT_TYPE, OPENED_DATE, STATUS)
- TRANSACTIONS(TRANSACTION_ID, ACCOUNT_ID, TRANSACTION_DATE, AMOUNT, CURRENCY, TRANSACTION_TYPE, COUNTERPARTY_NAME, COUNTERPARTY_COUNTRY, CHANNEL, IS_FLAGGED, FLAG_REASON)
- ALERTS(ALERT_ID, TRANSACTION_ID, ALERT_TYPE, SEVERITY, CREATED_AT, STATUS)
- LIQUIDITY_SNAPSHOTS(SNAPSHOT_DATE, HQLA_AMOUNT, NET_CASH_OUTFLOWS_30D, LCR_RATIO, STATUS)
- CREDIT_PROFILES(LOAN_ACCOUNT_ID, CUSTOMER_ID, OUTSTANDING_AMOUNT, DAYS_PAST_DUE, CREDIT_SCORE, NPA_FLAG, AS_OF_DATE)
- RING_EDGES(ACCOUNT_A, ACCOUNT_B, SHARED_ATTRIBUTE, SHARED_VALUE, LINK_STRENGTH): a Dynamic Table
- RINGS(RING_ID, MEMBER_ACCOUNTS, SHARED_LINK, TRANSACTION_IDS, DETECTED_AT): a Dynamic Table

Relationships: CUSTOMERS 1-N ACCOUNTS 1-N TRANSACTIONS 1-N ALERTS; CREDIT_PROFILES N-1 CUSTOMERS; LIQUIDITY_SNAPSHOTS stands alone; RINGS reference TRANSACTIONS through TRANSACTION_IDS.

### Seeded patterns (synthetic)
| Pattern | Seed |
|---|---|
| Structuring | ACC-0007: 4 branch cash deposits of INR 1.85 to 1.95 lakh within 10 days |
| High-risk country | ACC-0012: INR 6.5 lakh remittance to Myanmar |
| Velocity | ACC-0019: INR 7.5 lakh deposit, 86.7% out in under 24 hours |
| Ring | ACC-0031 to ACC-0035 each pay one counterparty within 72 hours; none individually flagged |
| Noise control | 25 other accounts pay one electricity board in the same window; must not form a ring |
| Liquidity | 30 daily LCR snapshots; 2026-09-17 breaches at 94% |
| Credit | about 40 loans; LN-0025 at 120 days past due (NPA); LN-0033 at 88 days (near miss) |

## 6. Policy documents (numbered clauses, indexed for retrieval)
POL-AML-001 Structuring (includes Clause 4.5, the RING_PATTERN rule); POL-AML-002 High-risk jurisdictions; POL-AML-003 Velocity; POL-AML-004 STR filing and KYC; POL-LIQ-001 Basel III LCR; POL-CR-001 NPA and provisioning. 35 clauses in total, in `policies/`.

## 7. Ring detection
A Dynamic Table self-joins transactions to find pairs of different accounts that paid the same counterparty within 72 hours. A hub filter removes counterparties paid by more than 8 distinct accounts (legitimate shared relationships such as utilities). A second Dynamic Table groups the remaining edges into connected components and keeps groups of 3 or more accounts. Per POL-AML-001 Clause 4.5, a ring is presumptively coordinated activity needing escalation.

## 8. Semantic layer and agent
- Semantic view over the tables with the six verified questions: why was a transaction flagged for structuring; was the high-risk remittance compliant; the velocity pattern on an account; is this account connected to anything else; are we LCR compliant; which loans are NPA and what provisioning is required.
- One agent with three tools: analytics over the semantic view, policy search over the clauses, and a ring lookup for an account.
- Agent instructions: cite a record ID and a policy clause for every claim; state uncertainty instead of guessing; ask which transaction, account or loan when it is not specified; always check the ring lookup for fraud/AML questions; never post externally unless the user explicitly asks in the conversation.

## 9. App
A chat box on one side and an audit-ready panel on the other. The panel shows the verdict, evidence rows, record IDs, policy citations with clause text, a confidence note, and a download button for the finding. Six example questions are clickable. Ring questions also draw the account graph.

## 10. Build plan
1. Plan: ontology, metrics and workflow.
2. Data: tables and synthetic data with the seeded patterns; verify counts and referential integrity.
3. Graph: RING_EDGES and RINGS; tune the hub threshold so the seeded ring is found and the utility is excluded.
4. Policies: load the 35 clauses; build the search service over them.
5. Semantic view: build and validate against the six questions.
6. Agent: configure the tools and instructions above.
7. App: build and deploy.
8. Test: six scenarios, an ambiguous question, the utility account, and an explicit-request-only external post; time three questions with a stopwatch and record the method.
9. Package: README, MVP brief, demo script, deck.

## 11. Acceptance checklist
- [ ] 8 tables with consistent synthetic data, seeded patterns and noise control
- [ ] Graph flags the seeded ring and excludes the utility
- [ ] 6 policies, 35 numbered clauses, indexed for search
- [ ] Semantic view validated against the six questions
- [ ] Agent with citation, clarify-if-ambiguous and no-unasked-post rules
- [ ] App deployed with chat, audit panel, six example questions, ring graph and download
- [ ] Six scenarios tested; each answer cites a record ID and a policy clause
- [ ] Ambiguous question gets a clarifying question
- [ ] Utility counterparty is not reported as a ring
- [ ] External post only on explicit request
- [ ] Measured timings recorded with method
- [ ] README, MVP brief, demo script and deck complete

## 12. Honest limits to state in the brief
Tested on a small synthetic dataset (hundreds of transactions); the hub threshold is tuned on one seeded case; entities are matched by exact name only; no device attribute (counterparty and a 72-hour window only); no live regulatory feed; the app runs inside Snowflake and needs a login; a human signs off on every filing.
