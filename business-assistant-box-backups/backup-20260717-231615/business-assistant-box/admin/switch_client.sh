#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="${BASE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
ENV_FILE="$BASE/.env"
SYMLINK="$BASE/current-client"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

# Log all output to file
mkdir -p "$BASE/logs"
LOG_FILE="$BASE/logs/switch_client.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=== switch_client started: $(date) ==="

FORCE=false

# Parse arguments
if [ -z "$1" ]; then
  echo "Usage: ./switch_client.sh <client-name> [--force]"
  echo ""
  echo "  --force  Switch even if validation warnings exist"
  exit 1
fi

CLIENT="$1"
shift
while [ $# -gt 0 ]; do
  case "$1" in
    --force) FORCE=true ;;
  esac
  shift
done

CLIENT_PATH="$BASE/clients/$CLIENT"

# License check — disabled pending fix for directory-count bug (issue #3)
# source "$SCRIPT_DIR/license_check.sh"
# check_license
# if [ "$LICENSE_TIER" = "single" ]; then
#   CURRENT_COUNT=$(count_active_clients)
#   if [ "$CURRENT_COUNT" -gt 1 ]; then
#     echo "❌ Single-client license. Cannot switch between multiple clients."
#     echo "   Upgrade to multi-client to serve more than one business."
#     exit 1
#   fi
# fi

echo "========================================"
echo "   Switch Active Client"
echo "========================================"
echo ""
echo "  Client:  $CLIENT"
echo "  Path:    $CLIENT_PATH"
echo "  Force:   $FORCE"
echo ""

# Step 1 — Confirm client exists
if [ ! -d "$CLIENT_PATH" ]; then
  echo "❌ Client directory not found: $CLIENT_PATH"
  echo "  Run list_clients.sh to see available clients."
  exit 1
fi

if [ "$CLIENT" = "templates" ]; then
  echo "❌ Cannot switch to 'templates' — it is a base template, not a client."
  exit 1
fi

# Step 2 — Validate client
echo "Validating client..."
echo ""
"$BASE/admin/test_client.sh" "$CLIENT"
VALIDATE_RESULT=$?

if [ $VALIDATE_RESULT -ne 0 ] && [ "$FORCE" = false ]; then
  echo ""
  echo "❌ Validation failed. Use --force to switch anyway."
  exit 1
fi

if [ $VALIDATE_RESULT -ne 0 ] && [ "$FORCE" = true ]; then
  echo ""
  echo "⚠️  Validation warnings present. Proceeding with --force."
fi

echo ""

# Step 3 — Backup .env
if [ -f "$ENV_FILE" ]; then
  BACKUP="$ENV_FILE.bak.$TIMESTAMP"
  cp "$ENV_FILE" "$BACKUP"
  echo "  ↩ Backed up .env → $BACKUP"
fi

# Step 4 — Update .env
if grep -q "^ACTIVE_CLIENT=" "$ENV_FILE" 2>/dev/null; then
  sed -i "s|^ACTIVE_CLIENT=.*|ACTIVE_CLIENT=$CLIENT|" "$ENV_FILE"
else
  echo "ACTIVE_CLIENT=$CLIENT" >> "$ENV_FILE"
fi

if grep -q "^OBSIDIAN_VAULT_PATH=" "$ENV_FILE" 2>/dev/null; then
  sed -i "s|^OBSIDIAN_VAULT_PATH=.*|OBSIDIAN_VAULT_PATH=$BASE/current-client|" "$ENV_FILE"
else
  echo "OBSIDIAN_VAULT_PATH=$BASE/current-client" >> "$ENV_FILE"
fi

echo "  Updated .env: ACTIVE_CLIENT=$CLIENT"
echo "  Updated .env: OBSIDIAN_VAULT_PATH=$BASE/current-client"

# Step 5 — Create/update symlink
if [ -L "$SYMLINK" ]; then
  rm "$SYMLINK"
fi
ln -sf "$CLIENT_PATH" "$SYMLINK"
echo "  Symlink: current-client → clients/$CLIENT"

# Step 6 — Update OpenClaw workspace client link
OPENCLAW_CLIENT_LINK="$BASE/openclaw/client"
if [ -L "$OPENCLAW_CLIENT_LINK" ]; then
  rm "$OPENCLAW_CLIENT_LINK"
fi
if [ -d "$BASE/openclaw" ]; then
  ln -sf "$CLIENT_PATH" "$OPENCLAW_CLIENT_LINK"
  echo "  Symlink: openclaw/client → clients/$CLIENT"
fi

# Step 7 — Notify about Obsidian vault change
echo "  Vault symlink updated. If Obsidian is open, close and reopen the vault."

# Step 8 — Flush old client chunks and re-index RAG
echo ""
echo "  Re-indexing RAG for $CLIENT..."
VENV_PYTHON="$BASE/vector-db/venv/bin/python3"
INDEX_SCRIPT="$BASE/vector-db/index_vault.py"

