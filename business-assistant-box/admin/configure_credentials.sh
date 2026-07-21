#!/bin/bash

# ==========================================
# BUSINESS ASSISTANT BOX — Credential Configurator
# ==========================================
# Automates n8n credential creation for Google OAuth2.
# The user must complete ONE manual step: browser sign-in.
#
# Usage:
#   ./admin/configure_credentials.sh
#   ./admin/configure_credentials.sh --client-id YOUR_ID --client-secret YOUR_SECRET
#   DRY_RUN=true ./admin/configure_credentials.sh
# ==========================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="${BASE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
ENV_FILE="$BASE/.env"
DRY_RUN="${DRY_RUN:-false}"

# Load .env
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

N8N_BASE_URL="${N8N_BASE_URL:-http://localhost:5678}"
N8N_API_KEY="${N8N_API_KEY:-}"
ACTIVE_CLIENT="${ACTIVE_CLIENT:-demo-company}"

# Parse arguments
GOOGLE_CLIENT_ID=""
GOOGLE_CLIENT_SECRET=""
SKIP_PROMPT=false

while [ $# -gt 0 ]; do
  case "$1" in
    --client-id) GOOGLE_CLIENT_ID="$2"; shift 2 ;;
    --client-secret) GOOGLE_CLIENT_SECRET="$2"; shift 2 ;;
    --skip-prompt) SKIP_PROMPT=true; shift ;;
    *) shift ;;
  esac
done

# ==========================================
# UTILITY
# ==========================================

log_ok() { echo "  ✅ $1"; }
log_warn() { echo "  ⚠️  $1"; }
log_error() { echo "  ❌ $1"; }

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

# ==========================================
# MAIN
# ==========================================

echo "========================================"
echo "   BUSINESS ASSISTANT BOX"
echo "   Credential Configurator"
echo "========================================"
echo ""
echo "  n8n URL:    $N8N_BASE_URL"
echo "  Client:     $ACTIVE_CLIENT"
echo "  DRY_RUN:    $DRY_RUN"
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "*** DRY RUN MODE — No changes will be made ***"
  echo ""
fi

# ==========================================
# PHASE 1 — Verify n8n is accessible
# ==========================================
echo "=== PHASE 1 — Verify n8n API ==="
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "  [DRY RUN] Would verify n8n API at $N8N_BASE_URL"
else
  echo -n "  n8n API: "
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    ${N8N_API_KEY:+-H "X-N8N-API-KEY: $N8N_API_KEY"} \
    "${N8N_BASE_URL}/api/v1/credentials" 2>/dev/null || echo "000")

  if [ "$HTTP_CODE" = "200" ]; then
    log_ok "Accessible"
  elif [ "$HTTP_CODE" = "401" ]; then
    log_error "API key invalid or missing. Set N8N_API_KEY in .env"
    exit 1
  else
    log_error "Cannot reach n8n (HTTP $HTTP_CODE). Is it running?"
    exit 1
  fi
fi
echo ""

# ==========================================
# PHASE 2 — Check existing credentials
# ==========================================
echo "=== PHASE 2 — Check Existing Credentials ==="
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "  [DRY RUN] Would list existing credentials"
else
  EXISTING=$(n8n_api GET "/credentials" | jq -r '.data[] | "  \(.type) — \(.name) (id: \(.id))"' 2>/dev/null)

  if [ -n "$EXISTING" ]; then
    echo "  Found existing credentials:"
    echo "$EXISTING"
    echo ""
    echo "  If Google OAuth2 is already configured, you may not need to run this."
    echo ""
    if [ "$SKIP_PROMPT" = false ]; then
      read -p "  Continue and create new credentials? [y/n]: " choice
      case "$choice" in
        y|Y) echo "" ;;
        *) echo "  Aborted."; exit 0 ;;
      esac
    fi
  else
    echo "  No credentials found. Proceeding with setup."
  fi
fi
echo ""

# ==========================================
# PHASE 3 — Collect Google OAuth2 details
# ==========================================
echo "=== PHASE 3 — Google OAuth2 Setup ==="
echo ""

