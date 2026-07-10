# PRE_CHECK.md

# Business Assistant Box

## Pre-Startup Validation

Purpose:

Verify that a completed install.sh build meets all required criteria before the Business Assistant starts.

This checklist is **configuration-aware** — it reads `.env` to determine which services and components are required.

---

# Configuration Source

File: `.env`

Key variables that control validation:

| Variable | Effect on Validation |
|----------|---------------------|
| AI_PROVIDER | Determines if OpenClaw API key is required or Ollama is required |
| LOCAL_LLM_ENABLED | If true, Ollama must be running |
| EMBEDDING_PROVIDER | If "ollama", Ollama must be running |
| EMBEDDING_DIMENSIONS | Determines expected vector column size in RAG schema |
| ACTIVE_CLIENT | Determines which client directory is validated |
| OBSIDIAN_ENABLED | If true, vault path must exist |
| RAG_ENABLED | If true, PostgreSQL + pgvector + schema required |
| DASHBOARD_ENABLED | If true, Open WebUI must be running |
| WORKFLOW_ENGINE | If "n8n", n8n must be running |

---

# Validation Rules

Startup Status:

- **PASS** — All required files and services present. Startup approved.
- **WARNING** — Startup permitted. Missing non-critical components. Review recommended.
- **FAIL** — Startup denied. Correct missing critical components.

---

# Root Directory Validation

Expected Root:

`/home/lalo/Documents/.nativeblackbox/opt/business-assistant-box/`

Required Directories:

- [ ] admin
- [ ] system
- [ ] clients
- [ ] vault
- [ ] postgres
- [ ] vector-db
- [ ] dashboard
- [ ] n8n
- [ ] openclaw
- [ ] docker
- [ ] logs
- [ ] backups

If any are missing: **FAIL**

---

# Environment File Validation

Expected: `.env` in project root.

Required Variables:

- [ ] AI_PROVIDER
- [ ] EMBEDDING_PROVIDER
- [ ] EMBEDDING_DIMENSIONS
- [ ] ACTIVE_CLIENT
- [ ] BASE_PATH
- [ ] RAG_ENABLED

If `.env` missing: **FAIL**

If variables missing: **WARNING**

---

# System File Validation

Expected Location: `system/`

Required Files:

- [ ] AGENTS.md
- [ ] POLICIES.md
- [ ] IDENTITY.md
- [ ] HEARTBEAT.md
- [ ] TOOLS.md
- [ ] PROMPTS.md
- [ ] SYSTEM_MEMORY.md

If any are missing: **FAIL**

Reason: System behavior cannot be guaranteed.

---

# Admin File Validation

Expected Location: `admin/`

Required Files:

- [ ] BUILD_PLAN.md
- [ ] INSTALL_STEPS.md
- [ ] CHECKLIST.md
- [ ] SECURITY.md
- [ ] TROUBLESHOOTING.md
- [ ] COMMANDS.md
- [ ] ACCEPTANCE_TESTS.md
- [ ] DEPLOYMENT.md
- [ ] PROJECT_STATUS.md
- [ ] NEXT_ACTIONS.md
- [ ] CHANGELOG.md
- [ ] ROADMAP.md
- [ ] ARCHITECTURE.md
- [ ] POST_INSTALL_CLIENT_SETUP.md
- [ ] PRE_CHECK.md

If any are missing: **WARNING**

System can operate but maintenance may be impacted.

---

# Vault Validation

Expected Location: `vault/`

Required Directories:

- [ ] company-documents
- [ ] financials
- [ ] contracts
- [ ] handbooks
- [ ] websites
- [ ] uploads

If any are missing: **WARNING**

RAG functionality may be limited.

---

# Client Validation (Active Client)

Validates only the client specified in `ACTIVE_CLIENT` from `.env`.

Expected Location: `clients/${ACTIVE_CLIENT}/`

Required Files:

- [ ] CLIENT_PROFILE.md
- [ ] OWNER_PREFERENCES.md
- [ ] BUSINESS_KNOWLEDGE.md
- [ ] FAQ.md

If any are missing: **FAIL** — Business knowledge incomplete.

---

# Procedure Validation

Expected Location: `clients/${ACTIVE_CLIENT}/PROCEDURES/`

Required Files:

- [ ] EMAIL.md
- [ ] CALENDAR.md
- [ ] DAILY_BRIEFING.md
- [ ] DOCUMENTS.md

If any are missing: **FAIL** — Workflow execution unavailable.

---

# Memory Validation

Expected Location: `clients/${ACTIVE_CLIENT}/MEMORY/`

Required Files:

