# CoCo development step 1: tables and synthetic data (UA33749), 2026-10-01

Prompt: see `prompt_A.txt` in this folder (sent by pasting from the clipboard into the Snowsight CoCo chat).

What CoCo did (each SQL statement approved by hand in the CoCo panel):
1. Planned the work in 7 steps.
2. Step 1: ran CREATE DATABASE VIGIL; CREATE SCHEMA VIGIL.CORE; created all 6 base tables.
3. Step 2: inserted CUSTOMERS and ACCOUNTS. CoCo checked its own result, saw 59 rows instead of 60 (SEQ4() starts at 0), and re-ran the inserts with ROW_NUMBER().
4. Step 3: inserted about 600 ordinary transactions (corrected from a first attempt as well).
5. Step 4: started inserting the seeded patterns (structuring first). The session expired before it finished.

Interrupted at step 4 of 7: Snowsight logged out ("Session expired" under the account's session policy). The state of steps 4 to 7 (seeded patterns, alerts, liquidity, credit) is therefore unverified and must be checked before continuing.
