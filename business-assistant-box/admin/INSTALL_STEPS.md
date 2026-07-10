# INSTALL_STEPS.md

# Business Assistant Box

## Installation Procedure

### Rules

Before making any changes:

1. Backup configuration.
2. Record commands executed.
3. Update CHECKLIST.md.
4. Update TROUBLESHOOTING.md if issues occur.

### Safety Controls

- `DRY_RUN=true` — Simulates the entire script without making any changes. Prints what WOULD happen (files created, containers started, software installed). Nothing is written, installed, or modified. Safe to run anytime — like a rehearsal with zero consequences.
- `SAFE_MODE=true` — Prevents overwriting existing files without creating a backup first. Prompts before replacing. Never removes containers or volumes automatically.
- Each phase prompts to continue/abort after completion.

---

# PHASE 0 — Project Scaffold

Creates directory structure and placeholder files.

Directories:
- admin/, system/, clients/, vault/, postgres/, vector-db/, dashboard/, n8n/, openclaw/, docker/, logs/, backups/
- vault/{company-documents, financials, contracts, handbooks, websites, uploads}
- clients/{templates, demo-company, law-office, insurance-agency, acme-roofing} with PROCEDURES/, MEMORY/, OUTPUTS/

Placeholder files (only created if missing):
- system: AGENTS.md, POLICIES.md, IDENTITY.md, HEARTBEAT.md, TOOLS.md, PROMPTS.md, SYSTEM_MEMORY.md
- admin: BUILD_PLAN.md, INSTALL_STEPS.md, CHECKLIST.md, SECURITY.md, TROUBLESHOOTING.md, COMMANDS.md, ACCEPTANCE_TESTS.md, DEPLOYMENT.md, PROJECT_STATUS.md, NEXT_ACTIONS.md, CHANGELOG.md, ROADMAP.md, ARCHITECTURE.md, POST_INSTALL_CLIENT_SETUP.md, PRE_CHECK.md
- clients/templates: CLIENT_PROFILE.md, OWNER_PREFERENCES.md, BUSINESS_KNOWLEDGE.md, FAQ.md, PROCEDURES/*.md, MEMORY/*.md

Verification:

All directories exist. No existing files overwritten.

---

# PHASE 0B — Environment Configuration

Creates `.env` if it does not already exist.

Prompts for:
- AI provider (OpenClaw API or Ollama)
- Embedding provider (Ollama or OpenClaw API)
- Embedding dimensions (default: 768)
- Active client
- Obsidian integration toggle

If `.env` exists: loads it without overwrite.

Verification:

`.env` present and loaded.

---

# PHASE 1 — Ubuntu Update & Tools

Commands:

```
sudo apt update
sudo apt upgrade -y
sudo apt install -y curl wget git nano vim unzip htop net-tools jq python3 python3-venv python3-pip
```

Verification:

No package errors. All commands available.

---

# PHASE 2 — Docker

Install Docker if not present:

```
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

Verification:

`docker ps` and `docker compose version` return successfully.

---

# PHASE 3 — PostgreSQL

Runs PostgreSQL via Docker using `pgvector/pgvector:pg16` image.

Behavior:
- If container running: skip.
- If container stopped: start it.
- If container missing: create it.
- Detects `postgres:16` image mismatch and warns (does not destroy).

Verification:

`docker ps` shows postgres container running.

---

# PHASE 4 — Optional Local AI / Ollama

Ollama is installed only if:
- `AI_PROVIDER=ollama` in .env, OR
- `LOCAL_LLM_ENABLED=true`, OR
- `EMBEDDING_PROVIDER=ollama`, OR
- User chooses to install when prompted.

Post-install configuration:
- Sets `OLLAMA_HOST=0.0.0.0` in `/etc/systemd/system/ollama.service`
- Sets `OLLAMA_NUM_PARALLEL=2` (handle concurrent requests)
- Sets `OLLAMA_MAX_LOADED_MODELS=3` (keep chat + embedding models loaded simultaneously)
- Runs `systemctl daemon-reload && systemctl restart ollama`
- Verifies Ollama is listening on `0.0.0.0:11434` (required for Docker container access)

Models pulled:
- qwen3:14b (required)
- gemma3:12b (optional, prompted)
- nomic-embed-text (if EMBEDDING_PROVIDER=ollama)

Verification:

- `ollama list` shows installed models.
- `ss -tlnp | grep 11434` shows `0.0.0.0:11434` (NOT `127.0.0.1`)

---

# PHASE 5 — Open WebUI

Runs Open WebUI via Docker (`ghcr.io/open-webui/open-webui:main`).

Container configuration:
- `--add-host=host.docker.internal:host-gateway` — Maps host IP inside container
- `-e OLLAMA_BASE_URL=http://host.docker.internal:11434` — Points WebUI to host Ollama
- `-p 3000:8080` — Exposes WebUI on port 3000
- `-v dashboard:/app/backend/data` — Persists WebUI data

Behavior:
- If container running with correct config: skip.
- If container running without OLLAMA_BASE_URL: recreate with correct config.
- If container stopped: start it.
- If container missing: create it.
- After start: tests WebUI → Ollama connectivity via `/ollama/api/version`

Verification:

- `http://SERVER_IP:3000` accessible.
- `curl http://localhost:3000/ollama/api/version` returns Ollama version.
- Models appear in WebUI model selection dropdown.

---

# PHASE 6 — n8n

Runs n8n via Docker (`n8nio/n8n`).

Behavior:
- If container running: skip.
- If container stopped: start it.
- If container missing: create it.

Verification:

`http://SERVER_IP:5678` accessible.

---

# PHASE 6B — OpenClaw

Installs OpenClaw via curl script:

```
curl -fsSL https://get.openclaw.com | sh
```

Behavior:
- If `openclaw` command already exists: skip.
- Otherwise: install via official script.

Verification:

`openclaw --version` returns successfully.

---

# PHASE 7 — pgvector

Enables pgvector extension in PostgreSQL:

```
CREATE EXTENSION IF NOT EXISTS vector;
```

Then validates explicitly:

```
SELECT extname FROM pg_extension WHERE extname='vector';
```

If validation fails:
- Warns that container may not include pgvector.
- Suggests switching to `pgvector/pgvector:pg16`.
- Does NOT delete container or volume.

Verification:

pgvector extension confirmed active.

---

# PHASE 7B — RAG Schema

Generates `vector-db/schema.sql` using `EMBEDDING_DIMENSIONS` from .env (default: 768).

Creates tables:
- `rag_documents` (id, client_name, source_path, title, created_at)
- `rag_chunks` (id, document_id, client_name, source_path, title, chunk_text, embedding, created_at)

If schema.sql already exists:
- SAFE_MODE prompts before replacing.
- Backup created as `schema.sql.bak.YYYYMMDD-HHMMSS`.

Deploys schema to PostgreSQL.

Verification:

Tables `rag_documents` and `rag_chunks` exist in database.

---

# PHASE 8 — Python RAG Dependencies

Creates virtual environment at `vector-db/venv/` if not present.

Installs:
- llama-index
- llama-index-readers-file
- psycopg2-binary
- python-dotenv
- requests

Verification:

venv exists and packages installed.

---

# PHASE 8B — RAG Index + Query Scripts

Creates/updates:
- `vector-db/index_vault.py` — Indexes system/, clients/{active_client}/, vault/ into pgvector.
- `vector-db/query_vault.py` — Queries RAG for relevant context.

If files exist:
- SAFE_MODE prompts before replacing.
- Backup created as `filename.bak.YYYYMMDD-HHMMSS`.

Exclusions (index_vault.py will NOT index):
- admin/
- logs/
- backups/
- docker/
- postgres/
- node_modules/
- .git/
- .env
- *.key
- *.pem

Verification:

Scripts present. Run `python vector-db/index_vault.py` to populate RAG.

---

# PHASE 9 — Obsidian Integration Notes

Only runs if `OBSIDIAN_ENABLED=true` in .env.

Installs Obsidian via .deb or AppImage (prompted).

Creates `admin/OBSIDIAN_SETUP.md` with vault path and usage rules.

If OBSIDIAN_SETUP.md exists:
- SAFE_MODE prompts before replacing.
- Backup created.

Vault path: `clients/{ACTIVE_CLIENT}/`

Obsidian is for client business knowledge ONLY. Not for admin, logs, docker, or backups.

Verification:

Obsidian installed (if chosen). OBSIDIAN_SETUP.md present.

---

# PHASE 10 — UI & n8n Customization

Script: `admin/customize_ui_n8n.sh`

Run after base install to configure Open WebUI and n8n for business workflows.

```bash
./admin/customize_ui_n8n.sh
```

Supports: `DRY_RUN=true` and `SAFE_MODE=true`

## What it creates:

**Phase A — Directories:**
- dashboard/business-buttons/
- dashboard/openwebui/
- dashboard/custom/
- n8n/workflows/
- n8n/templates/

**Phase B — Environment Defaults:**
- Appends N8N_BASE_URL, OPENWEBUI_BASE_URL, BUSINESS_BUTTONS_ENABLED, APPROVAL_REQUIRED_FOR_EMAIL_SEND to .env (if missing)

**Phase C — Business Button Manifest:**
- `dashboard/business-buttons/buttons.json` — Defines 6 workflow buttons (Check Email, Calendar, Daily Briefing, Create Document, Customer Intake, Ask Assistant)

**Phase D — Open WebUI Prompt Pack:**
- `dashboard/openwebui/OPENWEBUI_BUSINESS_ASSISTANT.md` — System prompt and configuration notes for Open WebUI

**Phase E — n8n Workflow Templates:**
- `n8n/workflows/email-review.json`
- `n8n/workflows/calendar-review.json`
- `n8n/workflows/daily-briefing.json`
- `n8n/workflows/create-document.json`
- `n8n/workflows/customer-intake.json`
- `n8n/workflows/ask-assistant.json`
- `n8n/IMPORT_NOTES.md`

These are placeholder webhook templates. Connect to OpenClaw after import.

**Phase F — Static Button Dashboard:**
- `dashboard/custom/index.html` — Prototype UI with 6 business buttons calling n8n webhooks
- `dashboard/custom/README.md`

**Phase G — Service Status:**
- Checks n8n and Open WebUI are running

Verification:

- Workflow JSON files present in `n8n/workflows/`
- Import into n8n at `http://SERVER_IP:5678`
- Test dashboard at `http://localhost:8088` (via `python3 -m http.server 8088`)
- Buttons call n8n webhook endpoints

---

# PHASE 11 — n8n Workflow Configuration

Script: `admin/configure_n8n.sh`

Run after `customize_ui_n8n.sh` to import, activate, and test workflows.

```bash
./admin/configure_n8n.sh
```

Supports: `DRY_RUN=true` and `SAFE_MODE=true`

Can be safely rerun.

## Phase 1 — Verify n8n Running

- Checks Docker container is running
- Tests n8n REST API access
- Validates API key if set
- Exits with guidance if n8n unreachable or auth fails

## Phase 2 — Configure Environment Variables

- Validates required variables: N8N_BASE_URL, N8N_API_KEY, ACTIVE_CLIENT, AI_PROVIDER
- Validates OPENCLAW_API_KEY if AI_PROVIDER=openclaw_api
- Validates OLLAMA_BASE_URL if AI_PROVIDER=ollama or EMBEDDING_PROVIDER=ollama
- Appends missing variables to .env

## Phase 3 — Verify Middleware Connection

- Tests connectivity to the AI layer (Ollama or OpenClaw API)
- Tests Ollama for embeddings if EMBEDDING_PROVIDER=ollama
- Verifies PostgreSQL is running (required for RAG workflows)
- Reports reachability status for each downstream service

## Phase 4 — Import Workflows

- Reads all JSON files from `n8n/workflows/`
- Skips workflows that already exist in n8n (never overwrites)
- Backs up existing workflow definitions before any changes (SAFE_MODE)
- Imports new workflows via n8n REST API

## Phase 5 — Activate Workflows

- Finds all "Business Assistant" workflows
- Activates inactive workflows
- Skips already-active workflows

## Phase 6 — Webhook Mappings

- Lists all expected webhook endpoints
- Verifies each maps to an existing active workflow
- Reports: active, inactive, or missing for each path
- Displays full webhook base URL

Expected mappings:
- POST /webhook/business/email-review
- POST /webhook/business/calendar-review
- POST /webhook/business/daily-briefing
- POST /webhook/business/create-document
- POST /webhook/business/customer-intake
- POST /webhook/business/ask-assistant

## Phase 7 — Test Webhooks

- POSTs test payload to each webhook endpoint
- Reports HTTP status for each (200=OK, 404=inactive, 500=error)
- Uses ACTIVE_CLIENT from .env in test payload

## Phase 8 — Generate Report

- Creates `n8n/N8N_CONFIG_REPORT.md` with:
  - Connection status
  - Environment variable state
  - Middleware reachability
  - Workflows imported/activated
  - Webhook mappings
  - Test results
  - Backups created
  - Warnings and errors
  - Next steps

Verification:

- All 6 workflows imported and active
- All 6 webhooks return 200
- Middleware reachable
- Report generated at `n8n/N8N_CONFIG_REPORT.md`

---

# PHASE 12 — Post-Install Client Setup

Script: `admin/post_install_client_setup.sh`

Run after infrastructure and n8n configuration to onboard new clients.

```bash
./admin/post_install_client_setup.sh
```

Supports: `DRY_RUN=true` and `SAFE_MODE=true`

Can be safely rerun. Never overwrites existing client data.

## Phase 1 — Select Clients

- Prompts for comma-separated client names
- Example: `acme-roofing,law-office,insurance-agency`

## Phase 2 — Create Client Directories

- Copies template files to new client workspace
- Creates PROCEDURES/, MEMORY/, OUTPUTS/ structure
- Skips existing files (never overwrites)

## Phase 3 — Create Client Vault Directories

- Creates `vault/<client>/{documents,contracts,financials,uploads}`

## Phase 4 — Update Active Client

- Sets ACTIVE_CLIENT and OBSIDIAN_VAULT_PATH in .env (prompted)

## Phase 5 — Validate Client Files

- Checks all required files exist for each client
- Reports missing files

## Phase 6 — Index Documents (RAG Ingest)

- Verifies prerequisites (PostgreSQL, venv, Ollama)
- Runs `index_vault.py` per client
- Indexes system/, clients/<client>/, vault/ into pgvector

## Phase 7 — Verify RAG Ingest

- Queries rag_chunks table for chunk count per client
- Confirms indexing succeeded

Verification:

- Client directories created with all template files
- Vault directories created
- ACTIVE_CLIENT updated in .env
- RAG chunks present for each indexed client

---

# PHASE 10 — RAG Pipeline (WebUI → pgvector)

Connects Open WebUI to the pgvector RAG database so chat queries automatically retrieve business context.

Script: `admin/configure_rag_pipeline.sh`

```bash
sudo ./admin/configure_rag_pipeline.sh
```

## What it does:

1. Installs `psycopg2-binary` inside the WebUI container
2. Tests pgvector connectivity from inside the container
3. Tests embedding generation (nomic-embed-text via Ollama)
4. Authenticates with Open WebUI admin API
5. Registers `business_rag_filter.py` as a Filter function
6. Enables the function globally (applies to all chats)
7. Runs end-to-end RAG retrieval test

## How it works at runtime:

1. User asks a question in Open WebUI chat
2. The RAG filter intercepts the message (inlet)
3. Generates an embedding for the user's question via Ollama
4. Queries pgvector for the top-5 most similar chunks
5. Injects the retrieved context into the system prompt
6. LLM receives the enriched prompt and answers with business knowledge

## Files:

- `dashboard/functions/business_rag_filter.py` — The filter function code
- Configurable via Valves in Open WebUI (Admin → Functions → Business Knowledge RAG)

## Configuration (Valves):

| Setting | Default | Description |
|---------|---------|-------------|
| pg_host | host.docker.internal | PostgreSQL host from container |
| pg_port | 5432 | PostgreSQL port |
| pg_user | admin | Database user |
| pg_password | strongpassword | Database password |
| pg_database | businessassistant | Database name |
| ollama_base_url | http://host.docker.internal:11434 | Ollama API for embeddings |
| embedding_model | nomic-embed-text | Embedding model |
| active_client | demo-company | Client filter for RAG queries |
| top_k | 5 | Number of context chunks |
| similarity_threshold | 0.3 | Minimum relevance score |
| enabled | true | Toggle RAG on/off |

## Requirements:

- Ollama with `OLLAMA_MAX_LOADED_MODELS=3` (keeps embedding model loaded)
- pgvector with indexed documents (`python vector-db/index_vault.py`)
- WebUI container with `--add-host=host.docker.internal:host-gateway`

Verification:

Ask "What is Life Legacy?" in Open WebUI — answer should reference BUSINESS_KNOWLEDGE.md content.

---

# PHASE POST — Verification & Repair

Script: `admin/post_install_verify.sh`

Run after install to verify all services are connected and working.

```bash
./admin/post_install_verify.sh
DRY_RUN=true ./admin/post_install_verify.sh   # preview only
```

Tests performed:
1. Ollama service active
2. Ollama listening on 0.0.0.0:11434 (auto-repairs if on 127.0.0.1)
3. Ollama API responsive
4. Ollama models available
5. Open WebUI container running with correct env/host config
6. WebUI → Ollama connectivity (auto-repairs by recreating container)
7. Models visible through WebUI
8. PostgreSQL running and accepting connections
9. n8n running and responding
10. Port summary (11434, 3000, 5678, 5432)

Auto-repairs:
- Ollama on wrong address → rewrites systemd service, restarts
- WebUI missing --add-host → recreates container with correct flags

Verification:

All 10 tests pass. Models appear in WebUI selection.

---

# Post-Installation

After all phases complete, the installer prints a summary:
- Base path
- .env status
- Ollama status
- PostgreSQL/pgvector/RAG status
- Files created
- Files backed up
- Warnings
- Suggested next commands

Run `pre_check.sh` to validate full system state.
