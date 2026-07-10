#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$BASE/.env"
FAIL=false
WARN=false

# Docker wrapper: uses sudo if user can't access docker socket
_docker() {
  if docker info &>/dev/null; then
    docker "$@"
  else
    sudo docker "$@"
  fi
}

echo "========================================"
echo "   BUSINESS ASSISTANT BOX - PRE CHECK"
echo "========================================"
echo ""

# --- ENVIRONMENT FILE VALIDATION ---
echo "=== ENVIRONMENT FILE VALIDATION ==="

if [ -f "$ENV_FILE" ]; then
  echo "[✓] .env exists"
  set -a
  source "$ENV_FILE"
  set +a
else
  echo "[✗] .env MISSING"
  FAIL=true
  echo "  Cannot proceed without .env. Using defaults for display only."
  AI_PROVIDER="openclaw_api"
  LOCAL_LLM_ENABLED="false"
  EMBEDDING_PROVIDER="ollama"
  EMBEDDING_DIMENSIONS="768"
  ACTIVE_CLIENT="demo-company"
  OBSIDIAN_ENABLED="true"
  OBSIDIAN_VAULT_PATH="$BASE/clients/demo-company"
  RAG_ENABLED="true"
  DASHBOARD_ENABLED="true"
  WORKFLOW_ENGINE="n8n"
fi

# Default EMBEDDING_DIMENSIONS if not set
EMBEDDING_DIMENSIONS="${EMBEDDING_DIMENSIONS:-768}"

# Check required variables
for var in AI_PROVIDER EMBEDDING_PROVIDER ACTIVE_CLIENT BASE_PATH RAG_ENABLED; do
  if [ -z "${!var}" ]; then
    echo "[✗] $var not set in .env"
    WARN=true
  fi
done

echo ""
echo "Configuration:"
echo "  AI Provider:       $AI_PROVIDER"
echo "  Local LLM:         $LOCAL_LLM_ENABLED"
echo "  Embedding:         $EMBEDDING_PROVIDER"
echo "  Embed Dimensions:  $EMBEDDING_DIMENSIONS"
echo "  Active Client:     $ACTIVE_CLIENT"
echo "  Obsidian:          $OBSIDIAN_ENABLED"
echo "  RAG:               $RAG_ENABLED"
echo "  Dashboard:         $DASHBOARD_ENABLED"
echo "  Workflow:           $WORKFLOW_ENGINE"
echo ""

# --- ROOT DIRECTORY VALIDATION ---
echo "=== ROOT DIRECTORY VALIDATION ==="
for dir in admin system clients vault postgres vector-db dashboard n8n openclaw docker logs backups; do
  if [ -d "$BASE/$dir" ]; then
    echo "[✓] $dir"
  else
    echo "[✗] $dir MISSING"
    FAIL=true
  fi
done
echo ""

# --- SYSTEM FILE VALIDATION ---
echo "=== SYSTEM FILE VALIDATION ==="
for f in AGENTS.md POLICIES.md IDENTITY.md HEARTBEAT.md TOOLS.md PROMPTS.md SYSTEM_MEMORY.md; do
  if [ -f "$BASE/system/$f" ]; then
    echo "[✓] $f"
  else
    echo "[✗] $f MISSING"
    FAIL=true
  fi
done
echo ""

# --- ADMIN FILE VALIDATION ---
# NOTE 2026-07-10: This section is informational only. These are documentation files,
# not runtime dependencies. The system works without them. Consider removing in future cleanup.
echo "=== ADMIN FILE VALIDATION ==="
for f in BUILD_PLAN.md INSTALL_STEPS.md CHECKLIST.md SECURITY.md TROUBLESHOOTING.md COMMANDS.md ACCEPTANCE_TESTS.md DEPLOYMENT.md PROJECT_STATUS.md NEXT_ACTIONS.md CHANGELOG.md ROADMAP.md ARCHITECTURE.md POST_INSTALL_CLIENT_SETUP.md PRE_CHECK.md; do
  if [ -f "$BASE/admin/$f" ]; then
    echo "[✓] $f"
  else
    echo "[✗] $f MISSING"
    WARN=true
  fi
done
echo ""

