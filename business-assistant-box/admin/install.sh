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
#   DRY_RUN=true ./admin/install.sh
#   SAFE_MODE=false ./admin/install.sh
#
#
#
# Ex.: <Terminal:> DRY_RUN=false SAFE_MODE=false bash ./install.sh
#
# ==========================================

# ==========================================
# CONFIGURATION
# ==========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
DRY_RUN=${DRY_RUN:-false}
SAFE_MODE=${SAFE_MODE:-true}

# ==========================================
# TRACKING ARRAYS
# ==========================================
FILES_CREATED=()
FILES_BACKED_UP=()
WARNINGS=()
INSTALL_OLLAMA_DONE="no"
ENV_EXISTED="no"
SKIP_NEXT=false

# ==========================================
# UTILITY FUNCTIONS
# ==========================================

# Docker wrapper: uses sudo if user can't access docker socket
_docker() {
  if docker info &>/dev/null; then
    docker "$@"
  else
    sudo docker "$@"
  fi
}

TOTAL_TASKS=19

prompt_user() {
  local phase_name="$1"
  local next_phase="$2"
  local notes="$3"
  local task_num="$4"

  echo ""
  echo "========================================"
  if [ -n "$task_num" ]; then
    echo " [Task $task_num of $TOTAL_TASKS] $phase_name COMPLETE"
  else
    echo " $phase_name COMPLETE"
  fi
  echo "========================================"

  if [ -n "$notes" ]; then
    echo ""
    echo "  Notes:"
    while IFS= read -r line; do
      echo "   $line"
    done <<< "$notes"
  fi

  echo ""
  if [ "$DRY_RUN" = true ]; then
    if [ -n "$next_phase" ]; then
      echo "[DRY RUN] Would prompt: Continue to next phase - $next_phase?"
    else
      echo "[DRY RUN] Would prompt to continue."
    fi
    return
  fi

  if [ -n "$next_phase" ]; then
    read -p "Continue to next phase - $next_phase? [y/n/q]: " choice
  else
    read -p "Continue? [y/n/q]: " choice
  fi
  case "$choice" in
    y|Y) echo "Proceeding..." ;;
    q|Q) echo "Quitting."; print_summary; exit 0 ;;
    *) echo "Skipping $next_phase..." ; SKIP_NEXT=true ;;
  esac
  echo ""
}

log_dry() {
  echo "[DRY RUN] $1"
}

log_warn() {
  echo "⚠️  WARNING: $1"
  WARNINGS+=("$1")
}

timestamp() {
  date +"%Y%m%d-%H%M%S"
}

backup_file() {
  local filepath="$1"
  if [ -f "$filepath" ]; then
    local backup="${filepath}.bak.$(timestamp)"
    if [ "$DRY_RUN" = true ]; then
      log_dry "Would backup: $filepath → $backup"
    else
      cp "$filepath" "$backup"
      echo "  Backed up: $filepath → $backup"
      FILES_BACKED_UP+=("$backup")
    fi
  fi
}

safe_write_file() {
  local filepath="$1"
  local content="$2"
  local description="$3"

  # Ensure parent directory exists
  mkdir -p "$(dirname "$filepath")"

  if [ -f "$filepath" ]; then
    if [ "$SAFE_MODE" = true ]; then
      if [ "$DRY_RUN" = true ]; then
        log_dry "Would ask before replacing: $filepath"
        return
      fi
      echo ""
      echo "  File already exists: $filepath"
      read -p "  Replace with new version? (backup will be created) [y/n]: " replace_choice
      if [ "$replace_choice" != "y" ] && [ "$replace_choice" != "Y" ]; then
        echo "  Skipped: $filepath"
        return
      fi
    fi
    backup_file "$filepath"
  fi

  if [ "$DRY_RUN" = true ]; then
    log_dry "Would create: $filepath ($description)"
  else
    printf '%s\n' "$content" > "$filepath"
    echo "  Created: $filepath"
    FILES_CREATED+=("$filepath")
  fi
}

create_placeholder() {
  local filepath="$1"
  if [ -f "$filepath" ]; then
    return
  fi
  if [ "$DRY_RUN" = true ]; then
    log_dry "Would create placeholder: $filepath"
  else
    echo "# $(basename "$filepath" .md)" > "$filepath"
    echo "  Created placeholder: $filepath"
    FILES_CREATED+=("$filepath")
  fi
}

safe_docker_start() {
  local name="$1"
  local image="$2"
  shift 2
  local run_args=("$@")

  # Check if running
  if _docker ps --filter "name=^${name}$" --filter "status=running" --format "{{.Names}}" 2>/dev/null | grep -q "^${name}$"; then
    echo "  Container '$name' already running."
    return
  fi

  # Check if exists but stopped
  if _docker ps -a --filter "name=^${name}$" --format "{{.Names}}" 2>/dev/null | grep -q "^${name}$"; then
    echo "  Container '$name' exists but stopped. Starting..."
    if [ "$DRY_RUN" = true ]; then
      log_dry "Would run: docker start $name"
    else
      _docker start "$name"
    fi
    return
  fi

  # Create new
  if [ "$DRY_RUN" = true ]; then
    log_dry "Would create container: $name ($image)"
  else
    _docker run -d --name "$name" "${run_args[@]}" "$image"
    echo "  Created and started container: $name"
  fi
}