if [ -f "$VENV_PYTHON" ] && [ -f "$INDEX_SCRIPT" ]; then
  # Flush all other clients' chunks so only active client data remains
  PG_USER="${PG_USER:-admin}" PG_PASSWORD="${PG_PASSWORD:-strongpassword}" PG_DATABASE="${PG_DATABASE:-businessassistant}" ACTIVE_CLIENT="$CLIENT" \
  "$VENV_PYTHON" -c "
import os, psycopg2
conn = psycopg2.connect(host='localhost', port=5432, user=os.environ['PG_USER'], password=os.environ['PG_PASSWORD'], dbname=os.environ['PG_DATABASE'])
cur = conn.cursor()
client = os.environ['ACTIVE_CLIENT']
cur.execute('DELETE FROM rag_chunks WHERE client_name != %s', (client,))
cur.execute('DELETE FROM rag_documents WHERE client_name != %s', (client,))
conn.commit()
conn.close()
print('  Flushed old client data from RAG database.')
" 2>/dev/null

  # Unload chat models from VRAM so embedding model gets full GPU
  echo "  Unloading chat models from VRAM for faster indexing..."
  for model in $(ollama ps 2>/dev/null | tail -n +2 | awk '{print $1}'); do
    ollama stop "$model" 2>/dev/null && echo "    Unloaded: $model"
  done
  sleep 2

  # Re-index active client
  INDEX_OUTPUT=$("$VENV_PYTHON" "$INDEX_SCRIPT" 2>&1)
  INDEX_EXIT=$?
  echo "$INDEX_OUTPUT" | tail -3
  if [ $INDEX_EXIT -eq 0 ]; then
    echo "  ✅ RAG re-indexed for $CLIENT"
  else
    echo "  ⚠️  RAG indexing failed. Run manually: $VENV_PYTHON $INDEX_SCRIPT"
  fi
else
  echo "  ⚠️  Python venv or index script not found. Run manually:"
  echo "     $VENV_PYTHON $INDEX_SCRIPT"
fi

# Step 9 — Ensure RAG filter is active in OpenWebUI
FILTER_FILE="$BASE/dashboard/functions/business_rag_filter.py"
if docker ps --format '{{.Names}}' | grep -q openwebui 2>/dev/null; then
  if [ -f "$FILTER_FILE" ]; then
    docker cp "$FILTER_FILE" openwebui:/tmp/filter.py 2>/dev/null
    docker exec openwebui python3 -c "
import sqlite3
with open('/tmp/filter.py', 'r') as f:
    code = f.read()
conn = sqlite3.connect('/app/backend/data/webui.db')
cur = conn.cursor()
cur.execute('SELECT id FROM function WHERE id=?', ('business_knowledge_rag',))
if cur.fetchone():
    cur.execute('UPDATE function SET content=?, is_active=1, is_global=1 WHERE id=?', (code, 'business_knowledge_rag'))
else:
    import json
    meta = json.dumps({'description': 'Business Knowledge RAG filter', 'manifest': {'title': 'Business Knowledge RAG', 'author': 'NativeBlackBox', 'version': '1.2.0', 'type': 'filter'}})
    cur.execute('INSERT INTO function (id, user_id, name, type, content, meta, is_active, is_global, updated_at, created_at) VALUES (?, ?, ?, ?, ?, ?, 1, 1, datetime(\"now\"), datetime(\"now\"))', ('business_knowledge_rag', 'system', 'Business Knowledge RAG', 'filter', code, meta))
conn.commit()
conn.close()
print('  ✅ RAG filter deployed and enabled in OpenWebUI')
" 2>&1
    docker restart openwebui >/dev/null 2>&1
    echo "  Waiting for OpenWebUI to finish restart..."
    sleep 15
    for i in $(seq 1 12); do
      HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null)
      if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "303" ]; then
        break
      fi
      sleep 5
    done
    # Re-enforce is_global=1 after restart (OpenWebUI startup can reset it)
    docker exec openwebui python3 -c "
import sqlite3
conn = sqlite3.connect('/app/backend/data/webui.db')
cur = conn.cursor()
cur.execute('UPDATE function SET is_active=1, is_global=1 WHERE id=\"business_knowledge_rag\"')
conn.commit()
conn.close()
print('  ✅ RAG filter confirmed global after restart')
" 2>&1
    echo "  ✅ OpenWebUI restarted with global RAG filter"
  else
    echo "  ⚠️  Filter file not found: $FILTER_FILE"
  fi
else
  echo "  ⚠️  OpenWebUI container not running. Deploy filter manually."
fi

echo ""
echo "========================================"
echo "  ✅ Switched to: $CLIENT"
echo "========================================"
echo ""
echo "  RAG indexed, filter active, ready to use."
echo ""
echo "  Optional:"
echo "    ./admin/post_install_verify.sh    # Full system check"
echo "    obsidian &                        # Open vault: $BASE/current-client"
echo ""
