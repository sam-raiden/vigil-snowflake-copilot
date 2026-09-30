# Execution notes, 2026-09-30

CoCo was not used at any phase (disabled on the trial account; see development/build_status.md). The user authorised a manual build.

Order actually run in Snowsight (ACCOUNTADMIN, COMPUTE_WH):
1. sql/01_schema_and_data.sql (all statements, one run)
2. sql/02_verify.sql
3. sql/03_policy_clauses.sql (table created; the trailing CORTEX.COMPLETE test failed as expected)
4. sql/04_search_service.sql (FAILED: EMBED_TEXT_768 not available for trial accounts)
5. sql/05_deploy_app.sql (stage + COPY INTO the app file + CREATE STREAMLIT); first run failed at runtime on `USE SCHEMA` (unsupported in Streamlit in Snowflake), fixed and redeployed with 05b
6. sql/06_environment.sql (pin streamlit=1.35.0 after `st.chat_input` was missing)
7. Redeployed 05b after the context-reuse fix

How SQL got into the editor: typing was too slow and DOM edits did not reach the editor, so the file was placed on the system clipboard and pasted with Ctrl+V.
