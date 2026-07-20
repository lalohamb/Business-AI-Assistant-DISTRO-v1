# INSTALL_STEPS.md

# Business Assistant Box — Installation Procedure

## Rules

Before making any changes:

1. Backup configuration.
2. Record commands executed.
3. Update CHECKLIST.md.
4. Update TROUBLESHOOTING.md if issues occur.

## Safety Controls

- `DRY_RUN=true` — Simulates the entire script without making any changes. Prints what WOULD happen. Nothing is written, installed, or modified.
- `SAFE_MODE=true` — Prevents overwriting existing files without creating a backup first. Prompts before replacing. Never removes containers or volumes.
- Each phase prompts to continue, skip, or quit after completion.

## Usage

```bash
# Full install (real)
sudo ./admin/install.sh

# Preview only
DRY_RUN=true ./admin/install.sh

# No prompts before overwrite
SAFE_MODE=false ./admin/install.sh
```

---

# PHASE 0 — Project Scaffold

Creates directory structure and placeholder files.

Directories created:
- Root: admin/, system/, clients/, postgres/, vector-db/, dashboard/, n8n/, openclaw/, docker/, logs/, backups/
- Vault: company-documents/, financials/, contracts/, handbooks/, websites/, uploads/
- Clients: templates/, demo-company/, law-office/, insurance-agency/, acme-roofing/ — each with PROCEDURES/, MEMORY/, OUTPUTS/{drafts,reports,summaries}/

Placeholder files (only created if missing):
- system/: AGENTS.md, POLICIES.md, IDENTITY.md, HEARTBEAT.md, TOOLS.md, PROMPTS.md, SYSTEM_MEMORY.md
- admin/: BUILD_PLAN.md, INSTALL_STEPS.md, CHECKLIST.md, SECURITY.md, TROUBLESHOOTING.md, COMMANDS.md, ACCEPTANCE_TESTS.md, DEPLOYMENT.md, PROJECT_STATUS.md, NEXT_ACTIONS.md, CHANGELOG.md, ROADMAP.md, ARCHITECTURE.md, POST_INSTALL_CLIENT_SETUP.md, PRE_CHECK.md
- clients/templates/: CLIENT_PROFILE.md, OWNER_PREFERENCES.md, BUSINESS_KNOWLEDGE.md, FAQ.md, PROCEDURES/{EMAIL,CALENDAR,DAILY_BRIEFING,DOCUMENTS}.md, MEMORY/{CUSTOMER_RULES,VENDOR_RULES,LEARNED_PATTERNS,OPEN_TASKS,TODAY}.md

---

# PHASE 0B — Environment Configuration

Creates `.env` if it does not exist. If it exists, loads without overwrite.

Interactive prompts (new install only):
- AI provider: OpenClaw API or Ollama
- Embedding provider: Ollama or OpenClaw API
- Embedding dimensions (default: 768)
- Active client (default: demo-company)
- Obsidian integration toggle

Variables written:
- AI_PROVIDER, LOCAL_LLM_ENABLED, OPENCLAW_API_KEY, OPENCLAW_MODEL
- OPENCLAW_WORKSPACE_PATH, OLLAMA_BASE_URL, OLLAMA_MODEL
- EMBEDDING_PROVIDER, EMBEDDING_MODEL, EMBEDDING_DIMENSIONS
- ACTIVE_CLIENT, BASE_PATH, OBSIDIAN_ENABLED, OBSIDIAN_VAULT_PATH
- RAG_ENABLED, DASHBOARD_ENABLED, WORKFLOW_ENGINE
- N8N_BASE_URL, N8N_API_KEY, OPENWEBUI_BASE_URL
- BUSINESS_BUTTONS_ENABLED, APPROVAL_REQUIRED_FOR_EMAIL_SEND

---

# PHASE 1 — Ubuntu Update & Tools

```bash
sudo apt --fix-broken install -y
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git nano vim unzip htop net-tools jq python3 python3-full python3-venv python3-pip
```

Handles broken apt state before proceeding. Verifies critical tools (curl, git, jq, python3) are available after install.

---

# PHASE 2 — Docker

Install methods (in order):
1. `sudo apt install -y docker.io docker-compose-v2`
2. Fallback: `curl -fsSL https://get.docker.com | sh`

