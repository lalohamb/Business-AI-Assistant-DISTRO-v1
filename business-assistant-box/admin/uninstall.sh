#!/bin/bash

# ==========================================
# BUSINESS ASSISTANT BOX - UNINSTALLER
# ==========================================
# Supports selective or full removal.
#
# SAFE: Will NOT remove:
#   - Linux kernel / system packages (apt core libs)
#   - Python3 (system dependency)
#   - User home directory
#   - Network configuration
#   - SSH keys
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="$(dirname "$BASE_PATH")/business-assistant-box-backups"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

# Docker wrapper
_docker() {
  if docker info &>/dev/null; then
    docker "$@"
  else
    sudo docker "$@"
  fi
}

echo "========================================"
echo "   BUSINESS ASSISTANT BOX - UNINSTALLER"
echo "========================================"
echo ""
echo "  Base path: $BASE_PATH"
echo ""
echo "  Select removal mode:"
echo ""
echo "    [1] Selective — choose which components to remove"
echo "    [2] Full      — remove everything for a clean reinstall"
echo "    [3] Cancel"
echo ""
read -p "  Choice [1/2/3]: " mode_choice

case "$mode_choice" in
  1) MODE="selective" ;;
  2) MODE="full" ;;
  *) echo "Aborted."; exit 0 ;;
esac

# ==========================================
# SELECTIVE MODE — build removal list
# ==========================================
REMOVE_CONTAINERS=false
REMOVE_VOLUMES=false
REMOVE_IMAGES=false
REMOVE_OLLAMA=false
REMOVE_DOCKER_ENGINE=false
REMOVE_RAG_VENV=false
REMOVE_RUNTIME=false
REMOVE_SYSTEM_CLEANUP=false

if [ "$MODE" = "full" ]; then
  REMOVE_CONTAINERS=true
  REMOVE_VOLUMES=true
  REMOVE_IMAGES=true
  REMOVE_OLLAMA=true
  REMOVE_DOCKER_ENGINE=true
  REMOVE_RAG_VENV=true
  REMOVE_RUNTIME=true
  REMOVE_SYSTEM_CLEANUP=true
else
  echo ""
  echo "  Select components to remove (y/n for each):"
  echo ""

  read -p "  [1] Docker containers (postgres, openwebui, n8n)? [y/n]: " c
  [ "$c" = "y" ] || [ "$c" = "Y" ] && REMOVE_CONTAINERS=true

  read -p "  [2] Docker volumes (unused)? [y/n]: " c
  [ "$c" = "y" ] || [ "$c" = "Y" ] && REMOVE_VOLUMES=true

  read -p "  [3] Docker images (pgvector, open-webui, n8n)? [y/n]: " c
  [ "$c" = "y" ] || [ "$c" = "Y" ] && REMOVE_IMAGES=true

  read -p "  [4] Ollama (binary, models, service, user)? [y/n]: " c
  [ "$c" = "y" ] || [ "$c" = "Y" ] && REMOVE_OLLAMA=true

  read -p "  [5] Docker engine itself? [y/n]: " c
  [ "$c" = "y" ] || [ "$c" = "Y" ] && REMOVE_DOCKER_ENGINE=true

  read -p "  [6] Python RAG venv (vector-db/venv)? [y/n]: " c
  [ "$c" = "y" ] || [ "$c" = "Y" ] && REMOVE_RAG_VENV=true

  read -p "  [7] Runtime data (postgres/, dashboard/, docker/, n8n/, logs/)? [y/n]: " c
  [ "$c" = "y" ] || [ "$c" = "Y" ] && REMOVE_RUNTIME=true

  read -p "  [8] System cleanup (apt autoremove, clean cache)? [y/n]: " c
  [ "$c" = "y" ] || [ "$c" = "Y" ] && REMOVE_SYSTEM_CLEANUP=true
fi

