# RAG Pipeline — Build Workflow

## What "building the RAG" means

Building the RAG means taking the client's `.md` and `.txt` files and loading them into
PostgreSQL as searchable vector embeddings. After the build, every chat message in Open WebUI
is automatically enriched with relevant business context before it reaches the LLM.

---

## Build Workflow (step by step)

### Step 1 — Schema creation (Phase 7B of install.sh)

`schema.sql` is applied to the PostgreSQL container once during install.

What it creates:

- `rag_documents` — one row per source file (client_name, source_path, title)
- `rag_chunks` — one row per text chunk, with a `vector(1024)` embedding column
- `idx_chunks_client` — a plain B-tree index on `client_name` for fast filtering

What it does NOT create: the vector index. That is deferred to Step 3.

```
schema.sql  →  psql  →  rag_documents table + rag_chunks table
```

Phase 7B skips writing `schema.sql` if the existing file already has the correct
embedding dimensions — prevents unnecessary reinstall prompts.

---

### Step 2 — Python venv setup (Phase 8 of install.sh)

A Python virtual environment is created at `vector-db/venv/` with three packages:

| Package | Purpose |
|---------|---------|
| `psycopg2-binary` | PostgreSQL connection |
| `python-dotenv` | Reads `.env` for DB credentials and model settings |
| `requests` | Calls Ollama embedding API |

No LlamaIndex or other framework. The scripts connect directly to pgvector and Ollama.

---

### Step 3 — Indexing (Phase 11 of install.sh → index_vault.py)

`index_vault.py` is the core build script. It runs once per client and can be re-run
any time client files change.

**What it reads from `.env`:**

| Variable | Default |
|----------|---------|
| `BASE_PATH` | path to project root |
| `ACTIVE_CLIENT` | e.g. `insurance-agency` |
| `EMBEDDING_MODEL` | `snowflake-arctic-embed:335m` |
| `OLLAMA_BASE_URL` | `http://localhost:11434` |
| `PG_HOST`, `PG_PORT`, `PG_USER`, `PG_PASSWORD`, `PG_DATABASE` | DB credentials |

**What it indexes:**

- `system/` — all `.md` and `.txt` files (AGENTS.md, TOOLS.md, POLICIES.md, etc.)
- `clients/<ACTIVE_CLIENT>/` — all `.md` and `.txt` files (BUSINESS_PROFILE.md, BUSINESS_KNOWLEDGE.md, etc.)

Excluded: `admin/`, `logs/`, `backups/`, `docker/`, `postgres/`, `venv/`, `.env`, `.key`, `.pem`

**Processing each file:**

```
Read file content
      ↓
chunk_text() — split into 512-char chunks with 64-char overlap
      ↓
For each chunk:
  POST /api/embeddings to Ollama  →  1024-dim float vector
      ↓
  INSERT into rag_documents (one row per file)
  INSERT into rag_chunks (one row per chunk + embedding)
```

**After all chunks are inserted:**

```
SELECT COUNT(*) FROM rag_chunks WHERE client_name = <ACTIVE_CLIENT>
      ↓
lists = max(1, int(row_count ** 0.5))   # e.g. 98 chunks → lists=9
      ↓
DROP INDEX IF EXISTS idx_chunks_embedding
CREATE INDEX idx_chunks_embedding ON rag_chunks
  USING ivfflat (embedding vector_cosine_ops) WITH (lists=<lists>)
```

The ivfflat index is built AFTER insertion with a `lists` value sized to the actual
row count. Building it before insertion or with the wrong `lists` value produces a
broken index that silently degrades retrieval quality.

**Console output on success:**
```
Found 22 files to index.
  Indexed: system/AGENTS.md (4 chunks)
  Indexed: clients/insurance-agency/BUSINESS_PROFILE.md (2 chunks)
  ...
  Vector index rebuilt (lists=9, 98 chunks)
Indexing complete.
```

---

### Step 4 — Filter registration (Phase 12 of install.sh)

`business_rag_filter.py` is written to `dashboard/functions/` by Phase 10, then
registered in Open WebUI's SQLite database by Phase 12.

Phase 12 does three things:

1. Inserts/updates the filter in the `function` table of `webui.db`
   - `id = 'business_knowledge_rag'`
   - `is_active = 1`
   - `is_global = 1` (applies to all chats, all models)

2. Reads the business name from `BUSINESS_PROFILE.md` on the host filesystem and writes
   the system prompt to the `model` table in `webui.db` for `llama3.2:latest`

3. Restarts the `openwebui` container so the filter is loaded

**Why Phase 11 must run before Phase 12:**
`_get_business_name()` in the filter queries `rag_chunks` at runtime. If Phase 12 runs
before Phase 11, the table is empty and the business name falls back to `"your business"`.

---

## Runtime flow (after build)

Every chat message in Open WebUI goes through this path:

```
User types question
      ↓
business_rag_filter.py — inlet()
  1. Embed question via Ollama (snowflake-arctic-embed:335m)
  2. Query rag_chunks with cosine similarity + boost scoring
  3. Return top 16 chunks above similarity_threshold=0.15
  4. Prepend context block + system instruction to message
      ↓
Ollama llama3.2:latest — generates answer using injected context
      ↓
User sees answer citing source files
```

`query_vault.py` is a CLI shortcut that runs steps 1-3 only — useful for testing
retrieval without going through Open WebUI.

---

## Re-indexing (after editing client files)

```bash
cd /path/to/business-assistant-box
./vector-db/venv/bin/python3 ./vector-db/index_vault.py
```

This clears all existing chunks for `ACTIVE_CLIENT` and rebuilds from scratch.
The ivfflat index is automatically rebuilt at the end with the correct `lists` value.

---

## Component roles summary

| File | Role | When it runs |
|------|------|-------------|
| `vector-db/schema.sql` | Creates tables | Once at install (Phase 7B) |
| `vector-db/index_vault.py` | Chunks + embeds + indexes files | Phase 11, and on demand |
| `vector-db/query_vault.py` | CLI retrieval test | On demand (debugging only) |
| `dashboard/functions/business_rag_filter.py` | Intercepts chat, injects context | Every chat message at runtime |

---

## Embedding model consistency rule

All four of these must use the same model and dimensions or RAG silently breaks:

| Location | Setting |
|----------|---------|
| `.env` `EMBEDDING_MODEL` | `snowflake-arctic-embed:335m` |
| `schema.sql` `vector(N)` | `1024` |
| `index_vault.py` default | `snowflake-arctic-embed:335m` |
| `business_rag_filter.py` valve default | `snowflake-arctic-embed:335m` |

To change the embedding model, always use `./admin/switch_embedding.sh` — never edit
`.env` manually without also rebuilding the schema and re-indexing.
