# RAG System Design — Decisions, Fixes & Fresh Install Guide

## Purpose

This document explains every design decision made in the RAG pipeline, why each fix was applied,
and what a fresh install must do correctly to avoid breaking the system. Use this as the
authoritative reference when debugging, upgrading, or reinstalling.

---

## System Overview

```
Client .md files (clients/insurance-agency/)
      ↓
index_vault.py  →  PostgreSQL rag_chunks table (pgvector, 1024-dim vectors)
                          ↓
User asks question in Open WebUI (port 3000)
      ↓
business_rag_filter.py (Open WebUI Filter Function)
  → embeds question via Ollama snowflake-arctic-embed:335m
  → queries pgvector with cosine similarity + boost scoring
  → injects top-16 chunks as context into the prompt
      ↓
Ollama llama3.2:latest generates answer using injected context
      ↓
User sees answer citing source files
```

---

## Component Map

| Component | Location | Purpose |
|-----------|----------|---------|
| `schema.sql` | `vector-db/schema.sql` | Defines `rag_documents` + `rag_chunks` tables with `vector(1024)` |
| `index_vault.py` | `vector-db/index_vault.py` | Reads `.md`/`.txt` files, chunks them, embeds via Ollama, writes to pgvector |
| `query_vault.py` | `vector-db/query_vault.py` | CLI diagnostic tool — test RAG without going through WebUI |
| `business_rag_filter.py` | `dashboard/functions/` | Open WebUI Filter — intercepts every chat message, injects RAG context |
| `install.sh` Phase 7B | `admin/install.sh` | Deploys `schema.sql` to PostgreSQL |
| `install.sh` Phase 8 | `admin/install.sh` | Creates Python venv, installs `psycopg2-binary`, `python-dotenv`, `requests` |
| `install.sh` Phase 8B | `admin/install.sh` | Writes `index_vault.py` and `query_vault.py` via heredoc |
| `install.sh` Phase 10 | `admin/install.sh` | Writes `business_rag_filter.py` via heredoc |
| `install.sh` Phase 11 | `admin/install.sh` | Runs `index_vault.py` to index the active client |
| `install.sh` Phase 12 | `admin/install.sh` | Registers filter in WebUI DB, sets system prompt on model table |
| `configure_rag_pipeline.sh` | `admin/configure_rag_pipeline.sh` | Re-syncs RAG filter, valves, and embedding model default in WebUI DB without full reinstall |
| `switch_embedding.sh` | `admin/switch_embedding.sh` | Switches embedding model atomically: pulls model, updates `.env`, rebuilds schema, re-indexes, updates filter |

---

## Embedding Model

**Model:** `snowflake-arctic-embed:335m`
**Dimensions:** 1024
**Provider:** Ollama (local, no cloud)

### Why this model

- Retrieval-focused architecture — designed for semantic search, not generation
- 1024 dimensions gives better discrimination than 768-dim models
- Available via Ollama with no API key

### Why NOT `nomic-embed-text`

Early versions defaulted to `nomic-embed-text` (768 dims). This caused silent failures:
- Schema built with `vector(768)` but queries used 1024-dim embeddings → dimension mismatch error
- All RAG queries returned empty results
- The mismatch was invisible — no error message, just no context injected

### Critical rule

**The embedding model must be consistent across all 4 places:**

| Place | Setting |
|-------|---------|
| `.env` `EMBEDDING_MODEL` | `snowflake-arctic-embed:335m` |
| `schema.sql` `vector(N)` | `1024` |
| `business_rag_filter.py` valve default | `snowflake-arctic-embed:335m` |
| `index_vault.py` default | `snowflake-arctic-embed:335m` |

If any one of these differs, RAG silently breaks. The installer infers `EMBEDDING_DIMENSIONS`
from `EMBEDDING_MODEL` if not set — but only for known models. Always set both in `.env`.

---

## PostgreSQL / pgvector

**Image:** `pgvector/pgvector:pg16` (NOT `postgres:16`)
**Port binding:** `-p 5432:5432` (NOT `-p 127.0.0.1:5432:5432`)