# --- VAULT VALIDATION ---
echo "=== VAULT VALIDATION ==="
for dir in company-documents financials contracts handbooks websites uploads; do
  if [ -d "$BASE/vault/$dir" ]; then
    echo "[✓] $dir"
  else
    echo "[✗] $dir MISSING"
    WARN=true
  fi
done
echo ""

# --- CLIENT VALIDATION (Active Client) ---
echo "=== CLIENT VALIDATION (Active: $ACTIVE_CLIENT) ==="
CLIENT_PATH="$BASE/clients/$ACTIVE_CLIENT"
SYMLINK_PATH="$BASE/current-client"

# Validate current-client symlink
echo -n "current-client symlink: "
if [ -L "$SYMLINK_PATH" ]; then
  SYMLINK_TARGET=$(readlink -f "$SYMLINK_PATH")
  EXPECTED_TARGET=$(readlink -f "$CLIENT_PATH")
  if [ "$SYMLINK_TARGET" = "$EXPECTED_TARGET" ]; then
    echo "✅ → $ACTIVE_CLIENT"
  else
    echo "⚠️  Points to $(basename "$SYMLINK_TARGET") (expected $ACTIVE_CLIENT)"
    WARN=true
  fi
else
  echo "❌ Missing (run: ./admin/switch_client.sh $ACTIVE_CLIENT)"
  WARN=true
fi

if [ ! -d "$CLIENT_PATH" ]; then
  echo "[✗] Client directory missing: $CLIENT_PATH"
  FAIL=true
else
  for f in CLIENT_PROFILE.md OWNER_PREFERENCES.md BUSINESS_KNOWLEDGE.md FAQ.md; do
    if [ -f "$CLIENT_PATH/$f" ]; then
      echo "[✓] $f"
    else
      echo "[✗] $f MISSING"
      FAIL=true
    fi
  done

  echo "  PROCEDURES:"
  for f in EMAIL.md CALENDAR.md DAILY_BRIEFING.md DOCUMENTS.md; do
    if [ -f "$CLIENT_PATH/PROCEDURES/$f" ]; then
      echo "    [✓] $f"
    else
      echo "    [✗] $f MISSING"
      FAIL=true
    fi
  done

  echo "  MEMORY:"
  for f in CUSTOMER_RULES.md VENDOR_RULES.md LEARNED_PATTERNS.md OPEN_TASKS.md TODAY.md; do
    if [ -f "$CLIENT_PATH/MEMORY/$f" ]; then
      echo "    [✓] $f"
    else
      echo "    [✗] $f MISSING"
      WARN=true
    fi
  done

  echo "  OUTPUTS:"
  for d in drafts reports summaries; do
    if [ -d "$CLIENT_PATH/OUTPUTS/$d" ]; then
      echo "    [✓] $d"
    else
      echo "    [✗] $d MISSING"
      WARN=true
    fi
  done
fi
echo ""

# --- SERVICE VALIDATION (Configuration-Aware) ---
echo "=== SERVICE VALIDATION ==="

# PostgreSQL — required if RAG_ENABLED
if [ "$RAG_ENABLED" = "true" ]; then
  echo -n "PostgreSQL (required by RAG): "
  _docker ps --filter "name=^postgres$" --filter "status=running" --format "{{.Names}}" 2>/dev/null | grep -q "^postgres$" && echo "✅ Running" || { echo "❌ Not running"; FAIL=true; }
else
  echo "PostgreSQL: SKIPPED (RAG disabled)"
fi

# Ollama — required if AI_PROVIDER=ollama OR LOCAL_LLM_ENABLED=true OR EMBEDDING_PROVIDER=ollama
if [ "$AI_PROVIDER" = "ollama" ] || [ "$LOCAL_LLM_ENABLED" = "true" ] || [ "$EMBEDDING_PROVIDER" = "ollama" ]; then
  echo -n "Ollama (required by config): "
  systemctl is-active ollama 2>/dev/null | grep -q "^active" && echo "✅ Running" || { echo "❌ Not running"; FAIL=true; }
else
  echo "Ollama: SKIPPED (not required)"
fi

