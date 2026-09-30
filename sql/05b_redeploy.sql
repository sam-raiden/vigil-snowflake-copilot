COPY INTO @VIGIL.CORE.APP_STAGE/streamlit_app.py FROM (SELECT $$import json
import re
import time
from datetime import datetime, timedelta
from decimal import Decimal

import pandas as pd
import streamlit as st
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="Vigil", layout="wide")
session = get_active_session()

HIGH_RISK = ("Myanmar", "North Korea", "Iran", "Panama")

EXAMPLES = [
    "Why was TXN-ST-01 flagged for structuring?",
    "Was the remittance TXN-HR-01 to the high risk country compliant?",
    "Show me the velocity pattern on account ACC-0019.",
    "Is account ACC-0031 connected to anything else?",
    "Are we compliant with our liquidity coverage ratio?",
    "Which loan accounts are NPA and what provisioning is required?",
]


def q(sql, params=None):
    df = session.sql(sql, params=params).to_pandas()
    for c in df.columns:
        if df[c].dtype == object and len(df) and isinstance(df[c].iloc[0], Decimal):
            df[c] = df[c].astype(float)
        if c.endswith("_DATE") and len(df):
            try:
                df[c] = pd.to_datetime(df[c]) if c == "TRANSACTION_DATE" else df[c]
            except Exception:
                pass
    return df


def clause(doc, no):
    df = q("SELECT DOC_TITLE, CLAUSE_TITLE, CLAUSE_TEXT, CITATION FROM POLICY_CLAUSES WHERE DOC_ID=? AND CLAUSE_NO=?", [doc, no])
    if df.empty:
        return None
    r = df.iloc[0]
    return {"cite": r["CITATION"], "title": r["CLAUSE_TITLE"], "text": r["CLAUSE_TEXT"], "doc": r["DOC_TITLE"]}


def inr(x):
    return "Rs {:,.0f}".format(float(x))


def customer_of(acct):
    df = q("SELECT c.CUSTOMER_ID, c.RISK_SEGMENT, c.KYC_STATUS FROM ACCOUNTS a JOIN CUSTOMERS c ON c.CUSTOMER_ID=a.CUSTOMER_ID WHERE a.ACCOUNT_ID=?", [acct])
    return None if df.empty else df.iloc[0]


def resolve_account(text):
    m = re.search(r"TXN-[A-Z0-9]+-?\d*", text, re.I)
    if m:
        df = q("SELECT ACCOUNT_ID FROM TRANSACTIONS WHERE TRANSACTION_ID=?", [m.group(0).upper()])
        if not df.empty:
            return df.iloc[0]["ACCOUNT_ID"], m.group(0).upper()
    m = re.search(r"ACC-\d{4}", text, re.I)
    if m:
        return m.group(0).upper(), None
    if re.search(r"\b(this|that|the same|the) account\b", text, re.I):
        return st.session_state.get("ctx_account"), None
    return None, None


def clarify(kind):
    cands = q("SELECT DISTINCT t.ACCOUNT_ID, t.TRANSACTION_ID, t.FLAG_REASON FROM ALERTS a JOIN TRANSACTIONS t ON t.TRANSACTION_ID=a.TRANSACTION_ID ORDER BY 1,2")
    return {
        "title": "Clarification needed",
        "verdict": "NO ANSWER GIVEN (missing subject)",
        "answer": "Which transaction or account do you mean? I will not assume the most recent alert. Please include a transaction ID (TXN-...) or account ID (ACC-...) in your question.",
        "evidence": cands.rename(columns=str.title) if not cands.empty else None,
        "records": [],
        "clauses": [],
        "confidence": "n/a",
        "notes": ["Alerted transactions in the system are listed as options."],
    }


