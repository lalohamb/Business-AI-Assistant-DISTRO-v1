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
#   DRY_RUN=true ./admin/post_install_client_setup.sh
#   SAFE_MODE=false ./admin/post_install_client_setup.sh
# ==========================================

set -euo pipefail

# ==========================================
# CONFIGURATION
# ==========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="${BASE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
ENV_FILE="$BASE/.env"
TEMPLATE_DIR="$BASE/clients/templates"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

DRY_RUN="${DRY_RUN:-false}"
SAFE_MODE="${SAFE_MODE:-true}"

# Load .env
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

RAG_VENV="$BASE/vector-db/venv"
OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-http://localhost:11434}"

# Tracking
CLIENTS_CREATED=()
FILES_COPIED=()
VAULT_DIRS_CREATED=()
INDEXED_CLIENTS=()
WARNINGS=()
ERRORS=()

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
    *) echo "Aborted."; print_summary; exit 0 ;;
  esac
  echo ""
}

print_summary() {
  echo ""
  echo "========================================"
  echo "       CLIENT SETUP SUMMARY"
  echo "========================================"
  echo ""
  echo "  Clients created:  ${#CLIENTS_CREATED[@]}"
  for c in "${CLIENTS_CREATED[@]:-}"; do echo "    + $c"; done
  echo ""
  echo "  Files copied:     ${#FILES_COPIED[@]}"
  echo "  Vault dirs:       ${#VAULT_DIRS_CREATED[@]}"
  echo "  RAG indexed:      ${#INDEXED_CLIENTS[@]}"
  for c in "${INDEXED_CLIENTS[@]:-}"; do echo "    + $c"; done
  echo ""
  echo "  Warnings:         ${#WARNINGS[@]}"
  if [ ${#WARNINGS[@]} -gt 0 ]; then
    for w in "${WARNINGS[@]}"; do echo "    ⚠️  $w"; done
  fi
  echo "  Errors:           ${#ERRORS[@]}"
  if [ ${#ERRORS[@]} -gt 0 ]; then
    for e in "${ERRORS[@]}"; do echo "    ❌ $e"; done
  fi
  echo ""
  echo "  Next steps:"
  echo "    1. Edit CLIENT_PROFILE.md, BUSINESS_KNOWLEDGE.md, FAQ.md for each client"
  echo "    2. Add business documents to clients/<name>/DOCUMENTS/"
  echo "    3. Re-run this script to re-index"
  echo "    4. Run pre_check.sh with ACTIVE_CLIENT=<client-name>"
  echo ""
}

# ==========================================
# MAIN
# ==========================================

# License check — disabled pending fix for directory-count bug (issue #3)
# source "$SCRIPT_DIR/license_check.sh"
# check_license

echo "========================================"
echo "   BUSINESS ASSISTANT BOX"
echo "   Post-Install Client Setup"
echo "========================================"
echo ""
echo "  Base:       $BASE"
echo "  Templates:  $TEMPLATE_DIR"
echo "  DRY_RUN:    $DRY_RUN"
echo "  SAFE_MODE:  $SAFE_MODE"
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "*** DRY RUN MODE — No changes will be made ***"
  echo ""
fi

# ==========================================
# PHASE 1 — Select Clients to Onboard
# ==========================================
echo "=== PHASE 1 — Select Clients ==="
echo ""

# Check templates exist
if [ ! -d "$TEMPLATE_DIR" ]; then
  log_error "Template directory not found: $TEMPLATE_DIR"
  echo "  Run install.sh first to create the scaffold."
  exit 1
fi

echo "Existing clients:"
for d in "$BASE/clients"/*/; do
  [ -d "$d" ] && echo "  - $(basename "$d")"
done
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "[DRY RUN] Would prompt for client names"
  CLIENT_LIST="${ACTIVE_CLIENT:-demo-company}"
else
  read -p "Enter client names to onboard (comma-separated, e.g. acme-roofing,law-office): " CLIENT_LIST
fi

if [ -z "$CLIENT_LIST" ]; then
  echo "No clients specified. Exiting."
  exit 0
fi

IFS=',' read -ra CLIENTS <<< "$CLIENT_LIST"

# Enforce license client limit
if ! can_add_client && [ "$DRY_RUN" = false ]; then
  check_client_limit  # prints error and exits
fi

# Single-client license can only onboard 1 client at a time
if [ "$LICENSE_TIER" = "single" ] && [ ${#CLIENTS[@]} -gt 1 ]; then
  echo "❌ Single-client license only allows 1 client."
  echo "   You specified ${#CLIENTS[@]} clients. Upgrade to multi-client."
  exit 1
fi

echo ""
echo "Clients to onboard: ${CLIENTS[*]}"

prompt_phase "PHASE 1 — Select Clients"

# ==========================================
# PHASE 2 — Create Client Directories
# ==========================================
echo "=== PHASE 2 — Create Client Directories ==="
echo ""

for client in "${CLIENTS[@]}"; do
  client=$(echo "$client" | xargs) # trim whitespace
  CLIENT_PATH="$BASE/clients/$client"

  echo "Client: $client"

  if [ -d "$CLIENT_PATH" ]; then
    # Check if it has files already
    file_count=$(find "$CLIENT_PATH" -type f 2>/dev/null | wc -l)
    if [ "$file_count" -gt 0 ]; then
      echo "  Already exists with $file_count files."
      if [ "$SAFE_MODE" = true ]; then
        echo "  SAFE_MODE: Skipping (will not overwrite existing client)."
        log_warn "Client '$client' already has files — skipped directory creation"
        continue
      fi
    fi
  fi

  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY RUN] Would create: $CLIENT_PATH from templates"
    CLIENTS_CREATED+=("$client")
    continue
  fi

  # Create directory structure
  mkdir -p "$CLIENT_PATH/PROCEDURES"
  mkdir -p "$CLIENT_PATH/MEMORY"
  mkdir -p "$CLIENT_PATH/OUTPUTS/drafts"
  mkdir -p "$CLIENT_PATH/OUTPUTS/reports"
  mkdir -p "$CLIENT_PATH/OUTPUTS/summaries"

  # Copy template files (only if target doesn't exist)
  for f in "$TEMPLATE_DIR"/*.md; do
    [ -f "$f" ] || continue
    target="$CLIENT_PATH/$(basename "$f")"
    if [ ! -f "$target" ]; then
      cp "$f" "$target"
      FILES_COPIED+=("$target")
    fi
  done

  for f in "$TEMPLATE_DIR/PROCEDURES"/*.md; do
    [ -f "$f" ] || continue
    target="$CLIENT_PATH/PROCEDURES/$(basename "$f")"
    if [ ! -f "$target" ]; then
      cp "$f" "$target"
      FILES_COPIED+=("$target")
    fi
  done

  for f in "$TEMPLATE_DIR/MEMORY"/*.md; do
    [ -f "$f" ] || continue
    target="$CLIENT_PATH/MEMORY/$(basename "$f")"
    if [ ! -f "$target" ]; then
      cp "$f" "$target"
      FILES_COPIED+=("$target")
    fi
  done

  log_ok "Created: $client ($(echo "${FILES_COPIED[@]}" | wc -w) files)"
  CLIENTS_CREATED+=("$client")
  echo ""
done

prompt_phase "PHASE 2 — Create Client Directories"

# ==========================================
# PHASE 3 — Create Client Vault Directories
# ==========================================
echo "=== PHASE 3 — Create Client Vault Directories ==="
echo ""

for client in "${CLIENTS[@]}"; do
  client=$(echo "$client" | xargs)
  CLIENT_DOCS="$BASE/clients/$client/DOCUMENTS"

  echo "Client documents: $client"

  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY RUN] Would create: $CLIENT_DOCS/{contracts,handbooks,financials,uploads,websites,company-documents}"
    VAULT_DIRS_CREATED+=("$CLIENT_DOCS")
    continue
  fi

  mkdir -p "$CLIENT_DOCS/contracts"
  mkdir -p "$CLIENT_DOCS/handbooks"
  mkdir -p "$CLIENT_DOCS/financials"
  mkdir -p "$CLIENT_DOCS/uploads"
  mkdir -p "$CLIENT_DOCS/websites"
  mkdir -p "$CLIENT_DOCS/company-documents"

  log_ok "Documents created: $CLIENT_DOCS"
  VAULT_DIRS_CREATED+=("$CLIENT_DOCS")
  echo ""
done

prompt_phase "PHASE 3 — Create Client Document Directories"

# ==========================================
# PHASE 4 — Update .env for Active Client
# ==========================================
echo "=== PHASE 4 — Update Active Client ==="
echo ""

if [ ${#CLIENTS[@]} -eq 1 ]; then
  NEW_CLIENT="${CLIENTS[0]}"
  NEW_CLIENT=$(echo "$NEW_CLIENT" | xargs)

  echo "Single client onboarded: $NEW_CLIENT"
  echo ""

  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would set ACTIVE_CLIENT=$NEW_CLIENT in .env"
  else
    read -p "Set ACTIVE_CLIENT=$NEW_CLIENT in .env? [y/n]: " set_active
    if [ "$set_active" = "y" ] || [ "$set_active" = "Y" ]; then
      if grep -q "^ACTIVE_CLIENT=" "$ENV_FILE" 2>/dev/null; then
        sed -i "s|^ACTIVE_CLIENT=.*|ACTIVE_CLIENT=$NEW_CLIENT|" "$ENV_FILE"
      else
        echo "ACTIVE_CLIENT=$NEW_CLIENT" >> "$ENV_FILE"
      fi
      echo "  Updated ACTIVE_CLIENT=$NEW_CLIENT"

      # Also update OBSIDIAN_VAULT_PATH
      if grep -q "^OBSIDIAN_VAULT_PATH=" "$ENV_FILE" 2>/dev/null; then
        sed -i "s|^OBSIDIAN_VAULT_PATH=.*|OBSIDIAN_VAULT_PATH=$BASE/clients/$NEW_CLIENT|" "$ENV_FILE"
      fi
      echo "  Updated OBSIDIAN_VAULT_PATH"
    else
      echo "  Skipped. ACTIVE_CLIENT unchanged."
    fi
  fi
else
  echo "Multiple clients onboarded. Set ACTIVE_CLIENT manually in .env:"
  for client in "${CLIENTS[@]}"; do
    echo "  ACTIVE_CLIENT=$(echo "$client" | xargs)"
  done
fi

prompt_phase "PHASE 4 — Update Active Client"

# ==========================================
# PHASE 5 — Validate Client Files
# ==========================================
echo "=== PHASE 5 — Validate Client Files ==="
echo ""

for client in "${CLIENTS[@]}"; do
  client=$(echo "$client" | xargs)
  CLIENT_PATH="$BASE/clients/$client"

  echo "Validating: $client"

  for f in CLIENT_PROFILE.md OWNER_PREFERENCES.md BUSINESS_KNOWLEDGE.md FAQ.md; do
    if [ -f "$CLIENT_PATH/$f" ]; then
      echo "  [✓] $f"
    else
      echo "  [✗] $f MISSING"
      log_warn "$client: $f missing"
    fi
  done

  echo "  PROCEDURES:"
  for f in EMAIL.md CALENDAR.md DAILY_BRIEFING.md DOCUMENTS.md; do
    if [ -f "$CLIENT_PATH/PROCEDURES/$f" ]; then
      echo "    [✓] $f"
    else
      echo "    [✗] $f MISSING"
      log_warn "$client: PROCEDURES/$f missing"
    fi
  done

  echo "  MEMORY:"
  for f in CUSTOMER_RULES.md VENDOR_RULES.md LEARNED_PATTERNS.md OPEN_TASKS.md TODAY.md; do
    if [ -f "$CLIENT_PATH/MEMORY/$f" ]; then
      echo "    [✓] $f"
    else
      echo "    [✗] $f MISSING"
    fi
  done

  echo "  OUTPUTS:"
  for d in drafts reports summaries; do
    if [ -d "$CLIENT_PATH/OUTPUTS/$d" ]; then
      echo "    [✓] $d"
    else
      echo "    [✗] $d MISSING"
    fi
  done
  echo ""
done

prompt_phase "PHASE 5 — Validate Client Files"

# ==========================================
# PHASE 6 — Index Documents (RAG Ingest)
# ==========================================
echo "=== PHASE 6 — Index Documents (RAG Ingest) ==="
echo ""

# Check prerequisites
READY_TO_INDEX=true

echo -n "  PostgreSQL: "
if docker ps --filter "name=^postgres$" --filter "status=running" --format "{{.Names}}" 2>/dev/null | grep -q "^postgres$"; then
  log_ok "Running"
else
  log_error "Not running — cannot index"
  READY_TO_INDEX=false
fi

echo -n "  RAG venv: "
if [ -d "$RAG_VENV" ]; then
  log_ok "Exists"
else
  log_error "Missing ($RAG_VENV) — run install.sh Phase 8"
  READY_TO_INDEX=false
fi

echo -n "  index_vault.py: "
if [ -f "$BASE/vector-db/index_vault.py" ]; then
  log_ok "Exists"
else
  log_error "Missing — run install.sh Phase 8B"
  READY_TO_INDEX=false
fi

if [ "${EMBEDDING_PROVIDER:-ollama}" = "ollama" ]; then
  echo -n "  Ollama (embeddings): "
  OLLAMA_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${OLLAMA_BASE_URL}/api/tags" 2>/dev/null || echo "000")
  if [ "$OLLAMA_CODE" = "200" ]; then
    log_ok "Reachable"
  else
    log_error "Not reachable — embeddings will fail"
    READY_TO_INDEX=false
  fi
fi

echo ""

if [ "$READY_TO_INDEX" = false ]; then
  log_warn "Skipping RAG indexing — prerequisites not met"
else
  for client in "${CLIENTS[@]}"; do
    client=$(echo "$client" | xargs)
    echo "Indexing client: $client"

    if [ "$DRY_RUN" = true ]; then
      echo "  [DRY RUN] Would run: ./vector-db/venv/bin/python3 ./vector-db/index_vault.py"
      INDEXED_CLIENTS+=("$client (dry run)")
      continue
    fi

    read -p "  Index $client now? [y/n]: " index_choice
    if [ "$index_choice" = "y" ] || [ "$index_choice" = "Y" ]; then
      echo "  Running indexer..."
      (
        cd "$BASE"
        source "$RAG_VENV/bin/activate"
        ACTIVE_CLIENT="$client" "$BASE/vector-db/venv/bin/python3" "$BASE/vector-db/index_vault.py"
        deactivate
      ) && {
        log_ok "Indexed: $client"
        INDEXED_CLIENTS+=("$client")
      } || {
        log_error "Indexing failed for $client"
      }
    else
      echo "  Skipped indexing for $client"
    fi
    echo ""
  done
fi

prompt_phase "PHASE 6 — Index Documents"

# ==========================================
# PHASE 7 — Verify RAG Ingest
# ==========================================
echo "=== PHASE 7 — Verify RAG Ingest ==="
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "[DRY RUN] Would query PostgreSQL for chunk counts"
else
  for client in "${CLIENTS[@]}"; do
    client=$(echo "$client" | xargs)
    echo -n "  $client: "

    COUNT=$(docker exec -i postgres psql -U admin businessassistant -t -c \
      "SELECT COUNT(*) FROM rag_chunks WHERE client_name = '$client'" 2>/dev/null | tr -d ' \n')

    if [ -n "$COUNT" ] && [ "$COUNT" -gt 0 ] 2>/dev/null; then
      log_ok "$COUNT chunks indexed"
    else
      log_warn "No chunks found for $client"
    fi
  done
fi

prompt_phase "PHASE 7 — Verify RAG Ingest"

# ==========================================
# SUMMARY
# ==========================================
print_summary
