#!/bin/bash

# ==========================================
# Switch Embedding Model
# ==========================================
# Switches the embedding model, updates .env, rebuilds RAG tables,
# and re-indexes the active client.
#
# Usage:
#   ./admin/switch_embedding.sh
#   ./admin/switch_embedding.sh nomic-embed-text 768
#   ./admin/switch_embedding.sh snowflake-arctic-embed:335m 1024
#   DRY_RUN=true ./admin/switch_embedding.sh
# ==========================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$BASE/.env"
DRY_RUN="${DRY_RUN:-false}"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

# Docker wrapper
_docker() {
  if docker info &>/dev/null; then
    docker "$@"
  else
    sudo docker "$@"
  fi
}

# Load current config
if [ -f "$ENV_FILE" ]; then
  set -a; source "$ENV_FILE"; set +a
fi

CURRENT_MODEL="${EMBEDDING_MODEL:-snowflake-arctic-embed:335m}"
CURRENT_DIMS="${EMBEDDING_DIMENSIONS:-1024}"
ACTIVE_CLIENT="${ACTIVE_CLIENT:-demo-company}"

echo "========================================="
echo "   Switch Embedding Model"
echo "========================================="
echo ""
echo "  Current model:      $CURRENT_MODEL"
echo "  Current dimensions: $CURRENT_DIMS"
echo "  Active client:      $ACTIVE_CLIENT"
echo ""

# ── Select new model ──
if [ -n "${1:-}" ] && [ -n "${2:-}" ]; then
  NEW_MODEL="$1"
  NEW_DIMS="$2"
else
  echo "  Available embedding models:"
  echo ""
  echo "    [1] nomic-embed-text          — 768 dims, 274MB, fast general-purpose"
  echo "    [2] snowflake-arctic-embed:335m — 1024 dims, 670MB, best retrieval accuracy"
  echo "    [3] mxbai-embed-large          — 1024 dims, 670MB, good accuracy"
  echo "    [4] snowflake-arctic-embed:s    — 384 dims, 67MB, fastest, lightweight"
  echo "    [5] all-minilm:l6-v2           — 384 dims, 46MB, minimal footprint"
  echo ""
  read -p "  Select model [1-5]: " choice
  case "$choice" in
    1) NEW_MODEL="nomic-embed-text"; NEW_DIMS=768 ;;
    2) NEW_MODEL="snowflake-arctic-embed:335m"; NEW_DIMS=1024 ;;
    3) NEW_MODEL="mxbai-embed-large"; NEW_DIMS=1024 ;;
    4) NEW_MODEL="snowflake-arctic-embed:s"; NEW_DIMS=384 ;;
    5) NEW_MODEL="all-minilm:l6-v2"; NEW_DIMS=384 ;;
    *) echo "  Invalid choice."; exit 1 ;;
  esac
fi

echo ""
echo "  New model:      $NEW_MODEL"
echo "  New dimensions: $NEW_DIMS"
echo ""

if [ "$NEW_MODEL" = "$CURRENT_MODEL" ] && [ "$NEW_DIMS" = "$CURRENT_DIMS" ]; then
  echo "  Already using this model. Nothing to do."
  exit 0
fi

if [ "$DRY_RUN" = true ]; then
  echo "[DRY RUN] Would:"
  echo "  1. Pull $NEW_MODEL via Ollama"
  echo "  2. Update .env (EMBEDDING_MODEL=$NEW_MODEL, EMBEDDING_DIMENSIONS=$NEW_DIMS)"
  echo "  3. Drop and recreate RAG tables with vector($NEW_DIMS)"
  echo "  4. Re-index $ACTIVE_CLIENT"
  echo "  5. Update RAG filter in OpenWebUI"
  exit 0
fi

read -p "  This will DELETE all existing RAG vectors and re-index. Continue? [yes/no]: " confirm
if [ "$confirm" != "yes" ] && [ "$confirm" != "y" ]; then
  echo "  Aborted."
  exit 0
fi

echo ""

# ── Step 1: Pull model ──
echo "Step 1/5 — Pulling $NEW_MODEL..."
if ollama list 2>/dev/null | grep -q "$NEW_MODEL"; then
  echo "  Already pulled."
else
  ollama pull "$NEW_MODEL" || { echo "  ❌ Failed to pull $NEW_MODEL"; exit 1; }
fi
echo ""

# ── Step 2: Update .env ──
echo "Step 2/5 — Updating .env..."
cp "$ENV_FILE" "$ENV_FILE.bak.$TIMESTAMP"
echo "  Backed up: .env → .env.bak.$TIMESTAMP"

sed -i "s|^EMBEDDING_MODEL=.*|EMBEDDING_MODEL=$NEW_MODEL|" "$ENV_FILE"
sed -i "s|^EMBEDDING_DIMENSIONS=.*|EMBEDDING_DIMENSIONS=$NEW_DIMS|" "$ENV_FILE"

echo "  EMBEDDING_MODEL=$NEW_MODEL"
echo "  EMBEDDING_DIMENSIONS=$NEW_DIMS"
echo ""

# ── Step 3: Rebuild RAG tables ──
echo "Step 3/5 — Rebuilding RAG tables (vector($NEW_DIMS))..."

SCHEMA_SQL="-- Business Assistant Box - RAG Schema
-- Requires: CREATE EXTENSION vector;
-- Embedding dimensions: ${NEW_DIMS}

DROP TABLE IF EXISTS rag_chunks CASCADE;
DROP TABLE IF EXISTS rag_documents CASCADE;

