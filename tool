import streamlit as st
import anthropic
import json
import re
from datetime import datetime

# ── Page config ────────────────────────────────────────────────────────────────
st.set_page_config(
    page_title="Competitor Intelligence",
    page_icon="🔍",
    layout="wide",
)

# ── Styles ─────────────────────────────────────────────────────────────────────
st.markdown("""
<style>
    .block-container { padding-top: 2rem; }
    .metric-card {
        background: #1e293b;
        border-radius: 12px;
        padding: 1rem 1.25rem;
        border: 1px solid #334155;
        text-align: center;
    }
    .metric-card .label { font-size: 0.7rem; color: #94a3b8; letter-spacing: 1px; margin-bottom: 4px; }
    .metric-card .value { font-size: 1.6rem; font-weight: 800; }
    .weakness-card {
        background: #1e293b;
        border-radius: 10px;
        padding: 1rem 1.25rem;
        margin-bottom: 0.75rem;
    }
    .quote-card {
        background: #1e293b;
        border-radius: 10px;
        padding: 1rem 1.25rem;
        margin-bottom: 0.75rem;
        border-left: 4px solid #ef4444;
    }
    .tag {
        display: inline-block;
        padding: 2px 10px;
        border-radius: 20px;
        font-size: 0.75rem;
        font-weight: 600;
        margin-right: 4px;
    }
    .tag-high   { background: rgba(239,68,68,0.15);  color: #fca5a5; }
    .tag-medium { background: rgba(249,115,22,0.15); color: #fdba74; }
    .tag-low    { background: rgba(234,179,8,0.15);  color: #fde68a; }
    .tag-source { background: rgba(99,102,241,0.15); color: #a5b4fc; }
    .opportunity-item {
        background: #1e293b;
        border-radius: 10px;
        padding: 1rem 1.25rem;
        margin-bottom: 0.75rem;
        display: flex;
        gap: 12px;
        align-items: flex-start;
    }
</style>
""", unsafe_allow_html=True)

# ── Helpers ─────────────────────────────────────────────────────────────────────
def severity_emoji(s: str) -> str:
    return {"High": "🔴", "Medium": "🟠", "Low": "🟡"}.get(s, "⚪")

def sentiment_score_color(score: int) -> str:
    if score >= 7: return "#22c55e"
    if score >= 5: return "#f97316"
    return "#ef4444"

def build_system_prompt() -> str:
    return """You are a competitive intelligence analyst. Given a company website URL, search for real customer complaints, negative reviews, and weaknesses about that company.

Search for:
1. G2, Trustpilot, Glassdoor, Reddit, Twitter/X reviews mentioning complaints
2. Common themes in negative feedback
3. Support issues, billing problems, product limitations
4. Specific quotes from unhappy customers
5. Recent news about controversies or problems

Return ONLY a valid JSON object (no markdown, no backticks) with this exact structure:
{
  "companyName": "Company Name",
  "website": "https://...",
  "industry": "Industry",
  "summary": "2-3 sentence executive summary of key weaknesses",
  "overallSentiment": 6,
  "reviewSources": [
    {"source": "G2", "rating": "4.2/5", "reviewCount": "3000+", "mainComplaints": ["complaint1","complaint2"]}
  ],
  "weaknessCategories": [
    {
      "category": "Category name",
      "severity": "High",
      "percentage": "35%",
      "description": "detailed description",
      "examples": ["example 1", "example 2"]
    }
  ],
  "customerQuotes": [
    {"quote": "quote text", "source": "Reddit", "sentiment": "negative", "topic": "topic area"}
  ],
  "topThemes": [
    {"theme": "Theme name", "frequency": "High", "detail": "explanation"}
  ],
  "opportunityGaps": ["opportunity 1", "opportunity 2"],
  "recentNews": [
    {"headline": "headline text", "summary": "brief summary", "sentiment": "negative"}
  ],
  "lastUpdated": "Month Year"
}"""

