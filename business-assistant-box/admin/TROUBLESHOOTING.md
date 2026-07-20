# TROUBLESHOOTING.md

# Business Assistant Box

## Troubleshooting Log

Purpose:

Track installation issues, root causes, resolutions, and lessons learned.

---

## Issue 1 — Open WebUI Crash Loop (Port 3000 Not Responding)

Date: 2026-07-11

Component: Open WebUI (openwebui container)

Phase: Phase 12 — Register RAG Filter

Issue Description: Open WebUI container crash-looping with 7+ restarts. Port 3000 unreachable.

Symptoms:
- `curl http://localhost:3000` returns connection refused
- `docker inspect openwebui` shows `restarts=7`
- Container status: restarting

Error Messages:
```
pydantic_core._pydantic_core.ValidationError: 2 validation errors for FunctionModel
updated_at
  Input should be a valid integer, unable to parse string as an integer
  [input_value='2026-07-11 05:46:35', input_type=str]
created_at
  Input should be a valid integer, unable to parse string as an integer
  [input_value='2026-07-11 05:46:35', input_type=str]
Application startup failed. Exiting.
```

Root Cause: `install.sh` Phase 12 inserted the RAG filter function into SQLite using `datetime("now")` which writes a string like `'2026-07-11 05:46:35'`. The current version of Open WebUI expects `updated_at` and `created_at` to be Unix integer timestamps.

Resolution:
```bash
# Fix from inside the container (has write access to DB)
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

Prevention: `install.sh` and `configure_rag_pipeline.sh` updated to use `int(time.time())` instead of `datetime("now")`.

Status: Resolved

---

## Issue 2 — RAG Query Returns Empty Results

Date: 2026-07-11

Component: PostgreSQL / pgvector

Phase: Phase 11 — Index Client

Issue Description: RAG queries return 0 results despite 261 chunks existing in the database.

Symptoms:
- E2E test "End-to-end RAG query" fails
- `SELECT COUNT(*) FROM rag_chunks` returns 261
- Embeddings are present (768 dimensions, not NULL)
- Disabling index scan returns results correctly

Commands Executed:
```sql
-- This returns results (bypasses index):
SET enable_indexscan = off;
SET enable_bitmapscan = off;
SELECT source_path FROM rag_chunks ORDER BY embedding <=> '[...]'::vector LIMIT 3;

-- This returns nothing (uses broken index):
SELECT source_path FROM rag_chunks ORDER BY embedding <=> '[...]'::vector LIMIT 3;
```

Root Cause: The ivfflat index was created with default `lists=100` in `schema.sql`, but only 261 rows exist. ivfflat requires `rows >> lists` to function. With 261 rows and 100 lists, most lists are empty and queries miss all data.

Resolution:
```sql
DROP INDEX IF EXISTS idx_chunks_embedding;
CREATE INDEX idx_chunks_embedding ON rag_chunks USING ivfflat (embedding vector_cosine_ops) WITH (lists = 16);
```

Prevention:
- `schema.sql` now comments out the index creation (index should be built after data exists)
- `index_vault.py` now rebuilds the index after every re-index with `lists = sqrt(row_count)`

Status: Resolved

---

## Issue 3 — psycopg2 Lost on Container Recreation

Date: 2026-07-11

Component: Open WebUI container / RAG filter

Phase: Phase 12 — Register RAG Filter

Issue Description: `pip install psycopg2-binary` inside the container is lost if the container is recreated (not just restarted).

Symptoms:
- After `docker rm openwebui && docker run ...`, the RAG filter fails silently
- No business context injected into chat
- Container logs may show import errors

Root Cause: Docker containers lose pip-installed packages when recreated. The install script installs psycopg2 at runtime but doesn't persist it.

Resolution: Added `requirements: psycopg2-binary` to the RAG filter's frontmatter:
```python
"""
title: Business Knowledge RAG
...
type: filter
requirements: psycopg2-binary
"""
```

Open WebUI reads this on startup and auto-installs the dependency. Verified in logs:
```
Installing requirements: psycopg2-binary
Requirement already satisfied: psycopg2-binary in /usr/local/lib/python3.11/site-packages
```

Prevention: Updated `install.sh` to include the `requirements:` line in the embedded RAG filter code.

Status: Resolved

---

## Issue 4 — RAG Filter Allows Hallucination

Date: 2026-07-12

Component: RAG filter (business_rag_filter.py)

Phase: Runtime

Issue Description: The model fabricates business information when RAG context doesn't contain the answer.

Symptoms:
- Model gives confident but incorrect answers about business details
- No "I don't know" responses when context is insufficient

Root Cause: The RAG filter prefix said "If the context doesn't help, answer normally" — giving the model explicit permission to use training data (hallucinate).

Resolution: Changed prefix to:
```
You are answering as Pinnacle Insurance Group's Business Assistant. Use ONLY the following verified business knowledge. Cite the source file. If the answer is not in the context below, say 'I don't have that information in our records.'
```

Status: Resolved

---

## Issue 5 — No Persistent System Prompt

Date: 2026-07-12

Component: Open WebUI configuration

Phase: Runtime

Issue Description: The model doesn't know it's "Pinnacle Insurance Group's assistant" unless identity-related RAG chunks happen to be retrieved.

Symptoms:
- Model responds generically without business context
- No consistent personality or rules enforcement
- AGENTS.md and IDENTITY.md only surface for identity-related queries

Root Cause: No `ui.default_system_prompt` was configured in Open WebUI's config database. The identity files were indexed as RAG chunks but competed with business content for the top_k slots.

Resolution: Inserted system prompt into Open WebUI config DB:
```bash
docker exec openwebui python3 -c "
import sqlite3, json, time
prompt = 'You are the Business Assistant for Pinnacle Insurance Group...'
conn = sqlite3.connect('/app/backend/data/webui.db')
cur = conn.cursor()
cur.execute('INSERT INTO config (key, value, updated_at) VALUES (?, ?, ?)',
    ('ui.default_system_prompt', json.dumps(prompt), int(time.time())))