Post-install:
- Adds user to docker group
- Enables docker.socket and docker.service via systemd
- Verifies daemon is running (retries with 10s wait if needed)

Sets `DOCKER_AVAILABLE=true/false` — all subsequent Docker phases check this flag and skip gracefully if false.

---

# PHASE 3 — PostgreSQL

Image: `pgvector/pgvector:pg16`

Container config:
- Name: postgres
- Port: 5432
- User: admin / Password: strongpassword
- Database: businessassistant
- Volume: `$BASE_PATH/postgres/data:/var/lib/postgresql/data`
- Restart policy: unless-stopped

Behavior:
- Running → skip
- Stopped → start
- Missing → create
- Stuck restarting → recreate with clean data directory

Post-start:
- Waits up to 30s for pg_isready
- Enables pgvector extension immediately: `CREATE EXTENSION IF NOT EXISTS vector`
- Detects wrong image (postgres:16 vs pgvector/pgvector:pg16) and warns

---

# PHASE 4 — Ollama

Installed automatically if AI_PROVIDER=ollama, LOCAL_LLM_ENABLED=true, or EMBEDDING_PROVIDER=ollama. Otherwise prompted.

Install: `curl -fsSL https://ollama.com/install.sh | sh`

Systemd configuration (added to /etc/systemd/system/ollama.service):
- `OLLAMA_HOST=0.0.0.0` — Required for Docker container access
- `OLLAMA_NUM_PARALLEL=2` — Concurrent requests
- `OLLAMA_MAX_LOADED_MODELS=3` — Keep chat + embedding models loaded

Models pulled:
- Primary: from .env `OLLAMA_MODEL` (default: qwen3:14b)
- Optional (prompted): qwen3:14b, gemma3:12b, llama3:8b, mistral:7b
- Embedding: from .env `EMBEDDING_MODEL` (default: nomic-embed-text)

Verification:
- `ollama list` shows models
- `ss -tlnp | grep 11434` shows 0.0.0.0:11434

---

# PHASE 5 — Open WebUI

Image: `ghcr.io/open-webui/open-webui:main`

Container config:
- Name: openwebui
- Port: 3000 → 8080 (internal)
- `--add-host=host.docker.internal:host-gateway`
- `-e OLLAMA_BASE_URL=http://host.docker.internal:11434`
- Volume: `$BASE_PATH/dashboard:/app/backend/data`
- Restart policy: unless-stopped

Behavior:
- Running with correct config → skip
- Running without OLLAMA_BASE_URL → recreate
- Stopped → start
- Missing → create

Post-start:
- Waits for HTTP 200/303 on port 3000
- Tests Ollama connectivity from inside container via host.docker.internal

Manual step: Open http://localhost:3000 and create admin account (first user = admin).

---

# PHASE 6 — n8n

Image: `n8nio/n8n`

Container config:
- Name: n8n
- Port: 5678
- `--add-host=host.docker.internal:host-gateway`
- Volume: `$BASE_PATH/n8n:/home/node/.n8n`
- Restart policy: unless-stopped
- Ownership: chown 1000:1000 on n8n directory (container runs as UID 1000)

Manual step: Open http://localhost:5678, create owner account, generate API key, set N8N_API_KEY in .env.

---

# PHASE 6A — Import n8n Workflows

Sources:
- `n8n/workflows/standard/*.json` (6 core workflows)
- `n8n/workflows/selectable/*.json` (10 optional workflows)

Behavior:
- Waits for n8n container to be ready
- Checks existing workflows by name — never overwrites
- Adds missing `id` field to JSON if absent
- Imports via `docker exec n8n n8n import:workflow`
- Reports imported count and skipped count

---

# PHASE 6A2 — Activate n8n Workflows

Activates all imported workflows via `docker exec n8n n8n publish:workflow --id=<ID>`.

Reports count of activated workflows.

---

# PHASE 6B — OpenClaw (Optional)

Install: `curl -fsSL https://get.openclaw.com | sh`

Behavior:
- If `openclaw` command exists → skip
- If get.openclaw.com unreachable → skip with warning
- Phase is skippable at the prompt

---

# PHASE 7 — pgvector Extension

Confirms PostgreSQL is accepting connections, then:

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

Validates with:

```sql
SELECT extname FROM pg_extension WHERE extname='vector';
```

If validation fails, warns about wrong container image.

---

# PHASE 7B — RAG Schema

