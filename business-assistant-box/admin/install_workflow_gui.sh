#!/bin/bash
# ==========================================
# install_workflow_gui.sh
# Installs the Workflow Dashboard (port 8088)
# and registers OpenWebUI tool functions.
#
# Safe to run on fresh install or existing system.
# Idempotent — re-running will rebuild/re-register.
#
# Usage:
#   ./admin/install_workflow_gui.sh
#   DRY_RUN=true ./admin/install_workflow_gui.sh
# ==========================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
DRY_RUN="${DRY_RUN:-false}"

# Load .env
ENV_FILE="$BASE_PATH/.env"
if [ -f "$ENV_FILE" ]; then
  set -a; source "$ENV_FILE"; set +a
fi

N8N_BASE_URL="${N8N_BASE_URL:-http://localhost:5678}"
DASHBOARD_DIR="$BASE_PATH/workflow-dashboard"
FUNCTIONS_DIR="$BASE_PATH/dashboard/functions"

log()      { echo "  $1"; }
log_ok()   { echo "  ✅ $1"; }
log_warn() { echo "  ⚠️  $1"; }
log_dry()  { echo "  [DRY RUN] $1"; }

_docker() {
  if docker info &>/dev/null; then docker "$@"; else sudo docker "$@"; fi
}

echo ""
echo "========================================"
echo "  WORKFLOW GUI INSTALLER"
echo "  Base: $BASE_PATH"
echo "  DRY_RUN: $DRY_RUN"
echo "========================================"
echo ""

# ── PHASE 12C — Build workflow-dashboard container ────────────
echo "=== PHASE 12C — Workflow Dashboard (port 8088) ==="
echo ""

if [ ! -d "$DASHBOARD_DIR" ]; then
  log_warn "workflow-dashboard/ directory not found at $DASHBOARD_DIR"
  log_warn "Ensure the workflow-dashboard/ folder exists before running this script."
  exit 1
fi

if [ "$DRY_RUN" = true ]; then
  log_dry "Would build Docker image: workflow-dashboard"
  log_dry "Would run container: workflow-dashboard on port 8088"
else
  # Stop and remove existing container if present
  if _docker ps -a --filter "name=^workflow-dashboard$" --format "{{.Names}}" 2>/dev/null | grep -q "^workflow-dashboard$"; then
    log "Removing existing workflow-dashboard container..."
    _docker stop workflow-dashboard 2>/dev/null || true
    _docker rm workflow-dashboard 2>/dev/null || true
  fi

  log "Building workflow-dashboard image..."
  _docker build -t workflow-dashboard "$DASHBOARD_DIR" 2>&1 | tail -5

  log "Starting workflow-dashboard container..."
  _docker run -d \
    --name workflow-dashboard \
    --restart unless-stopped \
    --add-host=host.docker.internal:host-gateway \
    -p 8088:8088 \
    -v "$BASE_PATH/n8n/workflows/manifest.json:/app/manifest.json:ro" \
    -v "$BASE_PATH/.env:/app/.env:ro" \
    workflow-dashboard

  # Wait for it to respond
  log "Waiting for dashboard to start..."
  for i in $(seq 1 20); do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8088 2>/dev/null)
    if [ "$HTTP_CODE" = "200" ]; then
      log_ok "Workflow Dashboard is live at http://localhost:8088"
      break
    fi
    sleep 2
  done

  if [ "$HTTP_CODE" != "200" ]; then
    log_warn "Dashboard did not respond within timeout. Check: docker logs workflow-dashboard"
  fi
fi

echo ""

# ── PHASE 12D — Register OpenWebUI tool functions ─────────────
echo "=== PHASE 12D — OpenWebUI Tool Functions ==="
echo ""

TOOL_FILES=(
  "tool_daily_briefing.py:run_daily_briefing:Run Daily Briefing:Triggers the Daily Briefing workflow"
  "tool_lead_followup.py:run_lead_followup:Run Lead Follow-Up:Triggers the Lead Follow-Up workflow"
  "tool_customer_intake.py:new_customer_intake:New Customer Intake:Submits a new customer intake"
  "tool_invoice_generator.py:generate_invoice:Generate Invoice:Generates a professional invoice"
)

# Check OpenWebUI is running
if ! _docker ps --filter "name=^openwebui$" --filter "status=running" --format "{{.Names}}" 2>/dev/null | grep -q "^openwebui$"; then
  log_warn "OpenWebUI container is not running. Skipping tool registration."
  log_warn "Start OpenWebUI first, then re-run this script."
else
  REGISTERED=0
  for entry in "${TOOL_FILES[@]}"; do
    IFS=':' read -r filename tool_id tool_name tool_desc <<< "$entry"
    tool_file="$FUNCTIONS_DIR/$filename"

    if [ ! -f "$tool_file" ]; then
      log_warn "Tool file not found: $tool_file — skipping"
      continue
    fi

    if [ "$DRY_RUN" = true ]; then
      log_dry "Would register tool: $tool_name ($tool_id)"
      continue
    fi

    RESULT=$(_docker exec -i openwebui python3 -c "
import sqlite3, json, sys, time

code = sys.stdin.read()
tool_id = '$tool_id'
tool_name = '$tool_name'
tool_desc = '$tool_desc'
now_ts = int(time.time())

conn = sqlite3.connect('/app/backend/data/webui.db')
cur = conn.cursor()

meta = json.dumps({'description': tool_desc, 'manifest': {'title': tool_name, 'version': '1.0.0', 'type': 'tool'}})

cur.execute('SELECT id FROM tool WHERE id=?', (tool_id,))
if cur.fetchone():
    cur.execute('UPDATE tool SET content=?, meta=?, updated_at=? WHERE id=?', (code, meta, now_ts, tool_id))
    print('UPDATED')
else:
    cur.execute(
        'INSERT INTO tool (id, user_id, name, content, meta, updated_at, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
        (tool_id, 'system', tool_name, code, meta, now_ts, now_ts)
    )
    print('CREATED')

conn.commit()
conn.close()
" < "$tool_file" 2>&1)

    if echo "$RESULT" | grep -qE "UPDATED|CREATED"; then
      log_ok "Registered: $tool_name ($RESULT)"
      REGISTERED=$((REGISTERED + 1))
    else
      log_warn "Registration issue for $tool_name: $RESULT"
    fi
  done

  if [ "$DRY_RUN" = false ] && [ "$REGISTERED" -gt 0 ]; then
    log "Restarting OpenWebUI to load tools..."
    _docker restart openwebui >/dev/null 2>&1

    # Wait for WebUI to come back
    for i in $(seq 1 20); do
      HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null)
      if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "303" ]; then
        log_ok "OpenWebUI restarted and ready"
        break
      fi
      sleep 3
    done
  fi
fi

echo ""
echo "========================================"
echo "  WORKFLOW GUI INSTALL COMPLETE"
echo "========================================"
echo ""
echo "  Workflow Dashboard:  http://localhost:8088"
echo "  Open WebUI:          http://localhost:3000"
echo ""
echo "  OpenWebUI Tools — enable in:"
echo "    Admin Panel → Functions → (each tool) → toggle ON"
echo ""
echo "  To rebuild dashboard after changes:"
echo "    docker stop workflow-dashboard && docker rm workflow-dashboard"
echo "    ./admin/install_workflow_gui.sh"
echo ""