conn.commit()
conn.close()
"
```

Prevention: Added system prompt configuration to `install.sh` Phase 12.

Status: Resolved

---

## Issue 6 — n8n Workflows Can't Run (No Google API Key)

Date: 2026-07-12

Component: n8n workflows

Phase: Automation

Issue Description: All workflows called Gemini API but `GOOGLE_API_KEY` was empty in `.env`.

Symptoms:
- Workflows fail with HTTP 400/403 when triggered
- No AI processing in email triage, daily briefing, etc.

Root Cause: Workflows were designed for Gemini but deployed without an API key. No fallback to local Ollama.

Resolution: Converted all 16 workflows from Gemini to local Ollama:
- URL: `http://host.docker.internal:11434/api/generate`
- Model: `($env.OLLAMA_MODEL || 'qwen3:14b')`
- Response parsing: `$json.response` (instead of `$json.candidates[0].content.parts[0].text`)

Prevention: Workflows now use environment variable `OLLAMA_MODEL` — no external API key needed.

Status: Resolved

---

## Issue 7 — n8n Container Missing OLLAMA_MODEL Environment Variable

Date: 2026-07-12

Component: n8n container

Phase: Automation

Issue Description: Workflows reference `$env.OLLAMA_MODEL` but the variable wasn't passed to the container.

Symptoms:
- Workflows fall back to hardcoded `qwen3:14b` (works but not configurable)

Root Cause: Original `docker run` command for n8n didn't include `-e OLLAMA_MODEL=...`.

Resolution: Recreated n8n container with env var:
```bash
docker stop n8n && docker rm n8n
docker run -d --name n8n \
  --restart unless-stopped \
  --add-host=host.docker.internal:host-gateway \
  -p 5678:5678 \
  -e OLLAMA_MODEL=qwen3:14b \
  -e N8N_BASE_URL=http://localhost:5678 \
  -v "/home/ubuntu/.business-assistant-box/business-assistant-box/n8n:/home/node/.n8n" \
  docker.n8n.io/n8nio/n8n:latest
```

Status: Resolved

---

## Quick Diagnostic Commands

