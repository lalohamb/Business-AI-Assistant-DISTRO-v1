# POST_INSTALL_CLIENT_SETUP.md

# Business Assistant Box — Client Onboarding

## Purpose

Automate new client workspace creation after the base system is installed.

The system cannot answer company-specific questions until a client business brain is created, populated, and indexed.

---

## Script

```bash
./admin/post_install_client_setup.sh
```

Supports: `DRY_RUN=true` and `SAFE_MODE=true`

Can be safely rerun. Never overwrites existing client files.

---

## Phases

### Phase 1 — Select Clients

- Lists existing clients
- Prompts for comma-separated client names to onboard
- Example: `acme-roofing,law-office,insurance-agency`

### Phase 2 — Create Client Directories

Creates from templates:

```
clients/<client-name>/
├── CLIENT_PROFILE.md
├── OWNER_PREFERENCES.md
├── BUSINESS_KNOWLEDGE.md
├── FAQ.md
├── PROCEDURES/
│   ├── EMAIL.md
│   ├── CALENDAR.md
│   ├── DAILY_BRIEFING.md
│   └── DOCUMENTS.md
├── MEMORY/
│   ├── CUSTOMER_RULES.md
│   ├── VENDOR_RULES.md
│   ├── LEARNED_PATTERNS.md
│   ├── OPEN_TASKS.md
│   └── TODAY.md
└── OUTPUTS/
    ├── drafts/
    ├── reports/
    └── summaries/
```

Behavior:
- Copies template files only if target doesn't already exist
- SAFE_MODE skips clients that already have files
- Never overwrites existing client data

### Phase 3 — Create Client Vault Directories

Creates per-client vault storage:

```
vault/<client-name>/
├── documents/
├── contracts/
├── financials/
└── uploads/
```

### Phase 4 — Update Active Client

- If single client onboarded: prompts to set `ACTIVE_CLIENT` in `.env`
- Also updates `OBSIDIAN_VAULT_PATH` to match
- If multiple clients: displays instructions for manual selection

### Phase 5 — Validate Client Files

Checks each onboarded client has:
- All 4 root files (CLIENT_PROFILE.md, OWNER_PREFERENCES.md, BUSINESS_KNOWLEDGE.md, FAQ.md)
- All 4 procedure files
- All 5 memory files
- All 3 output directories

Reports missing files as warnings.

### Phase 6 — Index Documents (RAG Ingest)

Prerequisites checked:
- PostgreSQL running
- RAG venv exists
- index_vault.py exists
- Ollama reachable (if EMBEDDING_PROVIDER=ollama)

For each client:
- Prompts before indexing
- Runs `ACTIVE_CLIENT=<client> python3 vector-db/index_vault.py`
- Indexes: system/, clients/<client>/, vault/

### Phase 7 — Verify RAG Ingest

Queries PostgreSQL for each client:
```sql
SELECT COUNT(*) FROM rag_chunks WHERE client_name = '<client>';
```

Reports chunk count per client.

---

## After Running the Script

### Complete These Files Manually

Each client needs real business content (not just placeholders):

**CLIENT_PROFILE.md:**
- Company Name
- Industry
- Website
- Primary Location
- Business Hours
- Owner / Main Contact
- Services Offered
- Customer Type
- Communication Style

**BUSINESS_KNOWLEDGE.md:**
- Company overview
- Products / Services
- Sales process
- Customer support process
- Common policies
- Frequently referenced business facts

**FAQ.md (minimum 10 entries):**
- What does the company do?
- What services are offered?
- What areas are served?
- What are business hours?
- How do customers request service?
- What is the normal response time?
- Who handles billing?
- Who approves quotes?
- Who handles complaints?
- What is the refund policy?

**OWNER_PREFERENCES.md:**
- Communication tone
- Approval requirements
- Working hours
- Delegation rules
- Priority contacts

**PROCEDURES/*.md:**
- How email is handled
- How calendar is managed
- What goes in daily briefings
- How documents are created/formatted

---

## Re-index After Editing

After populating client files, re-run indexing:

```bash
cd /home/lalo/Documents/.nativeblackbox/opt/business-assistant-box
source vector-db/venv/bin/activate
ACTIVE_CLIENT=<client-name> python3 vector-db/index_vault.py
```

Or re-run the script — Phase 6 will prompt for each client.

---

## Validation Questions

After indexing, test with:

1. What company are you assisting?
2. What does this company do?
3. What services does this company offer?
4. What are today's priorities?
5. What open tasks require attention?

If the assistant cannot answer, update the business files and re-index.

---

## Client Ready Criteria

A client is ready for production when:

- [x] CLIENT_PROFILE.md has real content
- [x] BUSINESS_KNOWLEDGE.md has real content
- [x] FAQ.md has at least 10 entries
- [x] OWNER_PREFERENCES.md is configured
- [x] PROCEDURES are customized
- [x] TODAY.md has current context
- [x] OPEN_TASKS.md has active tasks
- [x] RAG index has been updated (chunks > 0)
- [x] Validation questions pass
