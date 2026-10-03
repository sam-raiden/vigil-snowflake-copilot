# CoCo planning prompt 2 (Snowsight CoCo, UA33749), 2026-10-01

## Prompt (sent as typed)
Now outline the end-to-end workflow: signal detection, evidence gathering, documented finding, for three pillars: fraud/AML with graph-based ring detection, liquidity (LCR compliance), and credit (NPA classification). Each answer must cite a record ID and a policy clause. Planning only.

## CoCo response (summary written by us; the full text was long and only part was captured verbatim)
Structure CoCo returned: "Vigil: End-to-End Workflow: Signal to Evidence to Finding", in three pillars, each with phases Signal Detection, Evidence Gathering, Documented Finding, and ending with a "Summary: Record ID to Policy Clause Traceability" table.
- **Pillar 1 Fraud/AML, graph-based ring detection.** Signals: structuring, velocity spike, high-risk-country flow, ring formation by connected components over shared counterparties. Pipeline: TRANSACTIONS to RING_EDGES (pairwise edges by shared counterparty) to RINGS (connected components) as Dynamic Tables. Evidence packet: transaction trail for the accounts in the ring, ring topology from RING_EDGES and RINGS, customer KYC profile, prior alerts. Finding anchors: ALERTS.alert_id and RINGS.ring_id.
- **Pillar 2 Liquidity, LCR.** Signal: daily LCR below 100%. Evidence: HQLA and net outflow components from LIQUIDITY_SNAPSHOTS. Anchor: LIQUIDITY_SNAPSHOTS.snapshot_id (we use snapshot_date) with the Basel III clause.
- **Pillar 3 Credit, NPA.** Signal: 90+ days past due. Evidence: CREDIT_PROFILES rows, classification and provisioning. Anchor: CREDIT_PROFILES.profile_id (we use loan_account_id) with the RBI IRAC clause.
- CoCo finished by offering to move to DDL and Dynamic Table creation, with a suggested next step "Generate DDL for all base tables in Untitled.sql".

## Our notes
CoCo used generic column names and a $-based structuring band in places. We override these with the PRD's data model and INR thresholds in the development prompts.