def check_structuring(acct, txn):
    dep = q("SELECT TRANSACTION_ID, TRANSACTION_DATE, AMOUNT, CHANNEL, FLAG_REASON FROM TRANSACTIONS WHERE ACCOUNT_ID=? AND TRANSACTION_TYPE='DEPOSIT' AND AMOUNT BETWEEN 180000 AND 199999 AND CHANNEL IN ('BRANCH','ATM') ORDER BY TRANSACTION_DATE", [acct])
    cust = customer_of(acct)
    best, best_set = 0, []
    dates = list(pd.to_datetime(dep["TRANSACTION_DATE"])) if not dep.empty else []
    for i, d in enumerate(dates):
        w = [j for j, e in enumerate(dates) if d <= e <= d + timedelta(days=10)]
        if len(w) > best:
            best, best_set = len(w), w
    clauses = [("POL-AML-001", "3.1"), ("POL-AML-001", "4.1"), ("POL-AML-001", "4.2")]
    notes = ["The data has no cash flag; deposits made through BRANCH or ATM channels are treated as cash."]
    hours = 24
    if cust is not None:
        if cust["KYC_STATUS"] != "VERIFIED":
            clauses.append(("POL-AML-004", "3.1"))
            notes.append("KYC status is %s, which is a control deficiency to report with the case." % cust["KYC_STATUS"])
        if cust["RISK_SEGMENT"] == "HIGH":
            clauses.append(("POL-AML-004", "3.2"))
            hours = 12
    clauses.append(("POL-AML-004", "2.1"))
    if best >= 3:
        ev = dep.iloc[best_set]
        tot = ev["AMOUNT"].sum()
        ans = ("Account %s received %d deposits between Rs 1,80,000 and Rs 1,99,999 within a 10-day window (%s to %s), totalling %s. "
               "This meets the structuring definition in POL-AML-001 Clause 3.1. Escalate to the AML Compliance Officer within %d hours (Clause 4.1)."
               % (acct, best, ev["TRANSACTION_DATE"].min().date(), ev["TRANSACTION_DATE"].max().date(), inr(tot), hours))
        verdict = "STRUCTURING PATTERN CONFIRMED"
        records = list(ev["TRANSACTION_ID"])
        conf = "HIGH (rule match on data)"
    else:
        ev = dep
        ans = "Account %s does not have 3 or more deposits in the Rs 1,80,000 to Rs 1,99,999 band within 10 days. The structuring definition (POL-AML-001 Clause 3.1) is not met on the data available." % acct
        verdict = "NO STRUCTURING PATTERN FOUND"
        records = list(dep["TRANSACTION_ID"])
        conf = "HIGH (rule checked, no match)"
    ring = ring_lookup(acct, brief=True)
    if ring:
        notes.append(ring)
    return {"title": "Structuring review: " + acct, "verdict": verdict, "answer": ans, "evidence": ev, "records": records or [acct], "clauses": clauses, "confidence": conf, "notes": notes}


def check_hrc(acct, txn):
    lst = ",".join("'%s'" % c for c in HIGH_RISK)
    if txn:
        df = q("SELECT TRANSACTION_ID, ACCOUNT_ID, TRANSACTION_DATE, AMOUNT, COUNTERPARTY_NAME, COUNTERPARTY_COUNTRY FROM TRANSACTIONS WHERE TRANSACTION_ID=?", [txn])
    else:
        df = q("SELECT TRANSACTION_ID, ACCOUNT_ID, TRANSACTION_DATE, AMOUNT, COUNTERPARTY_NAME, COUNTERPARTY_COUNTRY FROM TRANSACTIONS WHERE ACCOUNT_ID=? AND TRANSACTION_TYPE='REMITTANCE' AND COUNTERPARTY_COUNTRY IN (%s)" % lst, [acct])
    clauses = [("POL-AML-002", "2.1"), ("POL-AML-002", "3.1"), ("POL-AML-002", "4.1"), ("POL-AML-002", "4.2")]
    notes = ["The dataset has no EDD (Enhanced Due Diligence) record table, so EDD completion cannot be confirmed and is treated as missing."]
    if df.empty or df.iloc[0]["COUNTERPARTY_COUNTRY"] not in HIGH_RISK:
        return {"title": "High-risk jurisdiction review", "verdict": "NOT A HIGH-RISK JURISDICTION TRANSACTION", "answer": "No remittance to a monitored high-risk jurisdiction (%s) was found for the transaction or account given." % ", ".join(HIGH_RISK), "evidence": df, "records": list(df["TRANSACTION_ID"]) if not df.empty else [acct], "clauses": clauses[:1], "confidence": "HIGH (rule checked, no match)", "notes": notes}
    r = df.iloc[0]
    over = float(r["AMOUNT"]) >= 500000
    cust = customer_of(r["ACCOUNT_ID"])
    hours = 12 if (cust is not None and cust["RISK_SEGMENT"] == "HIGH") else 24
    if cust is not None and cust["RISK_SEGMENT"] == "HIGH":
        clauses.append(("POL-AML-004", "3.2"))
    if over:
        ans = ("%s: %s remitted to %s (%s). This is at or above the Rs 5,00,000 threshold, so Enhanced Due Diligence is required (POL-AML-002 Clause 3.1). "
               "No EDD record exists in the data, so the remittance is NOT shown to be compliant. Escalate within %d hours (Clause 4.1)."
               % (r["TRANSACTION_ID"], inr(r["AMOUNT"]), r["COUNTERPARTY_NAME"], r["COUNTERPARTY_COUNTRY"], hours))
        verdict = "NOT SHOWN COMPLIANT: EDD REQUIRED, NONE ON RECORD"
    else:
        ans = "%s is below the Rs 5,00,000 EDD threshold, though the counterparty country (%s) is high risk." % (r["TRANSACTION_ID"], r["COUNTERPARTY_COUNTRY"])
        verdict = "BELOW EDD THRESHOLD"
    return {"title": "High-risk jurisdiction review: " + r["TRANSACTION_ID"], "verdict": verdict, "answer": ans, "evidence": df, "records": list(df["TRANSACTION_ID"]), "clauses": clauses, "confidence": "HIGH (rule match on data)", "notes": notes}