def fetch_report(url: str, api_key: str) -> dict:
    client = anthropic.Anthropic(api_key=api_key)
    response = client.messages.create(
        model="claude-opus-4-5",
        max_tokens=4000,
        tools=[{"type": "web_search_20250305", "name": "web_search"}],
        system=build_system_prompt(),
        messages=[{
            "role": "user",
            "content": (
                f"Search the web thoroughly for customer complaints, negative reviews, and weaknesses "
                f"of the company at {url}. Look at Reddit, G2, Trustpilot, Twitter/X, Glassdoor, and "
                f"news articles. Find real weaknesses competitors could exploit. Return only JSON."
            )
        }]
    )

    text = "".join(b.text for b in response.content if b.type == "text")
    clean = re.sub(r"```json|```", "", text).strip()
    return json.loads(clean)

# ── Rendering helpers ───────────────────────────────────────────────────────────
def render_overview(r: dict):
    st.subheader("📊 Review Platform Ratings")
    for s in r.get("reviewSources", []):
        with st.container():
            c1, c2 = st.columns([3, 1])
            with c1:
                st.markdown(f"**{s['source']}** &nbsp; `{s.get('reviewCount','N/A')} reviews`", unsafe_allow_html=True)
                tags = "".join(f'<span class="tag tag-high">{c}</span>' for c in s.get("mainComplaints", []))
                st.markdown(tags, unsafe_allow_html=True)
            with c2:
                st.markdown(f"<div style='font-size:1.5rem;font-weight:800;color:#fbbf24;text-align:right'>{s['rating']}</div>", unsafe_allow_html=True)
            st.divider()

    if r.get("recentNews"):
        st.subheader("📰 Recent News")
        for n in r["recentNews"]:
            st.markdown(f"**{n['headline']}**")
            st.caption(n.get("summary", ""))
            st.divider()

def render_weaknesses(r: dict):
    st.subheader("⚠️ Weakness Categories")
    for w in r.get("weaknessCategories", []):
        sev = w.get("severity", "Low")
        with st.expander(f"{severity_emoji(sev)} **{w['category']}** — {w.get('percentage','')} of complaints"):
            st.markdown(f'<span class="tag tag-{sev.lower()}">{sev} Severity</span>', unsafe_allow_html=True)
            st.write("")
            st.write(w.get("description", ""))
            if w.get("examples"):
                st.markdown("**Examples:**")
                for ex in w["examples"]:
                    st.markdown(f"- {ex}")

def render_quotes(r: dict):
    st.subheader("💬 Customer Quotes")
    for q in r.get("customerQuotes", []):
        st.markdown(f"""
        <div class="quote-card">
            <div style="font-style:italic;color:#e2e8f0;margin-bottom:8px;">"{q['quote']}"</div>
            <span style="color:#64748b;font-size:0.8rem;">— {q['source']}</span>
            &nbsp;<span class="tag tag-source">{q['topic']}</span>
        </div>
        """, unsafe_allow_html=True)

def render_themes(r: dict):
    st.subheader("🔍 Recurring Complaint Themes")
    freq_order = {"High": 0, "Medium": 1, "Low": 2}
    themes = sorted(r.get("topThemes", []), key=lambda x: freq_order.get(x.get("frequency","Low"), 2))
    for t in themes:
        freq = t.get("frequency", "Low")
        tag_cls = f"tag-{freq.lower()}"
        st.markdown(f'<span class="tag {tag_cls}">{freq} Frequency</span> &nbsp;<strong>{t["theme"]}</strong>', unsafe_allow_html=True)
        st.caption(t.get("detail", ""))
        st.divider()

def render_opportunities(r: dict):
    st.subheader("🎯 Competitive Opportunity Gaps")
    st.info("These gaps represent areas where you can differentiate and win customers away from this competitor.", icon="💡")
    for i, opp in enumerate(r.get("opportunityGaps", []), 1):
        st.markdown(f"""
        <div class="opportunity-item">
            <div style="background:linear-gradient(135deg,#6366f1,#8b5cf6);border-radius:8px;
                        width:28px;height:28px;display:flex;align-items:center;justify-content:center;
                        font-weight:800;color:white;flex-shrink:0;">{i}</div>
            <div style="color:#e2e8f0;font-size:0.95rem;">{opp}</div>
        </div>
        """, unsafe_allow_html=True)

