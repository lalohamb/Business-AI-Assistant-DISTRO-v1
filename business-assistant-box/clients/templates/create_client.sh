#!/usr/bin/env bash
# create_client.sh — Scaffold a new client folder from templates
# Usage: bash clients/templates/create_client.sh <client-slug>
#
# Example: bash clients/templates/create_client.sh my-plumbing-company

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLIENTS_DIR="$PROJECT_ROOT/clients"
TEMPLATE_DIR="$CLIENTS_DIR/templates"

# --- Validate input ---
if [ $# -lt 1 ]; then
    echo "Usage: $0 <client-slug>"
    echo ""
    echo "  client-slug: lowercase name with hyphens (e.g. my-plumbing-company)"
    echo ""
    echo "Example:"
    echo "  $0 acme-consulting"
    exit 1
fi

CLIENT_SLUG="$1"

# Validate slug format
if [[ ! "$CLIENT_SLUG" =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$ ]]; then
    echo "ERROR: Client slug must be lowercase alphanumeric with hyphens."
    echo "       Got: '$CLIENT_SLUG'"
    echo "       Example: my-business-name"
    exit 1
fi

TARGET_DIR="$CLIENTS_DIR/$CLIENT_SLUG"

if [ -d "$TARGET_DIR" ]; then
    echo "ERROR: Client folder already exists: $TARGET_DIR"
    exit 1
fi

# --- Create folder structure ---
echo "Creating client: $CLIENT_SLUG"

mkdir -p "$TARGET_DIR"/{DOCUMENTS/{company-documents,contracts,financials,handbooks,uploads,websites},MEMORY,OUTPUTS/{drafts,reports,summaries},PROCEDURES}

# --- Copy template files ---
for f in BUSINESS_PROFILE.md BUSINESS_KNOWLEDGE.md FAQ.md OWNER_PREFERENCES.md DAILY_BRIEFING.md; do
    if [ -f "$TEMPLATE_DIR/$f" ]; then
        cp "$TEMPLATE_DIR/$f" "$TARGET_DIR/$f"
    fi
done

# Copy MEMORY files
for f in TODAY.md OPEN_TASKS.md CUSTOMER_RULES.md VENDOR_RULES.md LEARNED_PATTERNS.md; do
    if [ -f "$TEMPLATE_DIR/MEMORY/$f" ]; then
        cp "$TEMPLATE_DIR/MEMORY/$f" "$TARGET_DIR/MEMORY/$f"
    fi
done

# Copy PROCEDURES files
for f in CALENDAR.md CUSTOMER_INTAKE.md DAILY_BRIEFING.md DOCUMENTS.md EMAIL.md; do
    if [ -f "$TEMPLATE_DIR/PROCEDURES/$f" ]; then
        cp "$TEMPLATE_DIR/PROCEDURES/$f" "$TARGET_DIR/PROCEDURES/$f"
    fi
done

# --- Done ---
echo ""
echo "✅ Client created: $TARGET_DIR"
echo ""
echo "Next steps:"
echo "  1. Edit the files in $TARGET_DIR/ (start with BUSINESS_PROFILE.md)"
echo "  2. Add documents to $TARGET_DIR/DOCUMENTS/"
echo "  3. Set active client:  sed -i 's/^ACTIVE_CLIENT=.*/ACTIVE_CLIENT=$CLIENT_SLUG/' $PROJECT_ROOT/.env"
echo "  4. Index:  source $PROJECT_ROOT/../venv/bin/activate && python3 $PROJECT_ROOT/vector-db/index_vault.py"
echo ""
echo "See clients/templates/NEW_CLIENT_SETUP.md for detailed instructions."
