# NEW_CLIENT_SETUP.md

## How to Create a New Business Client

This guide walks you through adding a new business to Business Assistant Box.

---

## Quick Start

```bash
# 1. Create the client folder from template
bash clients/templates/create_client.sh my-business-name

# 2. Edit the generated files (see below)

# 3. Add your documents
cp ~/my-documents/* clients/my-business-name/DOCUMENTS/company-documents/

# 4. Set as active client
sed -i 's/^ACTIVE_CLIENT=.*/ACTIVE_CLIENT=my-business-name/' .env

# 5. Index everything
source /home/ubuntu/.business-assistant-box/venv/bin/activate
python3 vector-db/index_vault.py

# 6. Test in Open WebUI (http://localhost:3000)
```

---

## Files to Fill In (Priority Order)

### 1. CLIENT_PROFILE.md (Required)
The assistant's identity. Fill in:
- Company name, industry, location
- Products/services list
- Key personnel names and roles
- Communication tone
- Business hours

### 2. BUSINESS_KNOWLEDGE.md (Required)
The operational encyclopedia. Fill in:
- Company overview and USP
- Detailed products/services with pricing
- Business processes (sales, onboarding, support)
- Industry terminology
- Systems used (CRM, email, accounting)
- Internal procedures

### 3. FAQ.md (Recommended)
Common questions the assistant should answer:
- Customer-facing questions
- Internal staff questions
- Vendor questions

### 4. OWNER_PREFERENCES.md (Recommended)
How the owner wants things done:
- Communication style and tone
- Scheduling rules
- Decision authority levels
- Things to never do

### 5. DAILY_BRIEFING.md (Optional)
Customize the morning briefing format for this business.

---

## Adding Documents

Place files in the appropriate subfolder:

| Folder | What Goes Here |
|--------|---------------|
| company-documents/ | Policies, org charts, procedures |
| contracts/ | Service agreements, vendor contracts |
| financials/ | P&L reports, budgets, invoices |
| handbooks/ | Employee handbooks, training docs |
| uploads/ | Anything that doesn't fit elsewhere |
| websites/ | Saved web pages, scraped content |

Supported formats: .md, .txt, .pdf, .docx, .xlsx, .csv, .html, .eml

---

## Setting Up MEMORY Files

These files give the assistant daily context:

| File | Purpose | Update Frequency |
|------|---------|-----------------|
| TODAY.md | Current day's schedule and priorities | Daily (auto or manual) |
| OPEN_TASKS.md | Active tasks and follow-ups | As tasks change |
| CUSTOMER_RULES.md | Client-specific preferences | As learned |
| VENDOR_RULES.md | Supplier info and terms | As needed |
| LEARNED_PATTERNS.md | Behavioral patterns to remember | As discovered |

---

## Setting Up PROCEDURES

These tell the assistant HOW to do things:

| File | Purpose |
|------|---------|
| CALENDAR.md | Scheduling rules and preferences |
| CUSTOMER_INTAKE.md | New customer onboarding steps |
| DAILY_BRIEFING.md | Briefing format and content |
| DOCUMENTS.md | Document creation standards |
| EMAIL.md | Email handling and response rules |

---

## Verification Checklist

After setup, verify:

- [ ] `python3 vector-db/index_vault.py` completes without errors
- [ ] Chunk count > 0 (check with: `psql -U bab -d bab -c "SELECT count(*) FROM documents"`)
- [ ] Ask a question in Open WebUI that's answered by your documents
- [ ] Response includes source citation
- [ ] Response says "I don't have that information" for questions NOT in your docs

---

## Tips

- Start with CLIENT_PROFILE.md and BUSINESS_KNOWLEDGE.md — these give the most value
- You don't need to fill every field in every file — blank fields are ignored
- Add documents incrementally — you can re-index anytime
- The assistant gets better as you add more specific knowledge
- Use OWNER_PREFERENCES.md to control tone and behavior