Generates `vector-db/schema.sql` using EMBEDDING_DIMENSIONS from .env (default: 768).

Tables created:
- `rag_documents` — id, client_name, source_path, title, created_at
- `rag_chunks` — id, document_id, client_name, source_path, title, chunk_text, embedding vector(768), created_at

Indexes:
- `idx_chunks_client` on client_name
- `idx_chunks_embedding` using ivfflat (vector_cosine_ops)

Deploys schema to PostgreSQL. SAFE_MODE backs up existing schema.sql before overwrite.

---

# PHASE 8 — Python RAG Dependencies

Creates venv at `vector-db/venv/` if not present.

Packages installed:
- llama-index
- llama-index-readers-file
- psycopg2-binary
- python-dotenv
- requests
- pymupdf (PDF parsing)
- python-docx (Word parsing)
- openpyxl (Excel parsing)
- beautifulsoup4 (HTML parsing)

---

# PHASE 8B — RAG Index + Query Scripts

Creates (if missing, SAFE_MODE protects existing):

- `vector-db/index_vault.py` — Indexes system/, clients/{ACTIVE_CLIENT}/, vault/ into pgvector
- `vector-db/query_vault.py` — CLI tool to query RAG database

Supported file formats for indexing:
- .md, .txt, .pdf, .docx, .xlsx, .csv, .html, .htm, .eml

Excluded from indexing:
- admin/, logs/, backups/, docker/, postgres/, .git/, venv/, .obsidian/
- .env, *.key, *.pem

Usage after install:
```bash
cd vector-db
./vector-db/venv/bin/python3 ./vector-db/index_vault.py
./vector-db/venv/bin/python3 ./vector-db/query_vault.py "your question"
```

---

# PHASE 9 — Obsidian (Native)

Only runs if `OBSIDIAN_ENABLED=true` in .env.

Actions:
- Creates `current-client` symlink → `clients/{ACTIVE_CLIENT}/` if missing
- Downloads and installs Obsidian .deb package
- Creates `admin/OBSIDIAN_SETUP.md` with vault path and usage rules

Manual step: Launch `obsidian &`, select "Open folder as vault", choose `current-client/`.

---

# PHASE 10 — RAG Pipeline (WebUI → pgvector)

Connects Open WebUI to the RAG database for automatic context retrieval during chat.

Actions:
1. Installs psycopg2-binary inside WebUI container
2. Tests pgvector connectivity from container (via host.docker.internal)
3. Pre-warms embedding model (nomic-embed-text)

Manual step: Run `sudo ./admin/configure_rag_pipeline.sh` to register the RAG filter function in Open WebUI (requires admin credentials).

---

# Post-Installation Summary

The installer prints:
- Base path, .env status, DRY_RUN/SAFE_MODE state
- PostgreSQL status (running, pgvector enabled, RAG schema deployed)
- Files created and backed up
- Warnings
- Obsidian and OpenClaw status
- Next commands to run

## Next Steps After Install

1. Create accounts (manual):
   - Open WebUI: http://localhost:3000 — first user becomes admin
   - n8n: http://localhost:5678 — create owner account, then Settings → API → Create API Key
   - Set `N8N_API_KEY=<your-key>` in .env

2. Run post-install scripts (in order):

```bash
./admin/post_install_verify.sh          # Verify all services connected
sudo ./admin/configure_rag_pipeline.sh  # Connect WebUI to RAG
./admin/configure_credentials.sh        # Create Google OAuth2 creds in n8n
./admin/configure_n8n.sh                # Test webhooks + generate report
./admin/switch_client.sh law-office     # Switch active client
cd vector-db && ./vector-db/venv/bin/python3 ./vector-db/index_vault.py  # Index vault into RAG
```

---

# Service Map (After Install)

| Service | Port | Container | Status Check |
|---------|------|-----------|--------------|
| PostgreSQL | 5432 | postgres | `docker exec postgres pg_isready -U admin` |
| Ollama | 11434 | (systemd) | `curl http://localhost:11434/api/version` |
| Open WebUI | 3000 | openwebui | `curl http://localhost:3000` |
| n8n | 5678 | n8n | `curl http://localhost:5678/healthz` |
| Obsidian | — | (native) | `pgrep -x obsidian` |
| OpenClaw | — | (deferred) | `openclaw --version` |