```bash
# Check all services
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Check Open WebUI logs for errors
docker logs openwebui --tail 30 2>&1

# Check if RAG filter is registered and active
docker exec openwebui python3 -c "
import sqlite3
conn = sqlite3.connect('/app/backend/data/webui.db')
cur = conn.cursor()
cur.execute(\"SELECT id, is_active, is_global, updated_at FROM function WHERE id='business_knowledge_rag'\")
print(cur.fetchone())
conn.close()
"

# Check system prompt is set
docker exec openwebui python3 -c "
import sqlite3
conn = sqlite3.connect('/app/backend/data/webui.db')
cur = conn.cursor()
cur.execute(\"SELECT value FROM config WHERE key='ui.default_system_prompt'\")
r = cur.fetchone()
print(f'Set: {bool(r)}, Length: {len(r[0]) if r else 0}')
conn.close()
"

# Test RAG retrieval end-to-end
docker exec openwebui python3 -c "
import psycopg2, requests
resp = requests.post('http://host.docker.internal:11434/api/embeddings', json={'model': 'nomic-embed-text', 'prompt': 'test query'}, timeout=120)
embedding = resp.json()['embedding']
conn = psycopg2.connect(host='host.docker.internal', port=5432, user='admin', password='strongpassword', dbname='businessassistant')
cur = conn.cursor()
cur.execute('SELECT source_path, 1-(embedding <=> %s::vector) FROM rag_chunks ORDER BY embedding <=> %s::vector LIMIT 3', (embedding, embedding))
for r in cur.fetchall(): print(r)
conn.close()
"

# Check chunk count
docker exec -i postgres psql -U admin businessassistant -t -c "SELECT client_name, COUNT(*) FROM rag_chunks GROUP BY client_name;"

# Check n8n has OLLAMA_MODEL
docker exec n8n printenv OLLAMA_MODEL

# Re-index after document changes
cd /home/ubuntu/.business-assistant-box/business-assistant-box
./vector-db/venv/bin/python3 ./vector-db/index_vault.py
```

---

## Issue 8 — System Prompt Silently Ignored

Date: 2026-07-15

Component: Open WebUI configuration / `model` table

Phase: Phase 12 — Register RAG Filter

Issue Description: System prompt set via `ui.default_system_prompt` in the config table had no effect. Model responded generically with no business identity.

Symptoms:
- Model doesn't identify as the business assistant
- No rules enforcement (email approval, no fabrication)
- Config table row exists but is ignored at runtime

Root Cause: Current Open WebUI versions ignore `ui.default_system_prompt` in the config table entirely. The only working mechanism is a row in the `model` table where `id` and `base_model_id` both match the Ollama model name.

Resolution: Write directly to the `model` table:
```bash
docker exec openwebui python3 -c "
import sqlite3, json, time
model_id = 'llama3.2:latest'
prompt = 'You are the Business Assistant for Pinnacle Insurance Group...'
now_ts = int(time.time())
conn = sqlite3.connect('/app/backend/data/webui.db')
cur = conn.cursor()
cur.execute('SELECT id FROM model WHERE id=?', (model_id,))
if cur.fetchone():
    params = json.loads(cur.execute('SELECT params FROM model WHERE id=?', (model_id,)).fetchone()[0] or '{}')
    params['system'] = prompt
    cur.execute('UPDATE model SET params=?, updated_at=? WHERE id=?', (json.dumps(params), now_ts, model_id))
else:
    cur.execute('INSERT INTO model (id, user_id, base_model_id, name, params, meta, is_active, updated_at, created_at) VALUES (?,"system",?,?,?,?,1,?,?)',
        (model_id, model_id, model_id, json.dumps({'system': prompt}), '{}', now_ts, now_ts))
conn.commit()
conn.close()
"
```

Prevention: `install.sh` Phase 12 updated to use the `model` table approach. Business name read from `BUSINESS_PROFILE.md`, model ID from `OLLAMA_MODEL` in `.env`.

Status: Resolved

---

## Issue 9 — Embedding Model Default Mismatch on Fresh Install

Date: 2026-07-15

Component: `install.sh` / RAG pipeline

Phase: Phase 0B (env setup), Phase 7B (schema), Phase 10 (RAG filter)

Issue Description: Fresh install with default choices produced a broken RAG pipeline. The installer menu defaulted to `nomic-embed-text` (768 dims) but the live system used `snowflake-arctic-embed:335m` (1024 dims). Schema was built with 768 dims, filter used wrong model, all RAG queries returned garbage.

Symptoms:
- RAG filter returns no results or irrelevant results on fresh install
- `e2e_validate.sh` Phase 7 fails: "Embedding returns X dims but .env says Y"
- Schema dimension mismatch error in Phase 5

