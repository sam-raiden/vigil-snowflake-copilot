# MVP brief: Vigil

## Problem
Banking and NBFC compliance teams get an alert and then spend time assembling evidence and the matching policy clause by hand. Fraud rings are worse: each account looks fine alone, so per-transaction rules never fire.

## What the MVP does
A compliance user asks a question and gets a finding with a verdict, the evidence rows, the record IDs, and the exact policy clauses, plus a downloadable note. It covers the three pillars in the problem statement:
- Fraud/AML: structuring, high-risk-jurisdiction remittances, velocity, and ring detection (the one novel part).
- Liquidity: LCR calculation and breach history against POL-LIQ-001.
- Credit: NPA classification and provisioning against POL-CR-001.

In the seeded data, five accounts (ACC-0031 to ACC-0035) each paid one counterparty within 45 hours, none individually flagged, and the graph layer groups them. A utility paid by 25 other accounts is correctly not grouped.

## Where it stops
It helps with the last step between an alert and a report. It does not detect fraud upstream, and it does not file anything: a human signs off.

## Challenges faced (honest)
- The Snowflake account is a trial, so every AI feature was disabled: CoCo, `CORTEX.COMPLETE`, and Cortex Search failed with explicit errors. The planned CoCo-generated build, Cortex Search, Analyst and Agents was therefore not possible. The rule-based app is the substitute, and it cannot handle free-form questions.
- Browser automation of Snowsight was flaky (frozen page on long typing, ignored first clicks), which cost time.
- The Streamlit runtime was too old for `st.chat_input`; fixed by pinning `streamlit=1.35.0` in `environment.yml`.
- A test found the app silently reusing an account from an earlier question; fixed and re-tested in a fresh session.

## Named gaps
Scale (638 transactions tested), noise filter tuned on one seeded case, exact-match entities only, no live regulatory feed, no real Slack posting, no anonymous public URL (Streamlit in Snowflake needs a login).

## Measurements
Single-run, server-side time per question was 0.17 s to 0.68 s across five of the six scenarios (`coco_lifecycle_log/testing/test_results.md`). No efficiency or accuracy percentage is claimed.

## Demo link
The app lives at `VIGIL.CORE.VIGIL_APP` in the Snowflake account (requires login). No public demo link exists. The repository is the public artifact.