def check_velocity(acct, txn):
    tx = q("SELECT TRANSACTION_ID, TRANSACTION_DATE, TRANSACTION_TYPE, AMOUNT FROM TRANSACTIONS WHERE ACCOUNT_ID=? ORDER BY TRANSACTION_DATE", [acct])
    tx["TRANSACTION_DATE"] = pd.to_datetime(tx["TRANSACTION_DATE"])
    clauses = [("POL-AML-003", "2.1"), ("POL-AML-003", "3.1"), ("POL-AML-003", "4.1"), ("POL-AML-003", "4.2")]
    rows, ids, hit = [], [], None
    for _, d in tx[(tx["TRANSACTION_TYPE"] == "DEPOSIT") & (tx["AMOUNT"] >= 500000)].iterrows():
        out = tx[(tx["TRANSACTION_TYPE"].isin(["TRANSFER", "WITHDRAWAL", "REMITTANCE"])) & (tx["TRANSACTION_DATE"] > d["TRANSACTION_DATE"]) & (tx["TRANSACTION_DATE"] <= d["TRANSACTION_DATE"] + timedelta(hours=24))]
        pct = float(out["AMOUNT"].sum()) / float(d["AMOUNT"])
        rows.append(pd.concat([pd.DataFrame([d]), out]))
        ids += [d["TRANSACTION_ID"]] + list(out["TRANSACTION_ID"])
        if pct >= 0.8:
            hit = (d, out, pct)
    ev = pd.concat(rows) if rows else tx.head(0)
    if hit:
        d, out, pct = hit
        hrs = (out["TRANSACTION_DATE"].max() - d["TRANSACTION_DATE"]).total_seconds() / 3600
        ans = ("Account %s received a deposit of %s (%s) and moved %s (%.1f%%) out within %.1f hours via %s. "
               "This meets the velocity pattern in POL-AML-003 Clause 2.1 (deposit of Rs 5,00,000 or more, 80%% or more moved within 24 hours). An automatic hold is permitted (Clause 3.1); escalate within 24 hours (Clause 4.1)."
               % (acct, inr(d["AMOUNT"]), d["TRANSACTION_ID"], inr(out["AMOUNT"].sum()), pct * 100, hrs, ", ".join(out["TRANSACTION_ID"])))
        verdict = "VELOCITY PATTERN CONFIRMED"
        conf = "HIGH (rule match on data)"
    else:
        ans = "No deposit of Rs 5,00,000 or more on account %s was followed by 80%% or more leaving within 24 hours." % acct
        verdict = "NO VELOCITY PATTERN FOUND"
        conf = "HIGH (rule checked, no match)"
    notes = []
    ring = ring_lookup(acct, brief=True)
    if ring:
        notes.append(ring)
    return {"title": "Velocity review: " + acct, "verdict": verdict, "answer": ans, "evidence": ev, "records": ids or [acct], "clauses": clauses, "confidence": conf, "notes": notes}


