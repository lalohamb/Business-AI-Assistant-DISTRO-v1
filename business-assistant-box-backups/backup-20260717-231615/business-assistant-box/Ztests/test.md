# Test Checklist — Business Assistant Box

## Test Order

Tests are ordered by dependency chain. If a lower layer fails, everything above it will also fail.

```
Layer 1: Ollama (foundation — LLM + embeddings)
Layer 2: PostgreSQL + pgvector (storage)
Layer 3: index_vault.py (indexing pipeline)
Layer 4: Open WebUI + RAG filter (chat + retrieval)
Layer 5: n8n (workflow automation)
Layer 6: Client vault (content quality)
Layer 7: End-to-end (full stack integration)
```

---

## Layer 1 — Ollama

| # | Test | Command | Expected |
|---|------|---------|----------|
| 1.1 | Service running | `curl -s http://localhost:11434/api/tags` | JSON with models list |
| 1.2 | Chat model loaded | `curl -s http://localhost:11434/api/tags \| grep qwen3` | Model name appears |
| 1.3 | Embedding model loaded | `curl -s http://localhost:11434/api/tags \| grep nomic-embed-text` | Model name appears |
| 1.4 | Chat completion works | `curl -s http://localhost:11434/api/generate -d '{"model":"qwen3:14b","prompt":"hi","stream":false}'` | JSON with `response` field |
| 1.5 | Embedding generation works | `curl -s http://localhost:11434/api/embeddings -d '{"model":"nomic-embed-text","prompt":"test"}'` | JSON with `embedding` array |
| 1.6 | Embedding dimensions correct | Check array length matches `EMBEDDING_DIMENSIONS` in .env | 768 (or 1024 if changed) |

---

## Layer 2 — PostgreSQL + pgvector

| # | Test | Command | Expected |
|---|------|---------|----------|
| 2.1 | Container running | `docker ps \| grep postgres` | Container up |
| 2.2 | Port accessible | `docker exec postgres pg_isready -U admin` | "accepting connections" |
| 2.3 | Database exists | `docker exec postgres psql -U admin -d businessassistant -c "SELECT 1"` | Returns 1 |
| 2.4 | pgvector extension | `docker exec postgres psql -U admin -d businessassistant -c "SELECT extversion FROM pg_extension WHERE extname='vector'"` | Version number |
| 2.5 | Tables exist | `docker exec postgres psql -U admin -d businessassistant -c "\dt rag_*"` | rag_documents, rag_chunks |
| 2.6 | Vector dimension correct | `docker exec postgres psql -U admin -d businessassistant -c "SELECT atttypmod FROM pg_attribute WHERE attrelid='rag_chunks'::regclass AND attname='embedding'"` | 768 (or configured value) |
| 2.7 | Data present | `docker exec postgres psql -U admin -d businessassistant -c "SELECT count(*) FROM rag_chunks"` | > 0 |
| 2.8 | ivfflat index exists | `docker exec postgres psql -U admin -d businessassistant -c "\di idx_chunks_embedding"` | Index listed |

---

## Layer 3 — index_vault.py

| # | Test | Command | Expected |
|---|------|---------|----------|
| 3.1 | Syntax valid | `python3 -c "import ast; ast.parse(open('vector-db/index_vault.py').read())"` | No error |
| 3.2 | .env loaded | `python3 -c "from dotenv import load_dotenv; load_dotenv('.env'); import os; print(os.getenv('ACTIVE_CLIENT'))"` | Client name |
| 3.3 | File discovery | `python3 -c "exec(open('vector-db/index_vault.py').read().split('def index')[0]); print(len(get_files(INDEX_PATHS)))"` | > 0 files |
| 3.4 | Full index run | `python3 vector-db/index_vault.py` | "Indexing complete." with chunk count |
| 3.5 | Dimension mismatch detection | Change EMBEDDING_DIMENSIONS in .env, run indexer | "Embedding dimensions changed" message |
| 3.6 | Multi-format extraction | Place .pdf/.docx/.xlsx in DOCUMENTS/, re-index | Files indexed without errors |

