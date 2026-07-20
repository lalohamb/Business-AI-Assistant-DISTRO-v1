#!/bin/bash
# ==========================================
# package.sh — Build distributable editions
# ==========================================
# Generates a clean distribution folder/zip for either edition:
#   ./admin/package.sh single   → single-business edition
#   ./admin/package.sh multi    → multi-client edition
#
# Output: dist/business-assistant-box-{edition}/
#         dist/business-assistant-box-{edition}.tar.gz
# ==========================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
EDITION="${1:-}"
DIST_DIR="$BASE_PATH/dist"

if [ -z "$EDITION" ] || [[ ! "$EDITION" =~ ^(single|multi)$ ]]; then
  echo "Usage: ./admin/package.sh <single|multi>"
  echo ""
  echo "  single  — One business per install (no client switching)"
  echo "  multi   — Multiple clients with switching support"
  exit 1
fi

PACKAGE_NAME="business-assistant-box-${EDITION}"
OUTPUT="$DIST_DIR/$PACKAGE_NAME"

echo "========================================="
echo "  Packaging: $EDITION edition"
echo "========================================="
echo ""

# Clean previous build
rm -rf "$OUTPUT"
mkdir -p "$OUTPUT"

# -------------------------------------------
# Copy core structure
# -------------------------------------------
echo "Copying core files..."

# Directories to include (empty structure)
for dir in system vector-db n8n/workflows/standard n8n/workflows/selectable openclaw dashboard docker logs backups; do
  mkdir -p "$OUTPUT/$dir"
done