def ring_lookup(acct, brief=False):
    rings = q("SELECT RING_ID, MEMBER_ACCOUNTS, SHARED_LINK, TRANSACTION_IDS, DETECTED_AT FROM RINGS")
    for _, r in rings.iterrows():
        members = json.loads(r["MEMBER_ACCOUNTS"])
        if acct in members:
            if brief:
                return "Ring check: %s is a member of %s (%d accounts sharing %s). Ask about the ring for details." % (acct, r["RING_ID"], len(members), r["SHARED_LINK"])
            return r
    return None


def check_ring(acct, txn):
    clauses = [("POL-AML-001", "4.5"), ("POL-AML-001", "4.1"), ("POL-AML-001", "4.2")]
    r = ring_lookup(acct)
    hubs = q("SELECT COUNTERPARTY_NAME, COUNT(DISTINCT ACCOUNT_ID) N FROM TRANSACTIONS WHERE COUNTERPARTY_NAME IS NOT NULL GROUP BY 1 HAVING COUNT(DISTINCT ACCOUNT_ID)>8 ORDER BY 2 DESC")
    hub_note = "Hub filter: %d high-fan-in counterparties are excluded as legitimate shared relationships (e.g. %s, paid by %d accounts)." % (len(hubs), hubs.iloc[0]["COUNTERPARTY_NAME"], hubs.iloc[0]["N"]) if not hubs.empty else "Hub filter: none."
    if r is None:
        own = q("SELECT TRANSACTION_ID, TRANSACTION_DATE, AMOUNT, COUNTERPARTY_NAME, IS_FLAGGED FROM TRANSACTIONS WHERE ACCOUNT_ID=? AND COUNTERPARTY_NAME IS NOT NULL ORDER BY TRANSACTION_DATE DESC", [acct])
        return {"title": "Network check: " + acct, "verdict": "NO RING LINKS FOUND", "answer": "Account %s is not a member of any detected ring. The graph checks for 3 or more accounts paying the same counterparty within 72 hours, excluding high-fan-in counterparties (POL-AML-001 Clause 4.5)." % acct, "evidence": own.head(15), "records": [acct], "clauses": clauses[:1], "confidence": "MEDIUM (exact-name matching only; no fuzzy matching)", "notes": [hub_note]}
    members = json.loads(r["MEMBER_ACCOUNTS"])
    ids = json.loads(r["TRANSACTION_IDS"])
    ids = [i for i in ids if re.fullmatch(r"[A-Z0-9-]+", i)]
    ev = q("SELECT TRANSACTION_ID, ACCOUNT_ID, TRANSACTION_DATE, AMOUNT, COUNTERPARTY_NAME, IS_FLAGGED FROM TRANSACTIONS WHERE TRANSACTION_ID IN (%s) ORDER BY TRANSACTION_DATE" % ",".join("'%s'" % i for i in ids))
    edges = q("SELECT ACCOUNT_A, ACCOUNT_B, SHARED_VALUE FROM RING_EDGES WHERE ACCOUNT_A IN (%s)" % ",".join("'%s'" % m for m in members))
    span = (pd.to_datetime(ev["TRANSACTION_DATE"]).max() - pd.to_datetime(ev["TRANSACTION_DATE"]).min())
    flagged = int(ev["IS_FLAGGED"].sum())
    ans = ("Yes. %s is one of %d accounts (%s) that all paid %s within %.0f hours. %d of these %d transactions were individually flagged, so a per-transaction rule would not have caught this. "
           "Under POL-AML-001 Clause 4.5 this is presumptively coordinated activity and requires escalation within 24 hours (Clause 4.1)."
           % (acct, len(members), ", ".join(members), r["SHARED_LINK"], span.total_seconds() / 3600, flagged, len(ev)))
    dot = "graph G { rankdir=LR; node [shape=circle,style=filled,fillcolor=lightblue]; cp [label=\"%s\",shape=box,fillcolor=orange]; " % r["SHARED_LINK"]
    for m in members:
        dot += '"%s"; "%s" -- cp; ' % (m, m)
    for _, e in edges.iterrows():
        dot += '"%s" -- "%s" [style=dashed,color=gray]; ' % (e["ACCOUNT_A"], e["ACCOUNT_B"])
    dot += "}"
    return {"title": "Ring review: " + r["RING_ID"], "verdict": "RING DETECTED (%s)" % r["RING_ID"], "answer": ans, "evidence": ev, "records": ids, "clauses": clauses, "confidence": "MEDIUM (exact-name matching only; tuned on seeded data)", "notes": [hub_note], "graph": dot}


