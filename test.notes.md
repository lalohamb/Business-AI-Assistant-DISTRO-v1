# Business Assistant Box — Session Notes

## Bug Fixes Applied

### 1. Port 3000 Crash-Loop (Open WebUI)

**Root Cause:** The install script's Phase 12 (Register RAG Filter) inserted the `business_knowledge_rag` function into SQLite using `datetime("now")`, which writes a string like `'2026-07-11 05:46:35'`. The current version of Open WebUI expects `updated_at` and `created_at` to be **Unix integer timestamps**. This caused a Pydantic validation error on every startup → crash loop (7 restarts).

**Error:**
```
pydantic_core._pydantic_core.ValidationError: 2 validation errors for FunctionModel
updated_at — Input should be a valid integer, unable to parse string as an integer
created_at — Input should be a valid integer, unable to parse string as an integer
Application startup failed. Exiting.
```

**Fix:** Updated timestamps from string to integer inside the container's SQLite DB:
```bash
docker exec openwebui python3 -c "
import sqlite3, time
conn = sqlite3.connect('/app/backend/data/webui.db')
cur = conn.cursor()
now_ts = int(time.time())
cur.execute('UPDATE function SET updated_at = ?, created_at = ? WHERE id = ?', (now_ts, now_ts, 'business_knowledge_rag'))
conn.commit()
conn.close()
"
docker restart openwebui
```

**Permanent fix:** Patched `install.sh` and `configure_rag_pipeline.sh` to use `int(time.time())` instead of `datetime("now")`.

---

### 2. RAG Query Returning Empty Results

**Root Cause:** The `ivfflat` index was created with default `lists=100` but only 261 rows exist. ivfflat needs significantly more rows than lists to return results. Queries using the index returned nothing; bypassing it worked fine.

**Fix:** Dropped and recreated the index with appropriate list count:
```sql
DROP INDEX IF EXISTS idx_chunks_embedding;
CREATE INDEX idx_chunks_embedding ON rag_chunks
  USING ivfflat (embedding vector_cosine_ops) WITH (lists = 16);
```

**Note:** The install script's `schema.sql` should also be updated to either skip the index at creation time or use HNSW instead.

---

### 3. psycopg2 Not Persistent in Container

**Issue:** `pip install psycopg2-binary` inside the container is lost on every restart. The RAG filter imports psycopg2 on load.

**Proper fix options:**
- Build a custom Docker image with psycopg2 baked in
- Add a startup script/entrypoint wrapper that installs it on boot

---

## End-to-End Test Results (All Passing)

| # | Test | Status |
|---|------|--------|
| 1 | Open WebUI (port 3000) | ✅ HTTP 200 |
| 2 | Ollama API (port 11434) | ✅ v0.13.5 |
| 3 | PostgreSQL | ✅ accepting connections |
| 4 | pgvector extension | ✅ enabled |
| 5 | RAG chunks in DB | ✅ 261 chunks (insurance-agency) |
| 6 | n8n (port 5678) | ✅ HTTP 200 |
| 7 | WebUI → Ollama | ✅ connected |
| 8 | WebUI → PostgreSQL | ✅ 261 chunks accessible |
| 9 | Embedding generation | ✅ 768 dimensions |
| 10 | End-to-end RAG query | ✅ fixed |
| 11 | RAG filter registered | ✅ active=1, global=1 |
| 12 | All ports open | ✅ 11434, 3000, 5678, 5432 |

---

## What's Already Working Well

- Knowledge files are solid — CLIENT_PROFILE, BUSINESS_KNOWLEDGE, FAQ, OWNER_PREFERENCES are detailed and insurance-specific
- RAG pipeline works — 261 chunks indexed, retrieval confirmed working
- n8n workflows exist — email triage, daily briefing, RAG query, approval router all defined
- System files are comprehensive — AGENTS, IDENTITY, POLICIES, TOOLS, HEARTBEAT, PROMPTS all populated
- Chunking is smart — splits on markdown `---` and `##` boundaries, preserves section context
- Embedding includes source context — `[Source: {title} for {client}]` prefix improves relevance

---

## Improvement Opportunities

### 1. No System Prompt Set in Open WebUI ⭐⭐⭐⭐⭐

The model doesn't persistently know it's "Pinnacle Insurance Group's assistant." The system files (AGENTS.md, IDENTITY.md) are indexed as RAG chunks but only surface if the user's question is semantically similar to identity content. For most business questions, the top 5 chunks will be business data — the model never sees its own rules.

**Action:** Open WebUI → Admin → Settings → Interface → Default System Prompt, paste:

> You are the Business Assistant for Pinnacle Insurance Group, an independent insurance agency in Fort Worth, TX. You report to Sandra Mitchell (Owner).
>
> Be professional, warm, concise. Use plain English. Summaries first, details on request. Cite your source document when answering from business knowledge.
>
> Rules: Never send emails, delete records, move money, or sign anything without approval. Never fabricate facts. Escalate legal threats, security incidents, fraud immediately. Claims over $25K — Sandra handles personally. Commercial policies — Sandra reviews before binding. Always quote minimum 3 carriers.
>
> When presenting options use: Option A (Recommended), Option B (Alternative), Option C (Needs More Info). End actionable responses with "Would you like me to proceed?" or "Shall I draft this?"
>
> Staff: Kevin Park (Ops), Tanya Brooks (Sales), Maria Gonzalez (Admin). Systems: HawkSoft, EZLynx, QuickBooks, Microsoft 365, RingCentral. Service area: Fort Worth, Arlington, Southlake, Keller TX.