### Why pgvector image matters

`postgres:16` does not include the pgvector extension. `CREATE EXTENSION vector` will fail
silently or error. Always use `pgvector/pgvector:pg16`.

### Why port binding matters

`-p 127.0.0.1:5432:5432` binds PostgreSQL to localhost only. Docker containers connect via
the bridge network (172.17.0.x), not 127.0.0.1. The RAG filter runs inside the `openwebui`
container and connects to `host.docker.internal:5432`. With localhost-only binding, every
psycopg2 connection silently fails — no error shown to the user, just no RAG context.

**Fix:** Use `-p 5432:5432` and control external access via UFW firewall instead.

### Schema dimensions

`schema.sql` contains `embedding vector(1024)`. This must match `EMBEDDING_DIMENSIONS` in `.env`.

Phase 7B of `install.sh` skips writing `schema.sql` if the existing file already has the
correct dimensions — this prevents unnecessary SAFE_MODE prompts on reinstall.

If you change embedding models, you must:
1. Update `.env` (`EMBEDDING_MODEL`, `EMBEDDING_DIMENSIONS`)
2. Run `./admin/switch_embedding.sh` — handles schema rebuild + re-index atomically

---

## RAG Filter (`business_rag_filter.py`)

### How it works

The filter is an Open WebUI "Filter Function" — it intercepts every incoming chat message
before it reaches the LLM. On each message:

1. Embeds the user's question via Ollama
2. Queries `rag_chunks` with cosine similarity
3. Applies a boost score to prioritize key client files
4. Injects the top-16 chunks as context into the message
5. Prepends a system instruction naming the business and telling the model to answer from context

### Boost scoring

Raw cosine similarity scores are flat with `snowflake-arctic-embed:335m` — relevant chunks
score 0.60-0.78 with no sharp cliff. System files (TOOLS.md, AGENTS.md) often outscore
client files on business queries because they contain more generic business language.

To counteract this, the filter applies score boosts:

```sql
+ CASE
    WHEN title IN ('BUSINESS_PROFILE.md','BUSINESS_KNOWLEDGE.md','FAQ.md','OWNER_PREFERENCES.md') THEN 0.08
    WHEN source_path LIKE 'clients/%' THEN 0.04
    ELSE 0.0
  END
```

This ensures key client knowledge files surface above generic system files.

### top_k history

| Version | top_k | Reason |
|---------|-------|--------|
| v0.1-0.2 | 5 | Initial default |
| v0.3 | 8 | More context for multi-topic answers |
| v0.5 | 12 | System files consuming top-8 slots; positions 9-12 still scoring 0.60-0.69 |
| Current | 16 | BUSINESS_PROFILE.md chunks scoring below position 12 on name queries |

### similarity_threshold history

| Version | Threshold | Reason |
|---------|-----------|--------|
| v0.1-0.4 | 0.3 | Initial default |
| v0.5 | 0.15 | snowflake-arctic-embed:335m scores relevant chunks at 0.60-0.78; 0.3 was not the issue but 0.15 gives headroom |

### Dynamic business name

The filter reads the business name from `rag_chunks` at runtime:

```python
def _get_business_name(self) -> str:
    # Queries: SELECT chunk_text FROM rag_chunks WHERE title = 'BUSINESS_PROFILE.md' ORDER BY id ASC LIMIT 1
    # Parses: line containing "Company Name:"
    # Fallback: "your business"
```

This means:
- No hardcoded business name anywhere in code
- Automatically correct after switching clients and re-indexing
- Works on fresh install as long as Phase 11 (indexing) ran before Phase 12 (filter registration)

**Important:** Phase 11 must complete before Phase 12 for `_get_business_name()` to return
the correct name. The install order guarantees this.

### Registration in WebUI

The filter is stored in Open WebUI's SQLite database (`dashboard/webui.db`) in the `function`
table with:
- `id = 'business_knowledge_rag'`
- `is_active = 1`
- `is_global = 1` (applies to all chats, all models)