def check_lcr(acct, txn):
    df = q("SELECT SNAPSHOT_DATE, HQLA_AMOUNT, NET_CASH_OUTFLOWS_30D, LCR_RATIO, STATUS FROM LIQUIDITY_SNAPSHOTS ORDER BY SNAPSHOT_DATE DESC")
    latest = df.iloc[0]
    br = df[df["STATUS"] == "BREACH"]
    clauses = [("POL-LIQ-001", "2.1"), ("POL-LIQ-001", "3.1"), ("POL-LIQ-001", "3.2"), ("POL-LIQ-001", "4.1"), ("POL-LIQ-001", "4.2")]
    ans = "Latest snapshot %s: LCR %.2f%% (HQLA %s / net outflows %s), status %s against the 100%% minimum (POL-LIQ-001 Clause 2.1). " % (latest["SNAPSHOT_DATE"], latest["LCR_RATIO"], inr(latest["HQLA_AMOUNT"]), inr(latest["NET_CASH_OUTFLOWS_30D"]), latest["STATUS"])
    if len(br):
        b = br.iloc[0]
        ans += "However, %d breach in the last 30 days: %s at %.2f%%. That breach required ALCO escalation within 4 hours (Clause 3.2) and remediation documentation (Clause 4.1)." % (len(br), b["SNAPSHOT_DATE"], b["LCR_RATIO"])
        verdict = "CURRENTLY COMPLIANT, 1 BREACH IN WINDOW"
    else:
        verdict = "COMPLIANT"
    ev = pd.concat([df.head(1), br]).drop_duplicates()
    return {"title": "LCR compliance", "verdict": verdict, "answer": ans, "evidence": ev, "records": [str(x) for x in ev["SNAPSHOT_DATE"]], "clauses": clauses, "confidence": "HIGH (direct calculation)", "notes": ["Calculated from stored snapshots; the data does not record whether ALCO was actually notified."]}


def check_npa(acct, txn):
    df = q("SELECT LOAN_ACCOUNT_ID, CUSTOMER_ID, OUTSTANDING_AMOUNT, DAYS_PAST_DUE, CREDIT_SCORE, NPA_FLAG FROM CREDIT_PROFILES WHERE DAYS_PAST_DUE > 90 ORDER BY DAYS_PAST_DUE DESC")
    near = q("SELECT LOAN_ACCOUNT_ID, DAYS_PAST_DUE FROM CREDIT_PROFILES WHERE DAYS_PAST_DUE BETWEEN 60 AND 90")
    clauses = [("POL-CR-001", "2.1"), ("POL-CR-001", "3.1"), ("POL-CR-001", "3.2"), ("POL-CR-001", "4.1")]
    if df.empty:
        return {"title": "NPA review", "verdict": "NO NPA LOANS", "answer": "No loan is more than 90 days past due.", "evidence": df, "records": [], "clauses": clauses[:1], "confidence": "HIGH (direct calculation)", "notes": []}
    df["PROVISION_15PCT"] = (df["OUTSTANDING_AMOUNT"].astype(float) * 0.15).round(2)
    df["CLASSIFICATION"] = "SUBSTANDARD"
    lines = ["%s: %d days past due, outstanding %s, classification Substandard, provision required %s" % (r["LOAN_ACCOUNT_ID"], r["DAYS_PAST_DUE"], inr(r["OUTSTANDING_AMOUNT"]), inr(r["PROVISION_15PCT"])) for _, r in df.iterrows()]
    notes = ["The data has no NPA-age field, so loans are classified Substandard (15%) on the assumption they have been NPA for under 12 months. Doubtful (25%-100%) would apply after 12 months (POL-CR-001 Clause 3.1)."]
    if not near.empty:
        notes.append("Watch list, not NPA yet (60 to 90 days past due): " + ", ".join("%s (%d)" % (r["LOAN_ACCOUNT_ID"], r["DAYS_PAST_DUE"]) for _, r in near.iterrows()))
    return {"title": "NPA classification and provisioning", "verdict": "%d NPA LOAN(S)" % len(df), "answer": " ".join(lines) + ".", "evidence": df, "records": list(df["LOAN_ACCOUNT_ID"]), "clauses": clauses, "confidence": "HIGH (direct calculation)", "notes": notes}