---

## Layer 4 — Open WebUI + RAG Filter

| # | Test | Command | Expected |
|---|------|---------|----------|
| 4.1 | Container running | `docker ps \| grep openwebui` | Container up |
| 4.2 | Web UI accessible | `curl -s -o /dev/null -w "%{http_code}" http://localhost:3000` | 200 |
| 4.3 | psycopg2 installed | `docker exec openwebui python3 -c "import psycopg2"` | No error |
| 4.4 | Filter registered in DB | `docker exec openwebui python3 -c "import sqlite3; conn=sqlite3.connect('/app/backend/data/webui.db'); cur=conn.cursor(); cur.execute(\"SELECT id,is_active,is_global FROM function WHERE id='business_knowledge_rag'\"); print(cur.fetchone())"` | `('business_knowledge_rag', 1, 1)` |
| 4.5 | Filter code matches disk | Compare `dashboard/functions/business_rag_filter.py` content with DB `content` column | Identical |
| 4.6 | Valves synced | `docker exec openwebui python3 -c "import sqlite3; conn=sqlite3.connect('/app/backend/data/webui.db'); cur=conn.cursor(); cur.execute(\"SELECT valves FROM function WHERE id='business_knowledge_rag'\"); print(cur.fetchone())"` | Contains `embedding_model` matching .env |
| 4.7 | Native RAG config aligned | `docker exec openwebui python3 -c "import sqlite3; conn=sqlite3.connect('/app/backend/data/webui.db'); cur=conn.cursor(); cur.execute(\"SELECT value FROM config WHERE key='rag.embedding_engine'\"); print(cur.fetchone())"` | `"ollama"` |
| 4.8 | Embedding from container | `docker exec openwebui python3 -c "import requests; r=requests.post('http://host.docker.internal:11434/api/embeddings',json={'model':'nomic-embed-text','prompt':'test'},timeout=120); print(len(r.json()['embedding']))"` | 768 |
| 4.9 | pgvector from container | `docker exec openwebui python3 -c "import psycopg2; conn=psycopg2.connect(host='host.docker.internal',port=5432,user='admin',password='strongpassword',dbname='businessassistant'); cur=conn.cursor(); cur.execute('SELECT count(*) FROM rag_chunks'); print(cur.fetchone()[0])"` | > 0 |
| 4.10 | Anti-hallucination prefix | Grep filter code for "Use ONLY the following verified business knowledge" | Present |
| 4.11 | top_k = 8 | Grep filter code for `top_k: int = Field(default=8)` | Present |

---

## Layer 5 — n8n

| # | Test | Command | Expected |
|---|------|---------|----------|
| 5.1 | Container running | `docker ps \| grep n8n` | Container up |
| 5.2 | Web UI accessible | `curl -s -o /dev/null -w "%{http_code}" http://localhost:5678` | 200 |
| 5.3 | OLLAMA_MODEL env set | `docker exec n8n env \| grep OLLAMA_MODEL` | `OLLAMA_MODEL=qwen3:14b` |
| 5.4 | Ollama reachable from n8n | `docker exec n8n curl -s http://host.docker.internal:11434/api/tags` | JSON response |
| 5.5 | Workflows imported | `docker exec n8n ls /home/node/.n8n/` or check n8n API | Workflow files present |
| 5.6 | No Gemini references | `grep -r "generativelanguage.googleapis" n8n/workflows/` | No matches |
| 5.7 | Model uses env var | `grep -l "env.OLLAMA_MODEL" n8n/workflows/standard/*.json n8n/workflows/selectable/*.json \| wc -l` | 16 |
| 5.8 | Daily briefing write-back | Check daily-briefing.json has "Write TODAY.md" node | Present |

---

## Layer 6 — Client Vault

