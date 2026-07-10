# ARCHITECTURE.md

# Business Assistant Box

## System Architecture

---

## Overview

Business Assistant Box is a private, on-premise AI office assistant for small and medium-sized businesses. It combines local AI, workflow automation, and a knowledge vault to handle email, calendar, documents, customer intake, and daily briefings.

---

## Architecture Layers

### Layer 1 — Infrastructure

| Component | Implementation |
|-----------|---------------|
| Operating System | Ubuntu 24.04 LTS |
| Containerization | Docker |
| Database | PostgreSQL (pgvector/pgvector:pg16) |
| Vector Extension | pgvector |
| Configuration | .env (centralized) |
| File System | Structured workspace at BASE_PATH |

### Layer 2 — AI / Intelligence

| Component | Implementation |
|-----------|---------------|
| Primary LLM | OpenClaw API (cloud) |
| Local LLM (optional) | Ollama (qwen3:14b, gemma3:12b) |
| Embeddings | nomic-embed-text via Ollama or OpenClaw API |
| RAG Engine | index_vault.py → pgvector → query_vault.py |
| Agent | OpenClaw |

### Layer 3 — Data / Knowledge

| Component | Implementation |
|-----------|---------------|
| Business Knowledge | clients/{client}/ (markdown files) |
| Knowledge Vault | vault/ (documents, contracts, financials) |
| System Intelligence | system/ (AGENTS, POLICIES, IDENTITY, PROMPTS) |
| Vector Storage | PostgreSQL rag_documents + rag_chunks tables |
| Human Editing | Obsidian (Docker, browser-based at port 3010) |

### Layer 4 — Automation

| Component | Implementation |
|-----------|---------------|
| Workflow Engine | n8n |
| Webhooks | 6 business workflow endpoints |
| Scheduling | n8n / cron |
| RAG Indexing | index_vault.py (nightly or on-demand) |

### Layer 5 — Interface

| Component | Implementation |
|-----------|---------------|
| Chat Interface | Open WebUI |
| Business Dashboard | Custom static HTML (dashboard/custom/index.html) |
| Business Buttons | 6 workflow buttons (buttons.json) |
| Admin Tools | Shell scripts (install.sh, pre_check.sh, etc.) |

### Layer 6 — Business Logic (Markdown-Driven)

| Component | Location |
|-----------|----------|
| Agent Behavior | system/AGENTS.md |
| Policies | system/POLICIES.md |
| Identity | system/IDENTITY.md |
| Prompts | system/PROMPTS.md |
| Client Profile | clients/{client}/CLIENT_PROFILE.md |
| Procedures | clients/{client}/PROCEDURES/*.md |
| Memory | clients/{client}/MEMORY/*.md |
| Owner Preferences | clients/{client}/OWNER_PREFERENCES.md |

This layer is unique — it's not code but markdown configuration that governs AI behavior across all other layers.

---

## Data Flow

```
User
  ↓
Open WebUI Chat (Layer 5, port 3000)
  ↓
RAG Filter Function (business_rag_filter.py)
  ↓
Embed question → Ollama nomic-embed-text (Layer 2)
  ↓
Query pgvector for relevant chunks (Layer 3 + Layer 1)
  ↓
Inject context into system prompt
  ↓
LLM generates answer (Ollama qwen3/gemma3, Layer 2)
  ↓
Response with business knowledge
  ↓
User
```

### Editing Flow

```
User edits in Obsidian (port 3010)
  ↓
Files saved to clients/{ACTIVE_CLIENT}/ on host
  ↓
Run: python vector-db/index_vault.py
  ↓
Chunks embedded and stored in pgvector
  ↓
Next chat query retrieves updated context
```

---

## Directory Structure

```
business-assistant-box/
├── .env                    # Centralized configuration
├── admin/                  # Build docs, scripts, checklists
├── system/                 # AI behavior rules (AGENTS, POLICIES, etc.)
├── clients/                # Per-client business brains
│   ├── templates/          # Base template for new clients
│   ├── demo-company/
│   ├── acme-roofing/
│   ├── law-office/
│   └── insurance-agency/
├── vault/                  # Shared knowledge documents
│   ├── company-documents/
│   ├── financials/
│   ├── contracts/
│   ├── handbooks/
│   ├── websites/
│   └── uploads/
├── vector-db/              # RAG scripts + schema + venv
├── postgres/               # PostgreSQL data volume
├── n8n/                    # n8n data + workflow JSON
├── openclaw/               # OpenClaw workspace
├── dashboard/              # Open WebUI data + custom UI
├── docker/                 # Docker configs (if needed)
├── logs/                   # Application logs
└── backups/                # Automated backups
```

---

## Multi-Client Architecture

- Each client has an isolated workspace under `clients/`
- `ACTIVE_CLIENT` in .env determines which client the system serves
- RAG indexes per-client (filterable by `client_name` column)
- Switching clients = change .env + re-index
- Templates provide consistent starting structure

---

## Security Boundaries

| Boundary | Rule |
|----------|------|
| admin/ | Never indexed, never exposed to AI |
| logs/ | Never indexed |
| backups/ | Never indexed |
| .env | Never indexed, contains credentials |
| *.key, *.pem | Never indexed |
| Client data | Isolated per-client in RAG queries |
| Email sending | Requires explicit approval |

---

## Service Map

| Service | Port | Container | Purpose |
|---------|------|-----------|---------|
| PostgreSQL | 5432 | postgres | Database + vector storage |
| Ollama | 11434 | (native) | Local LLM + embeddings |
| Open WebUI | 3000 | openwebui | Chat interface |
| Obsidian | 3010 | obsidian | Knowledge vault editor (browser) |
| n8n | 5678 | n8n | Workflow automation |
| OpenClaw | — | (native/API) | AI agent |
| Custom Dashboard | 8088 | (static) | Business button UI |

---

## Deployment Models

1. **On-Premise Appliance** (preferred) — Single box, all services local
2. **Private Cloud** — Docker on private VPS
3. **Hybrid** — Local Ollama + cloud OpenClaw API

---

## Configuration-Aware Design

All scripts and services read from `.env`. Behavior adapts based on:

- `AI_PROVIDER` → which LLM to use
- `EMBEDDING_PROVIDER` → which embedding service
- `RAG_ENABLED` → whether PostgreSQL + pgvector are required
- `DASHBOARD_ENABLED` → whether Open WebUI is required
- `WORKFLOW_ENGINE` → whether n8n is required
- `OBSIDIAN_ENABLED` → whether vault path is validated
- `ACTIVE_CLIENT` → which client workspace is active