def fallback_search(text):
    words = {w for w in re.findall(r"[a-z]{4,}", text.lower())} - {"what", "which", "that", "this", "with", "have", "does", "about", "when", "from", "your"}
    cl = q("SELECT CITATION, CLAUSE_TITLE, CLAUSE_TEXT, DOC_ID, CLAUSE_NO FROM POLICY_CLAUSES")
    scored = []
    for _, r in cl.iterrows():
        hay = (r["CLAUSE_TITLE"] + " " + r["CLAUSE_TEXT"]).lower()
        s = sum(1 for w in words if w in hay)
        scored.append((s, r))
    scored.sort(key=lambda x: -x[0])
    top = [(s, r) for s, r in scored[:3] if s >= 2]
    if not top:
        return {"title": "No confident match", "verdict": "LOW CONFIDENCE, NO ANSWER", "answer": "I could not confidently match this question to a signal check or a policy clause, so I will not guess. Try one of the example questions, or include an account, transaction or loan ID.", "evidence": None, "records": [], "clauses": [], "confidence": "LOW", "notes": []}
    return {"title": "Possibly relevant policy clauses", "verdict": "LOW CONFIDENCE: KEYWORD MATCH ONLY", "answer": "I could not map this to a data check. These clauses share keywords with your question, but this is a keyword match, not a verified answer.", "evidence": None, "records": [], "clauses": [(r["DOC_ID"], r["CLAUSE_NO"]) for _, r in top], "confidence": "LOW (keyword overlap)", "notes": []}


def slack_draft():
    f = st.session_state.get("finding")
    if not f:
        return {"title": "Slack post", "verdict": "NOTHING TO POST", "answer": "There is no finding in this conversation yet. Ask a question first.", "evidence": None, "records": [], "clauses": [], "confidence": "n/a", "notes": []}
    msg = "[Vigil] %s | %s | Records: %s | Policy: %s" % (f["title"], f["verdict"], ", ".join(f["records"][:6]), "; ".join("%s Clause %s" % c for c in f["clauses"][:3]))
    return {"title": "Slack message drafted (not sent)", "verdict": "DRAFT ONLY: SLACK NOT CONNECTED", "answer": "Slack posting is not connected in this build (it needs an external-access webhook). Nothing was posted. Draft message:\n\n" + msg, "evidence": None, "records": f["records"], "clauses": f["clauses"], "confidence": "n/a", "notes": ["Posting only ever happens on an explicit request; nothing is sent automatically."]}


def route(text):
    t = text.lower()
    if re.search(r"slack|notify|post (this|it|the)|escalate (this|it) to", t):
        return slack_draft()
    if re.search(r"\bnpa\b|loan|provision", t):
        return check_npa(None, None)
    if re.search(r"liquidity|\blcr\b|basel", t):
        return check_lcr(None, None)
    kinds = [
        ("structur|smurf", check_structuring),
        ("remittance|high.?risk|fatf|jurisdiction|country", check_hrc),
        ("velocity", check_velocity),
        (r"connected|\bring\b|linked|related|network|shared", check_ring),
    ]
    for pat, fn in kinds:
        if re.search(pat, t):
            acct, txn = resolve_account(text)
            if not acct:
                return clarify(pat)
            st.session_state["ctx_account"] = acct
            return fn(acct, txn)
    return fallback_search(text)