- [ ] CUSTOMER_RULES.md
- [ ] VENDOR_RULES.md
- [ ] LEARNED_PATTERNS.md
- [ ] OPEN_TASKS.md
- [ ] TODAY.md

If any are missing: **WARNING** — System can operate but memory is incomplete.

---

# Output Validation

Expected Location: `clients/${ACTIVE_CLIENT}/OUTPUTS/`

Required Directories:

- [ ] drafts
- [ ] reports
- [ ] summaries

If any are missing: **WARNING** — Outputs may not be saved correctly.

---

# Service Validation (Configuration-Aware)

## PostgreSQL

Required if: `RAG_ENABLED=true`

Check: Docker container "postgres" running.

If missing: **FAIL**

## Ollama

Required if: `AI_PROVIDER=ollama` OR `LOCAL_LLM_ENABLED=true` OR `EMBEDDING_PROVIDER=ollama`

Check: `systemctl is-active ollama` returns "active".

If not required: **SKIPPED**

If required and missing: **FAIL**

## OpenClaw API Key

Required if: `AI_PROVIDER=openclaw_api`

Check: `OPENCLAW_API_KEY` is set and non-empty in `.env`.

If missing: **FAIL**

## n8n

Required if: `WORKFLOW_ENGINE=n8n`

Check: Docker container "n8n" running.

If not required: **SKIPPED**

If required and missing: **FAIL**

## Dashboard (Open WebUI)

Required if: `DASHBOARD_ENABLED=true`

Check: Docker container "openwebui" running.

If not required: **SKIPPED**

If required and missing: **FAIL**

## Obsidian Vault Path

Required if: `OBSIDIAN_ENABLED=true`

Check: `OBSIDIAN_VAULT_PATH` directory exists.

If missing: **WARNING**

---

# pgvector Validation

Required if: `RAG_ENABLED=true`

## Container Image Check

- [ ] Postgres container uses `pgvector/pgvector:pg16`

If container uses `postgres:16`: **WARNING** — pgvector may not be available.

## Extension Check

Query:
```sql
SELECT extname FROM pg_extension WHERE extname='vector';
```

- [ ] pgvector extension active

If not found: **FAIL** — RAG cannot function without vector extension.

---

# RAG Schema Validation

Required if: `RAG_ENABLED=true`

## Schema File

- [ ] `vector-db/schema.sql` exists

## Tables Deployed

Query:
```sql
SELECT COUNT(*) FROM information_schema.tables
WHERE table_name IN ('rag_documents', 'rag_chunks');
```

- [ ] `rag_documents` table exists
- [ ] `rag_chunks` table exists

## Embedding Dimension

Expected: `vector(${EMBEDDING_DIMENSIONS})` column in `rag_chunks`.

## Embeddings Present

Query:
```sql
SELECT COUNT(*) FROM rag_chunks;
```

- [ ] At least 1 chunk indexed

If tables missing: **FAIL**

If no embeddings: **WARNING** — Knowledge retrieval unavailable. Run `index_vault.py`.

---

# RAG Scripts Validation

Required if: `RAG_ENABLED=true`

- [ ] `vector-db/index_vault.py` exists
- [ ] `vector-db/query_vault.py` exists
- [ ] `vector-db/venv/` exists

If missing: **WARNING** — RAG indexing/query unavailable.

---

# Obsidian Integration Validation

Required if: `OBSIDIAN_ENABLED=true`

- [ ] `admin/OBSIDIAN_SETUP.md` exists
- [ ] `OBSIDIAN_VAULT_PATH` directory exists
- [ ] Vault path points to client directory (not admin/logs/docker/backups)

If missing: **WARNING**

---

# Startup Decision

## PASS

All required files, directories, and services present based on current `.env` configuration.

Startup approved.

## WARNING

Startup permitted. Non-critical components missing. Review recommended.

Examples:
- Memory files incomplete
- Output directories missing
- No embeddings indexed yet
- Vault subdirectories missing

## FAIL

Startup denied. Critical components missing.

Examples:
- .env missing
- System files missing
- Active client files missing
- Required services not running
- pgvector extension not active
- RAG tables not deployed

---

# Validation Report Template

```
Date:
Active Client:
Configuration: AI_PROVIDER / EMBEDDING_PROVIDER / RAG_ENABLED
Status: PASS / WARNING / FAIL

Directories:    ✅/❌
System Files:   ✅/❌
Admin Files:    ✅/❌
Vault:          ✅/❌
Client Files:   ✅/❌
Services:       ✅/❌
pgvector:       ✅/❌
RAG Schema:     ✅/❌
RAG Scripts:    ✅/❌
Embeddings:     ✅/❌
Obsidian:       ✅/❌ (if enabled)

Missing Items:

Warnings:

Next Actions:
```
