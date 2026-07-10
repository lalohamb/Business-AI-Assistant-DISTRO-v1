# ARCHITECTURE.md

# Business Assistant Box

## System Architecture

---

## Overview

Business Assistant Box is a private, on-premise AI office assistant for small and medium-sized businesses. It combines local AI, workflow automation, and a knowledge vault to handle email, calendar, documents, customer intake, and daily briefings — all running on a single machine with no cloud dependency for core AI.

---

## Hardware (Current Build)

| Component | Spec |
|-----------|------|
| CPU | Intel Xeon E5-2630 v2 (24 threads) |
| RAM | 128 GB |
| Storage | 1 TB SSD (~810 GB free) |
| GPU 1 (Inference) | NVIDIA RTX 2060 SUPER (8 GB VRAM) |
| GPU 2 (Display) | NVIDIA GTX 970 (4 GB VRAM, display only) |
| OS | Ubuntu 24.04 LTS |

GPU pinning: Ollama is locked to the RTX 2060 SUPER via `CUDA_VISIBLE_DEVICES` UUID in `/etc/systemd/system/ollama.service.d/override.conf`.

---

## Architecture Layers

### Layer 1 — Infrastructure

| Component | Implementation |
|-----------|----------------|
| Operating System | Ubuntu 24.04 LTS |
| Containerization | Docker |
| Database | PostgreSQL (pgvector/pgvector:pg16) |
| Vector Extension | pgvector |
| Configuration | .env (centralized) |
| Licensing | .license (tier + expiration) |
| File System | Structured workspace at BASE_PATH |

### Layer 2 — AI / Intelligence

| Component | Implementation |
|-----------|----------------|
| Primary LLM | Ollama — qwen3:14b (9.3 GB) |
| Secondary LLM | Ollama — llama3.2 (2 GB) |
| Code Model | Ollama — qwen2.5-coder:7b (4.7 GB) |
| Embeddings | nomic-embed-text (274 MB) via Ollama |
| RAG Engine | index_vault.py → pgvector → query_vault.py |
| Chunking | 512 chars, 64 overlap |
| Agent (deferred) | OpenClaw (daemon, web search, local execution) |

### Layer 3 — Data / Knowledge

| Component | Implementation |
|-----------|----------------|
| Client Knowledge | clients/{client}/ (markdown files) |
| Shared Vault | vault/ (documents, contracts, financials) |
| System Intelligence | system/ (AGENTS, POLICIES, IDENTITY, PROMPTS, TOOLS) |
| Vector Storage | PostgreSQL rag_documents + rag_chunks tables |
| Human Editing | Obsidian (pointed at current-client symlink) |

### Layer 4 — Automation

| Component | Implementation |
|-----------|----------------|
| Workflow Engine | n8n (16 workflows: 6 standard + 10 selectable) |
| External AI | Google Gemini 2.0 Flash (via n8n for classification) |
| Credentials | Google OAuth2 (Gmail, Calendar, Sheets, Docs, Drive) |
| Scheduling | n8n internal scheduler |
| RAG Indexing | index_vault.py (on-demand or scripted) |

### Layer 5 — Interface

| Component | Implementation |
|-----------|----------------|
| Chat Interface | Open WebUI (port 3000) |
| Workflow UI | n8n editor (port 5678) |
| Knowledge Editor | Obsidian (local app, current-client symlink) |
| Admin Tools | Shell scripts in admin/ |

### Layer 6 — Business Logic (Markdown-Driven)

