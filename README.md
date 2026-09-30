# Vigil: cited risk, fraud and regulatory copilot (Snowflake)

Vigil answers plain-English compliance questions over transaction, alert, liquidity and credit data. Every answer cites a record ID and a policy clause. It also finds fraud rings that no single-transaction rule sees, using a graph layer built from Dynamic Tables.

All data is synthetic. Built for the Snowflake CoCo CLI Hackathon (GCC Edition), problem statement "Risk, Fraud and Regulatory Intelligence Copilot".

## What was actually built (read this first)

| Piece | Status |
|-------|--------|
| 8 tables, synthetic and referentially consistent (`sql/01_schema_and_data.sql`) | Built, verified |
| Ring detection: `RING_EDGES` and `RINGS` Dynamic Tables with a hub filter | Built, verified; finds the seeded ring, excludes the utility |
| 6 policy documents, 35 numbered clauses (`policies/`, table `POLICY_CLAUSES`) | Built |
| Streamlit app in Snowflake: chat, audit panel, 6 clickable questions, ring graph, download | Built, deployed, tested (`coco_lifecycle_log/testing/test_results.md`) |
| Clarify-if-ambiguous, no-answer-without-citation, low-confidence fallback | Built, tested |
| Semantic view `VIGIL_SV` (`sql/07_semantic_view.sql`), 6 tables, facts, dimensions, metrics | Built. Queries 1, 2, 3, 5, 6 checked through `SEMANTIC_VIEW()` (10 expected rows). Not validated through Cortex Analyst natural language, and the ring question (4) is not in it |
| Slack | Draft-only. Nothing is ever posted. Real Slack via MCP is not built |
| CoCo / Cortex Search / Cortex Analyst / Cortex Agents | **Not built, not used.** See below |

### Why there is no LLM, and what that changes
The Snowflake account used is a trial account, and Snowflake disables its AI features there:
- CoCo in Snowsight: "Cortex Code is not enabled or the usage limit has been reached"
- `SNOWFLAKE.CORTEX.COMPLETE`: "not available for trial accounts"
- Cortex Search service: "`EMBED_TEXT_768` is not available for trial accounts"

So this is **not** the CoCo-built, agent-driven system the brief describes. The code was written by hand, and the app routes questions with keyword rules to fixed SQL checks; it does not understand free-form language. The policy citations are exact clause lookups, not semantic search. On an account with Cortex enabled, the same tables and clauses are the input for a Cortex Search service, a semantic view and agents (`docs/UPGRADE_PATH.md`).

## Repo layout
- `app/streamlit_app.py`, `app/environment.yml`: the deployed app
- `sql/01_schema_and_data.sql`: schema, data, dynamic tables (the deployed version is the same statements on fewer lines)
- `sql/02_verify.sql`: data-layer checks; `sql/03_policy_clauses.sql`: clause table; `sql/05_deploy_app.sql`, `05b_redeploy.sql`, `06_environment.sql`: deployment
- `sql/04_search_service.sql`: **failed** on the trial account (kept as evidence and for the upgrade path)
- `policies/`: the six policies. `docs/`: MVP brief, demo script, upgrade path, deck. `coco_lifecycle_log/`: what happened in each phase, including the failures

## Run it
Needs a Snowflake account with a warehouse. Run `sql/01`, `sql/03`, then create the stage and Streamlit object as in `sql/05_deploy_app.sql` (it uploads the app file by `COPY INTO` a stage) and `sql/06_environment.sql`.

## Known gaps (stated up front)
- The app is inside Snowflake and needs a Snowflake login, so there is no anonymous public URL.
- Scale: tested on 638 transactions only.
- Noise filter (fan-in above 8 accounts) was tuned only against the one seeded utility. Entity matching is exact string only, no fuzzy matching. There is no device attribute, only counterparty and a 72-hour window.
- Connected components use 4 rounds of label propagation, enough for small rings, not proven for large ones.
- There is no EDD record table, so EDD completion is treated as missing. There is no cash flag, so BRANCH/ATM deposits are treated as cash. There is no NPA-age field, so NPAs are classified Substandard.
- No live regulatory feed. A human signs off on any filing.
- Latency numbers in the test log are single runs of server-side time.