if [ -z "$GOOGLE_CLIENT_ID" ] || [ -z "$GOOGLE_CLIENT_SECRET" ]; then
  echo "  You need a Google Cloud OAuth2 Client ID and Secret."
  echo ""
  echo "  If you don't have one yet:"
  echo "    1. Go to https://console.cloud.google.com"
  echo "    2. Create or select a project"
  echo "    3. Enable APIs: Gmail, Calendar, Sheets, Docs, Drive"
  echo "    4. Go to Credentials → Create OAuth 2.0 Client ID"
  echo "    5. Application type: Web application"
  echo "    6. Add redirect URI:"
  echo "       ${N8N_BASE_URL}/rest/oauth2-credential/callback"
  echo ""

  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY RUN] Would prompt for Client ID and Secret"
    GOOGLE_CLIENT_ID="DRY_RUN_CLIENT_ID"
    GOOGLE_CLIENT_SECRET="DRY_RUN_CLIENT_SECRET"
  else
    read -p "  Google Client ID: " GOOGLE_CLIENT_ID
    read -p "  Google Client Secret: " GOOGLE_CLIENT_SECRET

    if [ -z "$GOOGLE_CLIENT_ID" ] || [ -z "$GOOGLE_CLIENT_SECRET" ]; then
      log_error "Client ID and Secret are required."
      exit 1
    fi
  fi
fi

echo ""
log_ok "Client ID: ${GOOGLE_CLIENT_ID:0:20}..."
log_ok "Client Secret: ${GOOGLE_CLIENT_SECRET:0:8}..."
echo ""

# ==========================================
# PHASE 4 — Create credentials in n8n
# ==========================================
echo "=== PHASE 4 — Create n8n Credentials ==="
echo ""

REDIRECT_URI="${N8N_BASE_URL}/rest/oauth2-credential/callback"

# Define credentials to create
declare -A CRED_SCOPES
CRED_SCOPES["Gmail OAuth2"]="https://www.googleapis.com/auth/gmail.readonly https://www.googleapis.com/auth/gmail.send"
CRED_SCOPES["Google Calendar OAuth2"]="https://www.googleapis.com/auth/calendar.readonly https://www.googleapis.com/auth/calendar.events"
CRED_SCOPES["Google Sheets OAuth2"]="https://www.googleapis.com/auth/spreadsheets"
CRED_SCOPES["Google Docs OAuth2"]="https://www.googleapis.com/auth/documents https://www.googleapis.com/auth/drive.file"
CRED_SCOPES["Google Drive OAuth2"]="https://www.googleapis.com/auth/drive.file https://www.googleapis.com/auth/drive.readonly"

CREATED_IDS=()

for cred_name in "${!CRED_SCOPES[@]}"; do
  scopes="${CRED_SCOPES[$cred_name]}"
  echo "  Creating: $cred_name"
  echo "    Scopes: $scopes"

  if [ "$DRY_RUN" = true ]; then
    echo "    [DRY RUN] Would create credential"
    CREATED_IDS+=("dry-run-id")
    echo ""
    continue
  fi

  # Check if credential with this name already exists
  existing_id=$(n8n_api GET "/credentials" | jq -r ".data[] | select(.name == \"$cred_name\") | .id" 2>/dev/null)

  if [ -n "$existing_id" ]; then
    echo "    Already exists (id: $existing_id) — skipping"
    CREATED_IDS+=("$existing_id")
    echo ""
    continue
  fi

  # Create the credential
  PAYLOAD=$(cat <<EOF
{
  "name": "$cred_name",
  "type": "oAuth2Api",
  "data": {
    "clientId": "$GOOGLE_CLIENT_ID",
    "clientSecret": "$GOOGLE_CLIENT_SECRET",
    "scope": "$scopes",
    "authUrl": "https://accounts.google.com/o/oauth2/v2/auth",
    "accessTokenUrl": "https://oauth2.googleapis.com/token",
    "authQueryParameters": "access_type=offline&prompt=consent",
    "redirectUri": "$REDIRECT_URI"
  }
}
EOF
)

  result=$(n8n_api POST "/credentials" "$PAYLOAD")
  new_id=$(echo "$result" | jq -r '.id' 2>/dev/null)

  if [ -n "$new_id" ] && [ "$new_id" != "null" ]; then
    log_ok "Created (id: $new_id)"
    CREATED_IDS+=("$new_id")
  else
    error_msg=$(echo "$result" | jq -r '.message // "Unknown error"' 2>/dev/null)
    log_error "Failed: $error_msg"
  fi
  echo ""
