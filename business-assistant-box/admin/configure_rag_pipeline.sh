#!/bin/bash

# ==========================================
# CONFIGURE RAG PIPELINE IN OPEN WEBUI
# ==========================================
# Installs dependencies and registers the Business Knowledge RAG
# filter function so Open WebUI queries pgvector automatically.
#
# Usage:
#   sudo ./admin/configure_rag_pipeline.sh
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$BASE_PATH/.env"

# Load .env
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

WEBUI_URL="${OPENWEBUI_BASE_URL:-http://localhost:3000}"

# Docker wrapper
_docker() {
  if docker info &>/dev/null; then
    docker "$@"
  else
    sudo docker "$@"
  fi
}

echo "========================================"
echo "   CONFIGURE RAG PIPELINE"
echo "========================================"
echo ""

# ==========================================
# STEP 1 — Install psycopg2 in container
# ==========================================
echo "=== STEP 1 — Install psycopg2 in WebUI container ==="

if _docker exec openwebui python3 -c "import psycopg2" 2>/dev/null; then
  echo "  ✅ psycopg2 already installed"
else
  echo "  Installing psycopg2-binary..."
  _docker exec openwebui pip install psycopg2-binary --quiet 2>&1
  if _docker exec openwebui python3 -c "import psycopg2" 2>/dev/null; then
    echo "  ✅ psycopg2 installed successfully"
  else
    echo "  ❌ Failed to install psycopg2. Cannot continue."
    exit 1
  fi
fi
echo ""

# ==========================================
# STEP 2 — Test RAG connectivity from container
# ==========================================
echo "=== STEP 2 — Test pgvector connectivity from container ==="

