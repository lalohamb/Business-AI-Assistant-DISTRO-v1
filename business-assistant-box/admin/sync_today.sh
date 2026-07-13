#!/bin/bash
# sync_today.sh — Copy n8n-generated TODAY.md to client MEMORY and re-index
# Run via cron: 35 6 * * 1-5 /home/ubuntu/.business-assistant-box/business-assistant-box/admin/sync_today.sh

BASE_PATH="/home/ubuntu/.business-assistant-box/business-assistant-box"
ACTIVE_CLIENT="${ACTIVE_CLIENT:-insurance-agency}"
SOURCE="$BASE_PATH/n8n/storage/TODAY.md"
DEST="$BASE_PATH/clients/$ACTIVE_CLIENT/MEMORY/TODAY.md"

if [ -f "$SOURCE" ]; then
  cp "$SOURCE" "$DEST"
  echo "$(date): Synced TODAY.md to $DEST"

  # Re-index to pick up the new content
  cd "$BASE_PATH"
  ./vector-db/venv/bin/python3 ./vector-db/index_vault.py > /dev/null 2>&1
  echo "$(date): Re-indexed"
else
  echo "$(date): No TODAY.md found at $SOURCE — workflow may not have run yet"
fi