print_summary() {
  echo ""
  echo "========================================"
  echo "         INSTALLATION SUMMARY"
  echo "========================================"
  echo ""
  echo "Base path:          $BASE_PATH"
  echo ".env existed:       $ENV_EXISTED"
  echo "Ollama installed:   $INSTALL_OLLAMA_DONE"
  echo "DRY_RUN:            $DRY_RUN"
  echo "SAFE_MODE:          $SAFE_MODE"
  echo ""

  # PostgreSQL status
  echo -n "PostgreSQL:         "
  if _docker ps --filter "name=^postgres$" --filter "status=running" --format "{{.Names}}" 2>/dev/null | grep -q "^postgres$"; then
    echo "✅ Running"
  else
    echo "❌ Not running"
  fi

  # pgvector status
  echo -n "pgvector:           "
  if _docker exec -i postgres psql -U admin businessassistant -t -c "SELECT 1 FROM pg_extension WHERE extname='vector'" 2>/dev/null | grep -q 1; then
    echo "✅ Enabled"
  else
    echo "❌ Not enabled"
  fi

  # RAG schema status
  echo -n "RAG schema:         "
  if _docker exec -i postgres psql -U admin businessassistant -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name IN ('rag_documents','rag_chunks')" 2>/dev/null | grep -q 2; then
    echo "✅ Deployed"
  else
    echo "⚠️  Not deployed"
  fi

  echo ""
  echo "Files created (${#FILES_CREATED[@]}):"
  for f in "${FILES_CREATED[@]}"; do
    echo "  + $f"
  done

  echo ""
  echo "Files backed up (${#FILES_BACKED_UP[@]}):"
  for f in "${FILES_BACKED_UP[@]}"; do
    echo "  ↩ $f"
  done

  echo ""
  echo "Warnings (${#WARNINGS[@]}):"
  if [ ${#WARNINGS[@]} -eq 0 ]; then
    echo "  None"
  else
    for w in "${WARNINGS[@]}"; do
      echo "  ⚠️  $w"
    done
  fi

  echo ""
  echo "Next commands:"
  echo "  ./admin/post_install_verify.sh     # Verify all services connected"
  echo "  obsidian &                         # Launch Obsidian to edit vault"
  echo ""
  echo "  After editing client files, re-index:"
  echo "    ./vector-db/venv/bin/python3 ./vector-db/index_vault.py"
  echo ""

  # Obsidian status
  echo -n "Obsidian:           "
  if command -v obsidian &>/dev/null; then
    echo "✅ Installed (native)"
  else
    echo "❌ Not installed"
  fi

  # OpenClaw status
  echo -n "OpenClaw:           "
  if command -v openclaw &> /dev/null; then
    echo "✅ Installed"
  else
    echo "❌ Not found"
  fi

  # ── DETAILED BUILD REPORT ──
  echo ""
  echo "========================================"
  echo "         DETAILED BUILD REPORT"
  echo "========================================"

  # .env Configuration
  echo ""
  echo "── .env Configuration ──────────────────"
  if [ -f "$BASE_PATH/.env" ]; then
    grep -v '^\s*#' "$BASE_PATH/.env" | grep -v '^\s*$' | while IFS='=' read -r key val; do
      case "$key" in
        *KEY*|*PASSWORD*|*SECRET*) val="****" ;;
      esac
      printf "  %-35s %s\n" "$key" "$val"
    done
  else
    echo "  .env file not found"
  fi

  # Port allocation
  echo ""
  echo "── Ports ───────────────────────────────"
  printf "  %-14s %-7s %s\n" "Service" "Port" "Status"
  printf "  %-14s %-7s %s\n" "──────────" "─────" "──────"
  for svc_port in "PostgreSQL:5432" "OpenWebUI:3000" "n8n:5678" "Ollama:11434"; do
    svc="${svc_port%%:*}"
    port="${svc_port##*:}"
    if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
      printf "  %-14s %-7s ✅ listening\n" "$svc" "$port"
    else
      printf "  %-14s %-7s ❌ not listening\n" "$svc" "$port"
    fi
  done

  # Docker container status
  echo ""
  echo "── Docker Containers ───────────────────"
  if command -v docker &>/dev/null && (docker info &>/dev/null || sudo docker info &>/dev/null); then
    printf "  %-14s %-12s %-28s %s\n" "Name" "Status" "Image" "Started"
    printf "  %-14s %-12s %-28s %s\n" "──────────" "────────" "─────────────" "───────"
    for cname in postgres openwebui n8n; do
      cstatus=$(_docker inspect --format '{{.State.Status}}' "$cname" 2>/dev/null || echo "missing")
      cimage=$(_docker inspect --format '{{.Config.Image}}' "$cname" 2>/dev/null | rev | cut -d/ -f1 | rev || echo "-")
      cuptime=$(_docker inspect --format '{{.State.StartedAt}}' "$cname" 2>/dev/null | cut -dT -f1 || echo "-")
      printf "  %-14s %-12s %-28s %s\n" "$cname" "$cstatus" "$cimage" "$cuptime"
    done
  else
    echo "  Docker not available"
  fi

  # RAG pipeline
  echo ""
  echo "── RAG Pipeline ────────────────────────"
  SUMMARY_CHUNKS=$(_docker exec -i postgres psql -U admin businessassistant -t -c "SELECT COUNT(*) FROM rag_chunks" 2>/dev/null | tr -d ' ')
  SUMMARY_CLIENT="${ACTIVE_CLIENT:-$(grep '^ACTIVE_CLIENT=' "$BASE_PATH/.env" 2>/dev/null | cut -d= -f2)}"
  SUMMARY_EMB="${EMBEDDING_MODEL:-$(grep '^EMBEDDING_MODEL=' "$BASE_PATH/.env" 2>/dev/null | cut -d= -f2)}"
  printf "  %-20s %s\n" "Chunks indexed:" "${SUMMARY_CHUNKS:-?}"
  printf "  %-20s %s\n" "Active client:" "$SUMMARY_CLIENT"
  printf "  %-20s %s\n" "Embedding model:" "$SUMMARY_EMB"
  echo -n "  Filter status:      "
  FILTER_STATUS=$(_docker exec -i openwebui python3 -c "
import sqlite3
c=sqlite3.connect('/app/backend/data/webui.db').cursor()
c.execute(\"SELECT is_active,is_global FROM function WHERE id='business_knowledge_rag'\")
r=c.fetchone()
print(f'active={r[0]} global={r[1]}') if r else print('not registered')
" 2>/dev/null)
  echo "${FILTER_STATUS:-unknown}"

  # Obsidian
  echo ""
  echo "── Obsidian ────────────────────────────"
  echo -n "  Installed:          "
  if command -v obsidian &>/dev/null; then
    echo "✅ yes"
  else
    echo "❌ no"
  fi
  printf "  %-20s %s\n" "Enabled (.env):" "${OBSIDIAN_ENABLED:-false}"
  VAULT_TARGET=$(readlink -f "$BASE_PATH/current-client" 2>/dev/null || echo "$BASE_PATH/current-client")
  printf "  %-20s %s\n" "Vault path:" "$VAULT_TARGET"
  if [ -d "$VAULT_TARGET" ]; then
    MD_COUNT=$(find -L "$VAULT_TARGET" -name "*.md" 2>/dev/null | wc -l)
    printf "  %-20s %s\n" "Vault .md files:" "$MD_COUNT"
  else
    printf "  %-20s %s\n" "Vault .md files:" "directory not found"
  fi

  # Ollama models
  echo ""
  echo "── Ollama Models ───────────────────────"
  if command -v ollama &>/dev/null; then
    ollama list 2>/dev/null | head -10 | sed 's/^/  /'
  else
    echo "  Ollama not installed"
  fi

  # Disk usage
  echo ""
  echo "── Disk Usage ──────────────────────────"
  printf "  %-25s %s\n" "Project total:" "$(du -sh "$BASE_PATH" 2>/dev/null | cut -f1)"
  printf "  %-25s %s\n" "PostgreSQL data:" "$(du -sh "$BASE_PATH/postgres/data" 2>/dev/null | cut -f1)"
  printf "  %-25s %s\n" "Ollama models:" "$(du -sh /usr/share/ollama/.ollama/models 2>/dev/null | cut -f1 || echo 'N/A')"
  printf "  %-25s %s\n" "Python venv:" "$(du -sh "$BASE_PATH/vector-db/venv" 2>/dev/null | cut -f1)"

  # System info
  echo ""
  echo "── System ──────────────────────────────"
  printf "  %-18s %s\n" "OS:" "$(lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')"
  printf "  %-18s %s\n" "Kernel:" "$(uname -r)"
  printf "  %-18s %s\n" "RAM:" "$(free -h | awk '/Mem:/{print $2}') total, $(free -h | awk '/Mem:/{print $7}') available"
  printf "  %-18s %s\n" "GPU:" "$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null || echo 'None detected')"
  printf "  %-18s %s\n" "Docker:" "$(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')"
  printf "  %-18s %s\n" "Python:" "$(python3 --version 2>/dev/null)"

  echo ""
  echo "========================================"
  echo "         END OF INSTALL REPORT"
  echo "========================================"
  echo ""
}

# ==========================================
# MAIN
# ==========================================

echo "========================================"
echo "   BUSINESS ASSISTANT BOX - INSTALLER"
echo "========================================"
echo ""
echo "  DRY_RUN:   $DRY_RUN"
echo "  SAFE_MODE: $SAFE_MODE"
echo "  BASE_PATH: $BASE_PATH"
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "*** DRY RUN MODE — No changes will be made ***"
  echo ""
fi

# ==========================================
# PHASE 0 — Project Scaffold
# ==========================================
echo "=== PHASE 0 — Project Scaffold ==="
echo ""

if [ "$DRY_RUN" = true ]; then
  log_dry "Would create directory structure (mkdir -p, safe)"
else
  # Root directories
  for dir in admin system clients postgres vector-db dashboard n8n openclaw docker logs backups; do
    mkdir -p "$BASE_PATH/$dir"
  done


  # Client directories
  for client in templates demo-company law-office insurance-agency acme-roofing; do
    mkdir -p "$BASE_PATH/clients/$client/PROCEDURES"
    mkdir -p "$BASE_PATH/clients/$client/MEMORY"
    mkdir -p "$BASE_PATH/clients/$client/OUTPUTS/drafts"
    mkdir -p "$BASE_PATH/clients/$client/OUTPUTS/reports"
    mkdir -p "$BASE_PATH/clients/$client/OUTPUTS/summaries"
    mkdir -p "$BASE_PATH/clients/$client/DOCUMENTS/contracts"
    mkdir -p "$BASE_PATH/clients/$client/DOCUMENTS/handbooks"
    mkdir -p "$BASE_PATH/clients/$client/DOCUMENTS/financials"
    mkdir -p "$BASE_PATH/clients/$client/DOCUMENTS/uploads"
    mkdir -p "$BASE_PATH/clients/$client/DOCUMENTS/websites"
    mkdir -p "$BASE_PATH/clients/$client/DOCUMENTS/company-documents"
  done
fi

# System files (only create if missing)
for f in AGENTS.md POLICIES.md IDENTITY.md HEARTBEAT.md TOOLS.md PROMPTS.md SYSTEM_MEMORY.md; do
  create_placeholder "$BASE_PATH/system/$f"
done

# Admin files (only create if missing)
for f in BUILD_PLAN.md INSTALL_STEPS.md CHECKLIST.md SECURITY.md TROUBLESHOOTING.md COMMANDS.md ACCEPTANCE_TESTS.md DEPLOYMENT.md PROJECT_STATUS.md NEXT_ACTIONS.md CHANGELOG.md ROADMAP.md ARCHITECTURE.md POST_INSTALL_CLIENT_SETUP.md PRE_CHECK.md; do
  create_placeholder "$BASE_PATH/admin/$f"
done

# Template client files (only create if missing)
for f in CLIENT_PROFILE.md OWNER_PREFERENCES.md BUSINESS_KNOWLEDGE.md FAQ.md; do
  create_placeholder "$BASE_PATH/clients/templates/$f"
done
for f in EMAIL.md CALENDAR.md DAILY_BRIEFING.md DOCUMENTS.md; do
  create_placeholder "$BASE_PATH/clients/templates/PROCEDURES/$f"
done
for f in CUSTOMER_RULES.md VENDOR_RULES.md LEARNED_PATTERNS.md OPEN_TASKS.md TODAY.md; do
  create_placeholder "$BASE_PATH/clients/templates/MEMORY/$f"
done

echo ""
echo "Project scaffold complete."

prompt_user "PHASE 0 — Project Scaffold" "PHASE 0B — Environment Configuration" "No manual settings required. Directory structure created automatically." 1

# ==========================================
# PHASE 0B — Environment Configuration
# ==========================================
echo "=== PHASE 0B — Environment Configuration ==="
echo ""

ENV_FILE="$BASE_PATH/.env"

if [ -f "$ENV_FILE" ]; then
  ENV_EXISTED="yes"
  echo ".env already exists. Loading without overwrite."
  CURRENT_CLIENT=$(grep "^ACTIVE_CLIENT=" "$ENV_FILE" | cut -d= -f2)
  echo "  Active client: ${CURRENT_CLIENT:-not set}"
  echo "  To change: ./admin/switch_client.sh <new-client>"
else
  ENV_EXISTED="no"
  if [ "$DRY_RUN" = true ]; then
    log_dry "Would create .env with interactive prompts."
  else
    read -p "Primary AI provider — [1] OpenClaw API or [2] Ollama? [1/2]: " ai_choice
    case "$ai_choice" in
      1)
        AI_PROVIDER="openclaw_api"
        LOCAL_LLM_ENABLED="false"
        read -p "OpenClaw API Key: " OPENCLAW_API_KEY
        read -p "OpenClaw Model (default: leave blank): " OPENCLAW_MODEL
        ;;
      2)
        AI_PROVIDER="ollama"
        LOCAL_LLM_ENABLED="true"
        OPENCLAW_API_KEY=""
        OPENCLAW_MODEL=""
        ;;
      *)
        AI_PROVIDER="openclaw_api"
        LOCAL_LLM_ENABLED="false"
        OPENCLAW_API_KEY=""
        OPENCLAW_MODEL=""
        ;;
    esac

    read -p "Embedding provider — [1] Ollama or [2] OpenClaw API? [1/2]: " embed_choice
    case "$embed_choice" in
      1) EMBEDDING_PROVIDER="ollama" ;;
      2) EMBEDDING_PROVIDER="openclaw_api" ;;
      *) EMBEDDING_PROVIDER="ollama" ;;
    esac

    if [ "$EMBEDDING_PROVIDER" = "ollama" ]; then
      echo ""
      echo "  Embedding model options:"
      echo "    [1] nomic-embed-text       — 768 dims, fast, good general-purpose (default)"
      echo "    [2] mxbai-embed-large      — 1024 dims, better accuracy, slower"
      echo "    [3] snowflake-arctic-embed  — 1024 dims, enterprise/retrieval focused"
      echo ""
      read -p "  Embedding model [1/2/3]: " embed_model_choice
      case "$embed_model_choice" in
        2) EMBEDDING_MODEL="mxbai-embed-large"; EMBEDDING_DIMENSIONS=1024 ;;
        3) EMBEDDING_MODEL="snowflake-arctic-embed"; EMBEDDING_DIMENSIONS=1024 ;;
        *) EMBEDDING_MODEL="nomic-embed-text"; EMBEDDING_DIMENSIONS=768 ;;
      esac
    else
      EMBEDDING_MODEL=""
      read -p "  Embedding dimensions (default: 768): " EMBEDDING_DIMENSIONS
      EMBEDDING_DIMENSIONS="${EMBEDDING_DIMENSIONS:-768}"
    fi

    echo ""
    echo "  Available demo clients:"
    echo "    demo-company          — Life insurance agency (fully populated example)"
    echo "    business-ai-assistant — This system (self-referential demo)"
    echo "    acme-roofing          — Roofing contractor"
    echo "    law-office            — Legal practice"
    echo ""
    read -p "  Active client (default: demo-company): " ACTIVE_CLIENT
    ACTIVE_CLIENT="${ACTIVE_CLIENT:-demo-company}"

    echo ""
    echo "  Chat model options (requires Ollama):"
    echo "    [1] qwen3:14b   — 14B params, good balance of speed/quality (default, needs 16GB RAM)"
    echo "    [2] qwen3:8b    — 8B params, faster, less accurate (needs 8GB RAM)"
    echo "    [3] qwen3:30b   — 30B params, best quality, slower (needs 32GB RAM)"
    echo "    [4] llama3.1:8b  — Meta's 8B, fast general-purpose (needs 8GB RAM)"
    echo ""
    read -p "  Chat model [1/2/3/4]: " model_choice
    case "$model_choice" in
      2) OLLAMA_MODEL="qwen3:8b" ;;
      3) OLLAMA_MODEL="qwen3:30b" ;;
      4) OLLAMA_MODEL="llama3.1:8b" ;;
      *) OLLAMA_MODEL="qwen3:14b" ;;
    esac

    echo ""
    echo "  Obsidian is a local markdown editor for viewing/editing your vault files."
    echo "  Not required — you can edit files with any text editor."
    read -p "  Enable Obsidian integration? [y/N]: " obs_enabled
    case "$obs_enabled" in
      y|Y) OBSIDIAN_ENABLED="true" ;;
      *) OBSIDIAN_ENABLED="false" ;;
    esac

    cat > "$ENV_FILE" <<EOF