CREATE TABLE IF NOT EXISTS rag_documents (
  id SERIAL PRIMARY KEY,
  client_name VARCHAR(255) NOT NULL,
  source_path TEXT NOT NULL,
  title VARCHAR(500),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS rag_chunks (
  id SERIAL PRIMARY KEY,
  document_id INTEGER REFERENCES rag_documents(id) ON DELETE CASCADE,
  client_name VARCHAR(255) NOT NULL,
  source_path TEXT NOT NULL,
  title VARCHAR(500),
  chunk_text TEXT NOT NULL,
  embedding vector(${NEW_DIMS}),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chunks_client ON rag_chunks(client_name);
-- Note: vector index (ivfflat) is created by index_vault.py after data insertion
-- with correct lists parameter based on actual row count."

# Update schema file
echo "$SCHEMA_SQL" > "$BASE/vector-db/schema.sql"
echo "  Updated: vector-db/schema.sql"

# Deploy to PostgreSQL
echo "$SCHEMA_SQL" | _docker exec -i postgres psql -U "${PG_USER:-admin}" "${PG_DATABASE:-businessassistant}" 2>&1
echo "  ✅ RAG tables rebuilt with vector($NEW_DIMS)"
echo ""

# ── Step 4: Re-index ──
echo "Step 4/5 — Re-indexing $ACTIVE_CLIENT..."
VENV_PYTHON="$BASE/vector-db/venv/bin/python3"
INDEX_SCRIPT="$BASE/vector-db/index_vault.py"

# Unload all models from VRAM so embedding model gets full GPU
echo "  Unloading chat models from VRAM..."
for model in $(ollama ps 2>/dev/null | tail -n +2 | awk '{print $1}'); do
  ollama stop "$model" 2>/dev/null && echo "    Unloaded: $model"
done
sleep 2

if [ -f "$VENV_PYTHON" ] && [ -f "$INDEX_SCRIPT" ]; then
  "$VENV_PYTHON" "$INDEX_SCRIPT" 2>&1
  CHUNK_COUNT=$(_docker exec -i postgres psql -U "${PG_USER:-admin}" "${PG_DATABASE:-businessassistant}" -t -c "SELECT COUNT(*) FROM rag_chunks" 2>/dev/null | tr -d ' ')
  echo "  ✅ Indexed ($CHUNK_COUNT chunks)"
else
  echo "  ⚠️  Venv or index script not found. Run manually:"
  echo "     $VENV_PYTHON $INDEX_SCRIPT"
fi
echo ""

# ── Step 5: Sync RAG filter in OpenWebUI ──
echo "Step 5/5 — Syncing RAG filter in OpenWebUI..."
if _docker ps --format '{{.Names}}' | grep -q openwebui; then
  FILTER_FILE="$BASE/dashboard/functions/business_rag_filter.py"
  if [ -f "$FILTER_FILE" ]; then
    _docker exec -i openwebui python3 -c "
import sqlite3, json, sys, time, re

code = sys.stdin.read()
function_id = 'business_knowledge_rag'
now_ts = int(time.time())

# Update default embedding_model in source to match current
code = re.sub(r'embedding_model: str = Field\(default=\"[^\"]*\"\)', 'embedding_model: str = Field(default=\"${NEW_MODEL}\")', code)

conn = sqlite3.connect('/app/backend/data/webui.db')
cur = conn.cursor()
cur.execute('SELECT id FROM function WHERE id=?', (function_id,))
if cur.fetchone():
    cur.execute('UPDATE function SET content=?, is_active=1, is_global=1, updated_at=? WHERE id=?', (code, now_ts, function_id))
else:
    meta = json.dumps({'description': 'Business Knowledge RAG filter', 'manifest': {'title': 'Business Knowledge RAG', 'author': 'NativeBlackBox', 'version': '1.2.0', 'type': 'filter'}})
    cur.execute('INSERT INTO function (id, user_id, name, type, content, meta, is_active, is_global, updated_at, created_at) VALUES (?, ?, ?, ?, ?, ?, 1, 1, ?, ?)', (function_id, 'system', 'Business Knowledge RAG', 'filter', code, meta, now_ts, now_ts))
conn.commit()
conn.close()
print('  ✅ Filter deployed with embedding_model=${NEW_MODEL}')
" < "$FILTER_FILE" 2>&1

    _docker restart openwebui >/dev/null 2>&1
    echo "  Waiting for OpenWebUI..."
    sleep 15
    for i in $(seq 1 12); do
      HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null)
      if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "303" ]; then break; fi
      sleep 5
    done
    _docker exec openwebui python3 -c "
import sqlite3
conn = sqlite3.connect('/app/backend/data/webui.db')
cur = conn.cursor()
cur.execute('UPDATE function SET is_active=1, is_global=1 WHERE id=\"business_knowledge_rag\"')
conn.commit()
conn.close()
" 2>/dev/null
    echo "  ✅ OpenWebUI restarted with global RAG filter"
  else
    echo "  ⚠️  Filter file not found: $FILTER_FILE"
  fi
else
  echo "  ⚠️  OpenWebUI not running. Run manually: ./admin/configure_rag_pipeline.sh"
fi

echo ""
echo "========================================="
echo "  ✅ Embedding model switched"
echo "========================================="
echo ""
echo "  Model:      $NEW_MODEL"
echo "  Dimensions: $NEW_DIMS"
echo "  Chunks:     ${CHUNK_COUNT:-unknown}"
echo ""
echo "  To verify:"
echo "    $VENV_PYTHON $BASE/vector-db/query_vault.py \"What does this company do?\""
echo ""
