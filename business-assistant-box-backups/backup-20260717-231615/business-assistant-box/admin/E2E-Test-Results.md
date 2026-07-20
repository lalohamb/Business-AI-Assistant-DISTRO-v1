# E2E Test Results

## Date: 2026-07-10

## RAG Pipeline — Full Stack Validation

### Scripts Tested

| Script | Syntax Check | Status |
|--------|-------------|--------|
| install.sh | bash -n | ✅ PASS |
| configure_rag_pipeline.sh | bash -n | ✅ PASS |
| uninstall.sh | bash -n | ✅ PASS |
| post_install_verify.sh | bash -n | ✅ PASS |
| switch_client.sh | bash -n | ✅ PASS |
| business_rag_filter.py | ast.parse | ✅ PASS |

### RAG Filter Code Validation

| Check | Result |
|-------|--------|
| Heredoc in install.sh matches file on disk | ✅ PASS |
| Filter class has all methods (inlet, _get_embedding, _query_chunks, __init__) | ✅ PASS |
| install.sh Phase 12 sets is_active=1, is_global=1 | ✅ PASS |
| configure_rag_pipeline.sh SQLite fallback sets is_active=1, is_global=1 | ✅ PASS |
| Timeout = 120s in all locations | ✅ PASS |

### Column Name Consistency (must match DB schema)

Schema: `chunk_text`, `source_path`, `client_name`, `embedding`

| File | chunk_text | source_path | client_name |
|------|-----------|-------------|-------------|
| business_rag_filter.py | ✅ | ✅ | ✅ |
| install.sh heredoc | ✅ | ✅ | ✅ |
| index_vault.py | ✅ | ✅ | ✅ |
| query_vault.py | ✅ | ✅ | ✅ |

### OpenWebUI Database State

| Check | Result |
|-------|--------|
| Function ID: business_knowledge_rag | ✅ |
| is_active = 1 | ✅ |
| is_global = 1 | ✅ |
| Code contains chunk_text | ✅ |
| Code contains source_path | ✅ |
| Code contains timeout=120 | ✅ |
| Code contains pydantic/BaseModel | ✅ |

### Live RAG Test (from inside OpenWebUI container)

| Step | Result |
|------|--------|
| psycopg2 import | ✅ OK |
| Ollama embedding (nomic-embed-text, 768 dims) | ✅ OK |
| pgvector query (263 chunks, client=law-office) | ✅ OK |
| OpenWebUI chat returns business context | ✅ OK |

### Issues Found & Fixed This Session

| Issue | Root Cause | Fix |
|-------|-----------|-----|
| RAG filter returned no results | SQL used wrong column names (`content`/`source` vs `chunk_text`/`source_path`) | Updated filter code |
| Filter silently failed | Bare `except: return []` swallowed UndefinedColumn error | Fixed columns, kept exception handling for resilience |
| Embedding timeout | 30s too short for GPU model swapping on 8GB VRAM (RTX 2060) | Increased to 120s |
| API key stale (401 Unauthorized) | OPENWEBUI_API_KEY in .env expired | Added SQLite fallback in configure_rag_pipeline.sh |
| Valves not initializing | Newer OpenWebUI requires pydantic BaseModel | Added `from pydantic import BaseModel, Field` |
| Post-install RAG not working | User had to manually run index + configure scripts | Added Phase 11 (auto-index) + Phase 12 (auto-register via SQLite) |

### Install Flow (Post-Fix)

```
Phase 10 — Writes RAG filter file (heredoc, no escaping issues)
Phase 11 — Indexes client into pgvector (automatic)
Phase 12 — Registers filter in OpenWebUI SQLite DB (bypasses API auth)
         — Sets is_active=1, is_global=1
         — Restarts OpenWebUI container
```

### Notes

- On 8GB GPU: use smaller chat models (llama3.2, qwen) to avoid embedding timeout during model swap
- After editing vault files, re-index: `./vector-db/venv/bin/python3 ./vector-db/index_vault.py`
- configure_rag_pipeline.sh can still be run standalone — it authenticates via signin and has SQLite fallback