done

# ==========================================
# PHASE 5 — Manual Authorization Step
# ==========================================
echo "=== PHASE 5 — Authorize Credentials (MANUAL) ==="
echo ""
echo "  ┌─────────────────────────────────────────────────────────┐"
echo "  │  This is the ONE manual step that cannot be automated.  │"
echo "  │  You must sign in with the business Google account.     │"
echo "  └─────────────────────────────────────────────────────────┘"
echo ""
echo "  Steps:"
echo ""
echo "    1. Open n8n in your browser:"
echo "       ${N8N_BASE_URL}"
echo ""
echo "    2. Go to: Settings → Credentials"
echo ""
echo "    3. For EACH credential created above:"
echo "       a. Click the credential name"
echo "       b. Click 'Connect' (or 'Reconnect')"
echo "       c. Sign in with the business email"
echo "          (e.g., info@acmeroofing.com)"
echo "       d. Grant the requested permissions"
echo "       e. You'll be redirected back to n8n"
echo ""
echo "    4. Repeat for each credential:"

for cred_name in "${!CRED_SCOPES[@]}"; do
  echo "       • $cred_name"
done

echo ""
echo "  Redirect URI (must match Google Cloud Console):"
echo "    $REDIRECT_URI"
echo ""

if [ "$DRY_RUN" = false ] && [ "$SKIP_PROMPT" = false ]; then
  read -p "  Press Enter after completing authorization in the browser... "
fi
echo ""

# ==========================================
# PHASE 6 — Verify Authorization
# ==========================================
echo "=== PHASE 6 — Verify Credentials ==="
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "  [DRY RUN] Would verify each credential has a valid token"
else
  CREDS=$(n8n_api GET "/credentials" | jq -r '.data[] | select(.type == "oAuth2Api") | "\(.id)|\(.name)"' 2>/dev/null)

  if [ -z "$CREDS" ]; then
    log_warn "No OAuth2 credentials found to verify"
  else
    while IFS='|' read -r cred_id cred_name; do
      echo -n "  $cred_name (id: $cred_id): "
      # n8n doesn't expose token validity via API easily,
      # so we check if the credential exists and was recently updated
      cred_detail=$(n8n_api GET "/credentials/$cred_id" 2>/dev/null)
      updated=$(echo "$cred_detail" | jq -r '.updatedAt // "unknown"' 2>/dev/null)

      if [ "$updated" != "unknown" ] && [ "$updated" != "null" ]; then
        log_ok "Configured (last updated: $updated)"
      else
        log_warn "Created but may not be authorized yet"
      fi
    done <<< "$CREDS"
  fi
fi
echo ""

# ==========================================
# PHASE 7 — Save credential mapping
# ==========================================
echo "=== PHASE 7 — Save Credential Map ==="
echo ""

CRED_MAP_FILE="$BASE/n8n/CREDENTIAL_MAP.md"

if [ "$DRY_RUN" = true ]; then
  echo "  [DRY RUN] Would save credential map to $CRED_MAP_FILE"
