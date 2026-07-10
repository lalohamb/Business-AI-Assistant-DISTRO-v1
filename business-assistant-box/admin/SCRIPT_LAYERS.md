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

**Phases:** 0, 0B, 1, 2, 3, 4, 5, 6, 6B, 7, 7B, 8, 8B, 9

---

## Layer 2 — Configure Workflows

**Script:** `configure_n8n.sh`

**Purpose:** Import, activate, and test n8n workflows.

**Does:**
- Verify n8n is running
- Validate environment variables (writes missing to .env)
- Verify middleware connection (Ollama / OpenClaw API / PostgreSQL)
- Import workflow JSON files
- Activate workflows
- Create and verify webhook mappings
- Test webhooks with payload
- Generate N8N_CONFIG_REPORT.md

**Runs:** Safely rerun anytime. Never destroys existing workflows.

**Phases:** 1–8

**Prerequisite:** Layer 1 complete + `customize_ui_n8n.sh` run first (to generate workflow JSON)

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

**Purpose:** Generate workflow templates, dashboard UI, and Open WebUI configuration.

**Runs between:** Layer 1 and Layer 2

**Creates:**
- n8n/workflows/*.json (6 workflow templates)
- dashboard/business-buttons/buttons.json
- dashboard/custom/index.html
- dashboard/openwebui/OPENWEBUI_BUSINESS_ASSISTANT.md
- n8n/IMPORT_NOTES.md

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
Layer 1                    Layer 2                    Layer 3
install.sh          →   customize_ui_n8n.sh    →   post_install_client_setup.sh
                    →   configure_n8n.sh
                                                        ↓
                                                   pre_check.sh
                                                        ↓
                                                   PASS / FAIL
```

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
