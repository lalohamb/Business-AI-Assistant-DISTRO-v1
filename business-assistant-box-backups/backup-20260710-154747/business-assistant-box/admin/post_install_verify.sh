#!/bin/bash

# ==========================================
# POST-INSTALL VERIFICATION & REPAIR
# ==========================================
# Tests all service connectivity and fixes common misconfigurations.
# Safe to run multiple times. Repairs are idempotent.
#
# Usage:
#   ./admin/post_install_verify.sh
#   DRY_RUN=true ./admin/post_install_verify.sh   # show what would be fixed
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
DRY_RUN=${DRY_RUN:-false}
ENV_FILE="$BASE_PATH/.env"

PASS=0
FAIL=0
FIXED=0
WARNINGS=()

# Load .env
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

# Docker wrapper
_docker() {
  if docker info &>/dev/null; then
    docker "$@"
  else
    sudo docker "$@"
  fi
}

pass() { echo "  ✅ $1"; ((PASS++)); }
fail() { echo "  ❌ $1"; ((FAIL++)); }
fixed() { echo "  🔧 $1"; ((FIXED++)); }
warn() { echo "  ⚠️  $1"; WARNINGS+=("$1"); }

echo "========================================"
echo "   POST-INSTALL VERIFICATION & REPAIR"
echo "========================================"
echo ""
echo "  DRY_RUN:   $DRY_RUN"
echo "  BASE_PATH: $BASE_PATH"
echo ""

# ==========================================
# TEST 1 — Ollama Running
# ==========================================
echo "=== TEST 1 — Ollama Service ==="

if systemctl is-active ollama &>/dev/null; then
  pass "Ollama service is active"
else
  fail "Ollama service is not running"
  if [ "$DRY_RUN" = false ]; then
    echo "  Attempting repair: sudo systemctl start ollama"
    sudo systemctl start ollama
    sleep 3
    if systemctl is-active ollama &>/dev/null; then
      fixed "Ollama started successfully"
    else
      fail "Could not start Ollama"
    fi
  fi
fi
echo ""

# ==========================================
# TEST 2 — Ollama Listen Address
# ==========================================
echo "=== TEST 2 — Ollama Listen Address ==="

# Use ss without -p (process info requires matching user) and also check via curl
OLLAMA_LISTEN=$(ss -tln 2>/dev/null | grep ":11434")
if echo "$OLLAMA_LISTEN" | grep -q "0.0.0.0:11434\|\*:11434"; then
  pass "Ollama listening on 0.0.0.0:11434 (accessible to Docker)"
elif echo "$OLLAMA_LISTEN" | grep -q "127.0.0.1:11434"; then
  # Double-check: can Docker bridge reach it?
  DOCKER_GW=$(ip route show dev docker0 2>/dev/null | awk '/src/ {print $NF}' | head -1)
  if [ -n "$DOCKER_GW" ] && curl -s --max-time 3 "http://${DOCKER_GW}:11434/api/version" 2>/dev/null | grep -q "version"; then
    pass "Ollama on 127.0.0.1:11434 but reachable via Docker bridge ($DOCKER_GW)"
  else
    fail "Ollama only listening on 127.0.0.1:11434 (Docker containers cannot connect)"
    if [ "$DRY_RUN" = false ]; then
      echo "  Attempting repair: configure OLLAMA_HOST=0.0.0.0 in systemd service"
      OLLAMA_SERVICE="/etc/systemd/system/ollama.service"
      if [ -f "$OLLAMA_SERVICE" ]; then
        sudo sed -i '/OLLAMA_HOST/d' "$OLLAMA_SERVICE"
        sudo sed -i '/^\[Service\]/a Environment="OLLAMA_HOST=0.0.0.0"' "$OLLAMA_SERVICE"
        sudo systemctl daemon-reload
        sudo systemctl restart ollama
        sleep 3
        if ss -tln 2>/dev/null | grep -q "0.0.0.0:11434"; then
          fixed "Ollama now listening on 0.0.0.0:11434"
        else
          fail "Repair attempted but Ollama still on 127.0.0.1"
        fi
      else
        fail "Cannot find $OLLAMA_SERVICE to repair"
      fi
    fi
  fi