| Component | Location |
|-----------|----------|
| Agent Behavior | system/AGENTS.md |
| Policies | system/POLICIES.md |
| Identity | system/IDENTITY.md |
| Prompts | system/PROMPTS.md |
| Tools | system/TOOLS.md |
| System Memory | system/SYSTEM_MEMORY.md |
| Client Profile | clients/{client}/CLIENT_PROFILE.md |
| Business Knowledge | clients/{client}/BUSINESS_KNOWLEDGE.md |
| Owner Preferences | clients/{client}/OWNER_PREFERENCES.md |
| FAQ | clients/{client}/FAQ.md |
| Daily Briefing | clients/{client}/DAILY_BRIEFING.md |
| Procedures | clients/{client}/PROCEDURES/*.md |
| Memory | clients/{client}/MEMORY/*.md |
| Outputs | clients/{client}/OUTPUTS/ |

This layer is not code — it's markdown configuration that governs AI behavior across all other layers.

---

## Data Flow

```
User
  ↓
Open WebUI Chat (port 3000)
  ↓
RAG Filter Function (business_rag_filter.py)
  ↓
Embed question → Ollama nomic-embed-text
  ↓
Query pgvector for relevant chunks (filtered by client_name)
  ↓
Inject context into system prompt
  ↓
LLM generates answer (Ollama qwen3:14b)
  ↓
Response with business knowledge
  ↓
User
```

### Workflow Automation Flow

```
Trigger (schedule / webhook / email poll)
  ↓
n8n workflow executes
  ↓
Gemini 2.0 Flash classifies/generates (via Google API)
  ↓
Route based on classification (urgent → approval, routine → auto-handle)
  ↓
Action (send email, create event, draft document, notify owner)
```

### Knowledge Editing Flow

```
User edits in Obsidian (current-client → clients/{ACTIVE_CLIENT}/)
  ↓
Files saved to disk
  ↓
Run: ./venv/bin/python index_vault.py (from vector-db/)
  ↓
Chunks embedded and stored in pgvector
  ↓
Next chat query retrieves updated context
```

---

## Directory Structure

```
business-assistant-box/
├── .env                        # Centralized configuration
├── .license                    # Tier + expiration (multi, 2027-06-02)
├── current-client@ → clients/law-office/   # Symlink to active client
├── admin/                      # Scripts + documentation
│   ├── quickstart.sh           # Full setup orchestrator (7 phases)
│   ├── install.sh              # Core installation
│   ├── configure_n8n.sh        # Workflow import + activation
│   ├── configure_credentials.sh # Google OAuth2 credential creation
│   ├── switch_client.sh        # Client switching (.env + symlinks)
│   ├── test_client.sh          # Read-only client validation (6 tests)
│   ├── license_check.sh        # Tier + expiration enforcement
│   ├── pre_check.sh            # Pre-install system validation
│   └── *.md                    # Documentation files
├── system/                     # AI behavior rules
│   ├── AGENTS.md
│   ├── POLICIES.md
│   ├── IDENTITY.md
│   ├── PROMPTS.md
│   ├── TOOLS.md
│   ├── SYSTEM_MEMORY.md
│   └── HEARTBEAT.md
├── clients/                    # Per-client business brains
│   ├── templates/              # Base template for new clients
│   ├── demo-company/           # Demo (124 RAG chunks)
│   ├── acme-roofing/           # Acme Roofing & Exteriors (82 chunks)
│   ├── law-office/             # Carter & Associates, PLLC (84 chunks)
│   └── insurance-agency/       # Pinnacle Insurance Group (not yet indexed)
├── vault/                      # Shared knowledge documents
│   ├── company-documents/
│   ├── financials/
│   ├── contracts/
│   ├── handbooks/
│   ├── uploads/
│   └── websites/
├── vector-db/                  # RAG indexing
│   ├── venv/                   # Python venv (psycopg2, ollama, etc.)
│   ├── index_vault.py          # Indexes system/ + clients/ + vault/
│   ├── query_vault.py          # CLI query tool
│   └── schema.sql              # pgvector table definitions
├── n8n/                        # Workflow engine data
│   ├── workflows/
│   │   ├── standard/           # 6 core workflows (always active)
│   │   ├── selectable/         # 10 optional workflows
│   │   └── manifest.json       # Workflow registry (credentials, scopes)
│   └── database.sqlite         # n8n internal state
├── openclaw/                   # OpenClaw workspace (deferred)
│   └── client@ → ../clients/{ACTIVE_CLIENT}/
├── dashboard/                  # Open WebUI data
│   ├── functions/              # RAG filter functions
│   └── webui.db
├── postgres/                   # PostgreSQL data volume
│   └── data/
├── docker/                     # Docker configs
├── logs/                       # Application logs
└── backups/                    # Automated backups
```

---

## Multi-Client Architecture

- Each client has an isolated workspace under `clients/`
- `ACTIVE_CLIENT` in .env determines which client the system serves
- `current-client` is a symlink managed by `switch_client.sh`
- RAG indexes per-client (filterable by `client_name` column in pgvector)
- Switching: `./admin/switch_client.sh <client-name>` → updates .env, symlinks, re-index
- License tier controls single vs multi-client access
- Templates provide consistent starting structure for new clients

### Client File Structure

```
clients/{name}/
├── CLIENT_PROFILE.md       # Company identity, contacts, hours
├── BUSINESS_KNOWLEDGE.md   # Services, pricing, processes
├── OWNER_PREFERENCES.md    # Communication style, priorities
├── FAQ.md                  # Common questions + answers
├── DAILY_BRIEFING.md       # Today's priorities
├── MEMORY/
│   ├── CUSTOMER_RULES.md   # Per-customer handling rules
│   ├── VENDOR_RULES.md     # Vendor relationship notes
│   ├── LEARNED_PATTERNS.md # AI-observed patterns
│   ├── OPEN_TASKS.md       # Pending items
│   └── TODAY.md            # Today's context
├── PROCEDURES/
│   ├── EMAIL.md            # Email handling rules
│   ├── CALENDAR.md         # Scheduling rules
│   ├── CUSTOMER_INTAKE.md  # New client process
│   ├── DOCUMENTS.md        # Document handling
│   └── DAILY_BRIEFING.md   # Briefing generation rules
├── OUTPUTS/
│   ├── drafts/
│   ├── reports/
│   └── summaries/
└── DOCUMENTS/
```

---

## Workflows (n8n)

### Standard (always active)

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| email-triage | Poll Gmail every 5 min | Classify + route incoming email |
| calendar-review | Daily schedule | Morning calendar summary |
| daily-briefing | Daily schedule | Generate owner briefing |
| approval-router | Webhook | Route items needing approval |
| ask-assistant | Webhook | Ad-hoc AI queries from buttons |
| rag-query | Webhook | RAG-powered knowledge lookup |

### Selectable (per business type)

appointment-booking, customer-intake, document-drafting, expense-tracker, invoice-generator, lead-followup, report-generator, review-requester, social-post-scheduler, voicemail-transcription

---

## Security Boundaries

| Boundary | Rule |
|----------|------|
| admin/ | Never indexed, never exposed to AI |
| logs/ | Never indexed |
| backups/ | Never indexed |
| .env | Never indexed, contains credentials |
| .license | Never indexed |
| *.key, *.pem | Never indexed |
| Client data | Isolated per-client in RAG queries |
| Email sending | Requires explicit approval |
| OpenClaw | Permissions defined at install time |

---

## Service Map

| Service | Port | Runtime | Image/Binary | Purpose |
|---------|------|---------|--------------|---------|
| PostgreSQL | 5432 | Docker | pgvector/pgvector:pg16 | Database + vector storage |
| Ollama | 11434 | systemd (native) | ollama | Local LLM + embeddings |
| Open WebUI | 3000 | Docker | ghcr.io/open-webui/open-webui:main | Chat interface |
| n8n | 5678 | Docker | n8nio/n8n | Workflow automation |
| OpenClaw | — | (deferred) | — | AI agent with web search + local exec |

---

## Admin Scripts

| Script | Purpose |
|--------|---------|
| quickstart.sh | Full setup orchestrator (7 phases, supports DRY_RUN) |
| install.sh | Core system installation |
| pre_check.sh | Pre-install system validation |
| configure_n8n.sh | Import + activate workflows, map webhooks |
| configure_credentials.sh | Create Google OAuth2 credentials in n8n |
| switch_client.sh | Switch active client (.env + symlinks) |
| test_client.sh | Validate client data (6 read-only tests) |
| license_check.sh | Enforce tier limits + expiration |
| post_install_client_setup.sh | Post-install client data setup |
| post_install_verify.sh | Verify installation health |
| validate_env.sh | Validate .env completeness |
| uninstall.sh | Full system removal |

---

## Deployment Model

**On-Premise Appliance** — Single box, all services local, no cloud dependency for core AI. Google APIs used only for n8n workflow automation (email, calendar). LLM inference is 100% local via Ollama.

---

## Configuration

All scripts and services read from `.env`. Key variables:

| Variable | Current Value | Purpose |
|----------|---------------|---------|
| AI_PROVIDER | ollama | LLM provider |
| OLLAMA_MODEL | qwen3:14b | Primary inference model |
| EMBEDDING_MODEL | nomic-embed-text | Embedding model |
| ACTIVE_CLIENT | law-office | Currently active client |
| RAG_ENABLED | true | pgvector RAG active |
| WORKFLOW_ENGINE | n8n | Automation engine |
| OBSIDIAN_ENABLED | true | Knowledge editing enabled |
| DASHBOARD_ENABLED | true | Open WebUI active |
| APPROVAL_REQUIRED_FOR_EMAIL_SEND | true | Safety gate for outbound email |

### Safety Controls (set per-script, not in .env)

- `DRY_RUN=true` — Simulate without changes
- `SAFE_MODE=true` — Backup before overwrite, never destroy
