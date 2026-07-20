#!/bin/bash

# ==========================================
# E2E VALIDATION — Phase-by-Phase
# ==========================================
# Tests every tech stack component for missing configuration.
# Stops after each phase so you can inspect/fix before continuing.
#
# Usage:
#   ./admin/e2e_validate.sh
#   ./admin/e2e_validate.sh --no-pause   # Run all phases without stopping
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$BASE_PATH/.env"
NO_PAUSE=false

[ "$1" = "--no-pause" ] && NO_PAUSE=true

PASS=0
FAIL=0
PHASE_FAILS=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "  ${GREEN}✅ $1${NC}"; ((PASS++)); }
fail() { echo -e "  ${RED}❌ $1${NC}"; ((FAIL++)); ((PHASE_FAILS++)); }
warn() { echo -e "  ${YELLOW}⚠️  $1${NC}"; }

phase_gate() {
  local phase_name="$1"
  echo ""
  if [ $PHASE_FAILS -gt 0 ]; then
    echo -e "${RED}  ── $phase_name: $PHASE_FAILS FAILURE(S) ──${NC}"
  else
    echo -e "${GREEN}  ── $phase_name: ALL PASSED ──${NC}"
  fi
  PHASE_FAILS=0
  if [ "$NO_PAUSE" = false ]; then
    echo ""
    read -p "  Press ENTER to continue (q to quit): " choice
    [ "$choice" = "q" ] && { echo ""; echo "Stopped. Pass=$PASS Fail=$FAIL"; exit 1; }
  fi
  echo ""
}

_docker() {
  if docker info &>/dev/null; then docker "$@"; else sudo docker "$@"; fi
}

# Load .env
if [ -f "$ENV_FILE" ]; then
  set -a; source "$ENV_FILE"; set +a
else
  echo -e "${RED}FATAL: .env not found at $ENV_FILE${NC}"
  exit 1
fi

echo "========================================"
echo "   E2E VALIDATION — Phase-by-Phase"
echo "========================================"
echo ""
echo "  BASE_PATH:    $BASE_PATH"
echo "  ACTIVE_CLIENT: ${ACTIVE_CLIENT:-NOT SET}"
echo "  EMBEDDING:    ${EMBEDDING_MODEL:-NOT SET} (${EMBEDDING_DIMENSIONS:-?} dims)"
echo "  CHAT MODEL:   ${OLLAMA_MODEL:-NOT SET}"
echo ""

# ==========================================
# PHASE 1 — .env Completeness
# ==========================================
echo "═══ PHASE 1 — .env Required Variables ═══"
echo ""

REQUIRED_VARS=(
  AI_PROVIDER OLLAMA_BASE_URL OLLAMA_MODEL
  PG_HOST PG_PORT PG_USER PG_PASSWORD PG_DATABASE
  EMBEDDING_PROVIDER EMBEDDING_MODEL EMBEDDING_DIMENSIONS
  ACTIVE_CLIENT BASE_PATH RAG_ENABLED
  OPENWEBUI_BASE_URL
)

for var in "${REQUIRED_VARS[@]}"; do
  val="${!var}"
  if [ -z "$val" ]; then
    fail "$var is empty or missing"
  else
    pass "$var=$val"
  fi
done

# Check RAG_TOP_K (new addition)
if [ -z "$RAG_TOP_K" ]; then
  warn "RAG_TOP_K not set (will default to 8)"
else
  pass "RAG_TOP_K=$RAG_TOP_K"
fi

phase_gate "PHASE 1 — .env"

# ==========================================
# PHASE 2 — Directory Structure
# ==========================================
echo "═══ PHASE 2 — Directory Structure ═══"
echo ""

REQUIRED_DIRS=(
  "$BASE_PATH/system"
  "$BASE_PATH/clients/$ACTIVE_CLIENT"
  "$BASE_PATH/vector-db"
  "$BASE_PATH/dashboard"
  "$BASE_PATH/dashboard/functions"
  "$BASE_PATH/admin"
  "$BASE_PATH/postgres"
)

