# Build status, 2026-09-30 (Snowflake trial account)

## Done, built by hand in Snowsight (CoCo unavailable; user authorised manual build)
- VIGIL.CORE: 6 base tables + RING_EDGES + RINGS dynamic tables (sql/01_schema_and_data.sql).
- Verified (sql/02_verify.sql): 638 txns, 60 accounts, 8 alerts; RING_EDGES=10 edges, all via "Zenith Global Ventures";
  RINGS=1 (RING-001: ACC-0031..0035); utility counterparty excluded (0 rings); LCR breach 2026-09-17 = 94.00%;
  NPA = LN-0025 (120 DPD); structuring deposits total 760,000.
- POLICY_CLAUSES table: 35 numbered clauses from the 6 policies (sql/03_policy_clauses.sql).

## Blocked: every Snowflake AI feature is disabled for trial accounts
- CoCo (Snowsight): "Cortex Code is not enabled or the usage limit has been reached" (request_id b8df9070-cf48-4a2b-9eee-d6738c74c975)
- SNOWFLAKE.CORTEX.COMPLETE: "AI function COMPLETE is not available for trial accounts."
- CREATE CORTEX SEARCH SERVICE: "AI function EMBED_TEXT_768 is not available for trial accounts."
- Therefore not buildable now: Cortex Search service, Cortex Analyst semantic view verified queries, Cortex Agents, Slack MCP via agent.

## Not started
Streamlit app, agents, Slack, tests, GitHub push, MVP brief, video, deck.
