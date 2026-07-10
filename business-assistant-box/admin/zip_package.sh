#!/bin/bash

# ==========================================
# BUSINESS ASSISTANT BOX - PACKAGE FOR NEW MACHINE
# ==========================================
# Creates a portable zip containing ONLY source files needed for install.
# Excludes all runtime data (Docker volumes, venv, caches, databases).
#
# Usage:
#   ./admin/zip_package.sh
#   ./admin/zip_package.sh /path/to/output.zip
#
# On new machine:
#   unzip business-assistant-box-YYYYMMDD.zip -d /opt/
#   cd /opt/business-assistant-box
#   sudo ./admin/install.sh
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
DEFAULT_OUTPUT="$HOME/business-assistant-box-${TIMESTAMP}.zip"
OUTPUT="${1:-$DEFAULT_OUTPUT}"

echo "========================================"
echo "   PACKAGE FOR NEW MACHINE"
echo "========================================"
echo ""

# Check zip is available
if ! command -v zip &>/dev/null; then
  echo "Installing zip..."
  sudo apt install -y zip
fi

echo "Source:  $BASE_PATH"
echo "Output:  $OUTPUT"
echo ""
echo "Including:"
echo "  ✅ admin/                    (install scripts, docs, tests)"
echo "  ✅ system/                   (agent rules, policies)"
echo "  ✅ clients/                  (client business knowledge)"
echo "  ✅ vault/                    (shared documents)"
echo "  ✅ vector-db/*.py, *.sql     (RAG scripts, schema)"
echo "  ✅ n8n/workflows/            (workflow JSONs, manifest)"
echo "  ✅ dashboard/functions/      (RAG filter)"

echo "  ✅ openclaw/                 (workspace)"
echo "  ✅ .env                      (configuration)"
echo ""
echo "Excluding:"
echo "  ❌ dashboard/ (WebUI runtime: cache, uploads, webui.db)"
echo "  ❌ docker/              (container configs — regenerated)"
echo "  ❌ postgres/            (database data — regenerated)"
echo "  ❌ n8n/ (runtime: database, cache, crash.journal)"
echo "  ❌ vector-db/venv/      (Python venv — regenerated)"
echo "  ❌ logs/                (log files)"
echo "  ❌ backups/             (backup archives)"
echo "  ❌ *.bak.*              (backup files)"
echo "  ❌ .git/                (git history)"
echo "  ❌ node_modules/        (JS dependencies)"
echo "  ❌ .next/               (Next.js build cache)"
echo ""

read -p "Proceed? [y/n]: " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
  echo "Aborted."
  exit 0
fi

# Sanitize .env — strip credential values before packaging
SANITIZED_ENV="${BASE_PATH}/.env.package"
if [ -f "${BASE_PATH}/.env" ]; then
  sed -E 's/^(N8N_API_KEY=).+$/\1/' "${BASE_PATH}/.env" \
    | sed -E 's/^(OPENCLAW_API_KEY=).+$/\1/' \
    | sed -E 's/^(GOOGLE_API_KEY=).+$/\1/' \
    > "$SANITIZED_ENV"
  echo "  🔒 Credentials stripped from .env for packaging"
fi

cd "$(dirname "$BASE_PATH")"
PROJECT_DIR=$(basename "$BASE_PATH")

# Build zip with broad exclusions first
zip -r "$OUTPUT" "$PROJECT_DIR" \
  -x "${PROJECT_DIR}/.env" \
  -x "${PROJECT_DIR}/postgres/*" \
  -x "${PROJECT_DIR}/docker/*" \
  -x "${PROJECT_DIR}/logs/*" \
  -x "${PROJECT_DIR}/backups/*" \
  -x "${PROJECT_DIR}/vector-db/venv/*" \
  -x "${PROJECT_DIR}/.git/*" \
  -x "*.bak.*" \
  -x "*node_modules/*" \
  -x "*.next/*" \
  -x "*.sqlite3*" \
  -x "*.db-shm" \
  -x "*.db-wal" \
  -x "*__pycache__/*" \
  -x "*.pyc" \
  -x "${PROJECT_DIR}/n8n/database.sqlite" \
  -x "${PROJECT_DIR}/n8n/.n8n/*" \
  -x "${PROJECT_DIR}/n8n/crash.journal" \
  -x "${PROJECT_DIR}/n8n/binaryData/*" \
  -x "${PROJECT_DIR}/n8n/executionData/*" \
  -x "${PROJECT_DIR}/n8n/.cache/*" \
  -x "${PROJECT_DIR}/n8n/nodes/*" \
  -x "${PROJECT_DIR}/n8n/static/*" \
  -x "${PROJECT_DIR}/dashboard/cache/*" \
  -x "${PROJECT_DIR}/dashboard/uploads/*" \
  -x "${PROJECT_DIR}/dashboard/vector_db/*" \
  -x "${PROJECT_DIR}/dashboard/webui.db*" \
  -x "${PROJECT_DIR}/dashboard/audit.log*" \
  -x "${PROJECT_DIR}/dashboard/config.json" \
  -x "${PROJECT_DIR}/dashboard/sentence_transformers/*"

# Add sanitized .env (credentials stripped)
if [ -f "$SANITIZED_ENV" ]; then
  cd "$(dirname "$BASE_PATH")"
  cp "$SANITIZED_ENV" "${PROJECT_DIR}/.env"
  zip -u "$OUTPUT" "${PROJECT_DIR}/.env"
  cp "${BASE_PATH}/.env" "${PROJECT_DIR}/.env"  # restore original
  rm -f "$SANITIZED_ENV"
fi

echo ""
echo "========================================"
echo "         PACKAGE COMPLETE"
echo "========================================"
echo ""

ZIP_SIZE=$(du -h "$OUTPUT" | cut -f1)
FILE_COUNT=$(zipinfo -t "$OUTPUT" 2>/dev/null | grep -oP '\d+(?= files)' || echo "?")
echo "  📦 $OUTPUT"
echo "     Size: $ZIP_SIZE | Files: $FILE_COUNT"
echo ""
echo "  On new machine:"
echo "    1. Copy zip to new machine"
echo "    2. unzip $(basename "$OUTPUT") -d /opt/"
echo "    3. cd /opt/business-assistant-box"
echo "    4. Edit .env — update BASE_PATH and any API keys"
echo "    5. sudo ./admin/install.sh"
echo "    6. After install, create n8n credentials (see Phase 6 notes)"
echo "    7. sudo ./admin/post_install_verify.sh"
echo ""