for dir in "${REQUIRED_DIRS[@]}"; do
  if [ -d "$dir" ]; then
    pass "$dir"
  else
    fail "Missing: $dir"
  fi
done

# Symlink
if [ -L "$BASE_PATH/current-client" ]; then
  TARGET=$(readlink -f "$BASE_PATH/current-client")
  if [ -d "$TARGET" ]; then
    pass "current-client → $TARGET"
  else
    fail "current-client symlink points to non-existent: $TARGET"
  fi
else
  fail "current-client symlink missing"
fi

phase_gate "PHASE 2 — Directories"

# ==========================================
# PHASE 3 — Client Content
# ==========================================
echo "═══ PHASE 3 — Client Content ═══"
echo ""

CLIENT_DIR="$BASE_PATH/clients/$ACTIVE_CLIENT"
CRITICAL_FILES=("CLIENT_PROFILE.md" "BUSINESS_KNOWLEDGE.md")
OPTIONAL_FILES=("FAQ.md" "OWNER_PREFERENCES.md")

for f in "${CRITICAL_FILES[@]}"; do
  filepath="$CLIENT_DIR/$f"
  if [ -f "$filepath" ]; then
    SIZE=$(wc -c < "$filepath")
    if [ "$SIZE" -gt 50 ]; then
      pass "$f ($SIZE bytes)"
    else
      fail "$f exists but only $SIZE bytes (likely placeholder)"
    fi
  else
    fail "$f missing from $CLIENT_DIR"
  fi
done

for f in "${OPTIONAL_FILES[@]}"; do
  filepath="$CLIENT_DIR/$f"
  if [ -f "$filepath" ]; then
    pass "$f (optional, present)"
  else
    warn "$f not found (optional)"
  fi
done

MD_COUNT=$(find -L "$CLIENT_DIR" -name "*.md" 2>/dev/null | wc -l)
pass "Total .md files in client: $MD_COUNT"

phase_gate "PHASE 3 — Client Content"

# ==========================================
# PHASE 4 — Docker Engine
# ==========================================
echo "═══ PHASE 4 — Docker Engine ═══"
echo ""

if command -v docker &>/dev/null; then
  pass "Docker binary found"
else
  fail "Docker not installed"
fi

if docker info &>/dev/null || sudo docker info &>/dev/null; then
  pass "Docker daemon running"
else
  fail "Docker daemon not running"
fi

phase_gate "PHASE 4 — Docker"

# ==========================================
# PHASE 5 — PostgreSQL + pgvector
# ==========================================
echo "═══ PHASE 5 — PostgreSQL + pgvector ═══"
echo ""

if _docker ps --filter "name=^postgres$" --filter "status=running" --format "{{.Names}}" 2>/dev/null | grep -q "^postgres$"; then
  pass "postgres container running"
else
  fail "postgres container not running"
fi

if _docker exec -i postgres pg_isready -U "${PG_USER:-admin}" 2>/dev/null | grep -q "accepting"; then
  pass "PostgreSQL accepting connections"
else
  fail "PostgreSQL not accepting connections"
fi

# pgvector extension
PGV=$(_docker exec -i postgres psql -U "${PG_USER:-admin}" "${PG_DATABASE:-businessassistant}" -t -c "SELECT extname FROM pg_extension WHERE extname='vector';" 2>/dev/null | tr -d ' \n')
if [ "$PGV" = "vector" ]; then
  pass "pgvector extension enabled"
else
  fail "pgvector extension NOT enabled"
fi

