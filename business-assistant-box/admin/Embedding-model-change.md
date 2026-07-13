# Embedding Model Change Guide

## What Gets Updated When You Change the Embedding Model

| Layer | What Needs Updating | How It's Handled |
|-------|-------------------|------------------|
| PostgreSQL (vector column dimension) | `vector(768)` → `vector(1024)` | `index_vault.py` auto-detects mismatch, recreates tables |
| index_vault.py (which model to call) | `EMBEDDING_MODEL` env var | Reads from `.env` directly |
| RAG filter (query-time embedding model) | `valves.embedding_model` in WebUI DB | `configure_rag_pipeline.sh` Step 6 syncs it |
| WebUI native RAG (built-in upload/retrieval) | `rag.embedding_engine` + `rag.embedding_model` in config table | `configure_rag_pipeline.sh` Step 7 syncs it |

---

## Available Models

| Model | Parameters | Dimensions | Context | Best For |
|-------|-----------|------------|---------|----------|
| nomic-embed-text (default) | 137M | 768 | 8192 | Fast, good general-purpose |
| mxbai-embed-large | 335M | 1024 | 512 | Higher accuracy, slightly slower |
| snowflake-arctic-embed | 335M | 1024 | 512 | Enterprise/retrieval focused |

---

## Full Workflow After Changing Models

```bash
# 1. Edit .env
EMBEDDING_MODEL=mxbai-embed-large
EMBEDDING_DIMENSIONS=1024

# 2. Pull model
ollama pull mxbai-embed-large

# 3. Re-index (handles DB schema automatically)
python3 vector-db/index_vault.py

# 4. Sync WebUI (handles filter valves + native RAG config)
bash admin/configure_rag_pipeline.sh
```

---

## Notes

- Changing dimensions requires a full re-index (all existing embeddings become invalid)
- `nomic-embed-text` has 8192 token context vs 512 for the others — handles larger chunks better
- The dimension mismatch detection is automatic: just change `.env` and re-index
