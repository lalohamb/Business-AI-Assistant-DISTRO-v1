# CREDIT_REPAIR_LEAD_GEN.md

## Topic: Using Business Assistant Box as a Task Agent for Credit Repair Lead Generation

---

## Question 1

**Can the Business Assistant Box be used to do tasks — like finding leads over the internet for people who need credit repair?**

### Answer

Yes. The system is already built to do tasks, not just answer questions. The task execution layer is **n8n** (running at `http://localhost:5678`). It connects the AI to real-world actions.

### Existing Task-Capable Workflows

- Email Triage — reads, classifies, drafts responses
- Lead Follow-Up (`selectable/lead-followup.json`) — follows up on existing leads
- Customer Intake — processes new inquiries
- Daily Briefing — pulls data and compiles reports
- Document Drafting — generates proposals and letters

### Options for Finding Credit Repair Leads

**Option 1 — Scrape Public Sources (n8n workflow)**

Build an n8n workflow that:
1. Hits public sources where people ask about credit repair (Reddit, Facebook Groups via API, Craigslist, local forums)
2. Filters posts matching keywords: "bad credit", "credit score", "need a loan but bad credit", "credit repair help"
3. Extracts contact info or post details
4. Logs to a Google Sheet as a lead list
5. Routes to the existing Lead Follow-Up workflow

n8n has built-in nodes for: HTTP Request, HTML Extract, Google Sheets, and AI classification.

**Option 2 — Integrate a Lead Data API**

Connect n8n to a paid lead source:
- Bark.com API
- Thumbtack (if API access available)
- DataFiniti or similar B2C data providers
- Google Maps API

**Option 3 — Monitor Inbound Channels**

Set up the assistant to watch:
- Your own contact form (webhook trigger)
- A dedicated email inbox for inquiries
- A landing page form → Google Sheet → n8n intake

### To Configure for a Credit Repair Client

1. Create a new client folder: `clients/credit-repair-co/`
2. Fill in `BUSINESS_PROFILE.md` with credit repair services and target customer profile
3. Build a new n8n workflow: `n8n/workflows/selectable/credit-repair-lead-finder.json`
4. Add lead qualification logic to the AI prompt — e.g., "Does this person need credit repair? Score 1-10."
5. Output qualified leads to Google Sheets or trigger an email draft

The `PROCEDURES/` folder (per client) is where you document lead qualification criteria so the AI knows what a good lead looks like.

### What's Already There to Leverage

- `selectable/lead-followup.json` — handles following up once leads are found
- `selectable/customer-intake.json` — processes new inquiries coming in
- The RAG system — can be loaded with credit repair knowledge to qualify leads intelligently

---

## Question 2

**What if I use OpenClaw as the agent with clients/credit-repair-co/? How would that perform?**

### Answer

OpenClaw + credit-repair-co is a strong fit. OpenClaw's key advantage over Ollama for this use case is built-in web search + local execution.

### Capability Comparison

| Task | Ollama | OpenClaw |
|------|--------|----------|
| Search web for leads | ❌ No internet access | ✅ Built-in web search |
| Qualify leads with AI | ✅ | ✅ |
| Write to lead sheet | ❌ (needs n8n) | ✅ Direct file access |
| Trigger n8n follow-up | ❌ (needs n8n) | ✅ Can call webhooks |
| Run scripts autonomously | ❌ | ✅ |

OpenClaw collapses what would take 3-4 n8n nodes into a single agent action.

### How the Flow Would Look

```
OpenClaw agent (running as daemon)
    ↓
Web search: "need credit repair [city]" Reddit/Craigslist/forums
    ↓
AI qualifies: Does this person need credit repair? Score 1-10
    ↓
Writes qualified leads → clients/credit-repair-co/OUTPUTS/leads.csv
    ↓
Triggers n8n lead-followup.json webhook
    ↓
Draft outreach email → Approval Router → Human approves → Send
```

The `openclaw/client` symlink points to `clients/credit-repair-co/`, giving the agent full context about the business — services, pricing, target customer profile — so it qualifies leads against real business criteria.

### Setup Steps

1. Create the client folder:
```bash
cp -r clients/templates/ clients/credit-repair-co/
```