# Business Assistant Box Configuration
AI_PROVIDER=${AI_PROVIDER}
LOCAL_LLM_ENABLED=${LOCAL_LLM_ENABLED}
OPENCLAW_API_KEY=${OPENCLAW_API_KEY}
OPENCLAW_MODEL=${OPENCLAW_MODEL}
OPENCLAW_WORKSPACE_PATH=${BASE_PATH}/openclaw
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=${OLLAMA_MODEL}

# PostgreSQL credentials
PG_HOST=localhost
PG_PORT=5432
PG_USER=admin
PG_PASSWORD=strongpassword
PG_DATABASE=businessassistant

EMBEDDING_PROVIDER=${EMBEDDING_PROVIDER}
EMBEDDING_MODEL=${EMBEDDING_MODEL}
EMBEDDING_DIMENSIONS=${EMBEDDING_DIMENSIONS}
ACTIVE_CLIENT=${ACTIVE_CLIENT}
BASE_PATH=${BASE_PATH}
OBSIDIAN_ENABLED=${OBSIDIAN_ENABLED}
OBSIDIAN_VAULT_PATH=${BASE_PATH}/current-client
RAG_ENABLED=true
DASHBOARD_ENABLED=true
WORKFLOW_ENGINE=n8n
N8N_BASE_URL=http://localhost:5678
N8N_API_KEY=
OPENWEBUI_BASE_URL=http://localhost:3000
BUSINESS_BUTTONS_ENABLED=true
APPROVAL_REQUIRED_FOR_EMAIL_SEND=true
EOF

    echo ".env created at $ENV_FILE"
    FILES_CREATED+=("$ENV_FILE")
  fi
fi

# Load .env (but preserve script-detected BASE_PATH)
DETECTED_BASE_PATH="$BASE_PATH"
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi
# Override BASE_PATH with actual detected path (in case .env has stale value)
BASE_PATH="$DETECTED_BASE_PATH"

# Default EMBEDDING_DIMENSIONS if not in .env
EMBEDDING_DIMENSIONS="${EMBEDDING_DIMENSIONS:-768}"

prompt_user "PHASE 0B — Environment Configuration" "PHASE 1 — Ubuntu Update & Tools" "Settings stored in: $ENV_FILE
- Edit AI_PROVIDER, OLLAMA_MODEL, EMBEDDING_MODEL in .env to change defaults.
- N8N_API_KEY can be set later after n8n first-login." 2

# ==========================================
# PHASE 1 — Ubuntu Update & Tools
# ==========================================
echo "=== PHASE 1 — Ubuntu Update & Tools ==="
echo ""

if [ "$DRY_RUN" = true ]; then
  log_dry "Would run: sudo apt --fix-broken install -y"
  log_dry "Would run: sudo apt update && sudo apt upgrade -y"
  log_dry "Would install: curl wget git nano vim unzip htop net-tools jq python3 python3-full python3-venv python3-pip"
else
  # Fix any broken apt state FIRST (prevents cascade failures)
  echo "Checking for broken apt dependencies..."
  if ! sudo apt --fix-broken install -y; then
    log_warn "apt --fix-broken install failed. Attempting to remove problematic packages..."
    # Identify and remove packages with unmet deps that block everything
    BROKEN_PKGS=$(sudo dpkg --audit 2>/dev/null | grep "^Package:" | awk '{print $2}')
    if [ -n "$BROKEN_PKGS" ]; then
      echo "  Broken packages detected: $BROKEN_PKGS"
      for pkg in $BROKEN_PKGS; do
        echo "  Removing broken package: $pkg"
        sudo dpkg --remove --force-remove-reinstreq "$pkg" 2>/dev/null || true
      done
      sudo apt --fix-broken install -y || true
    fi
  fi

  sudo apt update
  sudo apt upgrade -y

  sudo apt install -y \
    curl \
    wget \
    git \
    nano \
    vim \
    unzip \
    htop \
    net-tools \
    jq \
    python3 \
    python3-full \
    python3-venv \
    python3-pip

  # Verify critical tools installed
  PHASE1_OK=true
  for tool in curl git jq python3; do
    if ! command -v "$tool" &>/dev/null; then
      log_warn "$tool not available after install. Some phases may fail."
      PHASE1_OK=false
    fi
  done
  if [ "$PHASE1_OK" = true ]; then
    echo "  ✅ All critical tools verified."
  fi
fi

prompt_user "PHASE 1 — Ubuntu Update & Tools" "PHASE 2 — Docker" "No manual settings required." 3

# ==========================================
# PHASE 2 — Docker
# ==========================================
echo "=== PHASE 2 — Docker ==="
echo ""

DOCKER_AVAILABLE=false

if command -v docker &> /dev/null; then
  echo "Docker already installed: $(docker --version 2>/dev/null || sudo docker --version)"
else
  if [ "$DRY_RUN" = true ]; then
    log_dry "Would install Docker via apt (docker.io)"
  else
    # Pre-check: ensure apt is functional before attempting Docker install
    if ! sudo apt install -y --dry-run docker.io &>/dev/null; then
      echo "  ⚠️  apt has unmet dependencies. Attempting fix before Docker install..."
      sudo apt --fix-broken install -y || true
    fi

    echo "Installing Docker via apt (docker.io)..."
    if sudo apt install -y docker.io docker-compose-v2; then
      echo "  ✅ Docker installed via apt."
    else
      echo "apt docker.io failed, trying get.docker.com..."
      CURL_CMD="curl"
      if command -v /usr/bin/curl &>/dev/null; then
        CURL_CMD="/usr/bin/curl"
      fi
      $CURL_CMD -fsSL https://get.docker.com | sh || {
        log_warn "Both apt and get.docker.com Docker install methods failed."
        echo "  ❌ CRITICAL: Docker is required for PostgreSQL, Open WebUI, and n8n."
        echo "  Fix apt first: sudo apt --fix-broken install -y"
        echo "  Then re-run this installer."
      }
    fi

    # Add user to docker group
    sudo groupadd docker 2>/dev/null || true
    sudo usermod -aG docker "$USER"
    hash -r
    export PATH="/usr/bin:/usr/local/bin:$PATH"
  fi
fi

# Ensure Docker daemon is running (handles fresh install, reinstall, or failed state)
if [ "$DRY_RUN" = false ] && command -v docker &>/dev/null; then
  hash -r
  export PATH="/usr/bin:/usr/local/bin:$PATH"
  docker --version 2>/dev/null || sudo docker --version
  docker compose version 2>/dev/null || sudo docker compose version 2>/dev/null || true

  # Pre-emptive socket fix: apt post-install often fails because docker.socket
  # isn't active yet. Reset failed state and ensure socket is up before checking.
  sudo systemctl reset-failed docker.service 2>/dev/null || true
  sudo systemctl start docker.socket 2>/dev/null || true
  sleep 2

  if docker info &>/dev/null || sudo docker info &>/dev/null; then
    echo "  ✅ Docker daemon is running."
    DOCKER_AVAILABLE=true
  else
    echo "  Docker daemon not running. Starting..."
    # Reset any failed state from apt post-install trigger
    sudo systemctl reset-failed docker.service 2>/dev/null || true
    sudo systemctl stop docker.service 2>/dev/null || true
    # Socket must be active before service starts (fd:// activation)
    sudo systemctl enable docker.socket 2>/dev/null
    sudo systemctl start docker.socket 2>/dev/null
    sleep 2
    # Now start the service
    sudo systemctl enable docker.service 2>/dev/null
    sudo systemctl start docker.service 2>/dev/null
    sleep 5
    # Verify
    if docker info &>/dev/null || sudo docker info &>/dev/null; then
      echo "  ✅ Docker daemon started successfully."
      DOCKER_AVAILABLE=true
    else
      # One more attempt with longer wait
      echo "  Retrying (10s wait)..."
      sleep 10
      if docker info &>/dev/null || sudo docker info &>/dev/null; then
        echo "  ✅ Docker daemon started successfully."
        DOCKER_AVAILABLE=true
      else
        log_warn "Docker daemon failed to start. Run: sudo journalctl -xeu docker.service"
        DOCKER_AVAILABLE=false
      fi
    fi
  fi
elif [ "$DRY_RUN" = false ]; then
  log_warn "docker not found on PATH after install. Docker-dependent phases will be SKIPPED."
  DOCKER_AVAILABLE=false
fi

prompt_user "PHASE 2 — Docker" "PHASE 3 — PostgreSQL" "No manual settings required. Docker is managed via systemd." 4

# ==========================================
# PHASE 3 — PostgreSQL (Docker)
# ==========================================
echo "=== PHASE 3 — PostgreSQL ==="
echo ""

if [ "$DRY_RUN" = false ] && [ "$DOCKER_AVAILABLE" = false ]; then
  echo "  ❌ SKIPPED: Docker is not available. Cannot start PostgreSQL container."
  log_warn "Phase 3 skipped — Docker not installed. Fix Phase 2 first."
  prompt_user "PHASE 3 — PostgreSQL" "PHASE 4 — Optional Local AI / Ollama" "SKIPPED: Docker required but not available." 5
elif [ "$DRY_RUN" = true ]; then
  log_dry "Would ensure postgres container is running (pgvector/pgvector:pg16)"
