# birth.md

# Business Assistant Box — Build Session Summary

**Date:** 2026-06-02

---

## What Was Built

This session created the complete automation framework for Business Assistant Box — a private, on-premise AI office assistant for small/medium businesses.

---

## Files Created

### Scripts (admin/)

| File | Purpose |
|------|---------|
| install.sh | Layer 1 — Full infrastructure installer (14 phases) |
| customize_ui_n8n.sh | Generate workflow templates, dashboard UI, buttons |
| configure_n8n.sh | Layer 2 — Import, activate, test n8n workflows (8 phases) |
| post_install_client_setup.sh | Layer 3 — Client onboarding (7 phases) |
| pre_check.sh | Configuration-aware system validation |
| uninstall.sh | Partial or complete teardown with backup |

### Documentation (admin/)

| File | Purpose |
|------|---------|
| INSTALL_STEPS.md | Full phase-by-phase install documentation |
| ARCHITECTURE.md | System architecture (6 layers, data flow, service map) |
| SCRIPT_LAYERS.md | Script execution order and layer definitions |
| PRE_CHECK.md | Validation criteria for a completed build |
| POST_INSTALL_CLIENT_SETUP.md | Client onboarding guide + script docs |
| UNINSTALL.md | Uninstaller documentation |
| Revised Installation Order.md | Converted from .txt to proper markdown |

### Configuration

| File | Purpose |
|------|---------|
| .env | Centralized configuration (all variables + safety control docs) |

### RAG System (vector-db/)

| File | Purpose |
|------|---------|
| schema.sql | PostgreSQL table definitions (rag_documents, rag_chunks) |
| index_vault.py | Index system/client/vault files into pgvector |
| query_vault.py | Query RAG for relevant context |

---

## Architecture Established

### 3 Script Layers

```
Layer 1: install.sh              → Install infrastructure (runs once)
Layer 2: configure_n8n.sh        → Configure workflows (safely rerunnable)
Layer 3: post_install_client_setup.sh → Onboard clients (per-client)
```

### 6 System Layers

1. Infrastructure (Ubuntu, Docker, PostgreSQL, pgvector)
2. AI / Intelligence (OpenClaw, Ollama, embeddings, RAG)
3. Data / Knowledge (vault, client files, system files, vectors)
4. Automation (n8n, webhooks, scheduling)
5. Interface (Open WebUI, custom dashboard, business buttons)
6. Business Logic (markdown-driven: AGENTS, POLICIES, PROCEDURES)

### Execution Order

```
install.sh → customize_ui_n8n.sh → configure_n8n.sh → post_install_client_setup.sh → pre_check.sh
```

---

## Safety Features Implemented

| Feature | Behavior |
|---------|----------|
| DRY_RUN=true | Simulates everything, changes nothing |
| SAFE_MODE=true | Backs up before overwrite, prompts before replacing |
| Idempotent | All scripts skip existing files/containers |
| Backup-before-overwrite | Timestamped .bak files for schema, scripts, configs |
| Phase prompts | Continue/abort after every phase |
| Configuration-aware | All validation reads .env to determine what's required |
| pgvector image detection | Warns about postgres:16 vs pgvector/pgvector:pg16 |
| Never destroys | No script deletes containers, volumes, or data without explicit confirmation |

---

## Services Supported

| Service | Container/Install | Port |
|---------|-------------------|------|
| PostgreSQL + pgvector | Docker (pgvector/pgvector:pg16) | 5432 |
| Ollama | Native (curl script) | 11434 |
| Open WebUI | Docker | 3000 |
| n8n | Docker | 5678 |
| OpenClaw | Native (curl script) | — |
| Obsidian | .deb or AppImage | — |
| Custom Dashboard | Static HTML | 8088 |

---

## Workflows Created (n8n)

| Workflow | Webhook |
|----------|---------|
| Email Review | POST /webhook/business/email-review |
| Calendar Review | POST /webhook/business/calendar-review |
| Daily Briefing | POST /webhook/business/daily-briefing |
| Create Document | POST /webhook/business/create-document |
| Customer Intake | POST /webhook/business/customer-intake |
| Ask Assistant | POST /webhook/business/ask-assistant |

---

## Clients Scaffolded

- templates (fully configured base)
- demo-company
- acme-roofing
- law-office
- insurance-agency

---

## Key Decisions Made

1. OpenClaw API as primary LLM provider, Ollama as optional local fallback
2. Obsidian = human-editable business brain (client data only, never admin/logs)
3. RAG indexes system/ + clients/{active}/ — never admin/logs/backups
4. Embedding dimensions configurable via .env (default 768)
5. Multi-client via ACTIVE_CLIENT in .env + client_name column in RAG tables
6. All scripts prompt after each phase — user controls the pace
7. pgvector/pgvector:pg16 image preferred over plain postgres:16
8. No credentials stored in markdown — .env only
