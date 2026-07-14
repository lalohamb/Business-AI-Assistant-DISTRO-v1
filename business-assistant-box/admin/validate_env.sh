#!/bin/bash

# ==========================================
# This script is read-only. It does not modify any files.
# Safe to run anytime.
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="${BASE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
ENV_FILE="$BASE/.env"

FAILURES=0
WARNINGS=0

echo "========================================"
echo "   BUSINESS ASSISTANT BOX"
echo "   Environment Validation"
echo "========================================"
echo ""
echo "  File: $ENV_FILE"
echo ""

# Check .env exists
if [ ! -f "$ENV_FILE" ]; then
  echo "❌ .env not found at $ENV_FILE"
  echo "  Run install.sh to create it."
  exit 1
fi

# Check .env permissions
ENV_PERMS=$(stat -c "%a" "$ENV_FILE" 2>/dev/null)
if [ "$ENV_PERMS" = "600" ]; then
  echo "✅ .env permissions: 600 (owner-only)"
else
  echo "⚠️  .env permissions: $ENV_PERMS (should be 600)"
  echo "  Fix: chmod 600 $ENV_FILE"
  ((WARNINGS++))
fi
echo ""

source "$ENV_FILE"

echo "=== REQUIRED KEYS ==="
echo ""

check_required() {
  local key="$1"
  local value="${!key}"
  local description="$2"

  echo -n "  $key: "
  if [ -n "$value" ]; then
    echo "✅ $value"
  else
    echo "❌ MISSING — $description"
    ((FAILURES++))
  fi
}

check_optional() {
  local key="$1"
  local value="${!key}"
  local description="$2"

  echo -n "  $key: "
  if [ -n "$value" ]; then
    echo "✅ $value"
  else
    echo "⚠️  Not set — $description"
    ((WARNINGS++))
  fi
}

check_path() {
  local key="$1"
  local value="${!key}"
  local description="$2"

  echo -n "  $key: "
  if [ -z "$value" ]; then
    echo "❌ MISSING — $description"
    ((FAILURES++))
  elif [ -d "$value" ] || [ -L "$value" ]; then
    echo "✅ $value (exists)"
  else
    echo "⚠️  $value (path not found)"
    ((WARNINGS++))
  fi
}

check_value() {
  local key="$1"
  local value="${!key}"
  local valid_values="$2"
  local description="$3"

  echo -n "  $key: "
  if [ -z "$value" ]; then
    echo "❌ MISSING — $description"
    ((FAILURES++))
  elif echo "$valid_values" | grep -qw "$value"; then
    echo "✅ $value"
  else
    echo "⚠️  '$value' (expected: $valid_values)"
    ((WARNINGS++))
  fi
}

# Core
check_required "BASE_PATH" "Root project directory"
check_required "ACTIVE_CLIENT" "Which client workspace is active"
check_value "AI_PROVIDER" "openclaw_api ollama" "Primary AI provider"
check_value "EMBEDDING_PROVIDER" "ollama openclaw_api" "Embedding source"
check_required "EMBEDDING_MODEL" "Embedding model name"
check_required "EMBEDDING_DIMENSIONS" "Vector size (e.g. 768)"

echo ""
echo "=== AI PROVIDER ==="
echo ""

check_required "OLLAMA_BASE_URL" "Ollama API endpoint"
check_required "OLLAMA_MODEL" "Default Ollama model"

if [ "$AI_PROVIDER" = "openclaw_api" ]; then
  check_required "OPENCLAW_API_KEY" "Required when AI_PROVIDER=openclaw_api"
  check_optional "OPENCLAW_MODEL" "OpenClaw model override"
else
  check_optional "OPENCLAW_API_KEY" "Not required when AI_PROVIDER=ollama"
  check_optional "OPENCLAW_MODEL" "Not required when AI_PROVIDER=ollama"
fi

check_path "OPENCLAW_WORKSPACE_PATH" "OpenClaw workspace directory"

echo ""
echo "=== SERVICES ==="
echo ""

check_value "RAG_ENABLED" "true false" "Whether RAG/pgvector is active"
check_value "DASHBOARD_ENABLED" "true false" "Whether Open WebUI is required"
check_value "WORKFLOW_ENGINE" "n8n none" "Workflow automation engine"
check_value "LOCAL_LLM_ENABLED" "true false" "Whether local Ollama is used"

echo ""
echo "=== N8N ==="
echo ""

check_required "N8N_BASE_URL" "n8n API endpoint"
check_optional "N8N_API_KEY" "Required for API access (generate in n8n Settings → API)"

echo ""
echo "=== OBSIDIAN ==="
echo ""

check_value "OBSIDIAN_ENABLED" "true false" "Whether Obsidian integration is active"
check_path "OBSIDIAN_VAULT_PATH" "Obsidian vault directory (should be current-client)"

echo ""
echo "=== DASHBOARD ==="
echo ""

check_required "OPENWEBUI_BASE_URL" "Open WebUI endpoint"
check_value "BUSINESS_BUTTONS_ENABLED" "true false" "Dashboard business buttons"
check_value "APPROVAL_REQUIRED_FOR_EMAIL_SEND" "true false" "Email send requires approval"

echo ""
echo "=== PATHS ==="
echo ""

check_path "BASE_PATH" "Project root"
check_path "OBSIDIAN_VAULT_PATH" "Obsidian vault"
check_path "OPENCLAW_WORKSPACE_PATH" "OpenClaw workspace"

# Check ACTIVE_CLIENT directory exists
echo -n "  clients/$ACTIVE_CLIENT: "
if [ -d "$BASE/clients/$ACTIVE_CLIENT" ]; then
  echo "✅ Exists"
else
  echo "❌ Not found"
  ((FAILURES++))
fi

# Check current-client symlink
echo -n "  current-client symlink: "
if [ -L "$BASE/current-client" ]; then
  TARGET=$(readlink -f "$BASE/current-client")
  echo "✅ → $(basename "$TARGET")"
else
  echo "⚠️  Missing (run: ./admin/switch_client.sh $ACTIVE_CLIENT)"
  ((WARNINGS++))
fi

echo ""
echo "========================================"
echo "         RESULT"
echo "========================================"
echo ""
echo "  Failures:  $FAILURES"
echo "  Warnings:  $WARNINGS"
echo ""

if [ "$FAILURES" -gt 0 ]; then
  echo "  ❌ INVALID — Fix required keys before running services."
  exit 1
elif [ "$WARNINGS" -gt 0 ]; then
  echo "  ⚠️  ACCEPTABLE — Optional keys missing. System may partially function."
  exit 0
else
  echo "  ✅ VALID — All keys present and correct."
  exit 0
fi