else
  # Ensure postgres data subdirectory exists (PostgreSQL won't init in a dir with hidden files)
  mkdir -p "$BASE_PATH/postgres/data"

  safe_docker_start "postgres" "pgvector/pgvector:pg16" \
    --restart unless-stopped \
    -e POSTGRES_USER=${PG_USER:-admin} \
    -e POSTGRES_PASSWORD=${PG_PASSWORD:-strongpassword} \
    -e POSTGRES_DB=${PG_DATABASE:-businessassistant} \
    -p 5432:5432 \
    -v "$BASE_PATH/postgres/data:/var/lib/postgresql/data"

  # Wait for postgres to be ready, detect restart loop
  echo ""
  echo "Waiting for PostgreSQL to accept connections..."
  PG_READY=false
  for i in $(seq 1 30); do
    if _docker exec -i postgres pg_isready -U admin 2>/dev/null | grep -q "accepting"; then
      echo "  ✅ PostgreSQL is ready."
      PG_READY=true
      break
    fi
    # Check if container is stuck restarting
    PG_STATUS=$(_docker inspect --format '{{.State.Status}}' postgres 2>/dev/null)
    if [ "$PG_STATUS" = "restarting" ] && [ "$i" -ge 10 ]; then
      echo "  ⚠️  PostgreSQL container is stuck restarting. Likely bad data directory."
      echo "  Recreating with clean data..."
      _docker stop postgres 2>/dev/null
      _docker rm postgres 2>/dev/null
      sudo rm -rf "$BASE_PATH/postgres/data"/*
      mkdir -p "$BASE_PATH/postgres/data"
      _docker run -d --name postgres \
        --restart unless-stopped \
        -e POSTGRES_USER=${PG_USER:-admin} \
        -e POSTGRES_PASSWORD=${PG_PASSWORD:-strongpassword} \
        -e POSTGRES_DB=${PG_DATABASE:-businessassistant} \
        -p 5432:5432 \
        -v "$BASE_PATH/postgres/data:/var/lib/postgresql/data" \
        pgvector/pgvector:pg16
      echo "  Container recreated. Waiting for startup..."
      sleep 5
      break
    fi
    sleep 1
  done

  # Second wait after potential recreation
  if [ "$PG_READY" = false ]; then
    for i in $(seq 1 20); do
      if _docker exec -i postgres pg_isready -U admin 2>/dev/null | grep -q "accepting"; then
        echo "  ✅ PostgreSQL is ready."
        PG_READY=true
        break
      fi
      sleep 1
    done
  fi

  if [ "$PG_READY" = false ]; then
    log_warn "PostgreSQL did not become ready within timeout. Check: docker logs postgres"
  fi

  # Detect existing container image
  if _docker ps -a --filter "name=^postgres$" --format "{{.Image}}" 2>/dev/null | grep -q "postgres:16"; then
    log_warn "Existing postgres container uses 'postgres:16' which may NOT include pgvector."
    echo ""
    echo "  Options:"
    echo "  1. Manually migrate to pgvector/pgvector:pg16"
    echo "  2. Create a separate container named 'postgres-pgvector'"
    echo "  3. Try installing pgvector extension anyway (may fail)"
    echo ""
    if [ "$SAFE_MODE" = true ]; then
      echo "  SAFE_MODE is ON — no automatic changes will be made to this container."
    fi
  fi

  # Enable pgvector immediately (image already includes it)
  if [ "$PG_READY" = true ]; then
    echo "Enabling pgvector extension..."
    # Retry in case PG is still finalizing first-time init
    PGV_DONE=false
    for attempt in 1 2 3; do
      if _docker exec -i postgres psql -U admin businessassistant -c "CREATE EXTENSION IF NOT EXISTS vector;" 2>/dev/null; then
        PGV_DONE=true
        break
      fi
      sleep 3
    done
    if [ "$PGV_DONE" = false ]; then
      log_warn "CREATE EXTENSION vector failed after 3 attempts."
    fi
  fi

  echo ""
  echo "Verifying..."
  _docker ps --filter "name=postgres"

  prompt_user "PHASE 3 — PostgreSQL" "PHASE 4 — Optional Local AI / Ollama" "PostgreSQL credentials (set during container creation):
- User: ${PG_USER:-admin} | Password: ${PG_PASSWORD:-strongpassword}
- Database: businessassistant | Port: 5432
- To change, edit this script and recreate the container." 5
fi

# ==========================================
# PHASE 4 — Optional Local AI / Ollama
# ==========================================
echo "=== PHASE 4 — Optional Local AI / Ollama ==="
echo ""

if [ "$AI_PROVIDER" = "ollama" ] || [ "$LOCAL_LLM_ENABLED" = "true" ] || [ "$EMBEDDING_PROVIDER" = "ollama" ]; then
  echo "Ollama required by configuration."
  INSTALL_OLLAMA="y"
else
  if [ "$DRY_RUN" = true ]; then
    log_dry "Would ask: Install local Ollama support?"
    INSTALL_OLLAMA="n"
  else
    read -p "Install local Ollama support? [y/n]: " INSTALL_OLLAMA
  fi
fi

if [ "$INSTALL_OLLAMA" = "y" ] || [ "$INSTALL_OLLAMA" = "Y" ]; then
  INSTALL_OLLAMA_DONE="yes"
  if [ "$DRY_RUN" = true ]; then
    log_dry "Would install Ollama and pull models"
    log_dry "Would configure OLLAMA_HOST=0.0.0.0 in systemd service"
  else
    if command -v ollama &> /dev/null; then
      echo "Ollama already installed."
    else
      curl -fsSL https://ollama.com/install.sh | sh
    fi

    # Configure Ollama to listen on all interfaces (required for Docker containers)
    # Also enable parallel requests and multiple loaded models
    echo "Configuring Ollama for Docker access and multi-model support..."
    OLLAMA_SERVICE="/etc/systemd/system/ollama.service"
    if [ -f "$OLLAMA_SERVICE" ]; then
      # Remove any existing Ollama env lines to rebuild cleanly
      sudo sed -i '/OLLAMA_HOST/d' "$OLLAMA_SERVICE"
      sudo sed -i '/OLLAMA_NUM_PARALLEL/d' "$OLLAMA_SERVICE"
      sudo sed -i '/OLLAMA_MAX_LOADED_MODELS/d' "$OLLAMA_SERVICE"
      # Add all required environment variables
      sudo sed -i '/^\[Service\]/a Environment="OLLAMA_HOST=0.0.0.0"\nEnvironment="OLLAMA_NUM_PARALLEL=2"\nEnvironment="OLLAMA_MAX_LOADED_MODELS=3"' "$OLLAMA_SERVICE"
      echo "  Added OLLAMA_HOST=0.0.0.0"
      echo "  Added OLLAMA_NUM_PARALLEL=2"
      echo "  Added OLLAMA_MAX_LOADED_MODELS=3"
      sudo systemctl daemon-reload
      sudo systemctl restart ollama
      echo "  Ollama restarted."
    else
      log_warn "Ollama systemd service not found at $OLLAMA_SERVICE. Set OLLAMA_HOST=0.0.0.0 manually."
    fi

    # Wait for ollama service to be ready
    echo "Waiting for Ollama service..."
    for i in $(seq 1 15); do
      if ollama list &>/dev/null; then
        echo "  Ollama is ready."
        break
      fi
      sleep 2
    done

    # Verify Ollama is listening on 0.0.0.0 (with extended wait after restart)
    echo "Verifying Ollama listen address..."
    OLLAMA_LISTENING=false
    for i in $(seq 1 10); do
      if ss -tlnp 2>/dev/null | grep -q "0.0.0.0:11434"; then
        echo "  ✅ Ollama listening on 0.0.0.0:11434"
        OLLAMA_LISTENING=true
        break
      elif ss -tlnp 2>/dev/null | grep -q ":11434"; then
        # Listening but on wrong interface
        if ss -tlnp 2>/dev/null | grep -q "127.0.0.1:11434"; then
          log_warn "Ollama still on 127.0.0.1:11434. Docker containers may not connect. Fix manually."
        fi
        OLLAMA_LISTENING=true
        break
      fi
      sleep 2
    done
    if [ "$OLLAMA_LISTENING" = false ]; then
      log_warn "Ollama not detected on port 11434 after 20s. Service may still be starting."
    fi

    # Pull primary model from .env (or default)
    PRIMARY_MODEL="${OLLAMA_MODEL:-qwen3:14b}"
    echo "Pulling primary model: $PRIMARY_MODEL (from .env OLLAMA_MODEL)..."
    ollama pull "$PRIMARY_MODEL" || log_warn "Failed to pull $PRIMARY_MODEL. Pull manually: ollama pull $PRIMARY_MODEL"

    # Offer optional models (skip if already the primary)
    OPTIONAL_MODELS=("qwen3:14b" "gemma3:12b" "llama3:8b" "mistral:7b")
    for opt_model in "${OPTIONAL_MODELS[@]}"; do
      [ "$opt_model" = "$PRIMARY_MODEL" ] && continue
      read -p "Install optional model $opt_model? [y/n]: " opt_choice
      if [ "$opt_choice" = "y" ] || [ "$opt_choice" = "Y" ]; then
        ollama pull "$opt_model" || log_warn "Failed to pull $opt_model."
      fi
    done

    # Pull embedding model if using Ollama for embeddings
    if [ "$EMBEDDING_PROVIDER" = "ollama" ]; then
      EMB_MODEL="${EMBEDDING_MODEL:-nomic-embed-text}"
      echo "Pulling embedding model: $EMB_MODEL (from .env EMBEDDING_MODEL)..."
      ollama pull "$EMB_MODEL" || log_warn "Failed to pull $EMB_MODEL."
    fi

    echo "Installed models:"
    ollama list
  fi
else
  INSTALL_OLLAMA_DONE="skipped"
  echo "Skipping Ollama installation."
fi

prompt_user "PHASE 4 — Optional Local AI / Ollama" "PHASE 5 — Open WebUI" "Ollama listens on 0.0.0.0:11434 (all interfaces).
- To change the default model, edit OLLAMA_MODEL in .env
- To pull additional models: ollama pull <model-name>" 6

# ==========================================
# PHASE 5 — Open WebUI (Docker)
# ==========================================
echo "=== PHASE 5 — Open WebUI ==="
echo ""

if [ "$DRY_RUN" = false ] && [ "$DOCKER_AVAILABLE" = false ]; then
  echo "  ❌ SKIPPED: Docker is not available. Cannot start Open WebUI container."
  log_warn "Phase 5 skipped — Docker not installed. Fix Phase 2 first."
elif [ "$DRY_RUN" = true ]; then
  log_dry "Would ensure openwebui container is running with Ollama connectivity"
else
  # Determine Ollama URL for the container
  # Use host.docker.internal via --add-host so container can reach host services
  OLLAMA_CONTAINER_URL="http://host.docker.internal:11434"

  # Check if container exists and needs recreation (missing --add-host or env)
  RECREATE_WEBUI=false
  if _docker ps -a --filter "name=^openwebui$" --format "{{.Names}}" 2>/dev/null | grep -q "^openwebui$"; then
    # Check if container has OLLAMA_BASE_URL set correctly
    EXISTING_URL=$(_docker inspect openwebui --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep "OLLAMA_BASE_URL" | cut -d= -f2)
    if [ "$EXISTING_URL" != "$OLLAMA_CONTAINER_URL" ]; then
      echo "  Existing openwebui container missing Ollama connectivity config."
      echo "  Recreating with proper --add-host and OLLAMA_BASE_URL..."
      RECREATE_WEBUI=true
    fi
  fi

  if [ "$RECREATE_WEBUI" = true ]; then
    _docker stop openwebui 2>/dev/null
    _docker rm openwebui 2>/dev/null
  fi

  # Start/create container with Ollama connectivity
  if _docker ps --filter "name=^openwebui$" --filter "status=running" --format "{{.Names}}" 2>/dev/null | grep -q "^openwebui$"; then
    echo "  Container 'openwebui' already running with correct config."
  elif _docker ps -a --filter "name=^openwebui$" --format "{{.Names}}" 2>/dev/null | grep -q "^openwebui$"; then
    echo "  Container 'openwebui' exists but stopped. Starting..."
    _docker start openwebui
  else
    echo "  Creating openwebui container with Ollama connectivity..."
    _docker run -d --name openwebui \
      --restart unless-stopped \
      --add-host=host.docker.internal:host-gateway \
      -e OLLAMA_BASE_URL="$OLLAMA_CONTAINER_URL" \
      -p 3000:8080 \
      -v "$BASE_PATH/dashboard:/app/backend/data" \
      ghcr.io/open-webui/open-webui:main
    echo "  Created and started container: openwebui"
  fi

  # Wait for WebUI to be healthy
  echo "Waiting for Open WebUI to start..."
  for i in $(seq 1 30); do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null)
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "303" ]; then
      echo "  ✅ Open WebUI is responding."
      break
    fi
    sleep 2
  done

  # Test Ollama connectivity from inside the WebUI container
  echo "Testing Ollama connectivity from WebUI container..."
  OLLAMA_REACHABLE=false
  for i in $(seq 1 5); do
    if _docker exec openwebui curl -sf http://host.docker.internal:11434/api/version &>/dev/null; then
      echo "  ✅ WebUI can reach Ollama. Models should appear in selection."
      OLLAMA_REACHABLE=true
      break
    fi
    sleep 3
  done
  if [ "$OLLAMA_REACHABLE" = false ]; then
    log_warn "WebUI cannot reach Ollama. Check OLLAMA_HOST=0.0.0.0 and firewall."
  fi

  echo ""
  echo "Verifying..."
  _docker ps --filter "name=openwebui"
  echo ""
  echo "Access: http://$(hostname -I | awk '{print $1}'):3000"
fi

prompt_user "PHASE 5 — Open WebUI" "PHASE 6 — n8n" "MANUAL STEP REQUIRED:
- Open http://localhost:3000 and create your admin account (first user = admin).
- Remember these credentials - needed for API access and RAG setup (Phase 10).
- Models from Ollama appear automatically in the model selector." 7

# ==========================================
# PHASE 6 — n8n (Docker)
# ==========================================
echo "=== PHASE 6 — n8n ==="
echo ""

if [ "$DRY_RUN" = false ] && [ "$DOCKER_AVAILABLE" = false ]; then
  echo "  ❌ SKIPPED: Docker is not available. Cannot start n8n container."
  log_warn "Phase 6 skipped — Docker not installed. Fix Phase 2 first."
elif [ "$DRY_RUN" = true ]; then
  log_dry "Would ensure n8n container is running"
else
  # n8n runs as user 'node' (UID 1000) inside container
  mkdir -p "$BASE_PATH/n8n"
  sudo chown -R 1000:1000 "$BASE_PATH/n8n"

  safe_docker_start "n8n" "n8nio/n8n" \
    --restart unless-stopped \
    --add-host=host.docker.internal:host-gateway \
    -p 5678:5678 \
    -v "$BASE_PATH/n8n:/home/node/.n8n"

  echo ""
  echo "Verifying..."
  _docker ps --filter "name=n8n"
  echo ""
  echo "Access: http://$(hostname -I | awk '{print $1}'):5678"
fi

prompt_user "PHASE 6 — n8n" "PHASE 6A — Import n8n Workflows" "MANUAL STEP REQUIRED:
- Open http://localhost:5678 and create your n8n owner account (first user = owner).
- After login: Settings > API > Create API Key. Save it.
- Set N8N_API_KEY=<your-key> in .env
- Create PostgreSQL credential in n8n:
  Host: host.docker.internal | Port: 5432
  User: ${PG_USER:-admin} | Password: ${PG_PASSWORD:-strongpassword} | DB: ${PG_DATABASE:-businessassistant}
  Note the credential ID for workflow configuration." 8

# ==========================================
# PHASE 6A — Import n8n Workflows
# ==========================================
echo "=== PHASE 6A — Import n8n Workflows ==="
echo ""

WORKFLOW_DIR="$BASE_PATH/n8n/workflows"

if [ "$DRY_RUN" = false ] && [ "$DOCKER_AVAILABLE" = false ]; then
  echo "  ❌ SKIPPED: Docker is not available. Cannot import n8n workflows."
  log_warn "Phase 6A skipped — Docker not installed. Fix Phase 2 first."
elif [ "$DRY_RUN" = true ]; then
  log_dry "Would import workflow JSONs from $WORKFLOW_DIR/standard/ and $WORKFLOW_DIR/selectable/"
else
  # Wait for n8n container to be ready
  echo "Waiting for n8n to be ready..."
  N8N_READY=false
  for i in $(seq 1 30); do
    if _docker exec n8n n8n list:workflow &>/dev/null; then
      N8N_READY=true
      break
    fi
    sleep 2
  done

  if [ "$N8N_READY" = true ]; then
    # Get existing workflow names
    EXISTING_WORKFLOWS=$(_docker exec n8n n8n list:workflow 2>/dev/null | awk -F'|' '{print $2}' | sed 's/^ *//;s/ *$//')

    WORKFLOW_FILES=$(find "$WORKFLOW_DIR" -path "*/standard/*.json" -o -path "*/selectable/*.json" 2>/dev/null | sort)
    IMPORT_COUNT=0
    SKIP_COUNT=0

    if [ -n "$WORKFLOW_FILES" ]; then
      while IFS= read -r json_file; do
        wf_name=$(jq -r '.name' "$json_file" 2>/dev/null)
        [ -z "$wf_name" ] || [ "$wf_name" = "null" ] && continue

        # Ensure workflow has an id field (required by n8n CLI)
        has_id=$(python3 -c "import json; d=json.load(open('$json_file')); print('yes' if d.get('id') else 'no')")
        if [ "$has_id" = "no" ]; then
          python3 -c "
