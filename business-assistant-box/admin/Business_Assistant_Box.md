# Business Assistant Box - Installer Refactor Prompt

You are working on an existing Business Assistant Box project.

IMPORTANT:

This is NOT a greenfield project.

Do NOT rewrite the installer from scratch.

Do NOT remove existing functionality.

Do NOT remove Docker support.

Do NOT remove PostgreSQL.

Do NOT remove pgvector.

Do NOT remove Open WebUI.

Do NOT remove n8n.

Do NOT remove Ollama support.

The objective is to ALIGN the existing install.sh and project structure with the Business Assistant Box architecture while preserving all current functionality.

---

## CURRENT GOALS

The system must support:

1. OpenClaw as the primary business assistant.
2. OpenClaw AI API as the primary LLM provider.
3. Ollama as an OPTIONAL local LLM provider.
4. Obsidian as the editable business knowledge vault.
5. PostgreSQL + pgvector as the RAG engine.
6. n8n as the workflow engine.
7. Open WebUI as the initial dashboard/chat interface.
8. Multi-client deployments.

---

## REQUIRED PROJECT STRUCTURE

BASE_PATH:

/home/lalo/Documents/.nativeblackbox/opt/business-assistant-box

Create and validate:

business-assistant-box/

├── admin/
│
├── system/
│
├── clients/
│   ├── templates/
│   ├── demo-company/
│   ├── law-office/
│   ├── insurance-agency/
│   └── acme-roofing/
│
├── vault/
│   ├── company-documents/
│   ├── financials/
│   ├── contracts/
│   ├── handbooks/
│   ├── websites/
│   └── uploads/
│
├── postgres/
├── vector-db/
├── dashboard/
├── n8n/
├── openclaw/
├── docker/
├── logs/
└── backups/

---

## SYSTEM FILES

system/

Required Files:

AGENTS.md
POLICIES.md
IDENTITY.md
HEARTBEAT.md
TOOLS.md
PROMPTS.md
SYSTEM_MEMORY.md

Installer should create placeholders if missing.

---

## ADMIN FILES

admin/

Required Files:

BUILD_PLAN.md
INSTALL_STEPS.md
CHECKLIST.md
SECURITY.md
TROUBLESHOOTING.md
COMMANDS.md
ACCEPTANCE_TESTS.md
DEPLOYMENT.md
PROJECT_STATUS.md
NEXT_ACTIONS.md
CHANGELOG.md
ROADMAP.md
ARCHITECTURE.md
POST_INSTALL_CLIENT_SETUP.md
PRE_CHECK.md

Installer should create placeholders if missing.

---

## CLIENT TEMPLATE

clients/templates/

Required Files:

BUSINESS_PROFILE.md
OWNER_PREFERENCES.md
BUSINESS_KNOWLEDGE.md
FAQ.md

PROCEDURES/

EMAIL.md
CALENDAR.md
DAILY_BRIEFING.md
DOCUMENTS.md

MEMORY/

CUSTOMER_RULES.md
VENDOR_RULES.md
LEARNED_PATTERNS.md
OPEN_TASKS.md
TODAY.md

OUTPUTS/

drafts/
reports/
summaries/

Installer should create placeholders if missing.

---

PHASE 0
ADD TO INSTALL.SH
-----------------

Before any software installation:

Create full directory structure.

Create missing placeholder files.

Create vault directories.

Create template client structure.

This becomes:

PHASE 0 — Project Scaffold

---

## AI PROVIDER CONFIGURATION

Create:

.env

Supported:

AI_PROVIDER=openclaw_api

OR

AI_PROVIDER=ollama

Variables:

AI_PROVIDER=openclaw_api

LOCAL_LLM_ENABLED=false

OPENCLAW_API_KEY=

OPENCLAW_MODEL=

OLLAMA_BASE_URL=http://localhost:11434

OLLAMA_MODEL=qwen3:14b

EMBEDDING_PROVIDER=ollama

EMBEDDING_MODEL=nomic-embed-text

ACTIVE_CLIENT=demo-company

BASE_PATH=/home/lalo/Documents/.nativeblackbox/opt/business-assistant-box

---

## OLLAMA CHANGES

Do NOT require Ollama.

Modify install.sh:

Ask:

Install local Ollama support?

[y/n]

If yes:

Install Ollama

Pull:

qwen3:14b

gemma3:12b

nomic-embed-text

If no:

Skip local LLM installation.

---

## OBSIDIAN INTEGRATION

Add support for:

OBSIDIAN_ENABLED=true

OBSIDIAN_VAULT_PATH=

Default:

clients/demo-company/

Obsidian must be treated as:

Human Editable Business Brain

Do NOT use Obsidian for:

admin/
logs/
docker/
backups/

Only:

client business knowledge

---

## PGVECTOR REQUIREMENTS

Keep PostgreSQL Docker deployment.

Keep pgvector extension.

Add:

PHASE 7B — RAG Schema

Create:

vector-db/schema.sql

Schema must create:

rag_documents

rag_chunks

Tables must support:

client_name

source_path

title

chunk_text

embedding

created_at

---

## RAG INDEXING

Create:

vector-db/index_vault.py

vector-db/query_vault.py

Index sources:

system/

clients/${ACTIVE_CLIENT}/

vault/

Exclude:

admin/
logs/
backups/
docker/
postgres/
.git
.env
*.key
*.pem

---

## EMBEDDING PROVIDER RULES

Embeddings must be configurable.

Supported:

EMBEDDING_PROVIDER=ollama

EMBEDDING_PROVIDER=openclaw_api

Main LLM and embeddings must be independent.

Example:

AI_PROVIDER=openclaw_api

EMBEDDING_PROVIDER=ollama

Valid.

---

## PRE_CHECK.SH CHANGES

Refactor pre_check.sh

Do not hardcode service requirements.

Rules:

PostgreSQL required if:

RAG_ENABLED=true

Ollama required only if:

AI_PROVIDER=ollama

OR

LOCAL_LLM_ENABLED=true

OR

EMBEDDING_PROVIDER=ollama

OpenClaw AI API requires:

OPENCLAW_API_KEY

Obsidian vault path required only if:

OBSIDIAN_ENABLED=true

Dashboard required only if:

DASHBOARD_ENABLED=true

n8n required only if:

WORKFLOW_ENGINE=n8n

---

## DO NOT REMOVE

Existing Docker support

Existing PostgreSQL deployment

Existing Open WebUI deployment

Existing n8n deployment

Existing pgvector setup

Existing installer phases

Existing prompts

Existing documentation

---

## SUCCESS CRITERIA

1. Existing install.sh still works.

2. Installer supports OpenClaw API mode.

3. Installer supports Ollama mode.

4. Obsidian integration supported.

5. pgvector schema automatically deployed.

6. Client template automatically created.

7. pre_check.sh becomes configuration-aware.

8. Multi-client architecture supported.

9. No existing functionality removed.

10. Architecture remains maintainable and production ready.

