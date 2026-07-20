#!/bin/bash

# ==========================================
# SAFETY CONTROLS
# ==========================================
# This script is read-only. It does not modify any files.
# Safe to run anytime against any client.
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="${BASE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
ENV_FILE="$BASE/.env"
MIN_FAQ_ENTRIES=10
MIN_CONTENT_LINES=5

if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-http://localhost:11434}"
EMBEDDING_PROVIDER="${EMBEDDING_PROVIDER:-ollama}"

# Parse arguments
if [ -z "$1" ]; then
  echo "Usage: ./test_client.sh <client-name>"
  echo ""
  echo "Tests a client workspace for production readiness."
  echo "Does NOT modify any files."
  exit 1
fi

CLIENT="$1"
CLIENT_PATH="$BASE/clients/$CLIENT"

PASS=true
WARNINGS=0
FAILURES=0

echo "========================================"
echo "   CLIENT READINESS TEST"
echo "========================================"
echo ""
echo "  Client:  $CLIENT"
echo "  Path:    $CLIENT_PATH"
echo ""

if [ ! -d "$CLIENT_PATH" ]; then
  echo "❌ Client directory not found."
  exit 1
fi

# ==========================================
# TEST 1 — File Structure
# ==========================================
echo "=== TEST 1 — File Structure ==="
echo ""

STRUCT_PASS=true

for f in BUSINESS_PROFILE.md OWNER_PREFERENCES.md BUSINESS_KNOWLEDGE.md FAQ.md; do
  if [ -f "$CLIENT_PATH/$f" ]; then
    echo "  [✓] $f"
  else
    echo "  [✗] $f MISSING"
    STRUCT_PASS=false
    ((FAILURES++))
  fi
done

for f in PROCEDURES/EMAIL.md PROCEDURES/CALENDAR.md PROCEDURES/DAILY_BRIEFING.md PROCEDURES/DOCUMENTS.md; do
  if [ -f "$CLIENT_PATH/$f" ]; then
    echo "  [✓] $f"
  else
    echo "  [✗] $f MISSING"
    STRUCT_PASS=false
    ((FAILURES++))
  fi
done

for f in MEMORY/CUSTOMER_RULES.md MEMORY/VENDOR_RULES.md MEMORY/LEARNED_PATTERNS.md MEMORY/OPEN_TASKS.md MEMORY/TODAY.md; do
  if [ -f "$CLIENT_PATH/$f" ]; then
    echo "  [✓] $f"
  else
    echo "  [✗] $f MISSING"
    ((WARNINGS++))
  fi
done

for d in OUTPUTS/drafts OUTPUTS/reports OUTPUTS/summaries; do
  if [ -d "$CLIENT_PATH/$d" ]; then
    echo "  [✓] $d/"
  else
    echo "  [✗] $d/ MISSING"
    ((WARNINGS++))
  fi
done

if [ "$STRUCT_PASS" = false ]; then
  PASS=false
fi
echo ""

# ==========================================
# TEST 2 — Content Quality
# ==========================================
echo "=== TEST 2 — Content Quality ==="
echo ""
echo "  Checking files have real content (more than just placeholders)..."
echo ""

check_content() {
  local file="$1"
  local label="$2"
  local min_lines="${3:-$MIN_CONTENT_LINES}"

  if [ ! -f "$file" ]; then
    return
  fi

  # Count non-empty, non-header, non-placeholder lines
  local content_lines
  content_lines=$(grep -v "^#" "$file" | grep -v "^---" | grep -v "^$" | grep -v "^<" | grep -v "^\*$" | wc -l)

  # Check for placeholder indicators
  local has_placeholders
  has_placeholders=$(grep -ciE "(enter |<.*>|\bTBD\b|\bTODO\b)" "$file" 2>/dev/null || true)
  has_placeholders=${has_placeholders:-0}

  if [ "$content_lines" -lt "$min_lines" ]; then
    echo "  ⚠️  $label: Only $content_lines content lines (minimum: $min_lines)"
    ((WARNINGS++))
  elif [ "$has_placeholders" -gt 3 ]; then
    echo "  ⚠️  $label: Has $has_placeholders placeholder markers — may not be filled in"
    ((WARNINGS++))
  else
    echo "  [✓] $label: $content_lines content lines"
  fi
}