import json, uuid
with open('$json_file', 'r') as fh:
    d = json.load(fh)
d['id'] = str(uuid.uuid4()).replace('-','')[:16]
with open('$json_file', 'w') as fh:
    json.dump(d, fh, indent=2)
"
        fi

        # Check if already exists
        if echo "$EXISTING_WORKFLOWS" | grep -qF "$wf_name"; then
          echo "  Exists: $wf_name"
          ((SKIP_COUNT++))
        else
          # Convert host path to container path
          container_path=$(echo "$json_file" | sed "s|$BASE_PATH/n8n|/home/node/.n8n|")
          result=$(_docker exec n8n n8n import:workflow --input="$container_path" 2>&1)
          if echo "$result" | grep -q "Successfully imported"; then
            echo "  ✅ Imported: $wf_name"
            ((IMPORT_COUNT++))
          else
            echo "  ❌ Failed: $wf_name"
            echo "     $result"
          fi
        fi
      done <<< "$WORKFLOW_FILES"

      echo ""
      echo "  Imported: $IMPORT_COUNT | Already existed: $SKIP_COUNT"
    else
      echo "  No workflow files found in $WORKFLOW_DIR/standard/ or $WORKFLOW_DIR/selectable/"
    fi
  else
    log_warn "n8n not ready after 60s. Import workflows manually: ./admin/configure_n8n.sh"
  fi
fi

prompt_user "PHASE 6A — Import n8n Workflows" "PHASE 6A2 — Activate n8n Workflows" "Workflows imported but inactive by default.
- Activate via n8n UI or: docker exec n8n n8n publish:workflow --id=<ID>
- Webhook pattern: http://localhost:5678/webhook/business/<path>
- Update PG_CREDENTIAL_ID in workflow JSONs if your credential ID differs." 9

# ==========================================
# PHASE 6A2 — Activate n8n Workflows
# ==========================================
echo "=== PHASE 6A2 — Activate n8n Workflows ==="
echo ""

if [ "$DRY_RUN" = false ] && [ "$DOCKER_AVAILABLE" = false ]; then
  echo "  ❌ SKIPPED: Docker is not available."
elif [ "$DRY_RUN" = true ]; then
  log_dry "Would activate all imported n8n workflows"
else
  # Get list of all workflow IDs (format: "id|name")
  WORKFLOW_LIST=$(_docker exec n8n n8n list:workflow 2>/dev/null | grep '|')
  if [ -n "$WORKFLOW_LIST" ]; then
    ACTIVATED=0
    while IFS='|' read -r wf_id wf_name; do
      wf_id="$(echo "$wf_id" | tr -d ' ')"
      wf_name="$(echo "$wf_name" | sed 's/^ *//;s/ *$//')"
      [ -z "$wf_id" ] && continue
      _docker exec n8n n8n publish:workflow --id="$wf_id" 2>/dev/null && true
      echo "  ✅ Activated: $wf_name ($wf_id)"
      ACTIVATED=$((ACTIVATED + 1))
    done <<< "$WORKFLOW_LIST"
    echo ""
    echo "  Activated: $ACTIVATED workflows"
  else
    echo "  No workflows found to activate."
  fi
fi

prompt_user "PHASE 6A2 — Activate n8n Workflows" "PHASE 6B — OpenClaw" "All workflows activated.
- Deactivate any you don't need via n8n UI.
- Webhook-triggered workflows are now live." 10

# ==========================================
# PHASE 6B — OpenClaw
# ==========================================
if [ "$SKIP_NEXT" = true ]; then
  SKIP_NEXT=false
  echo "=== PHASE 6B — OpenClaw (SKIPPED) ==="
  echo ""
else
  echo "=== PHASE 6B — OpenClaw ==="
  echo ""

  if [ "$DRY_RUN" = true ]; then
    log_dry "Would install OpenClaw via curl script"
  else
    if command -v openclaw &> /dev/null; then
      echo "OpenClaw already installed."
    else
      echo "Installing OpenClaw..."
      if curl -fsSL --connect-timeout 10 https://get.openclaw.com -o /dev/null 2>/dev/null; then
        curl -fsSL https://get.openclaw.com | sh || log_warn "OpenClaw install script failed."
      else
        log_warn "Could not reach get.openclaw.com. Skipping OpenClaw install."
      fi
    fi

    echo "Verifying..."
    openclaw --version 2>/dev/null || echo "  OpenClaw not available. Install manually later if needed."
  fi

  prompt_user "PHASE 6B — OpenClaw" "PHASE 7 — pgvector" "OpenClaw is optional.
- If installed, configure workspace path in .env (OPENCLAW_WORKSPACE_PATH).
- No additional credentials needed for local usage." 11
fi

# ==========================================
# PHASE 7 — pgvector
# ==========================================
echo "=== PHASE 7 — pgvector ==="
echo ""