# OpenClaw API — required if AI_PROVIDER=openclaw_api
if [ "$AI_PROVIDER" = "openclaw_api" ]; then
  echo -n "OpenClaw API Key: "
  if [ -n "$OPENCLAW_API_KEY" ] && [ "$OPENCLAW_API_KEY" != "" ]; then
    echo "✅ Set"
  else
    echo "❌ Missing"
    FAIL=true
  fi
fi

# n8n — required if WORKFLOW_ENGINE=n8n
if [ "$WORKFLOW_ENGINE" = "n8n" ]; then
  echo -n "n8n (required by config): "
  _docker ps --filter "name=^n8n$" --filter "status=running" --format "{{.Names}}" 2>/dev/null | grep -q "^n8n$" && echo "✅ Running" || { echo "❌ Not running"; FAIL=true; }
else
  echo "n8n: SKIPPED (workflow engine not n8n)"
fi

# Dashboard — required if DASHBOARD_ENABLED=true
if [ "$DASHBOARD_ENABLED" = "true" ]; then
  echo -n "Dashboard/Open WebUI (required by config): "
  _docker ps --filter "name=^openwebui$" --filter "status=running" --format "{{.Names}}" 2>/dev/null | grep -q "^openwebui$" && echo "✅ Running" || { echo "❌ Not running"; FAIL=true; }
else
  echo "Dashboard: SKIPPED (disabled)"
fi

echo ""

# --- PGVECTOR VALIDATION ---
if [ "$RAG_ENABLED" = "true" ]; then
  echo "=== PGVECTOR VALIDATION ==="

  # Container image check
  echo -n "Container image: "
  PG_IMAGE=$(_docker ps --filter "name=^postgres$" --format "{{.Image}}" 2>/dev/null)
  if [ -n "$PG_IMAGE" ]; then
    echo "$PG_IMAGE"
    if echo "$PG_IMAGE" | grep -q "pgvector"; then
      echo "  ✅ pgvector-enabled image"
    elif echo "$PG_IMAGE" | grep -q "postgres:16"; then
      echo "  ⚠️  postgres:16 may NOT include pgvector by default"
      WARN=true
    fi
  else
    echo "  ❌ No postgres container found"
  fi

  # Extension check
  echo -n "pgvector extension: "
  PGV_CHECK=$(_docker exec -i postgres psql -U admin businessassistant -t -c "SELECT extname FROM pg_extension WHERE extname='vector';" 2>/dev/null | tr -d ' \n')
  if [ "$PGV_CHECK" = "vector" ]; then
    echo "✅ Active"
  else
    echo "❌ Not found"
    FAIL=true
  fi

  echo ""
fi

