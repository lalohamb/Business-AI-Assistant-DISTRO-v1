#!/bin/bash

# ==========================================
# LICENSE GATE
# ==========================================
# Checks license tier and enforces client limits.
#
# License tiers:
#   single   — 1 client only (code license default)
#   multi    — unlimited clients (cloud/rig/upgraded license)
#
# License file: $BASE_PATH/.license
# Format:
#   TIER=single
#   LICENSE_KEY=BAB-XXXX-XXXX-XXXX
#   ISSUED=2025-06-01
#   EXPIRES=2026-06-01
#
# Usage in other scripts:
#   source "$BASE/admin/license_check.sh"
#   check_license            # exits if expired
#   check_client_limit       # exits if single-tier and >1 client exists
#   can_add_client           # returns 0 if allowed, 1 if not
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="${BASE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
LICENSE_FILE="$BASE/.license"

# Defaults (no license file = single-client trial)
LICENSE_TIER="single"
LICENSE_KEY=""
LICENSE_EXPIRES=""
MAX_CLIENTS=1

# Load license
if [ -f "$LICENSE_FILE" ]; then
  set -a
  source "$LICENSE_FILE"
  set +a
  LICENSE_TIER="${TIER:-single}"
  LICENSE_KEY="${LICENSE_KEY:-}"
  LICENSE_EXPIRES="${EXPIRES:-}"
fi

# Set limits by tier
case "$LICENSE_TIER" in
  single)  MAX_CLIENTS=1 ;;
  multi)   MAX_CLIENTS=999 ;;
  *)       MAX_CLIENTS=1 ;;
esac

count_active_clients() {
  local count=0
  for d in "$BASE/clients"/*/; do
    [ -d "$d" ] || continue
    local name=$(basename "$d")
    [ "$name" = "templates" ] && continue
    count=$((count + 1))
  done
  echo "$count"
}

check_license() {
  # Check expiration
  if [ -n "$LICENSE_EXPIRES" ]; then
    local today=$(date +%Y-%m-%d)
    if [[ "$today" > "$LICENSE_EXPIRES" ]]; then
      echo "❌ LICENSE EXPIRED on $LICENSE_EXPIRES"
      echo "   Renew at: [YOUR_RENEWAL_URL]"
      echo "   Current tier: $LICENSE_TIER"
      exit 1
    fi
  fi

  # No license file at all = trial mode
  if [ ! -f "$LICENSE_FILE" ]; then
    echo "⚠️  No license file found. Running in single-client trial mode."
    echo "   To upgrade: [YOUR_PURCHASE_URL]"
  fi
}

check_client_limit() {
  local current=$(count_active_clients)

  if [ "$current" -ge "$MAX_CLIENTS" ] && [ "$LICENSE_TIER" = "single" ]; then
    echo ""
    echo "❌ CLIENT LIMIT REACHED"
    echo ""
    echo "   License tier:    $LICENSE_TIER"
    echo "   Max clients:     $MAX_CLIENTS"
    echo "   Current clients: $current"
    echo ""
    echo "   Your license allows 1 client only."
    echo "   To serve multiple clients, upgrade to multi-client:"
    echo "     - Cloud plan: \$149-799/month (we manage everything)"
    echo "     - Multi-client license: \$4,500/year"
    echo "     - Custom rig with multi-client: \$4,500+"
    echo ""
    echo "   Upgrade: [YOUR_UPGRADE_URL]"
    exit 1
  fi
}

can_add_client() {
  local current=$(count_active_clients)
  if [ "$current" -ge "$MAX_CLIENTS" ]; then
    return 1
  fi
  return 0
}

print_license_info() {
  echo "  License tier:    $LICENSE_TIER"
  echo "  Max clients:     $MAX_CLIENTS"
  echo "  Current clients: $(count_active_clients)"
  if [ -n "$LICENSE_EXPIRES" ]; then
    echo "  Expires:         $LICENSE_EXPIRES"
  fi
  if [ -n "$LICENSE_KEY" ]; then
    echo "  Key:             ${LICENSE_KEY:0:8}..."
  fi
}