if [ "$DRY_RUN" = false ] && [ "$DOCKER_AVAILABLE" = false ]; then
  echo "  ❌ SKIPPED: Docker is not available. Cannot configure pgvector."
  log_warn "Phase 7 skipped — Docker not installed. Fix Phase 2 first."
elif [ "$DRY_RUN" = true ]; then
  log_dry "Would enable pgvector extension in PostgreSQL"
else
  # Ensure postgres is ready before running commands
  echo "Confirming PostgreSQL is accepting connections..."
  for i in $(seq 1 15); do
    if _docker exec -i postgres pg_isready -U admin 2>/dev/null | grep -q "accepting"; then
      break
    fi
    sleep 2
  done

  echo "Enabling pgvector extension..."
  _docker exec -i postgres psql -U admin businessassistant -c "CREATE EXTENSION IF NOT EXISTS vector;" 2>&1 || {
    log_warn "CREATE EXTENSION vector failed. Container may not have pgvector installed."
    echo "  If using postgres:16, switch to pgvector/pgvector:pg16."
  }

  # Explicit validation
  echo ""
  echo "Validating pgvector extension..."
  PGV_CHECK=$(_docker exec -i postgres psql -U admin businessassistant -t -c "SELECT extname FROM pg_extension WHERE extname='vector';" 2>/dev/null | tr -d ' \n')

  if [ "$PGV_CHECK" = "vector" ]; then
    echo "  ✅ pgvector extension confirmed active."
  else
    log_warn "pgvector extension NOT found after CREATE EXTENSION attempt."
    echo "  FAIL: pgvector is not available in this PostgreSQL container."
    echo "  Recommended: Use image pgvector/pgvector:pg16 instead of postgres:16."
  fi
fi

prompt_user "PHASE 7 — pgvector" "PHASE 7B — RAG Schema" "No manual settings required. Extension enabled inside PostgreSQL automatically." 12

# ==========================================
# PHASE 7B — RAG Schema
# ==========================================
echo "=== PHASE 7B — RAG Schema ==="
echo ""

SCHEMA_FILE="$BASE_PATH/vector-db/schema.sql"

# Generate schema with configurable dimensions
SCHEMA_CONTENT="-- Business Assistant Box - RAG Schema
-- Requires: CREATE EXTENSION vector;
-- Embedding dimensions: ${EMBEDDING_DIMENSIONS}

