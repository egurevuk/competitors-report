import streamlit as st
import json
from pathlib import Path

st.set_page_config(page_title="Competitor Intelligence", page_icon="🔍", layout="wide")

st.markdown("""
<style>
    .block-container { padding-top: 2rem; }
    .quote-card { background:#f8fafc; border-left:4px solid #ef4444; border-radius:6px; padding:12px 16px; margin-bottom:10px; }
    .tag { display:inline-block; padding:2px 10px; border-radius:20px; font-size:0.75rem; font-weight:600; margin-right:4px; }
    .tag-high   { background:#fee2e2; color:#dc2626; }
    .tag-medium { background:#ffedd5; color:#ea580c; }
    .tag-low    { background:#fef9c3; color:#ca8a04; }
</style>
""", unsafe_allow_html=True)

@st.cache_data
def load_data():
    path = Path(__file__).parent / "data.json"
    with open(path) as f:
        return json.load(f)

data = load_data()
companies = list(data.keys())

st.title("🔍 Competitor Intelligence Report")
st.caption("EOR & Global Payroll — Weakness Analysis")

# ── Summary metrics ────────────────────────────────────────────────────────────
cols = st.columns(len(companies))
for col, name in zip(cols, companies):
    r = data[name]
    score = r.get("overallSentiment", 0)
    color = "#22c55e" if score >= 7 else "#f97316" if score >= 5 else "#ef4444"
    col.markdown(f"""
    <div style="background:#1e293b;border-radius:10px;padding:14px;text-align:center;border:1px solid #334155">
        <div style="font-size:11px;color:#94a3b8;letter-spacing:1px">{name.upper()}</div>
        <div style="font-size:26px;font-weight:800;color:{color}">{score}/10</div>
        <div style="font-size:11px;color:#64748b">sentiment</div>
    </div>""", unsafe_allow_html=True)

st.divider()

# ── Company tabs ───────────────────────────────────────────────────────────────
tabs = st.tabs(companies + ["📊 Comparison"])

for i, name in enumerate(companies):
    r = data[name]
    with tabs[i]:
        st.subheader(r.get("companyName", name))
        st.caption(f"{r.get('industry','')} · {r.get('website','')}")
        st.write(r.get("summary", ""))

        inner = st.tabs(["Overview", "Weaknesses", "Quotes", "Opportunities"])

        with inner[0]:
            for s in r.get("reviewSources", []):
                c1, c2 = st.columns([4, 1])
                with c1:
                    st.markdown(f"**{s['source']}** &nbsp; `{s.get('reviewCount','')}`", unsafe_allow_html=True)
                    tags = " ".join(f'<span class="tag tag-high">{c}</span>' for c in s.get("mainComplaints", []))
                    st.markdown(tags, unsafe_allow_html=True)
                with c2:
                    st.markdown(f"<div style='font-size:1.4rem;font-weight:800;color:#f59e0b;text-align:right'>{s['rating']}</div>", unsafe_allow_html=True)
                st.divider()
            for t in r.get("topThemes", []):
                freq = t.get("frequency", "Low")
                color = "#ef4444" if freq == "High" else "#f97316" if freq == "Medium" else "#eab308"
                st.markdown(f"<span style='color:{color};font-weight:700;font-size:11px'>{freq.upper()}</span> &nbsp; **{t['theme']}**", unsafe_allow_html=True)
                st.caption(t.get("detail", ""))
                st.divider()

        with inner[1]:
            for w in r.get("weaknessCategories", []):
                sev = w.get("severity", "Low")
                tag_cls = f"tag-{sev.lower()}"
                with st.expander(f"**{w['category']}** — {w.get('percentage','')}"):
                    st.markdown(f'<span class="tag {tag_cls}">{sev} Severity</span>', unsafe_allow_html=True)
                    st.write(w.get("description", ""))
                    for ex in w.get("examples", []):
                        st.markdown(f"- {ex}")

        with inner[2]:
            for q in r.get("customerQuotes", []):
                st.markdown(f"""
                <div class="quote-card">
                    <div style="font-style:italic;color:#1e293b;margin-bottom:6px">"{q['quote']}"</div>
                    <span style="color:#64748b;font-size:0.8rem">— {q['source']}</span>
                    &nbsp;<span class="tag" style="background:#ede9fe;color:#7c3aed">{q['topic']}</span>
                </div>""", unsafe_allow_html=True)

        with inner[3]:
            st.info("Areas where you can win customers from this competitor.", icon="💡")
            for j, o in enumerate(r.get("opportunityGaps", []), 1):
                st.markdown(f"**{j}.** {o}")

# ── Comparison tab ─────────────────────────────────────────────────────────────
with tabs[-1]:
    st.subheader("Side-by-side Comparison")

    rows = []
    all_cats = list(dict.fromkeys(
        cat for name in companies
        for cat in [w["category"] for w in data[name].get("weaknessCategories", [])]
    ))

    import pandas as pd

    # Sentiment table
    sentiment_df = pd.DataFrame([{
        "Company":   name,
        "Sentiment": data[name].get("overallSentiment", 0),
        "High Issues": sum(1 for w in data[name].get("weaknessCategories",[]) if w.get("severity")=="High"),
        "Total Issues": len(data[name].get("weaknessCategories",[])),
        "Top Rating": (data[name].get("reviewSources",[{}])[0] or {}).get("rating","—"),
        "Opportunities": len(data[name].get("opportunityGaps",[])),
    } for name in companies])
    st.dataframe(sentiment_df, use_container_width=True, hide_index=True)

    st.divider()
    st.markdown("**Weakness Category Matrix**")

    matrix = []
    for cat in all_cats:
        row = {"Category": cat}
        for name in companies:
            w = next((x for x in data[name].get("weaknessCategories",[]) if x["category"]==cat), None)
            row[name] = (w["severity"] + " " + w.get("percentage","")) if w else "—"
        matrix.append(row)

    st.dataframe(pd.DataFrame(matrix), use_container_width=True, hide_index=True)

st.divider()
st.caption("Generated by Competitor Intelligence Reporter · Powered by Claude")
