# VIGIL: updated PRD (v2, 3 Oct 2026)

Replaces the original build PRD (`VIGIL_BUILD_PRD.md`) with what is true now. Scope is unchanged: a cited risk, fraud and regulatory copilot over synthetic data, covering fraud/AML (with graph-based ring detection), liquidity (LCR) and credit (NPA). No new features.

## 1. What changed since v1
| Item | v1 assumption | Reality |
|------|---------------|---------|
| Snowflake account | Hackathon signup gives CoCo and Cortex | Plain trial accounts (`ba61812`, a CoCo-developer signup) have Cortex and CoCo disabled. Only the **hackathon credit-link** account (`ua33749`) had them, and it was locked because of a non-corporate email |
| CoCo | Builds everything, logged at every phase | Used for planning (2 prompts) and the start of the data build on `ua33749`. The rest was built by hand on the old account |
| Who builds | One person, fully automated | An AI assistant cannot work inside a teammate's logged-in account (safety guard). The build in the teammate's account is done by pasting prompts from the runbook |
| Slack | One MCP connector, request-only | Draft-only until a webhook/external-access integration exists |

## 2. Current state
**Done (built and tested on the old account, code in the public repo `github.com/sam-raiden/vigil-snowflake-copilot`)**
- Schema, synthetic data, ring detection (`RING_EDGES`, `RINGS` Dynamic Tables with hub filter), 35 policy clauses, semantic view `VIGIL_SV`, rule-based Streamlit app, tests and logs.
- CoCo planning logs (ontology and workflow) from `ua33749`, plus a partial CoCo data build (database, 6 tables, customers, accounts, about 600 transactions).

**Not done**
- Anything that needs Cortex: Cortex Search service, Cortex Analyst validation, Cortex Agent, CoCo-generated build in a working account.
- Real Slack posting. Demo video. Official MVP brief submission. Final deck review.

## 3. Plan to finish (in priority order)
Account: the teammate's hackathon-link account (`rf23286`). Work is done by the owner/you pasting, one step at a time (`docs/RUNBOOK_PASTE_INTO_COCO.md`).

1. **Confirm Cortex** (1 min): `SELECT SNOWFLAKE.CORTEX.COMPLETE('llama3.1-8b','Reply OK');` must return OK.
2. **Data via CoCo** (`coco_lifecycle_log/development/prompt_A.txt`), then verify counts and the seeded patterns.
3. **Ring tables via CoCo** (or `sql/01_schema_and_data.sql` as a fallback), then confirm ACC-0031..0035 form one ring and the electricity-board utility does not.
4. **Policies and Cortex Search**: run `sql/03_policy_clauses.sql`, then `sql/04_search_service.sql` or the CoCo prompt.
5. **Semantic view**: `sql/07_semantic_view.sql` or the CoCo prompt; validate the six questions.
6. **Agent** (one agent: Analyst + Search + ring lookup) with the citation, clarify and no-auto-Slack instructions.
7. **App**: CoCo-built Streamlit calling the agent, or fall back to `app/streamlit_app.py` + `sql/05`, `sql/06`.
8. **Tests**: six scenarios, an ambiguous question, the utility account (no ring), Slack only on request; time three questions with a stopwatch.
9. **Submit** before **4 Oct 2026, 11:59 PM IST**: repo link, deployed app note (needs Snowflake login), MVP brief, deck; demo video if possible.

## 4. Fallback if the Cortex account is not usable in time
Submit the existing build: working app on the old account, public repo, CoCo planning logs and the partial CoCo data-build log, and the honest write-up (`README.md`, `docs/MVP_BRIEF.md`). It is complete but scores lower on CoCo usage.

## 5. Frozen scope (unchanged)
One agent only. No second connector. Nothing scheduled that acts unasked. No production data. No graph detection for liquidity or credit. No invented accuracy or efficiency percentages: any number in the app, brief or video is a measured, single-run figure with its method stated.

## 6. Data model and seeded patterns (unchanged)
8 entities: CUSTOMERS, ACCOUNTS, TRANSACTIONS, ALERTS, LIQUIDITY_SNAPSHOTS, CREDIT_PROFILES, RING_EDGES, RINGS. Seeded: structuring (ACC-0007, 4 deposits INR 1.85 to 1.95 lakh in 10 days), high-risk remittance (ACC-0012 to Myanmar, INR 6.5 lakh), velocity (ACC-0019, 86.7% out in under 24 h), ring (ACC-0031..0035 via one counterparty within 72 h, no individual flags), noise control (25 accounts paying one utility), LCR breach (2026-09-17, 94%), NPA (LN-0025, 120 days; LN-0033 at 88 days as a near miss).

## 7. Acceptance checklist (updated)
- [x] 8 tables, consistent synthetic data (old account); CoCo partial build on `ua33749`
- [x] Ring pattern and noise-control counterparty present; graph flags the ring and excludes the utility
- [x] 6 policy documents, 35 clauses (table)
- [ ] Policies indexed in Cortex Search (needs Cortex account)
- [~] Semantic view built; 5 of 6 queries checked via `SEMANTIC_VIEW()`; Analyst NL validation pending
- [ ] Cortex Agent with citation and clarify rules (rule-based equivalent in the app)
- [ ] Slack on explicit request (draft-only now)
- [~] Streamlit app deployed (old account, login required); agent-driven version pending
- [~] Six scenarios tested on the rule-based app; agent version pending
- [~] CoCo lifecycle logs: planning done, development partial, execution/testing pending in a Cortex account
- [x] Public GitHub repo
- [ ] MVP brief submitted, demo video, presentation uploaded

Legend: [x] done, [~] partly, [ ] not done.