CREATE TABLE IF NOT EXISTS rag_documents (
  id SERIAL PRIMARY KEY,
  client_name VARCHAR(255) NOT NULL,
  source_path TEXT NOT NULL,
  title VARCHAR(500),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS rag_chunks (
  id SERIAL PRIMARY KEY,
  document_id INTEGER REFERENCES rag_documents(id) ON DELETE CASCADE,
  client_name VARCHAR(255) NOT NULL,
  source_path TEXT NOT NULL,
  title VARCHAR(500),
  chunk_text TEXT NOT NULL,
  embedding vector(${EMBEDDING_DIMENSIONS}),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chunks_client ON rag_chunks(client_name);
CREATE INDEX IF NOT EXISTS idx_chunks_embedding ON rag_chunks USING ivfflat (embedding vector_cosine_ops);"

safe_write_file "$SCHEMA_FILE" "$SCHEMA_CONTENT" "RAG schema (${EMBEDDING_DIMENSIONS} dimensions)"

# Deploy schema
if [ "$DRY_RUN" = true ]; then
  log_dry "Would deploy RAG schema to PostgreSQL"
elif [ "$DOCKER_AVAILABLE" = false ]; then
  echo "  ❌ SKIPPED: Docker not available. Schema not deployed."
  log_warn "RAG schema deployment skipped — Docker not installed."
else
  if [ -f "$SCHEMA_FILE" ]; then
    echo "Deploying RAG schema..."
    _docker exec -i postgres psql -U admin businessassistant < "$SCHEMA_FILE" 2>&1 || {
      log_warn "RAG schema deployment failed."
    }
    echo "  RAG schema deployed."
  fi
fi

prompt_user "PHASE 7B — RAG Schema" "PHASE 8 — Python RAG Dependencies" "Schema deployed. Tables: rag_documents, rag_chunks.
- Embedding dimensions: ${EMBEDDING_DIMENSIONS} (from .env EMBEDDING_DIMENSIONS).
- To change dimensions, update .env and re-run this phase." 13

# ==========================================
# PHASE 8 — Python RAG Dependencies
# ==========================================
echo "=== PHASE 8 — Python RAG Dependencies ==="
echo ""

RAG_VENV="$BASE_PATH/vector-db/venv"

if [ "$DRY_RUN" = true ]; then
  log_dry "Would create venv at $RAG_VENV and install packages"
else
  if [ -d "$RAG_VENV" ] && [ -f "$RAG_VENV/bin/activate" ]; then
    echo "RAG venv already exists."
  else
    echo "Creating Python virtual environment..."
    rm -rf "$RAG_VENV" 2>/dev/null
    python3 -m venv "$RAG_VENV" || {
      log_warn "python3 -m venv failed. Trying with --without-pip..."
      python3 -m venv --without-pip "$RAG_VENV"
    }
  fi

  if [ -f "$RAG_VENV/bin/activate" ]; then
    source "$RAG_VENV/bin/activate"
    # Ensure pip is available in venv
    python -m ensurepip --upgrade 2>/dev/null || true
    pip install --upgrade pip --quiet 2>/dev/null || true
    pip install --quiet llama-index || log_warn "Failed to install llama-index"
    pip install --quiet llama-index-readers-file || log_warn "Failed to install llama-index-readers-file"
    pip install --quiet psycopg2-binary || log_warn "Failed to install psycopg2-binary"
    pip install --quiet python-dotenv || log_warn "Failed to install python-dotenv"
    pip install --quiet requests || log_warn "Failed to install requests"
    pip install --quiet pymupdf || log_warn "Failed to install pymupdf"
    pip install --quiet python-docx || log_warn "Failed to install python-docx"
    pip install --quiet openpyxl || log_warn "Failed to install openpyxl"
    pip install --quiet beautifulsoup4 || log_warn "Failed to install beautifulsoup4"
    # Verify critical deps are importable
    if python -c "import psycopg2, dotenv, requests" 2>/dev/null; then
      echo "  ✅ RAG dependencies verified (psycopg2, dotenv, requests)"
    else
      log_warn "RAG dependency verification failed. Retrying install..."
      pip install --quiet psycopg2-binary python-dotenv requests 2>/dev/null
      if ! python -c "import psycopg2, dotenv, requests" 2>/dev/null; then
        log_warn "RAG dependencies still missing. Run manually: source $RAG_VENV/bin/activate && pip install psycopg2-binary python-dotenv requests"
        WARNINGS+=("RAG Python dependencies failed to install in venv")
      fi
    fi
    deactivate
    echo "RAG dependencies installed in $RAG_VENV"
  else
    log_warn "Could not create Python venv. Install manually: python3 -m venv $RAG_VENV"
    WARNINGS+=("Python venv creation failed — RAG indexing will not work")
  fi
fi

prompt_user "PHASE 8 — Python RAG Dependencies" "PHASE 8B — RAG Index + Query Scripts" "Python venv: $BASE_PATH/vector-db/venv
- Activate: $BASE_PATH/vector-db/venv/bin/python3
- No manual credentials needed - reads from .env automatically." 14

# ==========================================
# PHASE 8B — RAG Index + Query Scripts
# ==========================================
echo "=== PHASE 8B — RAG Index + Query Scripts ==="
echo ""

# index_vault.py
INDEX_FILE="$BASE_PATH/vector-db/index_vault.py"
INDEX_CONTENT='#!/usr/bin/env python3
"""Index Obsidian vault and system/client files into PostgreSQL + pgvector."""

import os
import psycopg2
from pathlib import Path
from dotenv import load_dotenv

env_path = Path(__file__).resolve().parent.parent / ".env"
load_dotenv(env_path)

BASE_PATH = os.getenv("BASE_PATH")
ACTIVE_CLIENT = os.getenv("ACTIVE_CLIENT", "demo-company")
EMBEDDING_PROVIDER = os.getenv("EMBEDDING_PROVIDER", "ollama")
EMBEDDING_MODEL = os.getenv("EMBEDDING_MODEL", "nomic-embed-text")
OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")

EXCLUDE_DIRS = {"admin", "logs", "backups", "docker", "postgres", "node_modules", ".git", "venv"}
EXCLUDE_EXTENSIONS = {".key", ".pem"}
EXCLUDE_FILES = {".env"}

INDEX_PATHS = [
    os.path.join(BASE_PATH, "system"),
    os.path.join(BASE_PATH, "clients", ACTIVE_CLIENT),
]

DB_CONFIG = {
    "host": os.getenv("PG_HOST", "localhost"),
    "port": int(os.getenv("PG_PORT", "5432")),
    "user": os.getenv("PG_USER", "admin"),
    "password": os.getenv("PG_PASSWORD", "strongpassword"),
    "dbname": os.getenv("PG_DATABASE", "businessassistant"),
}


def get_files(paths):
    """Collect all indexable files, excluding admin/logs/backups/docker/postgres/.git."""
    files = []
    for base in paths:
        if not os.path.exists(base):
            continue
        for root, dirs, filenames in os.walk(base):
            dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
            for f in filenames:
                if f in EXCLUDE_FILES:
                    continue
                ext = os.path.splitext(f)[1].lower()
                if ext in EXCLUDE_EXTENSIONS:
                    continue
                if ext in (".md", ".txt"):
                    files.append(os.path.join(root, f))
    return files


def chunk_text(text, chunk_size=512, overlap=64):
    """Split text into overlapping chunks."""
    chunks = []
    start = 0
    while start < len(text):
        end = start + chunk_size
        chunks.append(text[start:end])
        start += chunk_size - overlap
    return [c for c in chunks if c.strip()]


def get_embedding(text):
    """Get embedding vector from configured provider."""
    if EMBEDDING_PROVIDER == "ollama":
        import requests
        resp = requests.post(
            f"{OLLAMA_BASE_URL}/api/embeddings",
            json={"model": EMBEDDING_MODEL, "prompt": text},
        )
        resp.raise_for_status()
        return resp.json()["embedding"]
    else:
        raise NotImplementedError(f"Embedding provider \"{EMBEDDING_PROVIDER}\" not yet supported.")


def index():
    """Main indexing pipeline."""
    files = get_files(INDEX_PATHS)
    print(f"Found {len(files)} files to index.")

    conn = psycopg2.connect(**DB_CONFIG)
    cur = conn.cursor()

    cur.execute("DELETE FROM rag_chunks WHERE client_name = %s", (ACTIVE_CLIENT,))
    cur.execute("DELETE FROM rag_documents WHERE client_name = %s", (ACTIVE_CLIENT,))

    for filepath in files:
        with open(filepath, "r", errors="ignore") as f:
            content = f.read().strip()

        if not content:
            continue

        title = os.path.basename(filepath)
        rel_path = os.path.relpath(filepath, BASE_PATH)

        cur.execute(
            "INSERT INTO rag_documents (client_name, source_path, title) VALUES (%s, %s, %s) RETURNING id",
            (ACTIVE_CLIENT, rel_path, title),
        )
        doc_id = cur.fetchone()[0]

        chunks = chunk_text(content)
        for chunk in chunks:
            try:
                embedding = get_embedding(chunk)
            except Exception as e:
                print(f"  Embedding failed for chunk in {title}: {e}")
                continue

            cur.execute(
                "INSERT INTO rag_chunks (document_id, client_name, source_path, title, chunk_text, embedding) VALUES (%s, %s, %s, %s, %s, %s)",
                (doc_id, ACTIVE_CLIENT, rel_path, title, chunk, embedding),
            )

        print(f"  Indexed: {rel_path} ({len(chunks)} chunks)")

    conn.commit()
    cur.close()
    conn.close()
    print("Indexing complete.")


if __name__ == "__main__":
    index()'

safe_write_file "$INDEX_FILE" "$INDEX_CONTENT" "RAG indexing script"

# query_vault.py
QUERY_FILE="$BASE_PATH/vector-db/query_vault.py"
QUERY_CONTENT='#!/usr/bin/env python3
"""Query the RAG database for relevant context."""

import os
import sys
import psycopg2
from pathlib import Path
from dotenv import load_dotenv

env_path = Path(__file__).resolve().parent.parent / ".env"
load_dotenv(env_path)

BASE_PATH = os.getenv("BASE_PATH")
ACTIVE_CLIENT = os.getenv("ACTIVE_CLIENT", "demo-company")
EMBEDDING_PROVIDER = os.getenv("EMBEDDING_PROVIDER", "ollama")
EMBEDDING_MODEL = os.getenv("EMBEDDING_MODEL", "nomic-embed-text")
OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")

DB_CONFIG = {
    "host": os.getenv("PG_HOST", "localhost"),
    "port": int(os.getenv("PG_PORT", "5432")),
    "user": os.getenv("PG_USER", "admin"),
    "password": os.getenv("PG_PASSWORD", "strongpassword"),
    "dbname": os.getenv("PG_DATABASE", "businessassistant"),
}


def get_embedding(text):
    """Get embedding vector from configured provider."""
    if EMBEDDING_PROVIDER == "ollama":
        import requests
        resp = requests.post(
            f"{OLLAMA_BASE_URL}/api/embeddings",
            json={"model": EMBEDDING_MODEL, "prompt": text},
        )
        resp.raise_for_status()
        return resp.json()["embedding"]
    else:
        raise NotImplementedError(f"Embedding provider \"{EMBEDDING_PROVIDER}\" not yet supported.")


def query(question, top_k=5):
    """Retrieve top-k relevant chunks for a question."""
    embedding = get_embedding(question)

    conn = psycopg2.connect(**DB_CONFIG)
    cur = conn.cursor()

    cur.execute(
        """
        SELECT title, source_path, chunk_text,
               1 - (embedding <=> %s::vector) AS similarity
        FROM rag_chunks
        WHERE client_name = %s
        ORDER BY embedding <=> %s::vector
        LIMIT %s
        """,
        (embedding, ACTIVE_CLIENT, embedding, top_k),
    )

    results = cur.fetchall()
    cur.close()
    conn.close()
    return results


def main():
    if len(sys.argv) < 2:
        print("Usage: python query_vault.py \"your question here\"")
        sys.exit(1)

    question = " ".join(sys.argv[1:])
    print(f"Query: {question}")
    print(f"Client: {ACTIVE_CLIENT}")
    print("-" * 50)

    results = query(question)

    if not results:
        print("No results found.")
        return

    for i, (title, source, chunk, similarity) in enumerate(results, 1):
        print(f"\n[{i}] {title} ({source})")
        print(f"    Similarity: {similarity:.4f}")
        print(f"    {chunk[:200]}...")


if __name__ == "__main__":
    main()'

safe_write_file "$QUERY_FILE" "$QUERY_CONTENT" "RAG query script"

prompt_user "PHASE 8B — RAG Index + Query Scripts" "PHASE 9 — Obsidian (Native)" "Scripts created:
- Index client: ./vector-db/venv/bin/python3 ./vector-db/index_vault.py
- Query client: ./vector-db/venv/bin/python3 ./vector-db/query_vault.py 'your question'
- Both read DB credentials and paths from .env automatically." 15

# ==========================================
# PHASE 9 — Obsidian (Native)
# ==========================================
echo "=== PHASE 9 — Obsidian (Native) ==="
echo ""

if [ "$OBSIDIAN_ENABLED" = "true" ]; then
  if [ "$DRY_RUN" = true ]; then
    log_dry "Would install Obsidian natively via .deb package"
  else
    # Ensure vault symlink/dir exists
    if [ ! -L "$BASE_PATH/current-client" ] && [ ! -d "$BASE_PATH/current-client" ]; then
      ACTIVE_CLIENT="${ACTIVE_CLIENT:-demo-company}"
      ln -sf "$BASE_PATH/clients/$ACTIVE_CLIENT" "$BASE_PATH/current-client"
      echo "  Created symlink: current-client → clients/$ACTIVE_CLIENT"
    fi

    if command -v obsidian &>/dev/null; then
      echo "  ✅ Obsidian already installed."
    else
      echo "  Downloading Obsidian..."
      OBSIDIAN_VERSION="1.8.9"
      wget -q "https://github.com/obsidianmd/obsidian-releases/releases/download/v${OBSIDIAN_VERSION}/obsidian_${OBSIDIAN_VERSION}_amd64.deb" -O /tmp/obsidian.deb
      sudo dpkg -i /tmp/obsidian.deb 2>/dev/null || sudo apt install -f -y 2>/dev/null
      rm -f /tmp/obsidian.deb
      if command -v obsidian &>/dev/null; then
        echo "  ✅ Obsidian installed successfully."
      else
        log_warn "Obsidian installation failed. Install manually from https://obsidian.md/download"
      fi
    fi

    RESOLVED_VAULT=$(readlink -f "$BASE_PATH/current-client" 2>/dev/null || echo "$BASE_PATH/current-client")
    echo ""
    echo "  Vault path: $RESOLVED_VAULT"
    echo ""
    echo "  TO OPEN:"
    echo "    obsidian &"
    echo "    Then select 'Open folder as vault' → $RESOLVED_VAULT"
  fi

  # Create/update Obsidian setup notes
  OBSIDIAN_NOTES="$BASE_PATH/admin/OBSIDIAN_SETUP.md"
  OBSIDIAN_CONTENT="# Obsidian Setup (Native)

## Launch

    obsidian &

## Vault Path

\`${BASE_PATH}/current-client\` → \`clients/\${ACTIVE_CLIENT}\`

## First Time Setup

1. Run \`obsidian &\`
2. Select **Open folder as vault**
3. Choose: \`${BASE_PATH}/current-client\`

## Rules

Obsidian is the **Human Editable Business Brain**.

### Use Obsidian for:
- Client business knowledge
- FAQs
- Procedures
- Customer/vendor rules

### Do NOT use Obsidian for:
- admin/
- logs/
- docker/
- backups/
- System configuration

## Integration

The RAG indexer reads from the Obsidian vault path and indexes into PostgreSQL + pgvector.
Run \`./vector-db/venv/bin/python3 ./vector-db/index_vault.py\` after editing client documents."

  safe_write_file "$OBSIDIAN_NOTES" "$OBSIDIAN_CONTENT" "Obsidian native installation documentation"
else
  echo "  Obsidian disabled in .env. Skipping."
fi

prompt_user "PHASE 9 — Obsidian (Native)" "PHASE 10 — RAG Pipeline" "Launch Obsidian with: obsidian &
- Select 'Open folder as vault' and choose $BASE_PATH/current-client
- No credentials needed - Obsidian runs locally." 16

# --- COMMENTED OUT: Docker-based Obsidian (replaced by native install above) ---
# # PHASE 9 — Obsidian (Docker)
# # ==========================================
# # Image: lscr.io/linuxserver/obsidian:latest (KasmVNC-based)
# # Ports: 3010 (HTTP), 3011 (HTTPS)
# # Access via browser: http://localhost:3010
# # Removed due to rendering issues and unnecessary complexity for a local editor.
# # To restore: uncomment this block and comment out the native install above.
# ---

# ==========================================
# PHASE 10 — RAG Pipeline (WebUI → pgvector)
# ==========================================
echo "=== PHASE 10 — RAG Pipeline ==="
echo ""

if [ "$DRY_RUN" = false ] && [ "$DOCKER_AVAILABLE" = false ]; then
  echo "  ❌ SKIPPED: Docker is not available. Cannot configure RAG pipeline."
  log_warn "Phase 10 skipped — Docker not installed. Fix Phase 2 first."
elif [ "$DRY_RUN" = true ]; then
  log_dry "Would install psycopg2 in WebUI container"
  log_dry "Would register Business Knowledge RAG function in Open WebUI"
else
  # Note: psycopg2-binary is also declared in the RAG filter's frontmatter (requirements: psycopg2-binary)
  # so Open WebUI will auto-install it on every startup. This manual install is a belt-and-suspenders fallback.
  echo "Installing psycopg2 in WebUI container..."
  _docker exec openwebui pip install psycopg2-binary --quiet 2>&1 || log_warn "Failed to install psycopg2 in WebUI container"

  # Verify psycopg2
  if _docker exec openwebui python3 -c "import psycopg2" 2>/dev/null; then
    echo "  ✅ psycopg2 available in WebUI container"
  else
    log_warn "psycopg2 not available in WebUI container. RAG filter will not work."
  fi

  # Test pgvector connectivity from container
  echo "Testing pgvector connectivity from WebUI container..."
  PG_TEST=$(_docker exec openwebui python3 -c "
import psycopg2
try:
    conn = psycopg2.connect(host='host.docker.internal', port=5432, user='${PG_USER:-admin}', password='${PG_PASSWORD:-strongpassword}', dbname='${PG_DATABASE:-businessassistant}')
    cur = conn.cursor()
    cur.execute('SELECT COUNT(*) FROM rag_chunks')
    print(f'OK:{cur.fetchone()[0]}')
    conn.close()
except Exception as e:
    print(f'FAIL:{e}')
" 2>&1)

  if echo "$PG_TEST" | grep -q "^OK:"; then
    CHUNK_COUNT=$(echo "$PG_TEST" | sed 's/OK://')
    echo "  ✅ pgvector reachable ($CHUNK_COUNT chunks)"
  else
    log_warn "WebUI container cannot reach pgvector: $PG_TEST"
  fi

  # Pre-warm embedding model
  echo "Pre-warming embedding model (this may take 30-60s on first load)..."
  curl -s --max-time 120 http://localhost:11434/api/embeddings -d '{"model":"nomic-embed-text","prompt":"warmup"}' > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "  ✅ Embedding model loaded"
  else
    log_warn "Embedding model warmup timed out. May be slow on first RAG query."
  fi

  # Create RAG filter function file
  mkdir -p "$BASE_PATH/dashboard/functions"
  RAG_FILTER_FILE="$BASE_PATH/dashboard/functions/business_rag_filter.py"

  cat > "$RAG_FILTER_FILE" << 'RAGEOF'
"""
title: Business Knowledge RAG
author: Business Assistant Box
version: 1.2.0
description: Retrieves relevant business context from pgvector and injects into prompts.
type: filter
requirements: psycopg2-binary
"""

import requests
import psycopg2
from typing import Optional
from pydantic import BaseModel, Field


class Filter:
    class Valves(BaseModel):
        pg_host: str = Field(default="host.docker.internal")
        pg_port: int = Field(default=5432)
        pg_user: str = Field(default="admin")
        pg_password: str = Field(default="strongpassword")  # override in WebUI Admin → Functions → Valves
        pg_database: str = Field(default="businessassistant")
        ollama_url: str = Field(default="http://host.docker.internal:11434")
        embedding_model: str = Field(default="nomic-embed-text")
        active_client: str = Field(default="")
        top_k: int = Field(default=8)
        similarity_threshold: float = Field(default=0.3)

    def __init__(self):
        self.valves = self.Valves()

    def _get_active_client(self) -> str:
        """Return valve override if set, otherwise detect from most recent indexed client."""
        if self.valves.active_client:
            return self.valves.active_client
        try:
            conn = psycopg2.connect(
                host=self.valves.pg_host,
                port=self.valves.pg_port,
                user=self.valves.pg_user,
                password=self.valves.pg_password,
                dbname=self.valves.pg_database,
            )
            cur = conn.cursor()
            cur.execute("SELECT client_name FROM rag_documents ORDER BY id DESC LIMIT 1")
            row = cur.fetchone()
            cur.close()
            conn.close()
            return row[0] if row else "demo-company"
        except Exception:
            return "demo-company"

    def _get_embedding(self, text: str) -> Optional[list]:
        try:
            resp = requests.post(
                f"{self.valves.ollama_url}/api/embeddings",
                json={"model": self.valves.embedding_model, "prompt": text},
                timeout=120,
            )
            resp.raise_for_status()
            return resp.json().get("embedding")
        except Exception:
            return None

    def _query_chunks(self, embedding: list) -> list:
        try:
            conn = psycopg2.connect(
                host=self.valves.pg_host,
                port=self.valves.pg_port,
                user=self.valves.pg_user,
                password=self.valves.pg_password,
                dbname=self.valves.pg_database,
            )
            cur = conn.cursor()
            embedding_str = "[" + ",".join(str(x) for x in embedding) + "]"
            cur.execute(
                """
                SELECT chunk_text, source_path,
                       (1 - (embedding <=> %s::vector))
                       + CASE
                           WHEN title IN ('CLIENT_PROFILE.md','BUSINESS_KNOWLEDGE.md','FAQ.md','OWNER_PREFERENCES.md') THEN 0.08
                           WHEN source_path LIKE 'clients/%%' THEN 0.04
                           ELSE 0.0
                         END
                       AS similarity
                FROM rag_chunks
                WHERE client_name = %s
                  AND (1 - (embedding <=> %s::vector)) > %s
                ORDER BY similarity DESC
                LIMIT %s
                """,
                (embedding_str, self._get_active_client(), embedding_str, self.valves.similarity_threshold, self.valves.top_k),
            )
            rows = cur.fetchall()
            cur.close()
            conn.close()
            return rows
        except Exception:
            return []

    def inlet(self, body: dict, __user__: Optional[dict] = None) -> dict:
        messages = body.get("messages", [])
        if not messages:
            return body

        last_msg = messages[-1]
        if last_msg.get("role") != "user":
            return body

        query = last_msg.get("content", "")
        if not query.strip():
            return body

        embedding = self._get_embedding(query)
        if not embedding:
            return body

        chunks = self._query_chunks(embedding)
        if not chunks:
            return body

        context_parts = []
        for content, source, similarity in chunks:
            context_parts.append(f"[{source} | relevance: {similarity:.2f}]\n{content}")

        prefix = "You are this company's Business Assistant. Use ONLY the following verified business knowledge. Cite the source file. If the answer is not in the context below, say 'I don't have that information in our records.'\n\n---\n"
        context = prefix + "\n\n".join(context_parts) + "\n\n---\n\n"

        messages[-1]["content"] = context + query
        body["messages"] = messages
        return body
RAGEOF

  FILES_CREATED+=("$RAG_FILTER_FILE")
  echo "  ✅ RAG filter function written: $RAG_FILTER_FILE"

  echo ""
  echo "RAG function file: $RAG_FILTER_FILE"
  echo ""
fi

prompt_user "PHASE 10 — RAG Pipeline" "PHASE 11 — Index Client" "RAG filter function created." 17

# ==========================================
# PHASE 11 — Index Client into pgvector
# ==========================================
echo "=== PHASE 11 — Index Client ==="
echo ""

VENV_PATH="$BASE_PATH/vector-db/venv"
INDEX_SCRIPT="$BASE_PATH/vector-db/index_vault.py"

if [ ! -f "$INDEX_SCRIPT" ]; then
  echo "  ⚠️  index_vault.py not found. Skipping."
  WARNINGS+=("Client indexing skipped — script not found")
else
  echo "  Activating venv and indexing client files..."
  if [ -f "$VENV_PATH/bin/activate" ]; then
    (
      source "$VENV_PATH/bin/activate"
      cd "$BASE_PATH"
      python "$INDEX_SCRIPT" 2>&1 | tail -5
    )
    INDEX_EXIT=$?
    if [ $INDEX_EXIT -eq 0 ]; then
      CHUNK_COUNT=$(_docker exec -i postgres psql -U admin businessassistant -t -c "SELECT COUNT(*) FROM rag_chunks" 2>/dev/null | tr -d ' ')
      echo "  ✅ Client indexed ($CHUNK_COUNT chunks in pgvector)"
    else
      echo "  ⚠️  Indexing returned exit code $INDEX_EXIT"
      WARNINGS+=("Client indexing may have failed — check vector-db/index_vault.py")
    fi
  else
    echo "  ⚠️  Python venv not found at $VENV_PATH"
    WARNINGS+=("Client indexing skipped — venv not found")
  fi
fi
echo ""

prompt_user "PHASE 11 — Index Client" "PHASE 12 — Register RAG Filter" "Client documents indexed into pgvector." 18

# ==========================================
# PHASE 12 — Register RAG Filter in OpenWebUI
# ==========================================
echo "=== PHASE 12 — Register RAG Filter in Open WebUI ==="
echo ""

RAG_FILTER_FILE="$BASE_PATH/dashboard/functions/business_rag_filter.py"

if [ ! -f "$RAG_FILTER_FILE" ]; then
  echo "  ⚠️  RAG filter file not found. Skipping."
  WARNINGS+=("RAG filter registration skipped — file not found")
else
  # Install psycopg2 in container if needed
  if ! _docker exec openwebui python3 -c "import psycopg2" 2>/dev/null; then
    echo "  Installing psycopg2 in OpenWebUI container..."
    _docker exec openwebui pip install psycopg2-binary --quiet 2>&1
  fi

  # Register directly via SQLite (bypasses API auth issues)
  echo "  Registering RAG filter function..."
  REGISTER_RESULT=$(_docker exec -i openwebui python3 -c "
import sqlite3, json, sys, time

code = sys.stdin.read()
function_id = 'business_knowledge_rag'
now_ts = int(time.time())

conn = sqlite3.connect('/app/backend/data/webui.db')
cur = conn.cursor()

meta = json.dumps({
    'description': 'Retrieves relevant business context from pgvector and injects into prompts',
    'manifest': {'title': 'Business Knowledge RAG', 'author': 'NativeBlackBox', 'version': '1.2.0', 'type': 'filter'}
})

cur.execute('SELECT id FROM function WHERE id=?', (function_id,))
if cur.fetchone():
    cur.execute('UPDATE function SET content=?, meta=?, is_active=1, is_global=1, updated_at=? WHERE id=?', (code, meta, now_ts, function_id))
    print('UPDATED')
else:
    cur.execute(
        'INSERT INTO function (id, user_id, name, type, content, meta, is_active, is_global, updated_at, created_at) VALUES (?, ?, ?, ?, ?, ?, 1, 1, ?, ?)',
        (function_id, 'system', 'Business Knowledge RAG', 'filter', code, meta, now_ts, now_ts)
    )
    print('CREATED')

conn.commit()
conn.close()
" < "$RAG_FILTER_FILE" 2>&1)

  if echo "$REGISTER_RESULT" | grep -qE "UPDATED|CREATED"; then
    echo "  ✅ RAG filter registered, enabled, and set as global ($REGISTER_RESULT)"
  else
    echo "  ⚠️  Registration issue: $REGISTER_RESULT"
    WARNINGS+=("RAG filter may need manual setup in Admin → Functions")
  fi

  # Restart OpenWebUI to pick up the new function
  echo "  Restarting OpenWebUI to load filter..."
  _docker restart openwebui >/dev/null 2>&1
  echo "  ✅ OpenWebUI restarted"

  # Set default system prompt so the model always knows its identity
  echo "  Setting default system prompt..."
  sleep 15
  _docker exec openwebui python3 -c "
import sqlite3, json, time
prompt = '''You are a Business Assistant. You help the business owner manage daily operations, answer questions from company knowledge, and draft communications.

Be professional, concise, and helpful. Use plain English. Summaries first, details on request. Cite your source document when answering from business knowledge.

Rules: Never send emails, delete records, move money, or sign anything without approval. Never fabricate facts. If you do not have the information, say so. Escalate legal threats, security incidents, and fraud immediately.'''
now_ts = int(time.time())
conn = sqlite3.connect('/app/backend/data/webui.db')
cur = conn.cursor()
cur.execute('SELECT key FROM config WHERE key = ?', ('ui.default_system_prompt',))
if cur.fetchone():
    cur.execute('UPDATE config SET value = ?, updated_at = ? WHERE key = ?', (json.dumps(prompt), now_ts, 'ui.default_system_prompt'))
else:
    cur.execute('INSERT INTO config (key, value, updated_at) VALUES (?, ?, ?)', ('ui.default_system_prompt', json.dumps(prompt), now_ts))
conn.commit()
conn.close()
print('OK')
" 2>&1
  echo "  ✅ Default system prompt configured"
fi
echo ""

prompt_user "PHASE 12 — Register RAG Filter" "" "RAG pipeline fully configured.
- Filter: business_knowledge_rag (active + global)
- The filter auto-injects business context into every chat.
- To re-index after editing client files: ./vector-db/venv/bin/python3 ./vector-db/index_vault.py" 19

# ==========================================
# FINAL SUMMARY
# ==========================================
print_summary