Root Cause: `nomic-embed-text` was hardcoded as the default in 5 separate places: the interactive menu catch-all, the Ollama pull fallback, the pre-warm curl, the RAG filter heredoc, and both Python script heredocs. None were consistent with each other or with the live system.

Resolution: Updated all defaults to `snowflake-arctic-embed:335m` / 1024 dims. Added model-aware dimension inference in `install.sh` so setting only `EMBEDDING_MODEL` in `.env` is sufficient.

Prevention:
- `install.sh` menu reordered: `snowflake-arctic-embed:335m` is option 1 and default
- `EMBEDDING_DIMENSIONS` inferred from model name if not set in `.env`
- `switch_embedding.sh` fallback defaults corrected

Status: Resolved

---

## Issue 10 — RAG top_k=8 Cutting Off Relevant Chunks

Date: 2026-07-15

Component: `business_rag_filter.py` / RAG pipeline

Phase: Runtime

Issue Description: Business queries were missing relevant chunks that ranked at positions 9-12.

Symptoms:
- Model gives incomplete answers on multi-faceted questions
- Known content (e.g. `CUSTOMER_INTAKE.md`, `employee-handbook-summary.md`) not surfacing
- `system/` files (TOOLS.md, AGENTS.md) appearing in top 8 for business queries

Root Cause: `snowflake-arctic-embed:335m` produces a flat score distribution. For the query "What carriers does Pinnacle work with?", positions 9-15 scored 0.569-0.600 — all genuinely relevant client chunks. k=8 cut them off. Additionally, system files scored similarly to client files and consumed top-8 slots.

Resolution: Raised `top_k` from 8 to 12 in `business_rag_filter.py`, `install.sh` heredoc, and `.env`.

Diagnostic command used:
```bash
docker exec openwebui python3 -c "
import requests, psycopg2
resp = requests.post('http://host.docker.internal:11434/api/embeddings', json={'model':'snowflake-arctic-embed:335m','prompt':'What carriers does Pinnacle work with?'}, timeout=60)
emb = resp.json()['embedding']
emb_str = '[' + ','.join(str(x) for x in emb) + ']'
conn = psycopg2.connect(host='host.docker.internal', port=5432, user='admin', password='strongpassword', dbname='businessassistant')
cur = conn.cursor()
cur.execute('SELECT source_path, 1-(embedding <=> %s::vector) FROM rag_chunks WHERE client_name=%s ORDER BY 2 DESC LIMIT 15', (emb_str, 'insurance-agency'))
for i, r in enumerate(cur.fetchall(), 1): print(i, f'{r[1]:.3f}', r[0])
conn.close()
"
```

Status: Resolved

---

## Lessons Learned

1. **Open WebUI expects integer timestamps** — Never use `datetime("now")` in direct SQLite inserts. Always use `int(time.time())`.
2. **ivfflat needs data before index creation** — Create the index AFTER inserting data, with `lists` proportional to `sqrt(row_count)`.
3. **Container pip installs are ephemeral** — Use Open WebUI's `requirements:` frontmatter for persistent dependencies.
4. **RAG prefix wording matters** — "Answer normally" = hallucination. "Say you don't know" = grounded responses.
5. **System prompt ≠ RAG chunks** — Identity/rules must be in the system prompt, not competing with business content for retrieval slots.
6. **Environment variables need explicit passing** — Docker containers don't inherit host env vars. Use `-e VAR=value` on `docker run`.
7. **n8n env vars require container recreation** — `docker restart` doesn't pick up new `-e` flags. Must `docker rm` + `docker run`.
8. **Open WebUI ignores `ui.default_system_prompt`** — Current versions only read system prompts from the `model` table. Always write to `model` with `base_model_id` matching the Ollama model ID.
9. **Embedding model defaults must be consistent everywhere** — The menu default, schema dimensions, RAG filter, and Python scripts must all agree. A single stale default silently breaks the entire RAG pipeline.
10. **`snowflake-arctic-embed:335m` has a flat score distribution** — Scores don't drop sharply after the top result. Use `top_k=12` minimum; `top_k=8` cuts off genuinely relevant chunks at positions 9-12.
11. **Docker postgres binding must be `0.0.0.0`** — `-p 127.0.0.1:5432:5432` blocks Docker container access via the bridge network. Use `-p 5432:5432` and rely on UFW for external blocking.