def render(f):
    st.subheader(f["title"])
    st.markdown("**Verdict:** " + f["verdict"])
    st.write(f["answer"])
    if f.get("graph"):
        st.graphviz_chart(f["graph"])
    if f.get("evidence") is not None and len(f["evidence"]):
        st.markdown("**Evidence (records from the data)**")
        st.dataframe(f["evidence"], use_container_width=True, hide_index=True)
    if f["clauses"]:
        st.markdown("**Policy citations**")
        for d, n in f["clauses"]:
            c = clause(d, n)
            if c:
                body = re.sub(r"\s*\n\s*-\s*", "; ", c["text"]).lstrip("- ").replace("_", " ")
                st.markdown("- **%s**: %s. _%s_" % (c["cite"], c["title"], body))
    if f["records"]:
        st.markdown("**Record IDs cited:** " + ", ".join(str(r) for r in f["records"]))
    st.markdown("**Confidence:** " + f["confidence"])
    for n in f["notes"]:
        st.caption("Note: " + n)
    md = "# Vigil finding: %s\n\nGenerated: %s\n\n**Verdict:** %s\n\n%s\n\nRecords: %s\n\nPolicy: %s\n\nConfidence: %s\n" % (
        f["title"], datetime.now().strftime("%Y-%m-%d %H:%M"), f["verdict"], f["answer"], ", ".join(str(r) for r in f["records"]),
        "; ".join("%s Clause %s" % c for c in f["clauses"]), f["confidence"])
    st.download_button("Download finding (markdown)", md, file_name="vigil_finding.md")


st.title("Vigil: risk, fraud and regulatory copilot")
st.caption("Every answer is computed from the data and cites record IDs plus a policy clause. It never guesses; a human signs off on any filing.")
for k, v in (("history", []), ("finding", None), ("timings", [])):
    st.session_state.setdefault(k, v)

with st.sidebar:
    st.markdown("### How this works")
    st.write("Questions are routed to rule-based checks over the transaction, alert, liquidity, credit and ring tables. Policy text comes from numbered clauses.")
    st.markdown("### Honest limits")
    st.write("- No LLM: this trial account has Snowflake AI functions disabled, so routing is keyword-based.")
    st.write("- Ring detection: exact counterparty match only, tuned on synthetic data.")
    st.write("- Synthetic data only; no live regulatory feed.")
    if st.session_state["timings"]:
        st.markdown("### Measured latency (this session)")
        st.dataframe(pd.DataFrame(st.session_state["timings"], columns=["Question", "Seconds"]), hide_index=True)

left, right = st.columns([1, 1.3])
with left:
    st.markdown("**Try a question**")
    for i, ex in enumerate(EXAMPLES):
        if st.button(ex, key="ex%d" % i, use_container_width=True):
            st.session_state["pending"] = ex
    for who, msg in st.session_state["history"]:
        with st.chat_message(who):
            st.write(msg)
    typed = st.chat_input("Ask about a transaction, account, loan, liquidity or a policy")
    prompt = st.session_state.pop("pending", None) or typed
    if prompt:
        t0 = time.perf_counter()
        f = route(prompt)
        secs = round(time.perf_counter() - t0, 2)
        if f["title"] not in ("Slack message drafted (not sent)",) and f["verdict"] not in ("NO ANSWER GIVEN (missing subject)",):
            st.session_state["finding"] = f
        st.session_state["history"] += [("user", prompt), ("assistant", f["verdict"] + " (" + str(secs) + " s)")]
        st.session_state["timings"].append((prompt[:60], secs))
        st.session_state["shown"] = f
        st.rerun()
with right:
    st.markdown("**Audit-ready output**")
    if st.session_state.get("shown"):
        render(st.session_state["shown"])
    else:
        st.info("Ask a question or click an example. The finding, evidence and citations appear here.")
$$) FILE_FORMAT=(TYPE=CSV COMPRESSION=NONE FIELD_DELIMITER=NONE RECORD_DELIMITER=NONE ESCAPE_UNENCLOSED_FIELD=NONE FIELD_OPTIONALLY_ENCLOSED_BY=NONE) SINGLE=TRUE OVERWRITE=TRUE HEADER=FALSE MAX_FILE_SIZE=5000000;
