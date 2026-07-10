# SCRIPT_LAYERS.md

# Business Assistant Box — Script Execution Layers

## Overview

The system is built and maintained through layered shell scripts. Each layer has a specific purpose, runs in order, and can be safely rerun.

---

## Layer 1 — Install Infrastructure

**Script:** `install.sh`

**Purpose:** Install all software and services from scratch.

**Installs:**
- Docker
- PostgreSQL (pgvector/pgvector:pg16)
- pgvector extension
- Open WebUI
- n8n
- OpenClaw
- Ollama (optional)
- Obsidian (optional)
- RAG dependencies (Python venv, schema, scripts)

**Also creates:**
- Project directory scaffold
- .env configuration
- System/admin placeholder files
- Client template structure

**Runs:** Once (idempotent — safe to rerun, skips existing)

**Phases:** 0, 0B, 1, 2, 3, 4, 5, 6, 6A, 6A2, 6B, 7, 7B, 8, 8B, 9, 10

---

## Layer 2 — Configure Workflows

**Script:** `configure_n8n.sh`

**Purpose:** Import, activate, and test n8n workflows.

**Does:**
- Verify n8n is running
- Validate environment variables (writes missing to .env)
- Verify middleware connection (Ollama / OpenClaw API / PostgreSQL)
- Import workflow JSON files from standard/ and selectable/
- Activate workflows
- Create and verify webhook mappings
- Test webhooks with payload
- Generate N8N_CONFIG_REPORT.md

**Runs:** Safely rerun anytime. Never destroys existing workflows.

**Phases:** 1–8

**Prerequisite:** Layer 1 complete (workflows must exist in n8n/workflows/standard/ and selectable/)

---

## Layer 3 — Client Onboarding

**Script:** `post_install_client_setup.sh`

**Purpose:** Create and configure new client workspaces.

**Does:**
- Prompt for client names
- Create client directories from templates
- Copy template files (never overwrites existing)
- Create per-client vault directories
- Update ACTIVE_CLIENT in .env
- Validate client file structure
- Run RAG indexing per client
- Verify chunk count in PostgreSQL

**Runs:** Once per new client (safe to rerun — skips existing)

**Phases:** 1–7

**Prerequisite:** Layer 1 complete

---

## Supporting Scripts

### customize_ui_n8n.sh

**Purpose:** Generate dashboard UI, button manifest, and Open WebUI configuration.

**Runs between:** Layer 1 and Layer 2

**Creates:**
- dashboard/business-buttons/buttons.json
- dashboard/custom/index.html
- dashboard/openwebui/OPENWEBUI_BUSINESS_ASSISTANT.md
- n8n/IMPORT_NOTES.md

**Does NOT create:**
- n8n workflow JSON files (these live in n8n/workflows/standard/ and n8n/workflows/selectable/ and are managed separately)

---

### pre_check.sh

**Purpose:** Validate system state against .env requirements.

**Runs:** Anytime (read-only, no modifications)

**Checks:**
- Directories, system files, admin files
- Active client files
- Services (PostgreSQL, Ollama, n8n, Open WebUI)
- pgvector extension + RAG schema + embeddings
- Obsidian integration

**Output:** PASS / WARNING / FAIL

---

### uninstall.sh

**Purpose:** Remove all or part of the installation.

**Runs:** When tearing down the system.

**Options:**
- Partial (services only, preserves workspace)
- Complete (everything deleted)

**Safety:** Prompts for backup before any removal.

---

## Execution Order

```
Layer 1                    Supporting                 Layer 2                    Layer 3
install.sh          →   customize_ui_n8n.sh    →   configure_n8n.sh    →   post_install_client_setup.sh
(Phases 0–10)           (dashboard + UI)            (workflow import)           (client onboarding)
                                                                                    ↓
                                                                               pre_check.sh
                                                                                    ↓
                                                                               PASS / FAIL
```

### install.sh Phase Summary

| Phase | Name | Purpose |
|-------|------|---------|
| 0 | Project Scaffold | Create directory structure |
| 0B | Environment Configuration | Generate .env |
| 1 | Ubuntu Update & Tools | Install system packages |
| 2 | Docker | Install and start Docker |
| 3 | PostgreSQL | Start pgvector container |
| 4 | Ollama | Install local LLM + pull models |
| 5 | Open WebUI | Start chat interface container |
| 6 | n8n | Start workflow engine container |
| 6A | Import n8n Workflows | Import JSON files into n8n |
| 6A2 | Activate n8n Workflows | Publish all imported workflows |
| 6B | OpenClaw | Install OpenClaw (optional) |
| 7 | pgvector | Enable vector extension |
| 7B | RAG Schema | Deploy rag_documents + rag_chunks tables |
| 8 | Python RAG Dependencies | Create venv, install packages |
| 8B | RAG Index + Query Scripts | Write index_vault.py + query_vault.py |
| 9 | Obsidian | Install native Obsidian editor |
| 10 | RAG Pipeline | Install psycopg2 in WebUI, test pgvector connectivity, pre-warm embeddings |

---

## Rerun / Maintenance Order

```
pre_check.sh              # Identify what's broken
     ↓
Rerun specific script     # Fix the gap
     ↓
pre_check.sh              # Confirm fix
```

---

## Teardown Order

```
uninstall.sh              # Reverse Layer 1 (with backup prompt)
```

---

## Safety Controls (All Scripts)

| Control | Default | Effect |
|---------|---------|--------|
| DRY_RUN | false | Simulates everything, changes nothing. Like a rehearsal. |
| SAFE_MODE | true | Backs up before overwrite, prompts before replacing, never destroys. |

Enable via environment:
```bash
DRY_RUN=true ./admin/install.sh
SAFE_MODE=false ./admin/configure_n8n.sh
```

---

## Script Inventory

| Script | Layer | Purpose |
|--------|-------|---------|
| install.sh | 1 | Install infrastructure |
| customize_ui_n8n.sh | 1→2 | Generate workflow templates + UI |
| configure_n8n.sh | 2 | Configure and test workflows |
| post_install_client_setup.sh | 3 | Onboard new clients |
| pre_check.sh | — | Validate system state |
| uninstall.sh | — | Remove installation |