2. Fill in `BUSINESS_PROFILE.md` with credit repair services and target customer

3. Create `PROCEDURES/lead-generation.md` with lead qualification criteria

4. Switch to OpenClaw and point the symlink:
```bash
sed -i 's/AI_PROVIDER=ollama/AI_PROVIDER=openclaw_api/' .env
./admin/switch_client.sh credit-repair-co
```

5. Set `OPENCLAW_API_KEY` in `.env`

### Caveats

- OpenClaw is currently marked "deferred" — no API key is configured yet
- Web scraping has legal/ToS considerations — stick to public posts where contact is intended
- Credit repair is regulated under CROA (Credit Repair Organizations Act) — POLICIES.md should reflect that the AI cannot promise credit score outcomes
- The `openclaw/client@` symlink already exists — architecture is ready, just needs the API key and client folder

---

## What Was Built

The following files were created as a result of this conversation:

### `clients/credit-repair-co/BUSINESS_PROFILE.md`
- Company identity and services
- CROA compliance guardrails
- Common customer Q&A
- Disallowed actions for the AI

### `clients/credit-repair-co/PROCEDURES/lead-generation.md`
- Definition of a qualified lead
- Lead scoring rubric (1-10)
- Approved public search sources
- Output format: `OUTPUTS/leads.csv`
- Outreach tone guidelines
- Compliance reminders

### Folder Structure Created
```
clients/credit-repair-co/
├── DOCUMENTS/
├── MEMORY/
├── OUTPUTS/
├── PROCEDURES/
│   └── lead-generation.md
└── BUSINESS_PROFILE.md
```

---

## Next Steps

- [ ] Obtain OpenClaw API key and set `OPENCLAW_API_KEY` in `.env`
- [ ] Fill in placeholder fields in `BUSINESS_PROFILE.md` (company name, owner, pricing, location)
- [ ] Run `./admin/switch_client.sh credit-repair-co` to activate the client
- [ ] Build `n8n/workflows/selectable/credit-repair-lead-finder.json` workflow
- [ ] Test lead qualification with a sample search before going live

---

## Question 3

**How can OpenClaw qualify leads based on debt thresholds, and how does it deliver those leads?**

### Qualification Criteria (updated in PROCEDURES/lead-generation.md)

A lead qualifies if they meet ANY ONE of the following:

| Criteria | Signal to Look For |
|----------|--------------------|
| $10K+ credit card debt | Mentions high card balances, maxed cards, multiple cards totaling $10K+ |
| $10K+ personal unsecured debt | Personal loans, medical debt, payday loans totaling $10K+ |
| Combined debt = $10K+ | Credit card + unsecured combined hits $10K (neither alone needs to) |
| Already in debt consolidation | Mentions DMP, consolidation loan, or working with a consolidation company |
| Paying $250+/month toward debt | Mentions monthly debt payments of $250 or more |

### Updated Lead Scoring

| Signal | Points |
|--------|--------|
| $10K+ credit card debt confirmed | +3 |
| $10K+ personal unsecured debt confirmed | +3 |
| Combined debt hits $10K threshold | +2 |
| Already in a debt consolidation program | +3 |
| Paying $250+/month toward debt | +2 |
| Mentions wanting to get out of debt faster | +1 |
| Denied for loan, apartment, car | +1 |
| Provides location | +1 |
| Mentions urgency | +2 |

- Score 6+ = qualified, log as `new`
- Score 8+ = high priority, log as `new-hot`, trigger n8n immediately

### How OpenClaw Delivers Leads to the Owner

1. Writes all qualified leads to `OUTPUTS/leads.csv` with expanded columns including debt type, amount estimate, monthly payment estimate, and consolidation status
2. Generates a session summary report at `OUTPUTS/lead-report-[date].md` with total leads, hot leads, breakdown by debt type, and top 3 leads in full detail
3. Triggers the n8n `lead-followup.json` webhook for `new-hot` leads immediately
4. Batches standard `new` leads and triggers the webhook once per session
5. All outreach drafts land in the n8n approval queue — no contact is made without human approval

---

Date Documented: 2026-07-19
