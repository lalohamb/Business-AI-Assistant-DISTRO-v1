# Embedding Model Change Guide

## What Gets Updated When You Change the Embedding Model

| Layer | What Needs Updating | How It's Handled |
|-------|-------------------|------------------|
| PostgreSQL (vector column dimension) | `vector(768)` → `vector(1024)` | `switch_embedding.sh` drops + recreates tables |
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
# Automated (recommended):
./admin/switch_embedding.sh

# Or with arguments:
./admin/switch_embedding.sh snowflake-arctic-embed:335m 1024
./admin/switch_embedding.sh nomic-embed-text 768
```

The script handles all steps: pull model, update .env, rebuild tables, re-index, and sync WebUI.

### Manual steps (if needed):

```bash
# 1. Edit .env
EMBEDDING_MODEL=mxbai-embed-large
EMBEDDING_DIMENSIONS=1024

# 2. Pull model
ollama pull mxbai-embed-large

# 3. Rebuild schema (REQUIRED — index_vault.py does NOT auto-detect dimension mismatch)
docker exec -i postgres psql -U admin businessassistant -c "DROP TABLE IF EXISTS rag_chunks CASCADE; DROP TABLE IF EXISTS rag_documents CASCADE;"
docker exec -i postgres psql -U admin businessassistant < vector-db/schema.sql

# 4. Re-index
./vector-db/venv/bin/python3 ./vector-db/index_vault.py

# 5. Sync WebUI (handles filter valves + native RAG config)
bash admin/configure_rag_pipeline.sh
```

---

## Notes

- Changing dimensions requires dropping tables + full re-index (old embeddings are incompatible)
- `index_vault.py` does NOT auto-detect dimension mismatch — it will error if schema doesn't match
- `nomic-embed-text` has 8192 token context vs 512 for the others — handles larger chunks better
- Use `DRY_RUN=true ./admin/switch_embedding.sh` to preview changes without executing