# ==========================================
# CONFIRM
# ==========================================
echo ""
echo "  Will remove:"
[ "$REMOVE_CONTAINERS" = true ] && echo "    • Docker containers"
[ "$REMOVE_VOLUMES" = true ] && echo "    • Docker volumes"
[ "$REMOVE_IMAGES" = true ] && echo "    • Docker images"
[ "$REMOVE_OLLAMA" = true ] && echo "    • Ollama (binary, models, service)"
[ "$REMOVE_DOCKER_ENGINE" = true ] && echo "    • Docker engine"
[ "$REMOVE_RAG_VENV" = true ] && echo "    • Python RAG venv"
[ "$REMOVE_RUNTIME" = true ] && echo "    • Runtime data"
[ "$REMOVE_SYSTEM_CLEANUP" = true ] && echo "    • System cleanup (apt)"
echo ""
echo "  Will KEEP:"
echo "    • admin/ (install scripts, docs)"
echo "    • system/ (agent rules, policies)"
echo "    • clients/ (business knowledge)"
echo "    • vault/ (shared documents)"
echo "    • n8n/workflows/ (workflow JSONs for reinstall)"
echo "    • vector-db/*.py, *.sql (RAG scripts)"
echo "    • .env (configuration)"
echo ""

read -p "  Proceed? [yes/no]: " proceed
if [ "$proceed" != "yes" ] && [ "$proceed" != "y" ] && [ "$proceed" != "Y" ]; then
  echo "Aborted."
  exit 0
fi
echo ""

# ==========================================
# BACKUP PROMPT
# ==========================================
read -p "Create backup before removal? [y/n]: " backup_choice
if [ "$backup_choice" = "y" ] || [ "$backup_choice" = "Y" ]; then
  BACKUP_TARGET="$BACKUP_DIR/backup-$TIMESTAMP"
  echo "Backing up to: $BACKUP_TARGET"
  mkdir -p "$BACKUP_TARGET"
  cp -r "$BASE_PATH" "$BACKUP_TARGET/" 2>/dev/null
  echo "✅ Backup saved: $BACKUP_TARGET"
  echo ""
fi

# ==========================================
# PHASE 1 — Docker Containers
# ==========================================
if [ "$REMOVE_CONTAINERS" = true ]; then
  echo "=== Removing Docker Containers ==="
  echo ""
  for container in postgres openwebui n8n openclaw; do
    if _docker ps -a --filter "name=^${container}$" --format "{{.Names}}" 2>/dev/null | grep -q "^${container}$"; then
      echo "  Stopping & removing: $container"
      _docker stop "$container" 2>/dev/null
      _docker rm -f "$container" 2>/dev/null
      echo "    ✅ $container removed"
    else
      echo "    — $container not found"
    fi
  done
  echo ""
fi

# ==========================================
# PHASE 2 — Docker Volumes
# ==========================================
if [ "$REMOVE_VOLUMES" = true ]; then
  echo "=== Removing Docker Volumes ==="
  echo ""
  _docker volume prune -f 2>/dev/null
  echo "  ✅ Volumes pruned"
  echo ""
fi

# ==========================================
# PHASE 3 — Docker Images
# ==========================================
if [ "$REMOVE_IMAGES" = true ]; then
  echo "=== Removing Docker Images ==="
  echo ""
  for image in "pgvector/pgvector:pg16" "postgres:16" "ghcr.io/open-webui/open-webui:main" "n8nio/n8n"; do
    if _docker images --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | grep -q "$image"; then
      _docker rmi "$image" 2>/dev/null
      echo "  ✅ Removed: $image"
    else
      echo "    — $image not found"
    fi
  done
  _docker image prune -f 2>/dev/null
  echo "  ✅ Dangling images pruned"
  echo ""
fi

# ==========================================
# PHASE 4 — Ollama
# ==========================================
if [ "$REMOVE_OLLAMA" = true ]; then
  echo "=== Removing Ollama ==="
  echo ""
  if command -v ollama &>/dev/null || [ -f /usr/local/bin/ollama ] || systemctl list-units --type=service 2>/dev/null | grep -q ollama; then
    sudo systemctl stop ollama 2>/dev/null
    sudo systemctl disable ollama 2>/dev/null
    sudo rm -f /usr/local/bin/ollama /usr/bin/ollama
    sudo rm -rf /usr/share/ollama /home/ollama
    rm -rf ~/.ollama
    sudo rm -f /etc/systemd/system/ollama.service
    sudo systemctl daemon-reload 2>/dev/null
    sudo userdel ollama 2>/dev/null
    sudo groupdel ollama 2>/dev/null
    echo "  ✅ Ollama removed (binary, models, service, user)"
  else
    echo "    — Ollama not found"
  fi
  echo ""
