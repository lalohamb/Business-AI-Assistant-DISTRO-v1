#!/bin/bash

# ==========================================
# BUSINESS ASSISTANT BOX — Quickstart
# ==========================================
# One command to set up a fresh machine end-to-end.
# Calls each script in order, pausing between phases.
#
# Usage:
#   sudo ./admin/quickstart.sh
#   DRY_RUN=true sudo ./admin/quickstart.sh
#
# Each phase can be skipped individually.
# If a phase fails, fix the issue and re-run — scripts
# are idempotent (safe to run again).
# ==========================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="${BASE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
ENV_FILE="$BASE/.env"
DRY_RUN="${DRY_RUN:-false}"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

echo "========================================"
echo "   BUSINESS ASSISTANT BOX"
echo "   Quickstart Installer"
echo "========================================"
echo ""
echo "  Base path:  $BASE"
echo "  DRY_RUN:    $DRY_RUN"
echo "  Date:       $TIMESTAMP"
echo ""
echo "  This will run the full setup sequence:"
echo ""
echo "    Phase 1 → install.sh            (infrastructure)"
echo "    Phase 2 → configure_credentials.sh (Google OAuth2)"
echo "    Phase 3 → configure_n8n.sh      (workflows)"
echo "    Phase 4 → post_install_client_setup.sh (client vault)"
echo "    Phase 5 → switch_client.sh      (activate client)"
echo "    Phase 6 → index_vault.py        (RAG indexing)"
echo "    Phase 7 → post_install_verify.sh (validation)"
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "*** DRY RUN MODE — No changes will be made ***"
  echo ""
fi

read -p "  Start quickstart? [yes/no]: " confirm
if [ "$confirm" != "yes" ] && [ "$confirm" != "y" ]; then
  echo "  Aborted."
  exit 0
fi
echo ""

# Track results
PHASE_RESULTS=()

run_phase() {
  local phase_num="$1"
  local phase_name="$2"
  local phase_cmd="$3"

  echo ""
  echo "========================================"
  echo "  PHASE $phase_num — $phase_name"
  echo "========================================"
  echo ""

  read -p "  Run this phase? [y/skip/quit]: " choice
  case "$choice" in
    y|Y|yes)
      echo ""
      if [ "$DRY_RUN" = true ]; then
        echo "  [DRY RUN] Would run: $phase_cmd"
        PHASE_RESULTS+=("Phase $phase_num: $phase_name — SKIPPED (dry run)")
      else
        eval "$phase_cmd"
        local exit_code=$?
        if [ $exit_code -eq 0 ]; then
          PHASE_RESULTS+=("Phase $phase_num: $phase_name — ✅ Complete")
        else
          PHASE_RESULTS+=("Phase $phase_num: $phase_name — ⚠️ Exited with code $exit_code")
          echo ""
          echo "  Phase $phase_num exited with code $exit_code."
          read -p "  Continue to next phase anyway? [y/n]: " cont
          if [ "$cont" != "y" ] && [ "$cont" != "Y" ]; then
            print_summary
            exit 1
          fi
        fi
      fi
      ;;
    skip|s|S)
      echo "  Skipping Phase $phase_num."
      PHASE_RESULTS+=("Phase $phase_num: $phase_name — SKIPPED")
      ;;
    quit|q|Q)
      echo "  Quitting."
      print_summary
      exit 0
      ;;
    *)
      echo "  Skipping Phase $phase_num."
      PHASE_RESULTS+=("Phase $phase_num: $phase_name — SKIPPED")
      ;;
  esac
}

print_summary() {
  echo ""
  echo "========================================"
  echo "         QUICKSTART SUMMARY"
  echo "========================================"
  echo ""
  for result in "${PHASE_RESULTS[@]:-}"; do
    echo "  $result"
  done
  echo ""

  if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE" 2>/dev/null
    echo "  Active Client: ${ACTIVE_CLIENT:-not set}"
    echo "  n8n:           ${N8N_BASE_URL:-http://localhost:5678}"
    echo "  Open WebUI:    ${OPENWEBUI_BASE_URL:-http://localhost:3000}"
    echo "  Ollama:        ${OLLAMA_BASE_URL:-http://localhost:11434}"
  fi

  echo ""
  echo "  Documentation:"
  echo "    admin/COMMANDS.md           — Full command reference"
  echo "    admin/WORKFLOW_SETUP.md     — Workflow configuration"
  echo "    admin/switch_client.md      — Client switching"
  echo "    admin/NEW_MACHINE_SETUP.md  — Hardware requirements"
  echo ""
}

