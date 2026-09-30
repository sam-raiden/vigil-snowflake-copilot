# POL-AML-001 — Structuring & Smurfing Detection
Version 1.0 | Owner: Financial Crime Compliance | Synthetic policy for the Vigil demo. Not a real bank policy.

## Clause 1.1 — Purpose
This policy defines how the bank identifies deposits deliberately split to avoid the cash reporting threshold.

## Clause 2.1 — Reporting Threshold
Cash transactions of INR 2,00,000 (₹2L) or more in a single transaction are subject to mandatory reporting.

## Clause 3.1 — Structuring Pattern Definition
Structuring is presumed when an account receives 3 or more cash deposits, each between ₹1,80,000 and ₹1,99,999, within any rolling 10-day window.

## Clause 3.2 — Aggregation
Deposits are aggregated per account. Deposits made across different channels or branches are aggregated together.

## Clause 4.1 — Escalation Timeline
A suspected structuring case must be escalated to the AML Compliance Officer within 24 hours of the alert being raised.

## Clause 4.2 — Evidentiary Standard
An escalation must cite the transaction IDs of every deposit in the pattern, their amounts and dates, and the account ID.

## Clause 4.5 — RING_PATTERN: Coordinated Account Activity
Three or more accounts transacting with the same counterparty or device within a 72-hour window, absent a legitimate shared business relationship, are presumptively treated as coordinated activity and require escalation within 24 hours. Counterparties that serve a legitimate broad customer base (for example utilities or government bodies) are excluded from this presumption. Evidence must cite the ring's member account IDs, the shared counterparty or device, and the transaction IDs involved.
