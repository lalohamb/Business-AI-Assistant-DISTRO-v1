#!/bin/bash
# ==========================================
# change_password.sh — Update PostgreSQL password
# ==========================================
# Changes the PG password in the running container and .env file.
# Open WebUI and n8n manage their own passwords internally.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$BASE_PATH/.env"

# Docker wrapper
_docker() {
  if docker info &>/dev/null; then
    docker "$@"
  else
    sudo docker "$@"
  fi
}

# Validate .env exists
if [ ! -f "$ENV_FILE" ]; then
  echo "❌ .env not found at $ENV_FILE"
  exit 1
fi

# Read current values
PG_USER=$(grep "^PG_USER=" "$ENV_FILE" | cut -d= -f2)
PG_USER="${PG_USER:-admin}"
CURRENT_PW=$(grep "^PG_PASSWORD=" "$ENV_FILE" | cut -d= -f2)

echo "=== Change PostgreSQL Password ==="
echo ""
echo "  Current user: $PG_USER"
echo ""

# Prompt for new password
read -sp "  New password: " NEW_PW
echo ""
read -sp "  Confirm:      " CONFIRM_PW
echo ""

if [ -z "$NEW_PW" ]; then
  echo "❌ Password cannot be empty."
  exit 1
fi

if [ "$NEW_PW" != "$CONFIRM_PW" ]; then
  echo "❌ Passwords do not match."
  exit 1
fi

if [ "$NEW_PW" = "$CURRENT_PW" ]; then
  echo "⚠️  New password is the same as current. No changes made."
  exit 0
fi

# Verify postgres container is running
if ! _docker ps --filter "name=^postgres$" --filter "status=running" --format "{{.Names}}" | grep -q "^postgres$"; then
  echo "❌ PostgreSQL container is not running."
  exit 1
fi

# Update password in PostgreSQL
echo ""
echo "  Updating password in PostgreSQL..."
if _docker exec -i postgres psql -U "$PG_USER" -c "ALTER USER $PG_USER PASSWORD '$NEW_PW';" 2>/dev/null; then
  echo "  ✅ PostgreSQL password updated."
else
  echo "❌ Failed to update password in PostgreSQL."
  exit 1
fi

# Update .env
sed -i "s|^PG_PASSWORD=.*|PG_PASSWORD=$NEW_PW|" "$ENV_FILE"
echo "  ✅ .env updated."

echo ""
echo "  Done. Services reading from .env (index_vault.py, RAG filter valves)"
echo "  will use the new password on next run."
echo ""
echo "  NOTE: If you configured PG credentials in n8n or Open WebUI RAG filter"
echo "  valves manually, update those separately."