# ==========================================
# PHASE 1 — Infrastructure
# ==========================================
run_phase 1 "Infrastructure (install.sh)" "$SCRIPT_DIR/install.sh"

# ==========================================
# PHASE 2 — Google OAuth2 Credentials
# ==========================================
run_phase 2 "Google OAuth2 Credentials (configure_credentials.sh)" "$SCRIPT_DIR/configure_credentials.sh"

# ==========================================
# PHASE 3 — n8n Workflows
# ==========================================
run_phase 3 "n8n Workflows (configure_n8n.sh)" "$SCRIPT_DIR/configure_n8n.sh"

# ==========================================
# PHASE 4 — Client Vault Setup
# ==========================================
run_phase 4 "Client Vault Setup (post_install_client_setup.sh)" "$SCRIPT_DIR/post_install_client_setup.sh"

# ==========================================
# PHASE 5 — Switch to Client
# ==========================================
echo ""
echo "========================================"
echo "  PHASE 5 — Activate Client"
echo "========================================"
echo ""

if [ -f "$ENV_FILE" ]; then
  source "$ENV_FILE" 2>/dev/null
fi

# List available clients
echo "  Available clients:"
for d in "$BASE/clients"/*/; do
  [ -d "$d" ] || continue
  client_name=$(basename "$d")
  [ "$client_name" = "templates" ] && continue
  echo "    • $client_name"
done
echo ""

read -p "  Which client to activate? [name/skip]: " client_choice
case "$client_choice" in
  skip|s|S|"")
    echo "  Skipping Phase 5."
    PHASE_RESULTS+=("Phase 5: Activate Client — SKIPPED")
    ;;
  *)
    if [ "$DRY_RUN" = true ]; then
      echo "  [DRY RUN] Would run: switch_client.sh $client_choice"
      PHASE_RESULTS+=("Phase 5: Activate Client ($client_choice) — SKIPPED (dry run)")
    else
      "$SCRIPT_DIR/switch_client.sh" "$client_choice"
      PHASE_RESULTS+=("Phase 5: Activate Client ($client_choice) — ✅ Complete")
    fi
    ;;
esac

# ==========================================
# PHASE 6 — RAG Indexing
# ==========================================
echo ""
echo "========================================"
echo "  PHASE 6 — RAG Indexing"
echo "========================================"
echo ""

read -p "  Index client vault into RAG? [y/skip]: " rag_choice
case "$rag_choice" in
  y|Y|yes)
    if [ "$DRY_RUN" = true ]; then
      echo "  [DRY RUN] Would run: vector-db/venv/bin/python vector-db/index_vault.py"
      PHASE_RESULTS+=("Phase 6: RAG Indexing — SKIPPED (dry run)")
    else
      if [ -f "$BASE/vector-db/venv/bin/python" ]; then
        "$BASE/vector-db/venv/bin/python" "$BASE/vector-db/index_vault.py"
        PHASE_RESULTS+=("Phase 6: RAG Indexing — ✅ Complete")
      else
        echo "  ⚠️  Python venv not found. Create it first:"
        echo "     python3 -m venv vector-db/venv"
        echo "     vector-db/venv/bin/pip install psycopg2-binary python-dotenv requests"
        PHASE_RESULTS+=("Phase 6: RAG Indexing — ⚠️ venv missing")
      fi
    fi
    ;;
  *)
    echo "  Skipping Phase 6."
    PHASE_RESULTS+=("Phase 6: RAG Indexing — SKIPPED")
    ;;
esac

# ==========================================
# PHASE 7 — Validation
# ==========================================
run_phase 7 "Validation (post_install_verify.sh)" "$SCRIPT_DIR/post_install_verify.sh"

# ==========================================
# SUMMARY
# ==========================================
print_summary

echo "========================================"
echo "  ✅ Quickstart complete."
echo "========================================"
echo ""
echo "  Open your services:"
echo "    • Open WebUI:  http://localhost:3000"
echo "    • n8n:         http://localhost:5678"
echo "    • Obsidian:    Open vault at $BASE/current-client"
echo ""
