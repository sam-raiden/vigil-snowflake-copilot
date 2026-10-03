# Runbook: build Vigil in a Cortex-enabled account (about 30 to 40 minutes of pasting)

Use this in the hackathon-link account. Do the steps in order. In each step, paste the text into the CoCo chat (blue star in Snowsight) and approve each SQL statement CoCo asks to run. Save each prompt and CoCo's answer into `coco_lifecycle_log/` (copy-paste into a text file).

## Step 0: check Cortex works (10 seconds)
In a SQL file run: `SELECT SNOWFLAKE.CORTEX.COMPLETE('llama3.1-8b','Reply OK');` It must return OK. If it says "not available for trial accounts", this is the wrong account.

## Step 1: planning (two prompts, nothing is created)
Prompts and CoCo's real answers from the earlier session are in `coco_lifecycle_log/planning/01_ontology_coco.md` and `02_workflow_coco.md`. Re-send them in the new account (short versions are fine) so the planning evidence exists for that account.

## Step 2: tables and data
Paste the whole of `coco_lifecycle_log/development/prompt_A.txt`. Afterwards ask CoCo: "Verify row counts and referential integrity, and show the seeded patterns TXN-ST-01..04, TXN-HR-01, TXN-VE-01..03, TXN-RG-01..05." Expected: about 638 transactions, 60 accounts, 8 alerts.

## Step 3: ring detection
Paste: "Create a Dynamic Table RING_EDGES in VIGIL.CORE that self-joins TRANSACTIONS to find pairs of different accounts that paid the same COUNTERPARTY_NAME within 72 hours, excluding any counterparty paid by more than 8 distinct accounts (the hub filter). Then create a Dynamic Table RINGS (RING_ID, MEMBER_ACCOUNTS array, SHARED_LINK, TRANSACTION_IDS array, DETECTED_AT) clustering RING_EDGES into connected components of 3 or more accounts. Check that ACC-0031..0035 form one ring through 'Zenith Global Ventures' and that 'Bangalore Electricity Board' is NOT clustered. Tune the threshold if needed." (If CoCo struggles, `sql/01_schema_and_data.sql` has a tested version of both tables.)

## Step 4: policies and search
Run `sql/03_policy_clauses.sql` (creates POLICY_CLAUSES with 35 clauses). Then paste: "Create a Cortex Search service VIGIL.CORE.POLICY_SEARCH over POLICY_CLAUSES, searching CLAUSE_TEXT, with attributes DOC_ID, CLAUSE_NO, CITATION, warehouse COMPUTE_WH, target lag 1 day. Test it with: 'what is the structuring definition', 'STR filing timeline', 'NPA provisioning'." If SQL is easier, `sql/04_search_service.sql` is ready.

## Step 5: semantic view
Run `sql/07_semantic_view.sql` (tested, creates VIGIL_SV), or ask CoCo: "Create a semantic view VIGIL_SV over the VIGIL.CORE tables with the relationships accounts to customers, transactions to accounts, alerts to transactions, credit_profiles to customers, and metrics for total amount, LCR and NPA. Validate it against these questions: why was TXN-ST-01 flagged for structuring; was remittance TXN-HR-01 compliant; velocity on ACC-0019; is ACC-0031 connected to anything else (use RINGS); are we LCR compliant; which loans are NPA and what provisioning (15% of outstanding for substandard)."

## Step 6: the agent
Paste: "Create a Cortex Agent VIGIL_AGENT with these tools: Cortex Analyst on the semantic view VIGIL_SV, Cortex Search on POLICY_SEARCH, and a custom function RING_LOOKUP(account_id) that returns the ring from RINGS for an account. Instructions: Every claim must cite a transaction ID, loan account ID or LCR snapshot date AND a policy document plus clause. If there is no confident policy match, say so instead of guessing. If the user does not say which transaction, account or loan, ask before answering; do not assume the most recent alert. For fraud/AML questions, always check RING_LOOKUP for related accounts. Never post to Slack unless the user explicitly asks in this conversation."

## Step 7: the app
Paste: "Create a Streamlit app in Snowflake called VIGIL_APP with a chat box on the left and an audit-ready output panel on the right, six clickable example questions (the six from step 5), that calls VIGIL_AGENT and shows the verdict, evidence rows, record IDs and policy citations, with a download button." As a fallback, the rule-based app in `app/streamlit_app.py` with `sql/05_deploy_app.sql` and `sql/06_environment.sql` works without an agent.

## Step 8: tests (save every result)
Run the six questions. Then: an ambiguous question ("Why was this transaction flagged?") must make the agent ask which one; ask about ACC-0040 (pays the utility), which must show no ring; ask the agent to post a finding to Slack only when you explicitly request it. Record the time of 3 questions with a stopwatch.

## Step 9: submission
Copy the CoCo prompts/responses into `coco_lifecycle_log/`, push the repo (already public at github.com/sam-raiden/vigil-snowflake-copilot), fill the MVP brief from `docs/MVP_BRIEF.md` (update the CoCo and Cortex lines to match what actually worked), record the demo from `docs/DEMO_SCRIPT.md`, and submit on Hack2Skill before **4 Oct 2026, 11:59 PM IST**.