else
  # Port not in ss output — but API might still respond (process ownership mismatch in ss)
  if curl -s --max-time 3 http://localhost:11434/api/version 2>/dev/null | grep -q "version"; then
    pass "Ollama API reachable on port 11434 (ss detection skipped due to permissions)"
  else
    fail "Ollama not detected on port 11434"
  fi
fi
echo ""

# ==========================================
# TEST 3 — Ollama API Responsive
# ==========================================
echo "=== TEST 3 — Ollama API ==="

OLLAMA_VERSION=$(curl -s --max-time 5 http://localhost:11434/api/version 2>/dev/null)
if echo "$OLLAMA_VERSION" | grep -q "version"; then
  pass "Ollama API responding: $OLLAMA_VERSION"
else
  fail "Ollama API not responding on localhost:11434"
fi
echo ""

# ==========================================
# TEST 4 — Ollama Models Available
# ==========================================
echo "=== TEST 4 — Ollama Models ==="

MODELS=$(ollama list 2>/dev/null | tail -n +2)
if [ -n "$MODELS" ]; then
  pass "Models available:"
  echo "$MODELS" | while read -r line; do echo "       $line"; done
else
  fail "No models found. Run: ollama pull qwen3:14b"
fi
echo ""

# ==========================================
# TEST 5 — Open WebUI Container
# ==========================================
echo "=== TEST 5 — Open WebUI Container ==="

if _docker ps --filter "name=^openwebui$" --filter "status=running" --format "{{.Names}}" 2>/dev/null | grep -q "^openwebui$"; then
  pass "openwebui container is running"

  # Check if it has the right env/config
  WEBUI_OLLAMA_URL=$(_docker inspect openwebui --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep "OLLAMA_BASE_URL" | cut -d= -f2)
  if [ -n "$WEBUI_OLLAMA_URL" ]; then
    pass "OLLAMA_BASE_URL set to: $WEBUI_OLLAMA_URL"
  else
    warn "OLLAMA_BASE_URL not set in container env. WebUI may use default (localhost inside container = unreachable)"
  fi

  # Check --add-host
  EXTRA_HOSTS=$(_docker inspect openwebui --format '{{range .HostConfig.ExtraHosts}}{{println .}}{{end}}' 2>/dev/null)
  if echo "$EXTRA_HOSTS" | grep -q "host.docker.internal"; then
    pass "host.docker.internal mapped to host gateway"
  else
    warn "host.docker.internal not configured. Container may not reach host services."
  fi
else
  fail "openwebui container is NOT running"
fi
echo ""

# ==========================================
# TEST 6 — WebUI ↔ Ollama Connectivity
# ==========================================
echo "=== TEST 6 — WebUI → Ollama Connectivity ==="

# Need to auth first or use the proxy endpoint
WEBUI_OLLAMA_TEST=$(curl -s --max-time 10 http://localhost:3000/ollama/api/version 2>/dev/null)
if echo "$WEBUI_OLLAMA_TEST" | grep -q "version"; then
  pass "WebUI can reach Ollama: $WEBUI_OLLAMA_TEST"
elif echo "$WEBUI_OLLAMA_TEST" | grep -q "could not connect"; then
  fail "WebUI CANNOT connect to Ollama"
  echo "       Response: $WEBUI_OLLAMA_TEST"

  if [ "$DRY_RUN" = false ]; then
    echo ""
    echo "  Attempting repair: recreate openwebui with --add-host and OLLAMA_BASE_URL..."
    _docker stop openwebui 2>/dev/null
    _docker rm openwebui 2>/dev/null

    _docker run -d --name openwebui \
      --restart unless-stopped \
      --add-host=host.docker.internal:host-gateway \
      -e OLLAMA_BASE_URL="http://host.docker.internal:11434" \
      -p 3000:8080 \
      -v "$BASE_PATH/dashboard:/app/backend/data" \
      ghcr.io/open-webui/open-webui:main

    echo "  Waiting for WebUI to start..."
    sleep 15

    RETRY=$(curl -s --max-time 10 http://localhost:3000/ollama/api/version 2>/dev/null)
    if echo "$RETRY" | grep -q "version"; then
      fixed "WebUI now connected to Ollama: $RETRY"
    else
      fail "Repair attempted but WebUI still cannot reach Ollama."
      echo "       Ensure Ollama is on 0.0.0.0:11434 (Test 2)"
    fi
  fi
elif echo "$WEBUI_OLLAMA_TEST" | grep -q "Not authenticated"; then
  warn "WebUI requires auth for this endpoint. Log in and check Settings → Connections."
else
  fail "Unexpected response from WebUI: $WEBUI_OLLAMA_TEST"
fi
echo ""

# ==========================================
# TEST 7 — Models Visible in WebUI
# ==========================================
echo "=== TEST 7 — Models in WebUI ==="

WEBUI_MODELS=$(curl -s --max-time 10 http://localhost:3000/ollama/api/tags 2>/dev/null)
if echo "$WEBUI_MODELS" | grep -q "qwen3\|gemma3"; then
  pass "Models visible through WebUI proxy"
  echo "$WEBUI_MODELS" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    for m in d.get('models',[]):
        print(f\"       - {m['name']}\")
except: pass
" 2>/dev/null
elif echo "$WEBUI_MODELS" | grep -q "Not authenticated"; then
  # Auth blocks WebUI proxy — verify models directly via Ollama API
  OLLAMA_MODELS=$(curl -s --max-time 5 http://localhost:11434/api/tags 2>/dev/null)
  if echo "$OLLAMA_MODELS" | grep -q "qwen3\|gemma3"; then
    pass "Models confirmed via Ollama API (WebUI requires auth, connectivity verified in Test 6)"
    echo "$OLLAMA_MODELS" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    for m in d.get('models',[]):
        print(f\"       - {m['name']}\")
except: pass
" 2>/dev/null
  else
    warn "WebUI requires auth and Ollama model check inconclusive"
  fi
elif echo "$WEBUI_MODELS" | grep -q "could not connect"; then
  fail "Cannot list models — WebUI not connected to Ollama (see Test 6)"
else
  warn "Could not verify models via API. Check WebUI manually at http://localhost:3000"
fi
echo ""

# ==========================================
# TEST 8 — PostgreSQL
# ==========================================
echo "=== TEST 8 — PostgreSQL ==="

if _docker ps --filter "name=^postgres$" --filter "status=running" --format "{{.Names}}" 2>/dev/null | grep -q "^postgres$"; then
  pass "postgres container is running"
  if _docker exec -i postgres pg_isready -U admin 2>/dev/null | grep -q "accepting"; then
    pass "PostgreSQL accepting connections"
  else
    fail "PostgreSQL not accepting connections"
  fi
else
  fail "postgres container is NOT running"
fi
echo ""

# ==========================================
# TEST 9 — n8n
# ==========================================
echo "=== TEST 9 — n8n ==="

if _docker ps --filter "name=^n8n$" --filter "status=running" --format "{{.Names}}" 2>/dev/null | grep -q "^n8n$"; then
  pass "n8n container is running"
  N8N_HTTP=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:5678 2>/dev/null)
  if [ "$N8N_HTTP" = "200" ] || [ "$N8N_HTTP" = "302" ]; then
    pass "n8n responding on port 5678"
  else
    warn "n8n returned HTTP $N8N_HTTP"
  fi
else
  fail "n8n container is NOT running"
fi
echo ""

# ==========================================
# TEST 9B — Obsidian
# ==========================================
echo "=== TEST 9B — Obsidian ==="

if [ "$OBSIDIAN_ENABLED" = "true" ]; then
  if command -v obsidian &>/dev/null; then
    pass "Obsidian installed (native)"
  else
    fail "Obsidian not installed"
    echo "  Install with: wget https://github.com/obsidianmd/obsidian-releases/releases/download/v1.8.9/obsidian_1.8.9_amd64.deb -O /tmp/obsidian.deb && sudo dpkg -i /tmp/obsidian.deb"
  fi

  # Check vault directory exists and has .md files
  VAULT_PATH="$BASE_PATH/current-client"
  if [ -d "$VAULT_PATH" ]; then
    MD_COUNT=$(find "$VAULT_PATH" -name "*.md" 2>/dev/null | wc -l)
    if [ "$MD_COUNT" -gt 0 ]; then
      pass "Vault directory has $MD_COUNT .md files: $VAULT_PATH"
    else
      warn "Vault directory exists but contains no .md files"
    fi
  else
    fail "Vault directory not found: $VAULT_PATH"
  fi
else
  echo "  Obsidian disabled in .env. Skipping."
fi
echo ""

# ==========================================
# TEST 10 — Port Summary
# ==========================================
echo "=== TEST 10 — Port Summary ==="
echo ""
printf "  %-20s %-10s %-10s\n" "SERVICE" "PORT" "STATUS"
printf "  %-20s %-10s %-10s\n" "-------" "----" "------"

for svc_port in "Ollama:11434" "Open WebUI:3000" "n8n:5678" "PostgreSQL:5432"; do
  SVC=$(echo "$svc_port" | cut -d: -f1)
  PORT=$(echo "$svc_port" | cut -d: -f2)
  if ss -tlnp 2>/dev/null | grep -q ":${PORT} "; then
    printf "  %-20s %-10s %-10s\n" "$SVC" "$PORT" "✅ OPEN"
  else
    printf "  %-20s %-10s %-10s\n" "$SVC" "$PORT" "❌ CLOSED"
  fi
done
echo ""

# ==========================================
# SUMMARY
# ==========================================
echo "========================================"
echo "         VERIFICATION SUMMARY"
echo "========================================"
echo ""
echo "  Passed:  $PASS"
echo "  Failed:  $FAIL"
echo "  Fixed:   $FIXED"
echo "  Warnings: ${#WARNINGS[@]}"
echo ""

if [ ${#WARNINGS[@]} -gt 0 ]; then
  echo "  Warnings:"
  for w in "${WARNINGS[@]}"; do
    echo "    ⚠️  $w"
  done
  echo ""
fi

if [ $FAIL -eq 0 ]; then
  echo "  ✅ ALL TESTS PASSED — System is ready."
  echo ""
  echo "  Open WebUI:  http://localhost:3000"
  echo "  n8n:         http://localhost:5678"
  echo "  PostgreSQL:  localhost:5432"
  echo "  Obsidian:    obsidian & (native app)"
  echo ""
  exit 0
else
  echo "  ❌ $FAIL TEST(S) FAILED"
  echo ""
  echo "  Common fixes:"
  echo "    - Ollama not on 0.0.0.0: sudo sed -i '/OLLAMA_HOST/d' /etc/systemd/system/ollama.service && sudo sed -i '/\\[Service\\]/a Environment=\"OLLAMA_HOST=0.0.0.0\"' /etc/systemd/system/ollama.service && sudo systemctl daemon-reload && sudo systemctl restart ollama"
  echo "    - WebUI can't reach Ollama: sudo docker stop openwebui && sudo docker rm openwebui && sudo docker run -d --name openwebui --restart unless-stopped --add-host=host.docker.internal:host-gateway -e OLLAMA_BASE_URL=http://host.docker.internal:11434 -p 3000:8080 -v $BASE_PATH/dashboard:/app/backend/data ghcr.io/open-webui/open-webui:main"
  echo ""
  exit 1
fi