---

### 2. RAG Filter Context Prefix Allows Hallucination ⭐⭐⭐⭐

**Current prefix:**
```
Use the following business knowledge to answer. If the context doesn't help, answer normally.
```

"Answer normally" gives the model permission to hallucinate.

**Better prefix:**
```
You are answering as Pinnacle Insurance Group's Business Assistant. Use ONLY the following verified business knowledge. Cite the source file. If the answer isn't in the context, say "I don't have that information in our records."
```

**Action:** Edit `dashboard/functions/business_rag_filter.py`, change the `prefix =` line in the `inlet` method.

**File location:** `/home/ubuntu/.business-assistant-box/business-assistant-box/dashboard/functions/business_rag_filter.py`
(mounted into container at `/app/backend/data/functions/business_rag_filter.py`)

---

### 3. RAG Filter Retrieves Only 5 Chunks ⭐⭐⭐

5 chunks × 512 chars = ~2,500 chars of context. For multi-topic questions this isn't enough.

**Action:** Open WebUI → Admin → Functions → Business Knowledge RAG → Valves → set `top_k` to **8**

---

### 4. index_vault.py Only Indexes .md and .txt Files ⭐⭐⭐⭐

The `get_files()` function filters to `ext in (".md", ".txt")` only. The docs claim PDF/DOCX/XLSX support, and the dependencies (pymupdf, python-docx, openpyxl, beautifulsoup4) are installed — but the actual extraction code for those formats is **missing** from index_vault.py.

**Action:** Add file extraction functions and expand the extension filter in `get_files()`.

---

### 5. n8n Workflows Use Gemini but Open WebUI Uses Ollama ⭐⭐⭐

- n8n workflows (email-triage, daily-briefing, rag-query) call `gemini-2.0-flash` via Google API
- Chat interface uses Ollama (`qwen3:14b`)
- No consistency between them
- `GOOGLE_API_KEY` in `.env` is **empty** — workflows can't run yet

**Action:** Either set up the Google API key, or modify n8n workflows to use Ollama (`http://host.docker.internal:11434/api/generate`).

---

### 6. No Real Documents Indexed ⭐⭐⭐⭐

`clients/insurance-agency/DOCUMENTS/` has 6 empty subdirectories. The assistant has no actual contracts, handbooks, carrier appointment letters, or financial docs to reference.

**Action:** Drop real business documents there and re-index:
```bash
./vector-db/venv/bin/python3 ./vector-db/index_vault.py
```

---

### 7. Empty Operational Memory (TODAY.md, OPEN_TASKS.md) ⭐⭐

These are blank templates. The assistant can't help with "what's on my plate today?" without data.

**Action:** Either populate manually each day, or add a step to the daily-briefing n8n workflow that writes output to `clients/insurance-agency/MEMORY/TODAY.md` and re-indexes.

---

## Priority Action Summary

| # | Action | Where | Effort | Impact |
|---|--------|-------|--------|--------|
| 1 | Set system prompt in Open WebUI | Admin → Settings → Interface | 2 min | ⭐⭐⭐⭐⭐ |
| 2 | Change RAG prefix to prevent hallucination | `business_rag_filter.py` | 5 min | ⭐⭐⭐⭐ |
| 3 | Increase top_k to 8 | RAG filter valves in Open WebUI | 1 min | ⭐⭐⭐ |
| 4 | Add PDF/DOCX extraction to index_vault.py | `vector-db/index_vault.py` | 1 hr | ⭐⭐⭐⭐ |
| 5 | Set GOOGLE_API_KEY or switch workflows to Ollama | `.env` or n8n workflow JSONs | 30 min | ⭐⭐⭐ |
| 6 | Add real documents to DOCUMENTS/ and re-index | File system | 30 min | ⭐⭐⭐⭐ |
| 7 | Wire daily-briefing output → TODAY.md | n8n workflow | 1 hr | ⭐⭐ |

---

## Knowledge Improvement Quick Reference

### Adding Knowledge Files

| Location | Use For |
|----------|---------|
| `clients/{client}/DOCUMENTS/` | Client-specific docs (contracts, invoices, correspondence) |
| `clients/{client}/MEMORY/` | Learned patterns, open tasks, daily state |
| `clients/{client}/PROCEDURES/` | Workflow definitions (email, calendar, intake, briefing) |

### Re-indexing After Changes
```bash
./vector-db/venv/bin/python3 ./vector-db/index_vault.py
```

### Supported Formats (currently)
`.md`, `.txt`

### Formats Needing Extraction Code Added
`.pdf`, `.docx`, `.xlsx`, `.csv`, `.html`, `.eml`
