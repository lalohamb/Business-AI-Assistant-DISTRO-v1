#!/bin/bash

# ==========================================
# SAFETY CONTROLS
# ==========================================
# DRY_RUN=true
#   Simulates the entire script without making any changes.
#   Prints what WOULD happen. Nothing is written, installed, or modified.
#   Safe to run anytime — like a rehearsal with zero consequences.
#
# SAFE_MODE=true
#   Prevents overwriting existing files without creating a backup first.
#   Prompts before replacing. Never removes containers or volumes.
#
# Override via environment:
#   DRY_RUN=true ./admin/configure_n8n.sh
#   SAFE_MODE=false ./admin/configure_n8n.sh
# ==========================================

set -euo pipefail

# ==========================================
# CONFIGURATION
# ==========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="${BASE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
ENV_FILE="$BASE/.env"
WORKFLOW_DIR="$BASE/n8n/workflows"
BACKUP_DIR="$BASE/n8n/backups"
REPORT_FILE="$BASE/n8n/N8N_CONFIG_REPORT.md"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

DRY_RUN="${DRY_RUN:-false}"
SAFE_MODE="${SAFE_MODE:-true}"

# Load .env
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

N8N_BASE_URL="${N8N_BASE_URL:-http://localhost:5678}"
N8N_API_KEY="${N8N_API_KEY:-}"
ACTIVE_CLIENT="${ACTIVE_CLIENT:-demo-company}"
AI_PROVIDER="${AI_PROVIDER:-openclaw_api}"
OPENCLAW_API_KEY="${OPENCLAW_API_KEY:-}"
OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-http://localhost:11434}"

# Tracking
IMPORTED=()
ACTIVATED=()
TESTED=()
BACKED_UP=()
WEBHOOK_MAPPINGS=()
WARNINGS=()
ERRORS=()
API_ACCESSIBLE="false"
MIDDLEWARE_REACHABLE="false"

# ==========================================
# UTILITY FUNCTIONS
# ==========================================

log_warn() {
  echo "⚠️  $1"
  WARNINGS+=("$1")
}

log_error() {
  echo "❌ $1"
  ERRORS+=("$1")
}

log_ok() {
  echo "✅ $1"
}

prompt_phase() {
  echo ""
  echo "========================================"
  echo " $1 COMPLETE"
  echo "========================================"
  echo ""
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would prompt to continue."
    return
  fi
  read -p "Continue to next phase? [y/n]: " choice
  case "$choice" in
    y|Y) echo "Proceeding..." ;;
    *) echo "Aborted."; generate_report; exit 0 ;;
  esac
  echo ""
}

n8n_api() {
  local method="$1"
  local endpoint="$2"
  local data="${3:-}"

  local headers=(-H "Content-Type: application/json" -H "Accept: application/json")
  if [ -n "$N8N_API_KEY" ]; then
    headers+=(-H "X-N8N-API-KEY: $N8N_API_KEY")
  fi

  if [ -n "$data" ]; then
    curl -s -X "$method" "${N8N_BASE_URL}/api/v1${endpoint}" "${headers[@]}" -d "$data"
  else
    curl -s -X "$method" "${N8N_BASE_URL}/api/v1${endpoint}" "${headers[@]}"
  fi
}

get_workflow_by_name() {
  local name="$1"
  n8n_api GET "/workflows" | jq -r ".data[] | select(.name == \"$name\") | .id" 2>/dev/null
}