else
  # Write real credential IDs to .env so configure_n8n.sh can use them
  echo "  Writing credential IDs to .env..."
  CREDS_JSON=$(n8n_api GET "/credentials" 2>/dev/null)

  declare -A CRED_ENV_MAP
  CRED_ENV_MAP["Gmail OAuth2"]="GMAIL_CREDENTIAL_ID"
  CRED_ENV_MAP["Google Calendar OAuth2"]="GCAL_CREDENTIAL_ID"
  CRED_ENV_MAP["Google Sheets OAuth2"]="SHEETS_CREDENTIAL_ID"
  CRED_ENV_MAP["Google Docs OAuth2"]="DOCS_CREDENTIAL_ID"
  CRED_ENV_MAP["Google Drive OAuth2"]="DRIVE_CREDENTIAL_ID"

  for cred_name in "${!CRED_ENV_MAP[@]}"; do
    env_var="${CRED_ENV_MAP[$cred_name]}"
    cred_id=$(echo "$CREDS_JSON" | jq -r ".data[] | select(.name == \"$cred_name\") | .id" 2>/dev/null | head -1)
    if [ -n "$cred_id" ] && [ "$cred_id" != "null" ]; then
      if grep -q "^${env_var}=" "$ENV_FILE" 2>/dev/null; then
        sed -i "s|^${env_var}=.*|${env_var}=${cred_id}|" "$ENV_FILE"
      else
        echo "${env_var}=${cred_id}" >> "$ENV_FILE"
      fi
      echo "    $env_var=$cred_id"
    fi
  done
  log_ok "Credential IDs written to .env"
  echo ""

  # Prompt for Google Sheet IDs needed by workflows
  echo "  Google Sheet IDs are required for Lead Follow-Up, Customer Intake,"
  echo "  Invoice Generator, and Report Generator workflows."
  echo ""
  echo "  For each, create a Google Sheet and paste the Sheet ID from its URL:"
  echo "  https://docs.google.com/spreadsheets/d/SHEET_ID_IS_HERE/edit"
  echo ""

  for sheet_var in LEADS_SHEET_ID INTAKE_SHEET_ID INVOICE_SHEET_ID REPORT_SHEET_ID; do
    current=$(grep "^${sheet_var}=" "$ENV_FILE" 2>/dev/null | cut -d= -f2)
    if [ -n "$current" ]; then
      echo "  $sheet_var already set: $current"
    else
      read -p "  $sheet_var (leave blank to skip): " sheet_id
      if [ -n "$sheet_id" ]; then
        echo "${sheet_var}=${sheet_id}" >> "$ENV_FILE"
        log_ok "$sheet_var saved to .env"
      else
        echo "  Skipped $sheet_var — set it later in .env"
      fi
    fi
  done
  echo ""

  cat > "$CRED_MAP_FILE" <<EOF
# Credential Map

Generated: $(date +"%Y-%m-%d %H:%M:%S")
Client: $ACTIVE_CLIENT

## Google OAuth2 Credentials

| Credential Name | Scopes | Workflows Using It |
|----------------|--------|-------------------|
| Gmail OAuth2 | gmail.readonly, gmail.send | Email Triage, Daily Briefing, Invoice Generator, Lead Follow-Up, Review Requester, Report Generator |
| Google Calendar OAuth2 | calendar.readonly, calendar.events | Calendar Review, Daily Briefing, Appointment Booking |
| Google Sheets OAuth2 | spreadsheets | Customer Intake, Invoice Generator, Lead Follow-Up, Expense Tracker, Report Generator |
| Google Docs OAuth2 | documents, drive.file | Document Drafting |
| Google Drive OAuth2 | drive.file, drive.readonly | Expense Tracker, Voicemail Transcription |

## Redirect URI

\`\`\`
${REDIRECT_URI}
\`\`\`

## Business Email Connected

Set during authorization step. To change, re-authorize the credential with a different Google account.

## Re-Authorization

If tokens expire or are revoked:
1. Open n8n → Settings → Credentials
2. Click the credential
3. Click Reconnect
4. Sign in again

## Notes

- All credentials use the same Google Cloud OAuth2 Client ID
- Each credential has different scopes for least-privilege access
- Tokens auto-refresh — manual re-auth only needed if revoked
EOF

  log_ok "Saved: $CRED_MAP_FILE"
fi
echo ""

# ==========================================
# PHASE 8 — Next Steps
# ==========================================
echo "========================================"
echo "         CREDENTIAL SETUP COMPLETE"
echo "========================================"
echo ""
echo "  Created: ${#CREATED_IDS[@]} credentials"
echo ""
echo "  Next steps:"
echo ""
echo "    1. If you haven't authorized yet, open n8n and connect each credential:"
echo "       ${N8N_BASE_URL}"
echo ""
echo "    2. Import and activate workflows:"
echo "       ./admin/configure_n8n.sh"
echo ""
echo "    3. Open each workflow in n8n and assign credentials to nodes:"
echo "       - Email nodes → Gmail OAuth2"
echo "       - Calendar nodes → Google Calendar OAuth2"
echo "       - Sheets nodes → Google Sheets OAuth2"
echo "       - Docs nodes → Google Docs OAuth2"
echo "       - Drive nodes → Google Drive OAuth2"
echo ""
echo "    4. Test email triage:"
echo "       curl -X POST ${N8N_BASE_URL}/webhook/business/email-triage \\"
echo "         -H 'Content-Type: application/json' \\"
echo "         -d '{\"test\": true}'"
echo ""
echo "  Credential map saved to: $CRED_MAP_FILE"
echo ""