# ── Main UI ─────────────────────────────────────────────────────────────────────
st.title("🔍 Competitor Intelligence Reporter")
st.caption("Enter a competitor's website to generate a deep weakness analysis powered by live web search.")

with st.sidebar:
    st.header("⚙️ Settings")
    api_key = st.text_input("Anthropic API Key", type="password", placeholder="sk-ant-...")
    st.caption("Get your key at [console.anthropic.com](https://console.anthropic.com)")
    st.divider()
    st.markdown("**How it works**")
    st.markdown("""
1. Enter the competitor URL  
2. Claude searches G2, Reddit, Trustpilot, Twitter/X & more  
3. A structured weakness report is generated  
4. Use insights to sharpen your positioning
    """)

# Input
col1, col2 = st.columns([4, 1])
with col1:
    company_url = st.text_input(
        "Company Website",
        placeholder="https://deel.com",
        label_visibility="collapsed"
    )
with col2:
    run = st.button("🔍 Analyze", use_container_width=True, type="primary")

if run:
    if not api_key:
        st.error("Please enter your Anthropic API key in the sidebar.")
        st.stop()
    if not company_url:
        st.error("Please enter a company URL.")
        st.stop()

    with st.spinner("Searching reviews, social networks, and news... this may take 30–60 seconds."):
        try:
            report = fetch_report(company_url, api_key)
            st.session_state["report"] = report
        except json.JSONDecodeError:
            st.error("Could not parse the AI response as JSON. Please try again.")
            st.stop()
        except Exception as e:
            st.error(f"Error: {e}")
            st.stop()

if "report" in st.session_state:
    r = st.session_state["report"]

    # ── Hero banner ──────────────────────────────────────────────────────────
    st.divider()
    st.markdown(f"## {r.get('companyName', 'Company')} — Weakness Report")
    st.caption(f"Industry: {r.get('industry','')} &nbsp;|&nbsp; {r.get('website','')} &nbsp;|&nbsp; Updated: {r.get('lastUpdated', datetime.now().strftime('%B %Y'))}")
    st.write(r.get("summary", ""))

    # ── Metric cards ─────────────────────────────────────────────────────────
    score = r.get("overallSentiment", 5)
    score_color = sentiment_score_color(score)
    sources = r.get("reviewSources", [])

    cols = st.columns(1 + min(len(sources), 3))
    with cols[0]:
        st.markdown(f"""
        <div class="metric-card">
            <div class="label">CUSTOMER SENTIMENT</div>
            <div class="value" style="color:{score_color}">{score}/10</div>
        </div>""", unsafe_allow_html=True)
    for i, s in enumerate(sources[:3]):
        with cols[i + 1]:
            st.markdown(f"""
            <div class="metric-card">
                <div class="label">{s['source'].upper()}</div>
                <div class="value" style="color:#a5b4fc">{s['rating']}</div>
                <div style="font-size:0.7rem;color:#64748b">{s.get('reviewCount','')}</div>
            </div>""", unsafe_allow_html=True)

    st.write("")

    # ── Tabs ─────────────────────────────────────────────────────────────────
    tabs = st.tabs(["📊 Overview", "⚠️ Weaknesses", "💬 Quotes", "🔍 Themes", "🎯 Opportunities"])
    with tabs[0]: render_overview(r)
    with tabs[1]: render_weaknesses(r)
    with tabs[2]: render_quotes(r)
    with tabs[3]: render_themes(r)
    with tabs[4]: render_opportunities(r)

    # ── Download ──────────────────────────────────────────────────────────────
    st.divider()
    st.download_button(
        label="⬇️ Download Raw JSON",
        data=json.dumps(r, indent=2),
        file_name=f"{r.get('companyName','report').lower().replace(' ','_')}_intelligence.json",
        mime="application/json"
    )