check_content "$CLIENT_PATH/BUSINESS_PROFILE.md" "BUSINESS_PROFILE" 10
check_content "$CLIENT_PATH/OWNER_PREFERENCES.md" "OWNER_PREFERENCES" 5
check_content "$CLIENT_PATH/BUSINESS_KNOWLEDGE.md" "BUSINESS_KNOWLEDGE" 15
check_content "$CLIENT_PATH/FAQ.md" "FAQ" 20
check_content "$CLIENT_PATH/PROCEDURES/EMAIL.md" "PROCEDURES/EMAIL" 10
check_content "$CLIENT_PATH/PROCEDURES/CALENDAR.md" "PROCEDURES/CALENDAR" 5
check_content "$CLIENT_PATH/PROCEDURES/DAILY_BRIEFING.md" "PROCEDURES/DAILY_BRIEFING" 5
check_content "$CLIENT_PATH/PROCEDURES/DOCUMENTS.md" "PROCEDURES/DOCUMENTS" 5
check_content "$CLIENT_PATH/MEMORY/TODAY.md" "MEMORY/TODAY" 3

echo ""

# ==========================================
# TEST 3 — FAQ Entry Count
# ==========================================
echo "=== TEST 3 — FAQ Entries ==="
echo ""

if [ -f "$CLIENT_PATH/FAQ.md" ]; then
  FAQ_COUNT=$(grep -c "^Q:" "$CLIENT_PATH/FAQ.md" 2>/dev/null || echo "0")
  echo -n "  FAQ questions found: $FAQ_COUNT (minimum: $MIN_FAQ_ENTRIES) "
  if [ "$FAQ_COUNT" -ge "$MIN_FAQ_ENTRIES" ]; then
    echo "✅"
  else
    echo "⚠️"
    ((WARNINGS++))
  fi
else
  echo "  ❌ FAQ.md missing"
  ((FAILURES++))
  PASS=false
fi

echo ""

# ==========================================
# TEST 4 — Company Identity Check
# ==========================================
echo "=== TEST 4 — Company Identity ==="
echo ""

if [ -f "$CLIENT_PATH/BUSINESS_PROFILE.md" ]; then
  # Check if company name is filled in
  COMPANY_NAME=$(grep "Company Name" "$CLIENT_PATH/BUSINESS_PROFILE.md" | head -1 | sed 's/.*Company Name[[:space:]]*:[[:space:]]*//' | tr -d '[:space:]')
  if [ -n "$COMPANY_NAME" ] && [ "$COMPANY_NAME" != ":" ] && [ "$COMPANY_NAME" != "" ]; then
    echo "  [✓] Company name appears set"
  else
    echo "  ⚠️  Company name may be empty — check BUSINESS_PROFILE.md"
    ((WARNINGS++))
  fi

  # Check if industry is filled
  INDUSTRY=$(grep "Industry" "$CLIENT_PATH/BUSINESS_PROFILE.md" | head -1 | sed 's/.*Industry[[:space:]]*:[[:space:]]*//' | tr -d '[:space:]')
  if [ -n "$INDUSTRY" ] && [ "$INDUSTRY" != ":" ] && [ "$INDUSTRY" != "" ]; then
    echo "  [✓] Industry appears set"
  else
    echo "  ⚠️  Industry may be empty"
    ((WARNINGS++))
  fi
else
  echo "  ❌ BUSINESS_PROFILE.md missing"
  ((FAILURES++))
  PASS=false
fi

echo ""

# ==========================================
# TEST 5 — RAG Indexability (Dry Check)
# ==========================================
echo "=== TEST 5 — RAG Indexability ==="
echo ""

# Count indexable files
INDEXABLE_FILES=$(find "$CLIENT_PATH" -name "*.md" -o -name "*.txt" | wc -l)
echo "  Indexable files (.md/.txt): $INDEXABLE_FILES"

if [ "$INDEXABLE_FILES" -lt 5 ]; then
  echo "  ⚠️  Very few files to index — RAG may have limited knowledge"
  ((WARNINGS++))