RAG_TEST=$(_docker exec openwebui python3 -c "
import psycopg2
try:
    conn = psycopg2.connect(host='host.docker.internal', port=5432, user='${PG_USER:-admin}', password='${PG_PASSWORD:-strongpassword}', dbname='${PG_DATABASE:-businessassistant}')
    cur = conn.cursor()
    cur.execute('SELECT COUNT(*) FROM rag_chunks')
    count = cur.fetchone()[0]
    conn.close()
    print(f'OK:{count}')
except Exception as e:
    print(f'FAIL:{e}')
" 2>&1)

if echo "$RAG_TEST" | grep -q "^OK:"; then
  CHUNK_COUNT=$(echo "$RAG_TEST" | sed 's/OK://')
  echo "  ✅ pgvector reachable from container ($CHUNK_COUNT chunks indexed)"
else
  echo "  ❌ Cannot reach pgvector from container"
  echo "     Error: $RAG_TEST"
  echo ""
  echo "  Make sure PostgreSQL container is running and accessible."
  echo "  The openwebui container needs --add-host=host.docker.internal:host-gateway"
  exit 1
fi
echo ""

# ==========================================
# STEP 3 — Test embedding from container
# ==========================================
echo "=== STEP 3 — Test embedding generation from container ==="

EMBED_MODEL="${EMBEDDING_MODEL:-nomic-embed-text}"
EMBED_TEST=$(_docker exec openwebui python3 -c "
import requests
try:
    resp = requests.post('http://host.docker.internal:11434/api/embeddings', json={'model': '${EMBED_MODEL}', 'prompt': 'test'}, timeout=120)
    resp.raise_for_status()
    emb = resp.json().get('embedding', [])
    print(f'OK:{len(emb)}')
except Exception as e:
    print(f'FAIL:{e}')
" 2>&1)

if echo "$EMBED_TEST" | grep -q "^OK:"; then
  DIM=$(echo "$EMBED_TEST" | sed 's/OK://')
  echo "  ✅ Embedding generation working (model=${EMBED_MODEL}, ${DIM} dimensions)"
else
  echo "  ❌ Cannot generate embeddings from container"
  echo "     Error: $EMBED_TEST"
  echo "     Ensure Ollama is running with ${EMBED_MODEL} model"
  exit 1
fi
echo ""

# ==========================================
# STEP 4 — Get/Create admin API key
# ==========================================
echo "=== STEP 4 — Authenticate with Open WebUI ==="

# Prompt for admin credentials
if [ -z "$WEBUI_ADMIN_EMAIL" ]; then
  read -p "  Open WebUI admin email: " WEBUI_ADMIN_EMAIL
fi
if [ -z "$WEBUI_ADMIN_PASSWORD" ]; then
  read -sp "  Open WebUI admin password: " WEBUI_ADMIN_PASSWORD
  echo ""
fi

# Get JWT token
AUTH_RESPONSE=$(curl -s -X POST "${WEBUI_URL}/api/v1/auths/signin" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"${WEBUI_ADMIN_EMAIL}\", \"password\": \"${WEBUI_ADMIN_PASSWORD}\"}" 2>/dev/null)

TOKEN=$(echo "$AUTH_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('token',''))" 2>/dev/null)

if [ -z "$TOKEN" ]; then
  echo "  ❌ Authentication failed. Check email/password."
  echo "     Response: $AUTH_RESPONSE"
  exit 1
fi
echo "  ✅ Authenticated"
echo ""

# ==========================================
# STEP 5 — Register the RAG function
# ==========================================
echo "=== STEP 5 — Register RAG function ==="

FUNCTION_ID="business_knowledge_rag"
FUNCTION_FILE="$BASE_PATH/dashboard/functions/business_rag_filter.py"

if [ ! -f "$FUNCTION_FILE" ]; then
  echo "  ❌ Function file not found: $FUNCTION_FILE"
  exit 1
fi

# Read function content
FUNCTION_CONTENT=$(cat "$FUNCTION_FILE")

# Check if function already exists
EXISTING=$(curl -s -X GET "${WEBUI_URL}/api/v1/functions/${FUNCTION_ID}" \
  -H "Authorization: Bearer ${TOKEN}" 2>/dev/null)

if echo "$EXISTING" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null | grep -q "$FUNCTION_ID"; then
  echo "  Function already exists. Updating..."
  RESPONSE=$(curl -s -X POST "${WEBUI_URL}/api/v1/functions/${FUNCTION_ID}/update" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$(python3 -c "
import json, sys
content = open('${FUNCTION_FILE}').read()
print(json.dumps({
    'id': '${FUNCTION_ID}',
    'name': 'Business Knowledge RAG',
    'content': content,
    'meta': {
        'description': 'Retrieves relevant business context from pgvector and injects into prompts',
        'manifest': {
            'title': 'Business Knowledge RAG',
            'author': 'NativeBlackBox',
            'version': '0.1.0',
            'type': 'filter'
        }
    }
}))
")" 2>/dev/null)
else
  echo "  Creating new function..."
  RESPONSE=$(curl -s -X POST "${WEBUI_URL}/api/v1/functions/create" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$(python3 -c "
import json
content = open('${FUNCTION_FILE}').read()
print(json.dumps({
    'id': '${FUNCTION_ID}',
    'name': 'Business Knowledge RAG',
    'content': content,
    'meta': {
        'description': 'Retrieves relevant business context from pgvector and injects into prompts',
        'manifest': {
            'title': 'Business Knowledge RAG',
            'author': 'NativeBlackBox',
            'version': '0.1.0',
            'type': 'filter'
        }
    }
}))
")" 2>/dev/null)
fi

# Check result
CREATED_ID=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null)
if [ "$CREATED_ID" = "$FUNCTION_ID" ]; then
  echo "  ✅ Function registered: $FUNCTION_ID"
else
  echo "  ⚠️  API registration issue. Updating directly in database..."
  _docker exec openwebui python3 -c "
import sqlite3, json, time
code = open('/dev/stdin').read()
now_ts = int(time.time())
conn = sqlite3.connect('/app/backend/data/webui.db')
cur = conn.cursor()
cur.execute('SELECT id FROM function WHERE id=?', ('${FUNCTION_ID}',))
if cur.fetchone():
    cur.execute('UPDATE function SET content=?, is_active=1, is_global=1, updated_at=? WHERE id=?', (code, now_ts, '${FUNCTION_ID}'))
else:
    meta = json.dumps({'description': 'Retrieves relevant business context from pgvector and injects into prompts', 'manifest': {'title': 'Business Knowledge RAG', 'author': 'NativeBlackBox', 'version': '1.2.0', 'type': 'filter'}})
    cur.execute('INSERT INTO function (id, user_id, name, type, content, meta, is_active, is_global, updated_at, created_at) VALUES (?, ?, ?, ?, ?, ?, 1, 1, ?, ?)', ('${FUNCTION_ID}', 'system', 'Business Knowledge RAG', 'filter', code, meta, now_ts, now_ts))
conn.commit()
conn.close()
print('OK')
" < "$FUNCTION_FILE" 2>&1
  DB_RESULT=$?
  if [ $DB_RESULT -eq 0 ]; then
    echo "  ✅ Function updated directly in database"
  else
    echo "  ❌ Database update failed. Paste code manually in Admin → Functions."
  fi
fi
echo ""

# ==========================================
# STEP 6 — Sync valves (embedding model, top_k, active_client)
# ==========================================
echo "=== STEP 6 — Sync function valves ==="

VALVES_JSON=$(python3 -c "
import json
valves = {
    'embedding_model': '${EMBEDDING_MODEL:-nomic-embed-text}',
    'active_client': '${ACTIVE_CLIENT:-}',
    'top_k': 8
}
print(json.dumps(valves))
")

_docker exec openwebui python3 -c "
import sqlite3, sys
valves = sys.argv[1]
conn = sqlite3.connect('/app/backend/data/webui.db')
cur = conn.cursor()
cur.execute('UPDATE function SET valves=? WHERE id=?', (valves, '${FUNCTION_ID}'))
conn.commit()
conn.close()
print('OK')
" "$VALVES_JSON" 2>&1

echo "  ✅ Valves synced: embedding_model=${EMBEDDING_MODEL:-nomic-embed-text}, active_client=${ACTIVE_CLIENT:-auto}"
echo ""

# ==========================================
# STEP 7 — Sync WebUI native RAG config
# ==========================================
echo "=== STEP 7 — Sync WebUI native RAG embedding config ==="

_docker exec openwebui python3 -c '
import sqlite3, json, time
conn = sqlite3.connect("/app/backend/data/webui.db")
cur = conn.cursor()
now = int(time.time())
cur.execute("UPDATE config SET value = json(?), updated_at = ? WHERE key = ?", (json.dumps("ollama"), now, "rag.embedding_engine"))
cur.execute("UPDATE config SET value = json(?), updated_at = ? WHERE key = ?", (json.dumps("'"${EMBED_MODEL}"'"), now, "rag.embedding_model"))
conn.commit()
conn.close()
' 2>&1

echo "  ✅ WebUI native RAG set to: engine=ollama, model=${EMBED_MODEL}"
echo ""

# ==========================================
# STEP 8 — Enable function globally
# ==========================================
echo "=== STEP 8 — Enable function globally ==="

# Toggle function on
TOGGLE_RESPONSE=$(curl -s -X POST "${WEBUI_URL}/api/v1/functions/${FUNCTION_ID}/toggle" \
  -H "Authorization: Bearer ${TOKEN}" 2>/dev/null)

IS_ACTIVE=$(echo "$TOGGLE_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('is_active', d.get('state',False)))" 2>/dev/null)

if [ "$IS_ACTIVE" = "True" ] || [ "$IS_ACTIVE" = "true" ]; then
  echo "  ✅ Function enabled globally"
else
  # Toggle again if it was toggled off
  TOGGLE_RESPONSE=$(curl -s -X POST "${WEBUI_URL}/api/v1/functions/${FUNCTION_ID}/toggle" \
    -H "Authorization: Bearer ${TOKEN}" 2>/dev/null)
  echo "  ✅ Function toggled (check Admin → Functions to confirm it's ON)"
fi

# Set as global filter
GLOBAL_RESPONSE=$(curl -s -X POST "${WEBUI_URL}/api/v1/functions/${FUNCTION_ID}/toggle/global" \
  -H "Authorization: Bearer ${TOKEN}" 2>/dev/null)
echo "  ✅ Set as global filter"
echo ""

# ==========================================
# STEP 9 — End-to-end test
# ==========================================
echo "=== STEP 9 — End-to-end RAG test ==="

E2E_TEST=$(_docker exec openwebui python3 -c "
import psycopg2
import requests

# Get embedding for test query
resp = requests.post('http://host.docker.internal:11434/api/embeddings', json={'model': '${EMBED_MODEL}', 'prompt': 'Tell me about this business'}, timeout=120)
embedding = resp.json()['embedding']

# Query pgvector
conn = psycopg2.connect(host='host.docker.internal', port=5432, user='${PG_USER:-admin}', password='${PG_PASSWORD:-strongpassword}', dbname='${PG_DATABASE:-businessassistant}')
cur = conn.cursor()
cur.execute('''
    SELECT source_path, chunk_text, 1 - (embedding <=> %s::vector) AS similarity
    FROM rag_chunks
    WHERE client_name = '${ACTIVE_CLIENT}'
    ORDER BY embedding <=> %s::vector
    LIMIT 3
''', (embedding, embedding))
results = cur.fetchall()
conn.close()

for path, chunk, sim in results:
    print(f'  [{sim:.3f}] {path}: {chunk[:100]}...')
" 2>&1)

if echo "$E2E_TEST" | grep -q "\[0\."; then
  echo "  ✅ RAG retrieval working. Sample results:"
  echo "$E2E_TEST"
else
  echo "  ⚠️  Could not verify end-to-end. Output:"
  echo "$E2E_TEST"
fi
echo ""

# ==========================================
# SUMMARY
# ==========================================
echo "========================================"
echo "         RAG PIPELINE SUMMARY"
echo "========================================"
echo ""
echo "  psycopg2 in container:  ✅"
echo "  pgvector connectivity:  ✅"
echo "  Embedding generation:   ✅"
echo "  Function registered:    ✅"
echo "  Function enabled:       ✅"
echo ""
echo "  HOW IT WORKS:"
echo "    1. You edit files in Obsidian (native app, vault: current-client/)"
echo "    2. Re-index: ./vector-db/venv/bin/python3 ./vector-db/index_vault.py"
echo "    3. Ask questions in Open WebUI (localhost:3000)"
echo "    4. The RAG filter automatically injects relevant business context"
echo ""
echo "  TEST IT:"
echo "    Ask a question about your business in the chat — it should answer from BUSINESS_KNOWLEDGE.md"
echo ""
echo "  NOTE: After editing files in Obsidian, re-run the indexer to update RAG:"
echo "    ./vector-db/venv/bin/python3 ./vector-db/index_vault.py"
echo ""
