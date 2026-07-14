#!/bin/bash
# ══════════════════════════════════════════════════════════════
# apply_branding.sh — Apply custom CSS + title to Open WebUI
# ══════════════════════════════════════════════════════════════
#
# USAGE:
#   ./admin/apply_branding.sh
#
# WHAT IT DOES:
#   1. Copies dashboard/custom.css into the container's static dir
#   2. Patches index.html to remove crossorigin (allows CSS loading)
#   3. Sets the UI title in the config database
#
# WHEN TO RUN:
#   - After install.sh (already called automatically in Phase 12B)
#   - After pulling a new Open WebUI image / recreating container
#   - After editing dashboard/custom.css
#
# IDEMPOTENT: Safe to run multiple times.
# ══════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
CSS_FILE="$BASE_PATH/dashboard/custom.css"
CONTAINER="openwebui"

# Docker wrapper
_docker() {
  if docker info &>/dev/null; then
    docker "$@"
  else
    sudo docker "$@"
  fi
}

# Pre-flight
if ! _docker ps --filter "name=^${CONTAINER}$" --filter "status=running" --format "{{.Names}}" 2>/dev/null | grep -q "^${CONTAINER}$"; then
  echo "❌ Container '$CONTAINER' is not running."
  exit 1
fi

if [ ! -f "$CSS_FILE" ]; then
  echo "❌ CSS file not found: $CSS_FILE"
  exit 1
fi

echo "Applying branding to Open WebUI..."

# 1. Copy CSS into container
_docker cp "$CSS_FILE" "$CONTAINER:/app/backend/open_webui/static/custom.css"
echo "  ✅ Custom CSS deployed"

# 2. Fix crossorigin attribute on the CSS link tag (blocks loading without CORS headers)
_docker exec "$CONTAINER" sed -i 's|href="/static/custom.css" crossorigin="use-credentials"|href="/static/custom.css"|g' /app/build/index.html 2>/dev/null || true
echo "  ✅ index.html patched (crossorigin removed)"

# 3. Set UI title via SQLite config
_docker exec "$CONTAINER" python3 -c "
import sqlite3, json, time
name = 'Business AI Assistant'
now_ts = int(time.time())
conn = sqlite3.connect('/app/backend/data/webui.db')
cur = conn.cursor()
cur.execute('SELECT key FROM config WHERE key = ?', ('ui.name',))
if cur.fetchone():
    cur.execute('UPDATE config SET value = ?, updated_at = ? WHERE key = ?', (json.dumps(name), now_ts, 'ui.name'))
else:
    cur.execute('INSERT INTO config (key, value, updated_at) VALUES (?, ?, ?)', ('ui.name', json.dumps(name), now_ts))
conn.commit()
conn.close()
" 2>/dev/null
echo "  ✅ UI title set: Business AI Assistant"

echo ""
echo "Done. Hard-refresh your browser (Ctrl+Shift+R) to see changes."