fi

# ==========================================
# PHASE 5 — Docker Engine
# ==========================================
if [ "$REMOVE_DOCKER_ENGINE" = true ]; then
  echo "=== Removing Docker Engine ==="
  echo ""
  if command -v docker &>/dev/null; then
    sudo apt remove -y docker.io docker-compose-v2 2>/dev/null
    sudo apt remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null
    sudo apt autoremove -y 2>/dev/null
    sudo rm -rf /var/lib/docker /var/lib/containerd /etc/docker
    sudo rm -f /var/run/docker.sock
    echo "  ✅ Docker removed"
  else
    echo "    — Docker not found"
  fi
  echo ""
fi

# ==========================================
# PHASE 6 — Python RAG venv
# ==========================================
if [ "$REMOVE_RAG_VENV" = true ]; then
  echo "=== Removing Python RAG venv ==="
  echo ""
  if [ -d "$BASE_PATH/vector-db/venv" ]; then
    rm -rf "$BASE_PATH/vector-db/venv"
    echo "  ✅ RAG venv removed"
  else
    echo "    — venv not found"
  fi
  echo ""
fi

# ==========================================
# PHASE 7 — Runtime Data
# ==========================================
if [ "$REMOVE_RUNTIME" = true ]; then
  echo "=== Removing Runtime Data ==="
  echo ""
  sudo rm -rf "$BASE_PATH/postgres"
  sudo rm -rf "$BASE_PATH/dashboard"
  sudo rm -rf "$BASE_PATH/docker"
  # Remove n8n runtime but preserve workflow JSONs for future installs
  find "$BASE_PATH/n8n" -mindepth 1 -maxdepth 1 ! -name "workflows" -exec rm -rf {} \; 2>/dev/null
  rm -rf "$BASE_PATH/logs"/*
  rm -rf "$BASE_PATH/backups"/*
  echo "  ✅ Runtime data cleaned (postgres/, dashboard/, docker/, n8n/ [workflows kept], logs/)"
  echo ""
fi

# ==========================================
# PHASE 8 — System Cleanup
# ==========================================
if [ "$REMOVE_SYSTEM_CLEANUP" = true ]; then
  echo "=== System Cleanup ==="
  echo ""
  sudo apt autoremove -y 2>/dev/null
  sudo apt clean 2>/dev/null
  echo "  ✅ System cleaned"
  echo ""
fi

# ==========================================
# SUMMARY
# ==========================================
echo "========================================"
echo "         UNINSTALL COMPLETE"
echo "========================================"
echo ""
echo "  Removed:"
[ "$REMOVE_CONTAINERS" = true ] && echo "    ✅ Docker containers"
[ "$REMOVE_VOLUMES" = true ] && echo "    ✅ Docker volumes"
[ "$REMOVE_IMAGES" = true ] && echo "    ✅ Docker images"
[ "$REMOVE_OLLAMA" = true ] && echo "    ✅ Ollama"
[ "$REMOVE_DOCKER_ENGINE" = true ] && echo "    ✅ Docker engine"
[ "$REMOVE_RAG_VENV" = true ] && echo "    ✅ Python RAG venv"
[ "$REMOVE_RUNTIME" = true ] && echo "    ✅ Runtime data"
[ "$REMOVE_SYSTEM_CLEANUP" = true ] && echo "    ✅ System cleanup"
echo ""
echo "  Preserved:"
echo "    ✅ admin/, system/, clients/, vault/"
echo "    ✅ n8n/workflows/ (workflow JSONs)"
echo "    ✅ vector-db/*.py, *.sql"
echo "    ✅ .env"
if [ "$backup_choice" = "y" ] || [ "$backup_choice" = "Y" ]; then
  echo "    ✅ Backup: $BACKUP_TARGET"
fi
echo ""
echo "  To reinstall: sudo ./admin/install.sh"
echo ""
