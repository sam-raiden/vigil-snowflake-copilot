# VIGIL — Build PRD for Autonomous Execution
**Audience: Claude Code, operating with full system permissions and an open Snowflake browser tab.**
**Goal: build, deploy, and submit the entire hackathon project end-to-end, without further human guidance beyond credentials/approvals.**

---

## 0. READ THIS FIRST — Non-Negotiable Operating Rules

1. **Everything must be built through CoCo (the Snowflake CoCo CLI or Desktop app), not hand-written directly.** This hackathon's grading criteria explicitly requires visible CoCo usage across Planning, Development, Execution, and Testing. If you write raw SQL/Python/YAML yourself instead of having CoCo generate it, you will produce a working app that **scores poorly**, because the judges look for CoCo evidence at every phase, not just a working demo.
   - Check whether the `coco` CLI is installed (`coco --version` or `which coco`). If not installed, install it per Snowflake's CoCo CLI setup docs before proceeding.
   - For every artifact below (schema, synthetic data, semantic model, Cortex Search service, Cortex Agents, Streamlit app), the correct sequence is: **issue the instruction to CoCo, let CoCo generate/execute it, save CoCo's output/transcript as evidence, then verify the result.** Do not skip straight to writing the file yourself and only using CoCo as an afterthought.
   - Log every CoCo interaction (prompt + response/output) to a `coco_lifecycle_log/` folder in the repo, timestamped and labeled by phase (planning/, development/, execution/, testing/). This log **is** the submission evidence.