# RAG tables exist
TABLE_COUNT=$(_docker exec -i postgres psql -U "${PG_USER:-admin}" "${PG_DATABASE:-businessassistant}" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name IN ('rag_documents','rag_chunks');" 2>/dev/null | tr -d ' \n')
if [ "$TABLE_COUNT" = "2" ]; then
  pass "RAG tables exist (rag_documents, rag_chunks)"
else
  fail "RAG tables missing (found $TABLE_COUNT/2)"
fi

# Embedding dimension matches schema
SCHEMA_DIM=$(_docker exec -i postgres psql -U "${PG_USER:-admin}" "${PG_DATABASE:-businessassistant}" -t -c "SELECT atttypmod FROM pg_attribute WHERE attrelid='rag_chunks'::regclass AND attname='embedding';" 2>/dev/null | tr -d ' \n')
if [ "$SCHEMA_DIM" = "$EMBEDDING_DIMENSIONS" ]; then
  pass "Schema dimension matches .env ($SCHEMA_DIM)"
elif [ -n "$SCHEMA_DIM" ]; then
  fail "Schema dimension=$SCHEMA_DIM but .env EMBEDDING_DIMENSIONS=$EMBEDDING_DIMENSIONS"
else
  warn "Could not detect schema dimension"
fi

# Chunks indexed for active client
CHUNK_COUNT=$(_docker exec -i postgres psql -U "${PG_USER:-admin}" "${PG_DATABASE:-businessassistant}" -t -c "SELECT COUNT(*) FROM rag_chunks WHERE client_name='${ACTIVE_CLIENT}';" 2>/dev/null | tr -d ' \n')
if [ -n "$CHUNK_COUNT" ] && [ "$CHUNK_COUNT" -gt 0 ] 2>/dev/null; then
  pass "Chunks indexed for $ACTIVE_CLIENT: $CHUNK_COUNT"
else
  fail "No chunks indexed for $ACTIVE_CLIENT"
fi

phase_gate "PHASE 5 — PostgreSQL + pgvector"

# ==========================================
# PHASE 6 — Ollama
# ==========================================
echo "═══ PHASE 6 — Ollama ═══"
echo ""

if command -v ollama &>/dev/null; then
  pass "Ollama binary found"
else
  fail "Ollama not installed"
fi

if systemctl is-active ollama &>/dev/null; then
  pass "Ollama service active"
else
  fail "Ollama service not active"
fi

# API responsive
OLLAMA_VER=$(curl -s --max-time 5 http://localhost:11434/api/version 2>/dev/null)
if echo "$OLLAMA_VER" | grep -q "version"; then
  pass "Ollama API responding"
else
  fail "Ollama API not responding on :11434"
fi

# Listen address (Docker needs non-loopback)
OLLAMA_LISTEN=$(ss -tln 2>/dev/null | grep ":11434")
if echo "$OLLAMA_LISTEN" | grep -qE "0\.0\.0\.0:11434|\*:11434|:::11434"; then
  pass "Ollama listening on all interfaces (:11434, Docker-accessible)"
elif echo "$OLLAMA_LISTEN" | grep -q "127.0.0.1:11434"; then
  fail "Ollama on 127.0.0.1 only — Docker containers can't reach it"
else
  warn "Could not determine Ollama listen address"
fi

# Show what's configured vs what's available
echo ""
echo "  .env config:"
echo "    OLLAMA_MODEL=$OLLAMA_MODEL"
echo "    EMBEDDING_MODEL=$EMBEDDING_MODEL"
echo ""
echo "  Pulled models:"
ollama list 2>/dev/null | tail -n +2 | awk '{printf "    %s (%s)\n", $1, $3" "$4}'
echo ""

# Chat model available (match first column only, handle tag variations)
if ollama list 2>/dev/null | awk '{print $1}' | grep -qF "${OLLAMA_MODEL}"; then
  pass "Chat model pulled: $OLLAMA_MODEL"
else
  MODEL_BASE=$(echo "$OLLAMA_MODEL" | cut -d: -f1)
  AVAILABLE=$(ollama list 2>/dev/null | awk '{print $1}' | grep "^${MODEL_BASE}" | head -1)
  if [ -n "$AVAILABLE" ]; then
    fail "Chat model $OLLAMA_MODEL not found (closest available: $AVAILABLE)"
  else
    fail "Chat model $OLLAMA_MODEL not pulled — run: ollama pull $OLLAMA_MODEL"
  fi
fi

# Embedding model available
if ollama list 2>/dev/null | awk '{print $1}' | grep -qF "${EMBEDDING_MODEL}"; then
  pass "Embedding model pulled: $EMBEDDING_MODEL"
else
  fail "Embedding model $EMBEDDING_MODEL not pulled — run: ollama pull $EMBEDDING_MODEL"
fi

phase_gate "PHASE 6 — Ollama"

# ==========================================
# PHASE 7 — Embedding Generation
# ==========================================
echo "═══ PHASE 7 — Embedding Generation ═══"
echo ""

EMB_RESULT=$(curl -s --max-time 30 http://localhost:11434/api/embeddings -d "{\"model\":\"${EMBEDDING_MODEL}\",\"prompt\":\"test\"}" 2>/dev/null)
EMB_LEN=$(echo "$EMB_RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('embedding',[])))" 2>/dev/null)

if [ "$EMB_LEN" = "$EMBEDDING_DIMENSIONS" ]; then
  pass "Embedding returns correct dimensions ($EMB_LEN)"
elif [ -n "$EMB_LEN" ] && [ "$EMB_LEN" -gt 0 ] 2>/dev/null; then
  fail "Embedding returns $EMB_LEN dims but .env says $EMBEDDING_DIMENSIONS"
else
  fail "Embedding generation failed (model may not be loaded)"
fi

phase_gate "PHASE 7 — Embedding"

# ==========================================
# PHASE 8 — Python venv + Scripts
# ==========================================
echo "═══ PHASE 8 — Python venv + RAG Scripts ═══"
echo ""

VENV="$BASE_PATH/vector-db/venv"

if [ -f "$VENV/bin/python3" ]; then
  pass "Python venv exists"
else
  fail "Python venv missing at $VENV"
fi

# Check critical imports
if [ -f "$VENV/bin/python3" ]; then
  IMPORT_TEST=$("$VENV/bin/python3" -c "import psycopg2, dotenv, requests; print('OK')" 2>&1)
  if [ "$IMPORT_TEST" = "OK" ]; then
    pass "Critical packages importable (psycopg2, dotenv, requests)"
  else
    fail "Import failed: $IMPORT_TEST"
  fi
fi

# index_vault.py exists and has override=True
if [ -f "$BASE_PATH/vector-db/index_vault.py" ]; then
  if grep -q "override=True" "$BASE_PATH/vector-db/index_vault.py"; then
    pass "index_vault.py has load_dotenv override=True"
  else
    fail "index_vault.py missing override=True (will inherit stale env vars)"
  fi
else
  fail "index_vault.py not found"
fi

# query_vault.py exists and has override=True
if [ -f "$BASE_PATH/vector-db/query_vault.py" ]; then
  if grep -q "override=True" "$BASE_PATH/vector-db/query_vault.py"; then
    pass "query_vault.py has load_dotenv override=True"
  else
    fail "query_vault.py missing override=True"
  fi
else
  fail "query_vault.py not found"
fi

phase_gate "PHASE 8 — Python + Scripts"

# ==========================================
# PHASE 9 — Open WebUI Container
# ==========================================
echo "═══ PHASE 9 — Open WebUI Container ═══"
echo ""

if _docker ps --filter "name=^openwebui$" --filter "status=running" --format "{{.Names}}" 2>/dev/null | grep -q "^openwebui$"; then
  pass "openwebui container running"
else
  fail "openwebui container not running"
fi

# HTTP responding
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:3000 2>/dev/null)
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "303" ]; then
  pass "WebUI responding on :3000 (HTTP $HTTP_CODE)"
else
  fail "WebUI not responding (HTTP $HTTP_CODE)"
fi

# host.docker.internal configured
EXTRA_HOSTS=$(_docker inspect openwebui --format '{{range .HostConfig.ExtraHosts}}{{println .}}{{end}}' 2>/dev/null)
if echo "$EXTRA_HOSTS" | grep -q "host.docker.internal"; then
  pass "host.docker.internal mapped"
else
  fail "host.docker.internal NOT mapped — container can't reach host services"
fi

# OLLAMA_BASE_URL set
WEBUI_OLLAMA=$(_docker inspect openwebui --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep "OLLAMA_BASE_URL" | cut -d= -f2)
if echo "$WEBUI_OLLAMA" | grep -q "host.docker.internal"; then
  pass "OLLAMA_BASE_URL=$WEBUI_OLLAMA"
else
  fail "OLLAMA_BASE_URL not set to host.docker.internal (got: $WEBUI_OLLAMA)"
fi

# psycopg2 in container
if _docker exec openwebui python3 -c "import psycopg2" 2>/dev/null; then
  pass "psycopg2 available in container"
else
  fail "psycopg2 NOT in container (RAG filter will fail)"
fi

phase_gate "PHASE 9 — Open WebUI Container"

# ==========================================
# PHASE 10 — RAG Filter in WebUI DB
# ==========================================
echo "═══ PHASE 10 — RAG Filter Registration ═══"
echo ""

FILTER_DB=$(_docker exec openwebui python3 -c "
import sqlite3
conn = sqlite3.connect('/app/backend/data/webui.db')
cur = conn.cursor()
cur.execute('SELECT is_active, is_global, content FROM function WHERE id=\"business_knowledge_rag\"')
row = cur.fetchone()
conn.close()
if row:
    print(f'ACTIVE={row[0]}|GLOBAL={row[1]}|LEN={len(row[2])}')
    # Check embedding model default
    import re
    m = re.search(r'embedding_model.*?Field\(default=\"([^\"]+)\"', row[2])
    if m:
        print(f'EMBED_DEFAULT={m.group(1)}')
    # Check identity chunk method
    if '_get_identity_chunk' in row[2]:
        print('HAS_IDENTITY=yes')
    else:
        print('HAS_IDENTITY=no')
else:
    print('NOT_FOUND')
" 2>/dev/null)

if echo "$FILTER_DB" | grep -q "NOT_FOUND"; then
  fail "RAG filter not registered in WebUI DB"
else
  # is_active
  if echo "$FILTER_DB" | grep -q "ACTIVE=1"; then
    pass "Filter is_active=1"
  else
    fail "Filter is_active != 1"
  fi

  # is_global
  if echo "$FILTER_DB" | grep -q "GLOBAL=1"; then
    pass "Filter is_global=1"
  else
    fail "Filter is_global != 1 (won't apply to all chats)"
  fi

  # Embedding model default matches .env
  DB_EMBED=$(echo "$FILTER_DB" | grep "EMBED_DEFAULT" | cut -d= -f2)
  if [ "$DB_EMBED" = "$EMBEDDING_MODEL" ]; then
    pass "Filter default embedding_model=$DB_EMBED (matches .env)"
  elif [ -n "$DB_EMBED" ]; then
    fail "Filter default=$DB_EMBED but .env=$EMBEDDING_MODEL (dimension mismatch!)"
  fi

  # Identity chunk method
  if echo "$FILTER_DB" | grep -q "HAS_IDENTITY=yes"; then
    pass "Filter has _get_identity_chunk method"
  else
    warn "Filter missing _get_identity_chunk (CLIENT_PROFILE.md won't auto-inject)"
  fi
fi

# Filter file on disk matches what's in DB (length check)
if [ -f "$BASE_PATH/dashboard/functions/business_rag_filter.py" ]; then
  DISK_LEN=$(wc -c < "$BASE_PATH/dashboard/functions/business_rag_filter.py" | tr -d ' ')
  DB_LEN=$(echo "$FILTER_DB" | grep -o 'LEN=[0-9]*' | cut -d= -f2)
  if [ -n "$DB_LEN" ] && [ -n "$DISK_LEN" ]; then
    DIFF=$((DISK_LEN - DB_LEN))
    ABS_DIFF=${DIFF#-}
    if [ "$ABS_DIFF" -lt 50 ]; then
      pass "Filter on disk ≈ DB version (diff: ${DIFF} bytes)"
    else
      warn "Filter on disk ($DISK_LEN bytes) differs from DB ($DB_LEN bytes) — may need re-deploy"
    fi
  fi
else
  fail "business_rag_filter.py not found on disk"
fi

phase_gate "PHASE 10 — RAG Filter"

# ==========================================
# PHASE 11 — WebUI → Ollama Connectivity
# ==========================================
echo "═══ PHASE 11 — WebUI → Ollama Connectivity ═══"
echo ""

OLLAMA_FROM_CONTAINER=$(_docker exec openwebui curl -sf --max-time 5 http://host.docker.internal:11434/api/version 2>/dev/null)
if echo "$OLLAMA_FROM_CONTAINER" | grep -q "version"; then
  pass "WebUI container can reach Ollama API"
else
  fail "WebUI container CANNOT reach Ollama (check OLLAMA_HOST=0.0.0.0)"
fi

# Embedding from container
EMB_FROM_CONTAINER=$(_docker exec openwebui python3 -c "
import requests
try:
    r = requests.post('http://host.docker.internal:11434/api/embeddings', json={'model':'${EMBEDDING_MODEL}','prompt':'test'}, timeout=30)
    r.raise_for_status()
    print(f'OK:{len(r.json().get(\"embedding\",[]))}')
except Exception as e:
    print(f'FAIL:{e}')
" 2>/dev/null)

if echo "$EMB_FROM_CONTAINER" | grep -q "^OK:${EMBEDDING_DIMENSIONS}$"; then
  pass "Embedding from container: correct dims ($EMBEDDING_DIMENSIONS)"
elif echo "$EMB_FROM_CONTAINER" | grep -q "^OK:"; then
  DIM_GOT=$(echo "$EMB_FROM_CONTAINER" | sed 's/OK://')
  fail "Embedding from container returns $DIM_GOT dims (expected $EMBEDDING_DIMENSIONS)"
else
  fail "Embedding from container failed: $EMB_FROM_CONTAINER"
fi

phase_gate "PHASE 11 — WebUI → Ollama"

# ==========================================
# PHASE 12 — WebUI → pgvector Connectivity
# ==========================================
echo "═══ PHASE 12 — WebUI → pgvector Connectivity ═══"
echo ""

PG_FROM_CONTAINER=$(_docker exec openwebui python3 -c "
import psycopg2
try:
    conn = psycopg2.connect(host='host.docker.internal', port=${PG_PORT:-5432}, user='${PG_USER:-admin}', password='${PG_PASSWORD:-strongpassword}', dbname='${PG_DATABASE:-businessassistant}')
    cur = conn.cursor()
    cur.execute('SELECT COUNT(*) FROM rag_chunks WHERE client_name=%s', ('${ACTIVE_CLIENT}',))
    print(f'OK:{cur.fetchone()[0]}')
    conn.close()
except Exception as e:
    print(f'FAIL:{e}')
" 2>/dev/null)

if echo "$PG_FROM_CONTAINER" | grep -q "^OK:"; then
  COUNT=$(echo "$PG_FROM_CONTAINER" | sed 's/OK://')
  pass "pgvector reachable from container ($COUNT chunks for $ACTIVE_CLIENT)"
else
  fail "pgvector NOT reachable from container: $PG_FROM_CONTAINER"
fi

phase_gate "PHASE 12 — WebUI → pgvector"

# ==========================================
# PHASE 13 — End-to-End RAG Query
# ==========================================
echo "═══ PHASE 13 — End-to-End RAG Query ═══"
echo ""

E2E_RESULT=$(_docker exec openwebui python3 -c "
import requests, psycopg2

# Generate embedding
resp = requests.post('http://host.docker.internal:11434/api/embeddings', json={'model':'${EMBEDDING_MODEL}','prompt':'Tell me about this business'}, timeout=60)
resp.raise_for_status()
embedding = resp.json()['embedding']

# Query pgvector
conn = psycopg2.connect(host='host.docker.internal', port=${PG_PORT:-5432}, user='${PG_USER:-admin}', password='${PG_PASSWORD:-strongpassword}', dbname='${PG_DATABASE:-businessassistant}')
cur = conn.cursor()
emb_str = '[' + ','.join(str(x) for x in embedding) + ']'
cur.execute('''
    SELECT source_path, chunk_text, 1 - (embedding <=> %s::vector) AS similarity
    FROM rag_chunks
    WHERE client_name = %s
    ORDER BY embedding <=> %s::vector
    LIMIT 3
''', (emb_str, '${ACTIVE_CLIENT}', emb_str))
results = cur.fetchall()
conn.close()

if results:
    print(f'OK:{len(results)}')
    for path, chunk, sim in results:
        print(f'  [{sim:.3f}] {path}: {chunk[:80]}...')
else:
    print('EMPTY')
" 2>/dev/null)

if echo "$E2E_RESULT" | grep -q "^OK:"; then
  pass "E2E RAG query returned results"
  echo "$E2E_RESULT" | grep -v "^OK:" | head -3
elif echo "$E2E_RESULT" | grep -q "EMPTY"; then
  fail "E2E RAG query returned 0 results (chunks may not match query)"
else
  fail "E2E RAG query failed: $E2E_RESULT"
fi

phase_gate "PHASE 13 — E2E RAG"

# ==========================================
# PHASE 14 — n8n
# ==========================================
echo "═══ PHASE 14 — n8n ═══"
echo ""

if _docker ps --filter "name=^n8n$" --filter "status=running" --format "{{.Names}}" 2>/dev/null | grep -q "^n8n$"; then
  pass "n8n container running"
else
  fail "n8n container not running"
fi

N8N_HTTP=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:5678 2>/dev/null)
if [ "$N8N_HTTP" = "200" ] || [ "$N8N_HTTP" = "302" ]; then
  pass "n8n responding on :5678 (HTTP $N8N_HTTP)"
else
  fail "n8n not responding (HTTP $N8N_HTTP)"
fi

# n8n API key set
if [ -n "$N8N_API_KEY" ]; then
  pass "N8N_API_KEY set in .env"
else
  warn "N8N_API_KEY empty — workflow automation via API won't work"
fi

phase_gate "PHASE 14 — n8n"

# ==========================================
# PHASE 15 — Script Integrity
# ==========================================
echo "═══ PHASE 15 — Script Integrity ═══"
echo ""

SCRIPTS=(
  "$BASE_PATH/admin/install.sh"
  "$BASE_PATH/admin/switch_client.sh"
  "$BASE_PATH/admin/switch_embedding.sh"
  "$BASE_PATH/admin/configure_rag_pipeline.sh"
  "$BASE_PATH/admin/post_install_verify.sh"
)

for script in "${SCRIPTS[@]}"; do
  name=$(basename "$script")
  if [ ! -f "$script" ]; then
    fail "$name not found"
    continue
  fi
  if [ ! -x "$script" ]; then
    fail "$name not executable (chmod +x needed)"
    continue
  fi
  SYNTAX=$(bash -n "$script" 2>&1)
  if [ $? -eq 0 ]; then
    pass "$name syntax OK + executable"
  else
    fail "$name syntax error: $SYNTAX"
  fi
done

# Python syntax
PY_FILES=(
  "$BASE_PATH/vector-db/index_vault.py"
  "$BASE_PATH/vector-db/query_vault.py"
  "$BASE_PATH/dashboard/functions/business_rag_filter.py"
)

for pyfile in "${PY_FILES[@]}"; do
  name=$(basename "$pyfile")
  if [ ! -f "$pyfile" ]; then
    fail "$name not found"
    continue
  fi
  PY_SYNTAX=$(python3 -c "import ast; ast.parse(open('$pyfile').read())" 2>&1)
  if [ $? -eq 0 ]; then
    pass "$name Python syntax OK"
  else
    fail "$name Python syntax error: $PY_SYNTAX"
  fi
done

phase_gate "PHASE 15 — Script Integrity"

# ==========================================
# SUMMARY
# ==========================================
echo "========================================"
echo "         VALIDATION SUMMARY"
echo "========================================"
echo ""
echo -e "  Passed:  ${GREEN}$PASS${NC}"
echo -e "  Failed:  ${RED}$FAIL${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
  echo -e "${GREEN}  ✅ ALL CHECKS PASSED — System is fully configured.${NC}"
  exit 0
else
  echo -e "${RED}  ❌ $FAIL CHECK(S) FAILED — Review above for details.${NC}"
  exit 1
fi