# Copy system files
cp "$BASE_PATH"/system/*.md "$OUTPUT/system/" 2>/dev/null || true

# Copy vector-db scripts
cp "$BASE_PATH/vector-db/index_vault.py" "$OUTPUT/vector-db/"
cp "$BASE_PATH/vector-db/query_vault.py" "$OUTPUT/vector-db/"
cp "$BASE_PATH/vector-db/schema.sql" "$OUTPUT/vector-db/" 2>/dev/null || true

# Copy workflows
cp "$BASE_PATH"/n8n/workflows/standard/*.json "$OUTPUT/n8n/workflows/standard/" 2>/dev/null || true
cp "$BASE_PATH"/n8n/workflows/selectable/*.json "$OUTPUT/n8n/workflows/selectable/" 2>/dev/null || true
cp "$BASE_PATH/n8n/workflows/manifest.json" "$OUTPUT/n8n/workflows/" 2>/dev/null || true

# Copy dashboard functions
if [ -d "$BASE_PATH/dashboard/functions" ]; then
  mkdir -p "$OUTPUT/dashboard/functions"
  cp "$BASE_PATH"/dashboard/functions/*.py "$OUTPUT/dashboard/functions/" 2>/dev/null || true
fi

# Copy .gitignore
cp "$BASE_PATH/.gitignore" "$OUTPUT/" 2>/dev/null || true

# -------------------------------------------
# Edition-specific: admin scripts
# -------------------------------------------
echo "Copying admin scripts ($EDITION)..."
mkdir -p "$OUTPUT/admin"

# Scripts included in BOTH editions
COMMON_SCRIPTS=(
  install.sh
  pre_check.sh
  post_install_verify.sh
  configure_n8n.sh
  configure_credentials.sh
  configure_rag_pipeline.sh
  customize_ui_n8n.sh
  post_install_client_setup.sh
  validate_env.sh
  uninstall.sh
  quickstart.sh
  current_client.sh
)

for script in "${COMMON_SCRIPTS[@]}"; do
  [ -f "$BASE_PATH/admin/$script" ] && cp "$BASE_PATH/admin/$script" "$OUTPUT/admin/"
done

# Scripts included in BOTH editions (docs)
COMMON_DOCS=(
  ARCHITECTURE.md
  INSTALL_STEPS.md
  COMMANDS.md
  NEW_MACHINE_SETUP.md
  PROJECT_STATUS.md
  TROUBLESHOOTING.md
  SECURITY.md
  CHECKLIST.md
  DEPLOYMENT.md
  WORKFLOW_SETUP.md
  VAULT_INDEXING.md
  OBSIDIAN_SETUP.md
  OpenClaw.md
  configure_credentials.md
  quickstart.md
  uninstall.md
  PRE_CHECK.md
  POST_INSTALL_CLIENT_SETUP.md
  ACCEPTANCE_TESTS.md
  CHANGELOG.md
  ROADMAP.md
)

for doc in "${COMMON_DOCS[@]}"; do
  [ -f "$BASE_PATH/admin/$doc" ] && cp "$BASE_PATH/admin/$doc" "$OUTPUT/admin/"
done

# -------------------------------------------
# Edition-specific: multi-client only
# -------------------------------------------
if [ "$EDITION" = "multi" ]; then
  echo "Adding multi-client components..."

  # Multi-only scripts
  MULTI_SCRIPTS=(switch_client.sh list_clients.sh test_client.sh license_check.sh validate_client.sh)
  for script in "${MULTI_SCRIPTS[@]}"; do
    [ -f "$BASE_PATH/admin/$script" ] && cp "$BASE_PATH/admin/$script" "$OUTPUT/admin/"
  done

  # Multi-only docs
  MULTI_DOCS=(switch_client.md CLIENT_ROUTING.md)
  for doc in "${MULTI_DOCS[@]}"; do
    [ -f "$BASE_PATH/admin/$doc" ] && cp "$BASE_PATH/admin/$doc" "$OUTPUT/admin/"
  done

  # License file
  cat > "$OUTPUT/.license" <<EOF
TIER=multi
EXPIRES=2027-06-02
LICENSE_KEY=BAB-MULTI-0001
EOF

  # Client directories with templates
  mkdir -p "$OUTPUT/clients/templates/PROCEDURES"
  mkdir -p "$OUTPUT/clients/templates/MEMORY"
  mkdir -p "$OUTPUT/clients/templates/OUTPUTS/drafts"
  mkdir -p "$OUTPUT/clients/templates/OUTPUTS/reports"
  mkdir -p "$OUTPUT/clients/templates/OUTPUTS/summaries"
  mkdir -p "$OUTPUT/clients/templates/DOCUMENTS"
  cp "$BASE_PATH"/clients/templates/*.md "$OUTPUT/clients/templates/" 2>/dev/null || true
  cp "$BASE_PATH"/clients/templates/PROCEDURES/*.md "$OUTPUT/clients/templates/PROCEDURES/" 2>/dev/null || true
  cp "$BASE_PATH"/clients/templates/MEMORY/*.md "$OUTPUT/clients/templates/MEMORY/" 2>/dev/null || true

  # .env template with ACTIVE_CLIENT
  cat > "$OUTPUT/.env.template" <<EOF
# Business Assistant Box Configuration (Multi-Client Edition)
AI_PROVIDER=ollama
LOCAL_LLM_ENABLED=true
OPENCLAW_API_KEY=
OPENCLAW_MODEL=
OPENCLAW_WORKSPACE_PATH=
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=qwen3:14b
EMBEDDING_PROVIDER=ollama
# Embedding model options (change EMBEDDING_DIMENSIONS to match):
#   nomic-embed-text       -> 768 dimensions (default, fast)
#   mxbai-embed-large      -> 1024 dimensions (better accuracy)
#   snowflake-arctic-embed -> 1024 dimensions (enterprise focused)
EMBEDDING_MODEL=nomic-embed-text
# Must match model above
EMBEDDING_DIMENSIONS=768
ACTIVE_CLIENT=my-business
BASE_PATH=
OBSIDIAN_ENABLED=true
OBSIDIAN_VAULT_PATH=
RAG_ENABLED=true
DASHBOARD_ENABLED=true
WORKFLOW_ENGINE=n8n
N8N_BASE_URL=http://localhost:5678
N8N_API_KEY=
OPENWEBUI_BASE_URL=http://localhost:3000
BUSINESS_BUTTONS_ENABLED=true
APPROVAL_REQUIRED_FOR_EMAIL_SEND=true
# Optional: only needed if switching workflows to Gemini (see Ollama-to-Gemini.md)
GOOGLE_API_KEY=
GOOGLE_PROJECT_ID=
GOOGLE_LOCATION=us-central1
GEMINI_MODEL=gemini-2.0-flash
EOF

fi

# -------------------------------------------
# Edition-specific: single-business only
# -------------------------------------------
if [ "$EDITION" = "single" ]; then
  echo "Building single-business edition..."

  # Single client directory (named at install time)
  mkdir -p "$OUTPUT/clients/my-business/PROCEDURES"
  mkdir -p "$OUTPUT/clients/my-business/MEMORY"
  mkdir -p "$OUTPUT/clients/my-business/OUTPUTS/drafts"
  mkdir -p "$OUTPUT/clients/my-business/OUTPUTS/reports"
  mkdir -p "$OUTPUT/clients/my-business/OUTPUTS/summaries"
  mkdir -p "$OUTPUT/clients/my-business/DOCUMENTS"

  # Copy template files as starting point
  if [ -d "$BASE_PATH/clients/templates" ]; then
    cp "$BASE_PATH"/clients/templates/*.md "$OUTPUT/clients/my-business/" 2>/dev/null || true
    cp "$BASE_PATH"/clients/templates/PROCEDURES/*.md "$OUTPUT/clients/my-business/PROCEDURES/" 2>/dev/null || true
    cp "$BASE_PATH"/clients/templates/MEMORY/*.md "$OUTPUT/clients/my-business/MEMORY/" 2>/dev/null || true
  fi

  # No license file needed
  # No switch/list/test_client scripts

  # .env template without multi-client references
  cat > "$OUTPUT/.env.template" <<EOF
# Business Assistant Box Configuration (Single-Business Edition)
AI_PROVIDER=ollama
LOCAL_LLM_ENABLED=true
OPENCLAW_API_KEY=
OPENCLAW_MODEL=
OPENCLAW_WORKSPACE_PATH=
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=qwen3:14b
EMBEDDING_PROVIDER=ollama
# Embedding model options (change EMBEDDING_DIMENSIONS to match):
#   nomic-embed-text       -> 768 dimensions (default, fast)
#   mxbai-embed-large      -> 1024 dimensions (better accuracy)
#   snowflake-arctic-embed -> 1024 dimensions (enterprise focused)
EMBEDDING_MODEL=nomic-embed-text
# Must match model above
EMBEDDING_DIMENSIONS=768
ACTIVE_CLIENT=my-business
BASE_PATH=
OBSIDIAN_ENABLED=true
OBSIDIAN_VAULT_PATH=
RAG_ENABLED=true
DASHBOARD_ENABLED=true
WORKFLOW_ENGINE=n8n
N8N_BASE_URL=http://localhost:5678
N8N_API_KEY=
OPENWEBUI_BASE_URL=http://localhost:3000
BUSINESS_BUTTONS_ENABLED=true
APPROVAL_REQUIRED_FOR_EMAIL_SEND=true
# Optional: only needed if switching workflows to Gemini (see Ollama-to-Gemini.md)
GOOGLE_API_KEY=
GOOGLE_PROJECT_ID=
GOOGLE_LOCATION=us-central1
GEMINI_MODEL=gemini-2.0-flash
EOF

  # Patch index_vault.py default client
  sed -i 's/ACTIVE_CLIENT = os.getenv("ACTIVE_CLIENT", "insurance-agency")/ACTIVE_CLIENT = os.getenv("ACTIVE_CLIENT", "my-business")/' "$OUTPUT/vector-db/index_vault.py"
  sed -i 's/ACTIVE_CLIENT = os.getenv("ACTIVE_CLIENT", "insurance-agency")/ACTIVE_CLIENT = os.getenv("ACTIVE_CLIENT", "my-business")/' "$OUTPUT/vector-db/query_vault.py"

fi

# -------------------------------------------
# Create archive
# -------------------------------------------
echo ""
echo "Creating archive..."
cd "$DIST_DIR"
tar -czf "${PACKAGE_NAME}.tar.gz" "$PACKAGE_NAME/"

# -------------------------------------------
# Summary
# -------------------------------------------
echo ""
echo "========================================="
echo "  Package complete: $EDITION edition"
echo "========================================="
echo ""
echo "  Folder: $OUTPUT/"
echo "  Archive: $DIST_DIR/${PACKAGE_NAME}.tar.gz"
echo ""

# File count
FILE_COUNT=$(find "$OUTPUT" -type f | wc -l)
DIR_COUNT=$(find "$OUTPUT" -type d | wc -l)
ARCHIVE_SIZE=$(du -h "$DIST_DIR/${PACKAGE_NAME}.tar.gz" | cut -f1)

echo "  Files: $FILE_COUNT"
echo "  Directories: $DIR_COUNT"
echo "  Archive size: $ARCHIVE_SIZE"
echo ""

if [ "$EDITION" = "single" ]; then
  echo "  Single-business edition:"
  echo "    - No client switching"
  echo "    - No license enforcement"
  echo "    - One business folder (my-business/)"
  echo "    - Customer renames at install time"
elif [ "$EDITION" = "multi" ]; then
  echo "  Multi-client edition:"
  echo "    - Client switching via switch_client.sh"
  echo "    - License tier enforcement"
  echo "    - Templates for new clients"
  echo "    - Supports unlimited client folders"
fi
echo ""
