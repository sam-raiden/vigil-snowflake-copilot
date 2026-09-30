# Upgrade path once Cortex is enabled (not done)

1. Run `sql/04_search_service.sql` to build `POLICY_SEARCH` over `POLICY_CLAUSES`.
2. Create a semantic view over the 8 tables and validate it with the six verified questions in the PRD, Section 5.
3. Create one agent with Cortex Analyst, Cortex Search and a custom function that reads `RINGS` for an account, using the instructions in the PRD, Section 6.
4. Replace `route()` in `app/streamlit_app.py` with a call to the agent, keeping `render()` and its citation panel.
5. Add the Slack MCP tool, callable on request only.

Nothing above has been run. The rule-based checks in the app double as expected-answer tests for the agent.