| # | Test | Command | Expected |
|---|------|---------|----------|
| 6.1 | ACTIVE_CLIENT set | `grep ACTIVE_CLIENT .env` | Non-empty value |
| 6.2 | Client folder exists | `ls clients/$ACTIVE_CLIENT/` | Directory listing |
| 6.3 | Required files present | `ls clients/$ACTIVE_CLIENT/{CLIENT_PROFILE,BUSINESS_KNOWLEDGE,FAQ,OWNER_PREFERENCES}.md` | All 4 exist |
| 6.4 | Files have content | `wc -l clients/$ACTIVE_CLIENT/BUSINESS_KNOWLEDGE.md` | > 20 lines |
| 6.5 | Not identical to template | `diff clients/$ACTIVE_CLIENT/CLIENT_PROFILE.md clients/templates/CLIENT_PROFILE.md` | Files differ |
| 6.6 | MEMORY populated | `cat clients/$ACTIVE_CLIENT/MEMORY/TODAY.md \| wc -l` | > 5 lines |
| 6.7 | DOCUMENTS has files | `find clients/$ACTIVE_CLIENT/DOCUMENTS -type f \| wc -l` | > 0 |
| 6.8 | Full client test | `bash admin/test_client.sh $ACTIVE_CLIENT` | READY or ACCEPTABLE |

---

## Layer 7 — End-to-End Integration

| # | Test | Command | Expected |
|---|------|---------|----------|
| 7.1 | RAG retrieval from container | Ask "What does this company do?" via WebUI | Answer cites CLIENT_PROFILE.md or BUSINESS_KNOWLEDGE.md |
| 7.2 | Anti-hallucination works | Ask about something NOT in documents | "I don't have that information in our records" |
| 7.3 | Source citation present | Any RAG-answered question | Response includes `[source_file.md]` reference |
| 7.4 | Daily briefing generates | Trigger daily-briefing workflow in n8n | Briefing output written to storage |
| 7.5 | sync_today.sh works | `bash admin/sync_today.sh` | TODAY.md copied to client MEMORY |
| 7.6 | Re-index after sync | Run index_vault.py after sync | New TODAY.md content in chunks |
| 7.7 | Client switch works | Change ACTIVE_CLIENT, re-index, ask question | Answers from new client's docs |
| 7.8 | Embedding model switch | Change model in .env, re-index, run configure_rag_pipeline.sh | All layers use new model |

---

## Quick Smoke Test (run all critical checks)

```bash
# Run this after any change to verify nothing is broken
echo "=== Ollama ===" && curl -sf http://localhost:11434/api/tags | python3 -c "import sys,json; m=json.load(sys.stdin)['models']; print(f'  Models: {len(m)}')" \
&& echo "=== PostgreSQL ===" && docker exec postgres pg_isready -U admin \
&& echo "=== Chunks ===" && docker exec postgres psql -U admin -d businessassistant -t -c "SELECT count(*) FROM rag_chunks" \
&& echo "=== OpenWebUI ===" && curl -sf -o /dev/null -w "  HTTP %{http_code}\n" http://localhost:3000 \
&& echo "=== n8n ===" && curl -sf -o /dev/null -w "  HTTP %{http_code}\n" http://localhost:5678 \
&& echo "=== RAG Filter ===" && docker exec openwebui python3 -c "import sqlite3; conn=sqlite3.connect('/app/backend/data/webui.db'); cur=conn.cursor(); cur.execute(\"SELECT is_active FROM function WHERE id='business_knowledge_rag'\"); print(f'  Active: {cur.fetchone()[0]}')" \
&& echo "✅ All checks passed"
```

---

## When to Run Each Layer

| Scenario | Run Layers |
|----------|-----------|
| After system reboot | 1, 2, 4.1-4.3, 5.1-5.2 |
| After adding documents | 3.4, 2.7, 7.1 |
| After changing embedding model | 1.3, 1.5, 1.6, 3.4, 2.6, 4.6-4.8, 7.8 |
| After editing RAG filter | 4.4-4.6, 4.10-4.11, 7.1-7.3 |
| After switching client | 6.1-6.8, 3.4, 7.1, 7.7 |
| After modifying n8n workflows | 5.3-5.8, 7.4 |
| Before going to production | All layers (full run) |
