#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="${BASE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
ENV_FILE="$BASE/.env"
SYMLINK="$BASE/current-client"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

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

# License check — single-client licenses can only use their one client
source "$SCRIPT_DIR/license_check.sh"
check_license
if [ "$LICENSE_TIER" = "single" ]; then
  CURRENT_COUNT=$(count_active_clients)
  if [ "$CURRENT_COUNT" -gt 1 ]; then
    echo "❌ Single-client license. Cannot switch between multiple clients."
    echo "   Upgrade to multi-client to serve more than one business."
    exit 1
  fi
fi

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

echo ""
echo "========================================"
echo "  ✅ Switched to: $CLIENT"
echo "========================================"
echo ""
echo "Next steps:"
echo "  1. Re-index RAG:"
echo "     source vector-db/venv/bin/activate"
echo "     ACTIVE_CLIENT=$CLIENT python3 vector-db/index_vault.py"
echo ""
echo "  2. Verify system:"
echo "     ./admin/post_install_verify.sh"
echo ""
echo "  3. Open Obsidian: obsidian & (vault: $BASE/current-client)"
echo ""
echo "  Note: n8n workflows query rag_chunks WHERE client_name='$CLIENT'."
echo "        Re-indexing (step 1) is required for workflows to use new client data."
echo ""
