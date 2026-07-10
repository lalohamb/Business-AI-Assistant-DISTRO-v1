#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="${BASE:-$(cd "$SCRIPT_DIR/.." && pwd)}"

if [ -z "$1" ]; then
  echo "Usage: ./validate_client.sh <client-name>"
  exit 1
fi

CLIENT="$1"
CLIENT_PATH="$BASE/clients/$CLIENT"
VALID=true

if [ ! -d "$CLIENT_PATH" ]; then
  echo "❌ Client directory not found: $CLIENT_PATH"
  exit 1
fi

echo "Validating client: $CLIENT"
echo ""

# Root files
for f in CLIENT_PROFILE.md OWNER_PREFERENCES.md BUSINESS_KNOWLEDGE.md FAQ.md; do
  if [ -f "$CLIENT_PATH/$f" ]; then
    echo "  [✓] $f"
  else
    echo "  [✗] $f MISSING"
    VALID=false
  fi
done

# Procedures
echo "  PROCEDURES:"
for f in EMAIL.md CALENDAR.md DAILY_BRIEFING.md DOCUMENTS.md; do
  if [ -f "$CLIENT_PATH/PROCEDURES/$f" ]; then
    echo "    [✓] $f"
  else
    echo "    [✗] $f MISSING"
    VALID=false
  fi
done

# Memory
echo "  MEMORY:"
for f in CUSTOMER_RULES.md VENDOR_RULES.md LEARNED_PATTERNS.md OPEN_TASKS.md TODAY.md; do
  if [ -f "$CLIENT_PATH/MEMORY/$f" ]; then
    echo "    [✓] $f"
  else
    echo "    [✗] $f MISSING"
    VALID=false
  fi
done

# Outputs
echo "  OUTPUTS:"
for d in drafts reports summaries; do
  if [ -d "$CLIENT_PATH/OUTPUTS/$d" ]; then
    echo "    [✓] $d"
  else
    echo "    [✗] $d MISSING"
    VALID=false
  fi
done

echo ""
if [ "$VALID" = true ]; then
  echo "✅ Client '$CLIENT' is valid."
  exit 0
else
  echo "❌ Client '$CLIENT' has missing files."
  exit 1
fi