backup_workflow() {
  local workflow_id="$1"
  local workflow_name="$2"

  mkdir -p "$BACKUP_DIR"

  local safe_name
  safe_name=$(echo "$workflow_name" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
  local backup_file="$BACKUP_DIR/${safe_name}.bak.${TIMESTAMP}.json"

  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would backup workflow '$workflow_name' (id: $workflow_id)"
    return
  fi

  local data
  data=$(n8n_api GET "/workflows/$workflow_id")
  echo "$data" > "$backup_file"
  BACKED_UP+=("$backup_file")
  echo "  ↩ Backed up: $backup_file"
}

generate_report() {
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would generate report at $REPORT_FILE"
    return
  fi

  cat > "$REPORT_FILE" <<EOF
# N8N Configuration Report

Generated: $TIMESTAMP

## Connection

- URL: $N8N_BASE_URL
- API Key: $([ -n "$N8N_API_KEY" ] && echo "Set" || echo "Not set")
- API Access: $([ "$API_ACCESSIBLE" = "true" ] && echo "✅ Verified" || echo "❌ Failed")

## Environment Variables

- N8N_BASE_URL: $N8N_BASE_URL
- N8N_API_KEY: $([ -n "$N8N_API_KEY" ] && echo "Configured" || echo "⚠️ Missing")
- AI_PROVIDER: $AI_PROVIDER
- ACTIVE_CLIENT: $ACTIVE_CLIENT
- OLLAMA_BASE_URL: $OLLAMA_BASE_URL

## Middleware Connection

- Provider: $AI_PROVIDER
- Reachable: $([ "$MIDDLEWARE_REACHABLE" = "true" ] && echo "✅ Yes" || echo "❌ No")

## Workflows Imported (${#IMPORTED[@]})

$(for w in "${IMPORTED[@]:-}"; do echo "- $w"; done)

## Workflows Activated (${#ACTIVATED[@]})

$(for w in "${ACTIVATED[@]:-}"; do echo "- $w"; done)

## Webhook Mappings (${#WEBHOOK_MAPPINGS[@]})

$(for w in "${WEBHOOK_MAPPINGS[@]:-}"; do echo "- $w"; done)

## Webhooks Tested (${#TESTED[@]})

$(for w in "${TESTED[@]:-}"; do echo "- $w"; done)

## Backups Created (${#BACKED_UP[@]})

$(for w in "${BACKED_UP[@]:-}"; do echo "- $w"; done)

## Warnings (${#WARNINGS[@]})

$(if [ ${#WARNINGS[@]} -eq 0 ]; then echo "None"; else for w in "${WARNINGS[@]}"; do echo "- $w"; done; fi)

## Errors (${#ERRORS[@]})

$(if [ ${#ERRORS[@]} -eq 0 ]; then echo "None"; else for e in "${ERRORS[@]}"; do echo "- $e"; done; fi)

## Next Steps

- Open n8n: $N8N_BASE_URL
- Verify workflows are active
- Connect placeholder nodes to OpenClaw execution
- Test from dashboard: \`cd $BASE/dashboard/custom && python3 -m http.server 8088\`
EOF

  echo "Report saved: $REPORT_FILE"
}

# ==========================================
# MAIN
# ==========================================

echo "========================================"
echo "   BUSINESS ASSISTANT BOX"
echo "   n8n Workflow Configurator"
echo "========================================"
echo ""
echo "  n8n URL:    $N8N_BASE_URL"
echo "  API Key:    $([ -n "$N8N_API_KEY" ] && echo "Set" || echo "Not set (using session auth)")"
echo "  AI Provider: $AI_PROVIDER"
echo "  Client:     $ACTIVE_CLIENT"
echo "  DRY_RUN:    $DRY_RUN"
echo "  SAFE_MODE:  $SAFE_MODE"
echo "  Workflows:  $WORKFLOW_DIR"
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "*** DRY RUN MODE — No changes will be made ***"
  echo ""
fi

# ==========================================
# PHASE 1 — Verify n8n Running
# ==========================================
echo "=== PHASE 1 — Verify n8n Running ==="
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "[DRY RUN] Would test: GET $N8N_BASE_URL/api/v1/workflows"
else
  # Check container
  echo -n "  Docker container: "
  if docker ps --filter "name=^n8n$" --filter "status=running" --format "{{.Names}}" 2>/dev/null | grep -q "^n8n$"; then
    log_ok "Running"
  else
    log_error "n8n container not running. Try: docker start n8n"
    generate_report
    exit 1
  fi

  # Check API
  echo -n "  API access: "
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -H "Accept: application/json" \
    ${N8N_API_KEY:+-H "X-N8N-API-KEY: $N8N_API_KEY"} \
    "${N8N_BASE_URL}/api/v1/workflows" 2>/dev/null || echo "000")

  if [ "$RESPONSE" = "200" ]; then
    log_ok "Accessible (HTTP $RESPONSE)"
    API_ACCESSIBLE="true"
  elif [ "$RESPONSE" = "401" ]; then
    log_error "API returned 401 — API key required or invalid."
    echo ""
    echo "  Set N8N_API_KEY in .env or provide via environment:"
    echo "  N8N_API_KEY=your-key ./admin/configure_n8n.sh"
    echo ""
    echo "  To generate an API key in n8n:"
    echo "  Settings → API → Create API Key"
    generate_report
    exit 1
  elif [ "$RESPONSE" = "000" ]; then
    log_error "Cannot connect to n8n at $N8N_BASE_URL"
    generate_report
    exit 1
  else
    log_error "n8n API returned unexpected HTTP $RESPONSE"
    generate_report
    exit 1
  fi
fi

prompt_phase "PHASE 1 — Verify n8n Running"

# ==========================================
# PHASE 2 — Configure Environment Variables
# ==========================================
echo "=== PHASE 2 — Configure Environment Variables ==="
echo ""

echo "Validating required environment variables for n8n integration..."
echo ""

ENV_VALID=true

# N8N_BASE_URL
echo -n "  N8N_BASE_URL: "
if [ -n "$N8N_BASE_URL" ]; then
  log_ok "$N8N_BASE_URL"
else
  log_error "Not set"
  ENV_VALID=false
fi

# N8N_API_KEY
echo -n "  N8N_API_KEY: "
if [ -n "$N8N_API_KEY" ]; then
  log_ok "Set (${#N8N_API_KEY} chars)"
else
  log_warn "Not set — some operations may require session auth"
fi

# ACTIVE_CLIENT
echo -n "  ACTIVE_CLIENT: "
if [ -n "$ACTIVE_CLIENT" ]; then
  log_ok "$ACTIVE_CLIENT"
else
  log_error "Not set"
  ENV_VALID=false
fi

# AI_PROVIDER
echo -n "  AI_PROVIDER: "
if [ -n "$AI_PROVIDER" ]; then
  log_ok "$AI_PROVIDER"
else
  log_error "Not set"
  ENV_VALID=false
fi

# OPENCLAW_API_KEY (if provider is openclaw)
if [ "$AI_PROVIDER" = "openclaw_api" ]; then
  echo -n "  OPENCLAW_API_KEY: "
  if [ -n "$OPENCLAW_API_KEY" ]; then
    log_ok "Set (${#OPENCLAW_API_KEY} chars)"
  else
    log_warn "Not set — workflows calling OpenClaw will fail"
  fi
fi

# OLLAMA_BASE_URL (if provider is ollama)
if [ "$AI_PROVIDER" = "ollama" ] || [ "${EMBEDDING_PROVIDER:-}" = "ollama" ]; then
  echo -n "  OLLAMA_BASE_URL: "
  if [ -n "$OLLAMA_BASE_URL" ]; then
    log_ok "$OLLAMA_BASE_URL"
  else
    log_error "Not set"
    ENV_VALID=false
  fi
fi

# Write missing variables to .env if needed
echo ""
if [ "$DRY_RUN" = true ]; then
  echo "[DRY RUN] Would append missing variables to .env"
else
  APPENDED=false

  if ! grep -q "^N8N_BASE_URL=" "$ENV_FILE" 2>/dev/null; then
    echo "N8N_BASE_URL=$N8N_BASE_URL" >> "$ENV_FILE"
    echo "  Added N8N_BASE_URL to .env"
    APPENDED=true
  fi

  if ! grep -q "^N8N_API_KEY=" "$ENV_FILE" 2>/dev/null; then
    echo "N8N_API_KEY=$N8N_API_KEY" >> "$ENV_FILE"
    echo "  Added N8N_API_KEY to .env"
    APPENDED=true
  fi

  if [ "$APPENDED" = false ]; then
    echo "  All required variables present in .env"
  fi
fi

if [ "$ENV_VALID" = false ]; then
  log_error "Missing critical environment variables. Fix .env before continuing."
fi

prompt_phase "PHASE 2 — Configure Environment Variables"

# ==========================================
# PHASE 3 — Verify Middleware Connection
# ==========================================
echo "=== PHASE 3 — Verify Middleware Connection ==="
echo ""
echo "Checking that n8n can reach the AI middleware layer..."
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "[DRY RUN] Would test middleware connectivity"
else
  # Test based on AI_PROVIDER
  if [ "$AI_PROVIDER" = "ollama" ]; then
    echo -n "  Ollama ($OLLAMA_BASE_URL): "
    OLLAMA_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${OLLAMA_BASE_URL}/api/tags" 2>/dev/null || echo "000")
    if [ "$OLLAMA_CODE" = "200" ]; then
      log_ok "Reachable"
      MIDDLEWARE_REACHABLE="true"
    else
      log_error "Not reachable (HTTP $OLLAMA_CODE)"
      echo "    Is Ollama running? Try: ollama serve"
    fi

  elif [ "$AI_PROVIDER" = "openclaw_api" ]; then
    echo -n "  OpenClaw API: "
    if [ -z "$OPENCLAW_API_KEY" ]; then
      log_warn "Cannot verify — OPENCLAW_API_KEY not set"
    else
      # Test OpenClaw connectivity (adjust URL if known)
      OPENCLAW_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer $OPENCLAW_API_KEY" \
        "https://api.openclaw.com/v1/health" 2>/dev/null || echo "000")
      if [ "$OPENCLAW_CODE" = "200" ] || [ "$OPENCLAW_CODE" = "204" ]; then
        log_ok "Reachable (HTTP $OPENCLAW_CODE)"
        MIDDLEWARE_REACHABLE="true"
      elif [ "$OPENCLAW_CODE" = "401" ]; then
        log_error "Authentication failed — check OPENCLAW_API_KEY"
      elif [ "$OPENCLAW_CODE" = "000" ]; then
        log_warn "Cannot reach OpenClaw API — may be network or URL issue"
      else
        log_warn "OpenClaw returned HTTP $OPENCLAW_CODE"
      fi
    fi
  fi

  # Also test if n8n can reach Ollama (for embeddings even if using OpenClaw for LLM)
  if [ "${EMBEDDING_PROVIDER:-}" = "ollama" ] && [ "$AI_PROVIDER" != "ollama" ]; then
    echo -n "  Ollama for embeddings ($OLLAMA_BASE_URL): "
    EMBED_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${OLLAMA_BASE_URL}/api/tags" 2>/dev/null || echo "000")
    if [ "$EMBED_CODE" = "200" ]; then
      log_ok "Reachable"
    else
      log_warn "Ollama not reachable — embeddings may fail"
    fi
  fi

  # Test PostgreSQL (needed for RAG workflows)
  echo -n "  PostgreSQL (for RAG): "
  if docker ps --filter "name=^postgres$" --filter "status=running" --format "{{.Names}}" 2>/dev/null | grep -q "^postgres$"; then
    log_ok "Running"
  else
    log_warn "Not running — RAG queries in workflows will fail"
  fi
fi

prompt_phase "PHASE 3 — Verify Middleware Connection"

# ==========================================
# PHASE 4 — Import Workflows
# ==========================================
echo "=== PHASE 4 — Import Workflows ==="
echo ""

# Find workflow JSONs in standard/ and selectable/ subdirectories
WORKFLOW_FILES=$(find "$WORKFLOW_DIR" -path "*/standard/*.json" -o -path "*/selectable/*.json" 2>/dev/null | sort)

if [ -z "$WORKFLOW_FILES" ]; then
  log_warn "No workflow JSON files found in $WORKFLOW_DIR/standard/ or $WORKFLOW_DIR/selectable/"
  echo "  Expected structure: workflows/standard/*.json and workflows/selectable/*.json"
else
  while IFS= read -r json_file; do
    filename=$(basename "$json_file")
    rel_path=$(echo "$json_file" | sed "s|$WORKFLOW_DIR/||")
    workflow_name=$(jq -r '.name' "$json_file" 2>/dev/null)

    if [ -z "$workflow_name" ] || [ "$workflow_name" = "null" ]; then
      log_warn "Skipping $rel_path — no 'name' field found"
      continue
    fi

    echo "Processing: $workflow_name ($rel_path)"

    if [ "$DRY_RUN" = true ]; then
      echo "  [DRY RUN] Would check if workflow exists, import if not"
      IMPORTED+=("$workflow_name (dry run)")
      continue
    fi

    # Check if workflow already exists
    existing_id=$(get_workflow_by_name "$workflow_name")

    if [ -n "$existing_id" ]; then
      echo "  Already exists (id: $existing_id) — skipping import."

      if [ "$SAFE_MODE" = true ]; then
        backup_workflow "$existing_id" "$workflow_name"
      fi
    else
      # Import new workflow
      import_data=$(jq 'del(.id) | del(.versionId)' "$json_file")
      result=$(n8n_api POST "/workflows" "$import_data")
      new_id=$(echo "$result" | jq -r '.id' 2>/dev/null)

      if [ -n "$new_id" ] && [ "$new_id" != "null" ]; then
        log_ok "Imported: $workflow_name (id: $new_id)"
        IMPORTED+=("$workflow_name")
      else
        error_msg=$(echo "$result" | jq -r '.message // "Unknown error"' 2>/dev/null)
        log_error "Failed to import $workflow_name: $error_msg"
      fi
    fi
    echo ""
  done <<< "$WORKFLOW_FILES"
fi

prompt_phase "PHASE 4 — Import Workflows"

# ==========================================
# PHASE 5 — Activate Workflows
# ==========================================
echo "=== PHASE 5 — Activate Workflows ==="
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "[DRY RUN] Would activate all business-assistant workflows"
else
  # Get all workflows
  all_workflows=$(n8n_api GET "/workflows" | jq -r '.data[] | "\(.id)|\(.name)|\(.active)"' 2>/dev/null)

  while IFS='|' read -r wf_id wf_name wf_active; do
    # Activate workflows prefixed with [BAB] or "Business Assistant"
    if echo "$wf_name" | grep -qiE "^\[BAB\]|business assistant"; then
      if [ "$wf_active" = "true" ]; then
        echo "  Already active: $wf_name"
      else
        echo -n "  Activating: $wf_name... "
        result=$(n8n_api PATCH "/workflows/$wf_id" '{"active": true}')
        is_active=$(echo "$result" | jq -r '.active' 2>/dev/null)
        if [ "$is_active" = "true" ]; then
          log_ok "Activated"
          ACTIVATED+=("$wf_name")
        else
          log_error "Failed to activate $wf_name"
        fi
      fi
    fi
  done <<< "$all_workflows"
fi

prompt_phase "PHASE 5 — Activate Workflows"

# ==========================================
# PHASE 6 — Create Webhook Mappings
# ==========================================
echo "=== PHASE 6 — Webhook Mappings ==="
echo ""
echo "Registered webhook endpoints:"
echo ""

EXPECTED_WEBHOOKS=(
  "business/email-triage|[BAB] Email Triage"
  "business/calendar-review|[BAB] Calendar Review"
  "business/daily-briefing|[BAB] Daily Briefing"
  "business/approval-router|[BAB] Approval Router"
  "business/rag-query|[BAB] RAG Query"
  "business/customer-intake|[BAB] Customer Intake"
  "business/document-drafting|[BAB] Document Drafting"
  "business/appointment-booking|[BAB] Appointment Booking"
  "business/invoice-generator|[BAB] Invoice Generator"
  "business/lead-followup|[BAB] Lead Follow-Up"
  "business/review-requester|[BAB] Review Requester"
  "business/expense-tracker|[BAB] Expense Tracker"
  "business/social-post-scheduler|[BAB] Social Post Scheduler"
  "business/report-generator|[BAB] Report Generator"
  "business/voicemail-transcription|[BAB] Voicemail Transcription"
)

if [ "$DRY_RUN" = true ]; then
  for mapping in "${EXPECTED_WEBHOOKS[@]}"; do
    IFS='|' read -r path name <<< "$mapping"
    echo "  [DRY RUN] POST ${N8N_BASE_URL}/webhook/$path → $name"
    WEBHOOK_MAPPINGS+=("POST /webhook/$path → $name")
  done
else
  # Get active workflows and their webhook paths
  all_workflows=$(n8n_api GET "/workflows" | jq -r '.data[] | "\(.id)|\(.name)|\(.active)"' 2>/dev/null)

  for mapping in "${EXPECTED_WEBHOOKS[@]}"; do
    IFS='|' read -r expected_path expected_name <<< "$mapping"

    # Check if workflow exists and is active
    wf_status=$(echo "$all_workflows" | grep "$expected_name" | head -1)

    if [ -n "$wf_status" ]; then
      IFS='|' read -r wf_id wf_name wf_active <<< "$wf_status"
      if [ "$wf_active" = "true" ]; then
        echo "  ✅ POST /webhook/$expected_path → $expected_name (active)"
        WEBHOOK_MAPPINGS+=("POST /webhook/$expected_path → $expected_name (active)")
      else
        echo "  ⚠️  POST /webhook/$expected_path → $expected_name (inactive)"
        WEBHOOK_MAPPINGS+=("POST /webhook/$expected_path → $expected_name (inactive)")
        log_warn "Webhook $expected_path exists but workflow is inactive"
      fi
    else
      echo "  ❌ POST /webhook/$expected_path → $expected_name (NOT FOUND)"
      WEBHOOK_MAPPINGS+=("POST /webhook/$expected_path → $expected_name (missing)")
      log_warn "Workflow '$expected_name' not found — webhook $expected_path will 404"
    fi
  done
fi

echo ""
echo "Base webhook URL: ${N8N_BASE_URL}/webhook/"

prompt_phase "PHASE 6 — Webhook Mappings"

# ==========================================
# PHASE 7 — Test Webhooks
# ==========================================
echo "=== PHASE 7 — Test Webhooks ==="
echo ""

WEBHOOK_PATHS=(
  "business/email-triage"
  "business/calendar-review"
  "business/daily-briefing"
  "business/approval-router"
  "business/rag-query"
  "business/customer-intake"
  "business/document-drafting"
  "business/appointment-booking"
  "business/invoice-generator"
  "business/lead-followup"
  "business/review-requester"
  "business/expense-tracker"
  "business/social-post-scheduler"
  "business/report-generator"
  "business/voicemail-transcription"
)

TEST_PAYLOAD="{\"client\":\"$ACTIVE_CLIENT\",\"source\":\"configure_n8n_test\",\"instruction\":\"test\"}"

for path in "${WEBHOOK_PATHS[@]}"; do
  webhook_url="${N8N_BASE_URL}/webhook/${path}"
  echo -n "  POST $path: "

  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would test"
    TESTED+=("$path (dry run)")
    continue
  fi

  http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$webhook_url" \
    -H "Content-Type: application/json" \
    -d "$TEST_PAYLOAD" 2>/dev/null || echo "000")

  case "$http_code" in
    200|201)
      log_ok "OK ($http_code)"
      TESTED+=("$path")
      ;;
    404)
      log_warn "$path — 404 (workflow not active or path mismatch)"
      ;;
    500)
      log_warn "$path — 500 (workflow error)"
      ;;
    000)
      log_error "$path — Connection failed"
      ;;
    *)
      log_warn "$path — HTTP $http_code"
      ;;
  esac
done

prompt_phase "PHASE 7 — Test Webhooks"

# ==========================================
# PHASE 8 — Generate Report
# ==========================================
echo "=== PHASE 8 — Generate Report ==="
echo ""

generate_report

prompt_phase "PHASE 8 — Generate Report"

# ==========================================
# SUMMARY
# ==========================================
echo "========================================"
echo "         CONFIGURATION COMPLETE"
echo "========================================"
echo ""
echo "  Imported:    ${#IMPORTED[@]} workflows"
echo "  Activated:   ${#ACTIVATED[@]} workflows"
echo "  Webhooks:    ${#WEBHOOK_MAPPINGS[@]} mapped"
echo "  Tested:      ${#TESTED[@]} webhooks"
echo "  Backed up:   ${#BACKED_UP[@]} files"
echo "  Middleware:  $([ "$MIDDLEWARE_REACHABLE" = "true" ] && echo "✅ Reachable" || echo "❌ Not verified")"
echo "  Warnings:    ${#WARNINGS[@]}"
echo "  Errors:      ${#ERRORS[@]}"
echo ""
echo "  Report:      $REPORT_FILE"
echo ""