# --- RAG VALIDATION ---
if [ "$RAG_ENABLED" = "true" ]; then
  echo "=== RAG VALIDATION ==="

  # Schema file
  echo -n "vector-db/schema.sql: "
  if [ -f "$BASE/vector-db/schema.sql" ]; then
    echo "✅ Exists"
  else
    echo "❌ Missing"
    WARN=true
  fi

  # Tables
  echo -n "RAG tables: "
  TABLE_COUNT=$(_docker exec -i postgres psql -U admin businessassistant -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name IN ('rag_documents','rag_chunks')" 2>/dev/null | tr -d ' \n')
  if [ "$TABLE_COUNT" = "2" ]; then
    echo "✅ Both tables present"
  else
    echo "❌ Missing (found $TABLE_COUNT/2)"
    FAIL=true
  fi

  # Embeddings
  echo -n "Embeddings: "
  CHUNK_COUNT=$(_docker exec -i postgres psql -U admin businessassistant -t -c "SELECT COUNT(*) FROM rag_chunks" 2>/dev/null | tr -d ' \n')
  if [ -n "$CHUNK_COUNT" ] && [ "$CHUNK_COUNT" -gt 0 ] 2>/dev/null; then
    echo "✅ $CHUNK_COUNT chunks indexed"
  else
    echo "⚠️  No embeddings found (run index_vault.py)"
    WARN=true
  fi

  echo ""
fi

# --- RAG SCRIPTS VALIDATION ---
if [ "$RAG_ENABLED" = "true" ]; then
  echo "=== RAG SCRIPTS VALIDATION ==="

  echo -n "vector-db/index_vault.py: "
  if [ -f "$BASE/vector-db/index_vault.py" ]; then
    echo "✅ Exists"
  else
    echo "❌ Missing"
    WARN=true
  fi

  echo -n "vector-db/query_vault.py: "
  if [ -f "$BASE/vector-db/query_vault.py" ]; then
    echo "✅ Exists"
  else
    echo "❌ Missing"
    WARN=true
  fi

  echo -n "vector-db/venv/: "
  if [ -d "$BASE/vector-db/venv" ]; then
    echo "✅ Exists"
  else
    echo "❌ Missing"
    WARN=true
  fi

  echo ""
fi

# --- OBSIDIAN VALIDATION ---
if [ "$OBSIDIAN_ENABLED" = "true" ]; then
  echo "=== OBSIDIAN VALIDATION ==="

  echo -n "Obsidian binary: "
  if command -v obsidian &>/dev/null; then
    echo "✅ Installed"
  else
    echo "⚠️  Not installed (install from https://obsidian.md/download)"
    WARN=true
  fi

  echo -n "admin/OBSIDIAN_SETUP.md: "
  if [ -f "$BASE/admin/OBSIDIAN_SETUP.md" ]; then
    echo "✅ Exists"
  else
    echo "⚠️  Missing"
    WARN=true
  fi

  echo -n "Vault path ($OBSIDIAN_VAULT_PATH): "
  if [ -L "$OBSIDIAN_VAULT_PATH" ] || [ -d "$OBSIDIAN_VAULT_PATH" ]; then
    echo "✅ Exists"
    # Verify vault points to client dir, not admin/logs/docker/backups
    RESOLVED_PATH=$(readlink -f "$OBSIDIAN_VAULT_PATH" 2>/dev/null || echo "$OBSIDIAN_VAULT_PATH")
    if echo "$RESOLVED_PATH" | grep -qE "/(admin|logs|docker|backups)/"; then
      echo "  ⚠️  Vault path should point to client directory, not system directories"
      WARN=true
    fi
  else
    echo "❌ Missing"
    WARN=true
  fi

  echo ""
fi

# --- STARTUP DECISION ---
echo "========================================"
echo "         STARTUP DECISION"
echo "========================================"

if [ "$FAIL" = true ]; then
  echo "❌ FAIL — Startup denied."
  echo "Correct missing critical components."
  echo ""
  echo "========================================"
  echo "         VALIDATION REPORT"
  echo "========================================"
  echo ""
  echo "Date:             $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Active Client:    $ACTIVE_CLIENT"
  echo "Configuration:    AI=$AI_PROVIDER / EMBED=$EMBEDDING_PROVIDER / RAG=$RAG_ENABLED"
  echo "Status:           FAIL"
  echo ""
  echo "Next Actions:"
  echo "  - Review missing items above"
  echo "  - Run install.sh to fix scaffold issues"
  echo "  - Start required services"
  exit 1
elif [ "$WARN" = true ]; then
  echo "⚠️  WARNING — Startup permitted."
  echo "Missing non-critical components. Review recommended."
  echo ""
  echo "========================================"
  echo "         VALIDATION REPORT"
  echo "========================================"
  echo ""
  echo "Date:             $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Active Client:    $ACTIVE_CLIENT"
  echo "Configuration:    AI=$AI_PROVIDER / EMBED=$EMBEDDING_PROVIDER / RAG=$RAG_ENABLED"
  echo "Status:           WARNING"
  echo ""
  echo "Next Actions:"
  echo "  - Review warnings above"
  echo "  - Run index_vault.py if embeddings missing"
  echo "  - Create missing memory/output files as needed"
  exit 0
else
  echo "✅ PASS — Startup approved."
  echo "All required files and services present."
  echo ""
  echo "========================================"
  echo "         VALIDATION REPORT"
  echo "========================================"
  echo ""
  echo "Date:             $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Active Client:    $ACTIVE_CLIENT"
  echo "Configuration:    AI=$AI_PROVIDER / EMBED=$EMBEDDING_PROVIDER / RAG=$RAG_ENABLED"
  echo "Status:           PASS"
  exit 0
fi