else
  echo "  [✓] Sufficient files for RAG indexing"
fi

# Check total content size
TOTAL_CHARS=$(find "$CLIENT_PATH" -name "*.md" -exec cat {} + 2>/dev/null | wc -c)
echo "  Total content: $TOTAL_CHARS characters"

if [ "$TOTAL_CHARS" -lt 1000 ]; then
  echo "  ⚠️  Very little content — AI will have limited context"
  ((WARNINGS++))
elif [ "$TOTAL_CHARS" -lt 5000 ]; then
  echo "  ⚠️  Minimal content — consider adding more business knowledge"
  ((WARNINGS++))
else
  echo "  [✓] Content volume adequate"
fi

echo ""

# Check embedding service reachable
echo -n "  Embedding service ($EMBEDDING_PROVIDER): "
if [ "$EMBEDDING_PROVIDER" = "ollama" ]; then
  EMBED_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${OLLAMA_BASE_URL}/api/tags" 2>/dev/null || echo "000")
  if [ "$EMBED_CODE" = "200" ]; then
    echo "✅ Reachable"
  else
    echo "⚠️  Not reachable — indexing will fail"
    ((WARNINGS++))
  fi
else
  echo "Configured (verify API key manually)"
fi

echo ""

# ==========================================
# TEST 6 — Comparison to Templates
# ==========================================
echo "=== TEST 6 — Differentiation from Templates ==="
echo ""

TEMPLATE_PATH="$BASE/clients/templates"
IDENTICAL=0
CHECKED=0

if [ -d "$TEMPLATE_PATH" ]; then
  for f in BUSINESS_PROFILE.md OWNER_PREFERENCES.md BUSINESS_KNOWLEDGE.md FAQ.md; do
    if [ -f "$CLIENT_PATH/$f" ] && [ -f "$TEMPLATE_PATH/$f" ]; then
      ((CHECKED++))
      if diff -q "$CLIENT_PATH/$f" "$TEMPLATE_PATH/$f" > /dev/null 2>&1; then
        echo "  ⚠️  $f is identical to template (not customized)"
        ((IDENTICAL++))
        ((WARNINGS++))
      else
        echo "  [✓] $f has been customized"
      fi
    fi
  done

  if [ "$IDENTICAL" -eq 0 ]; then
    echo "  [✓] All checked files differ from templates"
  elif [ "$IDENTICAL" -eq "$CHECKED" ]; then
    echo ""
    echo "  ❌ ALL files are still template copies — client has no real content"
    PASS=false
    ((FAILURES++))
  fi
else
  echo "  (templates/ not found — skipping comparison)"
fi

echo ""

# ==========================================
# RESULT
# ==========================================
echo "========================================"
echo "         TEST RESULT"
echo "========================================"
echo ""
echo "  Client:    $CLIENT"
echo "  Failures:  $FAILURES"
echo "  Warnings:  $WARNINGS"
echo ""

if [ "$PASS" = false ]; then
  echo "  ❌ NOT READY — Critical issues must be fixed before switching."
  echo ""
  echo "  Fix:"
  echo "    - Ensure all required files exist"
  echo "    - Add real business content (not just placeholders)"
  echo "    - Customize files from template defaults"
  exit 1
elif [ "$WARNINGS" -gt 5 ]; then
  echo "  ⚠️  MARGINAL — Client has many warnings. Review before switching."
  echo ""
  echo "  Recommend:"
  echo "    - Fill in empty fields in BUSINESS_PROFILE.md"
  echo "    - Add at least $MIN_FAQ_ENTRIES Q&A pairs to FAQ.md"
  echo "    - Add real business knowledge"
  echo "    - Run: ./admin/switch_client.sh $CLIENT --force"
  exit 0
elif [ "$WARNINGS" -gt 0 ]; then
  echo "  ⚠️  ACCEPTABLE — Minor gaps. Safe to switch."
  echo ""
  echo "  Run: ./admin/switch_client.sh $CLIENT"
  exit 0
else
  echo "  ✅ READY — Client is fully prepared for production."
  echo ""
  echo "  Run: ./admin/switch_client.sh $CLIENT"
  exit 0
fi