Open WebUI can reset `is_global` to 0 on restart. Phase 12 re-enforces `is_global=1` after
restarting the container. The `update_containers.sh` script also re-enforces this.

---

## System Prompt

**Location:** `model` table in `dashboard/webui.db`, row `id = 'llama3.2:latest'`

### Why NOT the config table

Open WebUI's `config` table has a `ui.default_system_prompt` key. Current versions of
Open WebUI ignore this entirely. The system prompt must be written to the `model` table
with `base_model_id` matching the Ollama model name.

### What it contains

```
You are the Business Assistant for {business_name}. You help the business owner manage
daily operations, answer questions from company knowledge, and draft communications.
Be professional, concise, and helpful. Use plain English. Cite your source document
when answering from business knowledge. Rules: Never send emails, delete records, move
money, or sign anything without approval. Never fabricate facts. If you do not have the
information, say so. Escalate legal threats, security incidents, and fraud immediately.
```

### How business_name is set in install.sh Phase 12

Phase 12 runs a Python script inside the `openwebui` container. The business name is read
from `BUSINESS_PROFILE.md` on the **host filesystem** (not inside the container). The path
is passed as a shell variable expansion:

```bash
profile_path = os.path.join('${BASE_PATH}', 'clients', '${ACTIVE_CLIENT}', 'BUSINESS_PROFILE.md')
```

**Critical:** `BASE_PATH` and `ACTIVE_CLIENT` must be shell-expanded before the string is
passed to `docker exec`. Using `os.environ.get('BASE_PATH')` inside the container fails
because those env vars don't exist inside the container.

---

## Python venv

**Location:** `vector-db/venv/`
**Created by:** Phase 8 of `install.sh`

### Packages installed

| Package | Purpose |
|---------|---------|
| `psycopg2-binary` | PostgreSQL connection |
| `python-dotenv` | Reads `.env` |
| `requests` | Calls Ollama embedding API |

### Packages intentionally NOT installed

| Package | Why removed |
|---------|-------------|
| `llama-index` | Not used — caused 10+ minute hang during install |
| `llama-index-readers-file` | Not used — same issue |

`index_vault.py` and `query_vault.py` connect directly to pgvector via `psycopg2` and
call Ollama via `requests`. No LlamaIndex framework is needed.

### venv rebuild

If the venv is missing or broken:
```bash
python3 -m venv vector-db/venv
vector-db/venv/bin/pip install psycopg2-binary python-dotenv requests
```

---

## Chunking Strategy

**Chunk size:** 512 characters
**Overlap:** 64 characters

### Why character-based not token-based

Simple, no tokenizer dependency, consistent across all file types.

### Known limitation

512-char chunks can split key facts across chunk boundaries. For example, "Company Name:
Pinnacle Insurance Group" may land in a chunk that scores poorly for "what is the business
name" queries because the surrounding context is unrelated.

**Mitigation:** The `BUSINESS_PROFILE.md` file has an identity sentence at the top:
```
The business name is Pinnacle Insurance Group. The owner is Sandra Mitchell...
```
This ensures the first chunk of the file contains the key facts in plain language that
scores well for identity queries.

---

## Score Distribution (snowflake-arctic-embed:335m)

This model produces a flat score distribution — relevant and irrelevant chunks score
similarly. Example for query "what is the business name":

```
[0.7130] DOCUMENTS.md       ← irrelevant, high score
[0.7000] AGENTS.md          ← irrelevant, high score
[0.6955] CALENDAR.md        ← irrelevant
[0.6919] BUSINESS_KNOWLEDGE.md  ← relevant, but wrong chunk
[0.6051] BUSINESS_PROFILE.md  ← relevant, low score
```

This is why:
- `top_k=16` is needed (not 5 or 8)
- Boost scoring is needed (to surface client files above system files)
- `similarity_threshold=0.15` is used (not 0.3 — would cut off valid chunks)

---

## Fresh Install Checklist

These are the things most likely to break on a fresh install and why:

| Risk | Cause | Prevention |
|------|-------|-----------|
| Wrong embedding dimensions | `.env` has `EMBEDDING_MODEL` but not `EMBEDDING_DIMENSIONS` | Installer infers dims from model name — verify after install |
| pgvector extension missing | Using `postgres:16` image instead of `pgvector/pgvector:pg16` | Phase 3 uses correct image; Phase 7 validates extension |
| RAG filter not global | WebUI resets `is_global=0` on restart | Phase 12 re-enforces after restart; check with e2e_validate.sh |
| System prompt says "your business" | `BASE_PATH`/`ACTIVE_CLIENT` not expanded in docker exec | Fixed in Phase 12 — uses shell expansion not os.environ |
| No chunks indexed | Phase 11 skipped or failed | Run `./vector-db/venv/bin/python3 ./vector-db/index_vault.py` manually |
| psycopg2 missing in container | Container recreated without reinstalling | `requirements: psycopg2-binary` in filter frontmatter auto-installs it |
| n8n workflows not active | Restart needed after publish | Phase 6A2 restarts n8n after activation |
| venv missing | pip killed mid-install (llama-index hang) | llama-index removed from Phase 8; venv builds in <60s now |
| Business name wrong in system prompt | BUSINESS_PROFILE.md not yet indexed when Phase 12 runs | Phase 11 (index) always runs before Phase 12 (register filter) |

---

## Validation

Run after every install or change:

```bash
# Full e2e validation (all phases)
./admin/e2e_validate.sh --no-pause

# Quick RAG test from terminal (bypasses WebUI)
./vector-db/venv/bin/python3 ./vector-db/query_vault.py "what is the business name"
./vector-db/venv/bin/python3 ./vector-db/query_vault.py "what products do you offer"
./vector-db/venv/bin/python3 ./vector-db/query_vault.py "who is the owner"

# Check chunk count
docker exec -i postgres psql -U admin businessassistant -t -c \
  "SELECT title, COUNT(*) FROM rag_chunks WHERE client_name='insurance-agency' GROUP BY title ORDER BY COUNT(*) DESC;"

# Check filter status in WebUI DB
docker exec openwebui python3 -c "
import sqlite3
conn = sqlite3.connect('/app/backend/data/webui.db')
cur = conn.cursor()
cur.execute('SELECT is_active, is_global FROM function WHERE id=\"business_knowledge_rag\"')
print(cur.fetchone())
conn.close()
"
```

---

## Switching Clients

```bash
./admin/switch_client.sh <client-name>
```

This script:
1. Updates `ACTIVE_CLIENT` in `.env`
2. Updates the `current-client` symlink
3. Re-indexes the new client's files into pgvector
4. Updates the RAG filter's `active_client` valve in WebUI DB
5. Updates the system prompt with the new client's business name

After switching, the filter's `_get_business_name()` will automatically return the new
client's name on the next query.

---

## Switching Embedding Models

```bash
./admin/switch_embedding.sh
```

This script handles the full migration atomically:
1. Pulls the new model via Ollama
2. Updates `.env` (`EMBEDDING_MODEL`, `EMBEDDING_DIMENSIONS`)
3. Drops and recreates the schema with new vector dimensions
4. Re-indexes all client files with the new model
5. Updates the filter's `embedding_model` valve in WebUI DB

**Never change `EMBEDDING_MODEL` in `.env` manually without running this script.**
The schema dimensions and indexed vectors must always match the active embedding model.

---

## Key Files Reference

| File | Do not change without... |
|------|--------------------------|
| `vector-db/schema.sql` | Running `switch_embedding.sh` if changing dimensions |
| `dashboard/functions/business_rag_filter.py` | Re-deploying to WebUI DB (Phase 12 or manually) |
| `admin/install.sh` Phase 10 heredoc | Keeping in sync with `business_rag_filter.py` |
| `.env` `EMBEDDING_MODEL` | Running `switch_embedding.sh` |
| `clients/{client}/BUSINESS_PROFILE.md` | Re-running `index_vault.py` |
