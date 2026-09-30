# CoCo prompt pack (Phase 1 and 2). Send each through CoCo and log prompt + response.

## P1 — Ontology (planning)
See PRD Section 7 step 2. Sent 2026-09-30 via Snowsight CoCo. Result: "Cortex Code is not enabled or the usage limit has been reached" (request_id b8df9070-cf48-4a2b-9ecc-d6738c74c975). CoCo is blocked on this account.

## P2 — Workflow (planning)
Outline the end-to-end workflow: signal detection -> evidence gathering -> documented finding, for three pillars: fraud/AML (with graph-based ring detection), liquidity (LCR compliance), and credit (NPA classification).

## P3 — Synthetic data (development)
Generate referentially consistent synthetic data for the 8 tables, with these seeded patterns: structuring (3-5 cash deposits of INR 1.8L-1.99L in 10 days on one account); a remittance >= INR 5L to Myanmar/North Korea/Iran/Panama; a velocity case (deposit >= 5L, 80%+ out within 24h); a ring of 4-5 different accounts sharing one counterparty or device within 72 hours, each unremarkable alone; one innocent utility counterparty paid by many unrelated accounts (noise control); 30 daily LCR snapshots with one breach; about 40 credit profiles with one over 90 days past due.

## P4 — Ring layer
Create a Dynamic Table RING_EDGES that self-joins TRANSACTIONS to find account pairs sharing a counterparty within 72 hours, then cluster into RINGS by connected components, excluding any counterparty linked to more than N accounts. Tune N so the utility is excluded and the seeded ring is kept.

## P5 — Search, semantic model, agent, app
Stage /policies and build a Cortex Search service; generate the semantic model and validate it against the 6 verified queries in PRD Section 5; configure the Cortex Agent per PRD Section 6; scaffold the Streamlit app per PRD Section 7 step 12.