2. **Scope is frozen. Do not add features beyond what's specified in this document.** Specifically excluded, on purpose: a second MCP connector (e.g. Jira), a third agent, any unattended/scheduled automation that acts without a user asking first, real production data, graph-based network detection for liquidity/credit (those two pillars are calculation + citation only).
3. **This is a copilot, not an autonomous agent.** Nothing should run on a schedule or fire without an explicit user question first, except the Dynamic Table refresh for the graph edges (which only refreshes data, it doesn't act on it).
4. **Never let an answer ship without a citation.** Every response from the app must reference either a real transaction/record ID from the data or a real policy document + clause. If confidence is low, the app must say so explicitly instead of guessing.
5. **Don't invent marketing numbers.** Do not claim specific percentage improvements ("60% reduction," etc.) anywhere in the app, docs, or demo video unless they are actually measured against something concrete in this build. If you want a headline number, measure it for real (e.g., time a scripted flow) and state the measurement method next to the number.
6. The reference schema, policy text, and semantic model sections below describe the **required shape and content** — but the actual creation of these artifacts in Snowflake must happen via CoCo prompts (see Section 7, Build Sequence), not by directly running these SQL blocks yourself outside of CoCo. Use these sections as the spec you feed to CoCo and as the acceptance criteria you check CoCo's output against.

---

## 1. Hackathon Context

**Event:** Snowflake CoCo CLI Hackathon — GCC Edition, presented by Snowflake and YourStory (Hack2Skill platform).
**Eligibility:** Developers/professionals at GCC organizations based in India. Solo or teams up to 4.
**Prize pool:** $10,000 grand pool, 3 winners + consolation prizes.
**Problem statement chosen:** "Risk, Fraud and Regulatory Intelligence Copilot."

### Problem statement, verbatim
> Banking and NBFC teams manage real time fraud, liquidity and credit risk, and regulatory reporting (AML, Basel, and local regulations), largely manual today. Build a copilot that surfaces risk and fraud signals and produces audit ready regulatory outputs from natural language questions.
> - Combine transaction and account data with policy and filing text
> - Let a business or compliance user ask questions and get governed, explainable, evidence backed answers
> - Cover the flow from signal to evidence to a documented finding or report

### Judging focus
- Real World Relevance
- Technical Execution
- Solution Completeness

### CoCo usage requirement (graded at every phase)
- **Planning:** explore data, frame the problem, draft solution design, outline data model/ontology/workflow — via CoCo, before any build.
- **Development:** build pipelines, semantic views, models, agents, app code — via CoCo CLI/Desktop, not by hand.
- **Execution:** run and orchestrate the complete end-to-end solution through CoCo, including any scheduled/automated runs where relevant.
- **Testing:** validate outputs, test accuracy, handle errors/edge cases, confirm correct behavior — via CoCo, before the demo.

### Recommended CoCo tasks (use as many as genuinely fit)
1. Synthetic, referentially-consistent data generation (no production data needed)
2. Data pipeline creation (dynamic tables, tasks, streams — incremental/near-real-time)
3. Semantic model + ontology authoring, with **verified queries** (explicitly called out as crucial for accuracy)
4. Streamlit report/app generation
5. MCP connections to external tools (Jira, Slack, Google Drive, etc.)
6. Document/unstructured processing combined with structured data

### Official reference architecture for this exact problem statement (from Snowflake's own explainer session)
1. Generate synthetic, referentially consistent transaction + account datasets — no production data needed
2. Build semantic views over transaction data and policy text for governed natural language queries
3. Create Cortex Agent skills for fraud signal detection, AML pattern matching, and Basel metric computation
4. Orchestrate the full flow: signal → evidence → audit-ready regulatory report, via CLI
5. Scaffold a compliance officer Streamlit dashboard with cited, explainable outputs
6. Connect to external regulatory sources via MCP for live policy lookups *(we deliberately scope this out — see Section 9)*

### Ingenuity bonuses available (pursue only where noted in Section 9's scope table)
Reusable/shareable skills, MCP connectors to external tools, scheduled automations, custom tools/function calling, multi-agent orchestration, working across CLI/Desktop/Snowsight Cloud Agents/Slackbot, guardrails and graceful fallback.

### Submission requirements (do not skip any of these)
- [ ] Public GitHub repository (must be public, not private) with all code
- [ ] Deployed, working prototype link (not local-only)
- [ ] MVP brief filled in using the platform's official template (challenges faced, MVP brief, public demo link, presentation upload)
- [ ] Publicly accessible demo view link
- [ ] Presentation upload
- [ ] Account provisioning must use the hackathon's dedicated Snowflake sign-up link (not the generic trial) to get CoCo + AI features + container services activated, plus the $400 credit

---

## 2. Our Solution, One Paragraph

**Vigil** is a graph-based fraud-ring detector and cited compliance copilot covering all three risk pillars named in the PS. A chat box takes a plain-English question. Fraud/AML questions traverse a relationship graph over transaction data to catch rings no single flagged transaction reveals; liquidity and credit questions go through Cortex Analyst calculation plus a policy citation. A two-agent system (Investigator → Compliance Writer) handles the fraud pillar's evidence-gathering. Every answer renders in an audit-ready output panel next to the chat, and never ships without citing a transaction ID or policy clause.

**The one genuinely novel piece:** the graph/ring-detection layer for fraud. Everything else (calculation + citation for liquidity/credit, RAG-style policy retrieval) is solid, well-executed, standard practice — be honest about that distinction in the pitch.

---

## 3. Data Model (the spec to feed CoCo — do not hand-write this directly, see Section 7)

8 entities across 3 pillars:

```
CUSTOMERS
  CUSTOMER_ID PK, FULL_NAME, RISK_SEGMENT (LOW/MEDIUM/HIGH), KYC_STATUS (VERIFIED/PENDING/EXPIRED),
  ONBOARDED_DATE, COUNTRY

ACCOUNTS
  ACCOUNT_ID PK, CUSTOMER_ID FK, ACCOUNT_TYPE (SAVINGS/CURRENT), OPENED_DATE, STATUS

TRANSACTIONS
  TRANSACTION_ID PK, ACCOUNT_ID FK, TRANSACTION_DATE, AMOUNT, CURRENCY,
  TRANSACTION_TYPE (TRANSFER/DEPOSIT/WITHDRAWAL/REMITTANCE),
  COUNTERPARTY_NAME, COUNTERPARTY_COUNTRY, CHANNEL (ONLINE/BRANCH/ATM/MOBILE),
  IS_FLAGGED, FLAG_REASON (STRUCTURING_SUSPECTED/HIGH_RISK_COUNTRY/VELOCITY/null)

ALERTS  (simulates the upstream fraud engine's output — out of scope to build the engine itself)
  ALERT_ID PK, TRANSACTION_ID FK, ALERT_TYPE, SEVERITY, CREATED_AT, STATUS

LIQUIDITY_SNAPSHOTS
  SNAPSHOT_DATE PK, HQLA_AMOUNT, NET_CASH_OUTFLOWS_30D, LCR_RATIO, STATUS (COMPLIANT/BREACH)

CREDIT_PROFILES
  LOAN_ACCOUNT_ID PK, CUSTOMER_ID FK, OUTSTANDING_AMOUNT, DAYS_PAST_DUE, CREDIT_SCORE,
  NPA_FLAG, AS_OF_DATE

RING_EDGES  (graph layer output — a Dynamic Table, auto-refreshing)
  ACCOUNT_A, ACCOUNT_B, SHARED_ATTRIBUTE (counterparty/device/time_window), LINK_STRENGTH

RINGS  (clustered output of connected-components over RING_EDGES)
  RING_ID PK, MEMBER_ACCOUNTS (array), SHARED_LINK, TRANSACTION_IDS (array), DETECTED_AT
```

### Required seeded patterns in the synthetic data
- **Structuring:** one account, 3–5 cash deposits each between ₹1.8L–₹1.99L, within a 10-day window
- **High-risk country:** one remittance ≥ ₹5L to a FATF grey-list country (Myanmar, North Korea, Iran, Panama)
- **Velocity:** one deposit ≥ ₹5L followed by an 80%+ withdrawal/transfer within 24 hours
- **Ring (new, not yet built in earlier prototype — build this now):** 4–5 *different* accounts, each individually unremarkable, all transacting with the *same* shared counterparty or device within a tight window, so no single account trips a per-transaction rule alone
- **Noise control (critical — do not skip):** also seed one *innocent* high-frequency shared counterparty (e.g., a common utility/electricity board) that many unrelated accounts pay, specifically to test that the ring-detection hub-node filter does NOT falsely cluster them
- **Liquidity:** 30 daily LCR snapshots, one with LCR < 100% (breach)
- **Credit:** ~40 credit profiles, one with days-past-due > 90 (NPA)

---

## 4. Policy Documents (6 total — the content CoCo's document processing should ingest)

Create these as real files (markdown or PDF) and index them via Cortex Search. Each needs numbered clauses so citations can reference a specific clause, not just a document.

1. **POL-AML-001 — Structuring & Smurfing Detection.** Clause defining the ₹2L reporting threshold, the structuring pattern definition (3+ deposits ₹1.8L–1.99L within 10 days), escalation timeline (24 hrs), evidentiary standard.
2. **POL-AML-002 — High-Risk Jurisdiction Transactions.** FATF grey/black list definition, Enhanced Due Diligence requirement above ₹5L, mandatory escalation, evidentiary standard.
3. **POL-AML-003 — Transaction Velocity Monitoring.** Velocity pattern definition (₹5L+ deposit, 80%+ moved within 24 hrs), automatic hold provision, escalation timeline, evidentiary standard.
4. **POL-AML-004 — STR Filing Timelines & KYC Obligations.** 7-working-day STR filing rule (PMLA Rule 8), KYC-status dependency, risk-segment escalation multiplier, control deficiency reporting.
5. **POL-LIQ-001 — Basel III LCR Compliance.** LCR ≥ 100% requirement, breach classification and 4-hour ALCO escalation, remediation documentation, evidentiary standard.
6. **POL-CR-001 — NPA Classification & Provisioning.** 90-day NPA threshold (RBI IRAC norms), sub-classification (Substandard/Doubtful/Loss), provisioning percentages (15%–100%), evidentiary standard.

**New requirement not in the earlier prototype:** add a short **RING_PATTERN clause** (can go in POL-AML-001 as Clause 4.5, or a new short document) defining what constitutes a fraud ring for citation purposes — e.g., "3 or more accounts transacting with the same counterparty or device within a 72-hour window, absent a legitimate shared business relationship, is presumptively treated as coordinated activity requiring escalation." Without this, the ring-detection feature has no policy clause to cite, which breaks the "every answer needs a citation" rule for that scenario specifically.

---

## 5. Semantic Model / Ontology (feed this shape to CoCo; have CoCo generate and refine it)

**Entities and relationships:**
```
CUSTOMERS 1—N ACCOUNTS 1—N TRANSACTIONS 1—N ALERTS
CREDIT_PROFILES N—1 CUSTOMERS
LIQUIDITY_SNAPSHOTS (standalone, institution-level, no FK)
RING_EDGES many—many ACCOUNTS (via ACCOUNT_A/ACCOUNT_B)
RINGS 1—N TRANSACTIONS (via TRANSACTION_IDS)
```

**Required verified queries** (ask CoCo to validate the semantic model against these natural-language questions specifically, since these are the exact demo questions):
1. "Why was this transaction flagged for structuring?"
2. "Was the remittance to the high risk country compliant?"
3. "Show me the velocity pattern on this account."
4. "Is this account connected to anything else?" *(the ring question — new)*
5. "Are we compliant with our liquidity coverage ratio?"
6. "Which loan accounts are NPA and what provisioning is required?"

---

## 6. Cortex Agents & Orchestration Spec

- **Do not hand-build a custom Python orchestration loop.** Configure native Cortex Agents with tools + natural-language instructions. Snowflake's own guidance for this hackathon explicitly warns against a LangGraph-style custom loop — native agents score better and do the same job.
- **Tools to register:**
  - Cortex Analyst, pointed at the semantic model (Section 5)
  - Cortex Search, pointed at the indexed policy documents (Section 4)
  - A custom tool/function for the ring lookup (query RING_EDGES/RINGS for a given account)
  - Slack, via MCP — callable only, never scheduled
- **Agent instructions (natural language, configure exactly this behavior):**
  - "Every claim in your answer must cite a specific transaction ID, loan account ID, or LCR snapshot date, AND a specific policy document + clause. Never state a fact without a citation."
  - "If you cannot find a confident match for the policy citation, say so explicitly instead of guessing. State your uncertainty plainly."
  - "Never call the Slack tool unless the user explicitly asks you to notify, post, or escalate in this conversation. Never post automatically based on your own confidence assessment."
  - "If the user's question doesn't specify which transaction, account, or loan they mean, and none is available from context, ask which one before answering. Do not assume the most recent alert."
  - "For fraud/AML questions, check the ring lookup tool for related accounts before answering, in addition to the transaction data itself."

---

## 7. Build Sequence — Execute in This Order

### Phase 1 — Planning (produce and log evidence for each step)
1. Open CoCo (CLI or Desktop), connect to the Snowflake account from the hackathon's dedicated signup link (confirms CoCo + AI features + container services are active).
2. Prompt CoCo: *"I'm building a Risk, Fraud & Regulatory Intelligence Copilot for banking/NBFC compliance. Here's my target data model: [paste Section 3]. Draft a semantic ontology and describe the relationships and canonical risk metrics I should define."*
3. Prompt CoCo: *"Outline the end-to-end workflow: signal detection → evidence gathering → documented finding, for three pillars: fraud/AML (with graph-based ring detection), liquidity (LCR compliance), and credit (NPA classification)."*
4. Save both CoCo responses to `coco_lifecycle_log/planning/`.

### Phase 2 — Development
5. Prompt CoCo to generate the synthetic data per Section 3, including the new ring pattern and the noise-control counterparty. Verify referential integrity once generated.
6. Prompt CoCo to create the 8 tables in Snowflake from that data.
7. Prompt CoCo: *"Create a Dynamic Table that self-joins TRANSACTIONS to find account pairs sharing a counterparty, device, or narrow time window, output as RING_EDGES. Then cluster RING_EDGES into RINGS using connected-components, excluding any counterparty connected to more than [N] accounts as a noise filter."* Tune N against the seeded noise-control counterparty until it's correctly excluded while the real ring is still detected.
8. Author the 6 policy documents (Section 4) as files; prompt CoCo to stage them and build a Cortex Search service over them.
9. Prompt CoCo to generate the semantic model (Section 5), then validate it against all 6 verified queries.
10. Prompt CoCo to configure the Cortex Agent(s) with the tools and instructions in Section 6.
11. Prompt CoCo to wire the Slack MCP connector, request-triggered only.
12. Prompt CoCo to scaffold the Streamlit app: chat input on one side, an audit-ready output panel on the other (per the PS's own "questions in, audit-ready outputs" split) — include the 6 example questions as clickable prompts.
13. Log every prompt/response to `coco_lifecycle_log/development/`.

### Phase 3 — Execution
14. Run the full pipeline end-to-end through CoCo's orchestration, not by manually clicking through separate pieces.
15. Deploy the Streamlit app in Snowflake; confirm it has a real, working URL.
16. Log this to `coco_lifecycle_log/execution/`.

### Phase 4 — Testing & Validation
17. Run all 6 scenarios from Section 5 through the deployed app. For each, confirm the answer cites a real record ID and a real policy clause.
18. Ask an ambiguous question with no transaction/account/loan specified, and no prior context — confirm the agent asks a clarifying question instead of guessing.
19. Confirm the noise-control counterparty does NOT get flagged as a ring.
20. Ask the app to post a finding to Slack — confirm it only does so after being explicitly asked, never automatically.
21. Time the full question-to-answer cycle for at least 3 of the scenarios; record the actual numbers (don't invent them).
22. Log all test runs and results to `coco_lifecycle_log/testing/`.

### Phase 5 — Submission
23. Push the full repository to a **public** GitHub repo.
24. Confirm the deployed link works from a fresh, logged-out browser session where applicable.
25. Fill in the official MVP brief template (challenges faced, MVP brief, demo link, presentation).
26. Record a demo video following this script:
    - Show 2–3 seeded accounts whose transactions look clean individually
    - Ask about the ring → graph reveals the connection → cited finding
    - Ask the liquidity question → cited LCR finding
    - Ask the credit question → cited NPA finding
    - Ask it to post one finding to Slack, on request
27. Upload the presentation (Vigil_PRD.pdf content can inform slides, but build an actual slide deck).

---

## 8. What NOT to Build (explicit exclusions — do not let the agent "improve" scope beyond this)

- No second MCP connector beyond Slack
- No splitting the agent into 3+ separate agents
- No scheduled/unattended background jobs that act without being asked (the RING_EDGES Dynamic Table refreshing data is fine; anything that *acts* on new data without a user question is not)
- No live external regulatory-source MCP connector (named as a deliberate gap in the pitch, not built)
- No real production data, ever
- No graph/network detection logic for liquidity or credit risk — those stay as calculation + citation only
- No invented accuracy/efficiency percentage claims anywhere

---

## 9. Honest Talking Points (bake these into the demo narration / MVP brief, don't let them get lost)

- We solve the last-mile gap between an alert existing and a regulator-ready report existing — not detection itself (an upstream engine still produces the initial flag) and not filing (a human always signs off).
- The graph-based ring detection is the one genuinely novel piece; liquidity and credit are honest, simpler retrieval + calculation, because that risk isn't relationship-shaped the way fraud rings are.
- This pattern (graph-based entity resolution) is commercially proven at companies like Quantexa and in Palantir's own banking deployments — we're not claiming a production-grade system from a hackathon, we're proving the core mechanism on a validated approach.
- Named gaps to state upfront, not hide: scale (this won't handle millions of transactions/day untuned), noise filtering (tuned only against our own seeded test case), entity resolution (exact string match only, no fuzzy matching), no live external regulatory feed.

---

## 10. Acceptance Checklist (Claude Code: do not consider this done until every box is checked)

- [ ] All 8 tables created and populated with referentially consistent synthetic data
- [ ] Ring pattern + noise-control counterparty both present in the data
- [ ] 6 policy documents authored and indexed in Cortex Search
- [ ] Semantic model validated against all 6 verified queries
- [ ] Graph layer correctly flags the seeded ring AND correctly excludes the noise counterparty
- [ ] Cortex Agent(s) configured with citation-enforcement and clarify-if-ambiguous instructions
- [ ] Slack/MCP fires only on explicit request, verified by test
- [ ] Streamlit app deployed with a working public-reachable URL
- [ ] All 6 demo scenarios tested and produce cited, correct answers
- [ ] CoCo lifecycle logs present for all 4 phases
- [ ] GitHub repo public, contains everything, deployed link works
- [ ] MVP brief, demo video, and presentation all submitted per the platform's template
