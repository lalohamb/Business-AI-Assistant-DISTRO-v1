#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="${BASE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
ENV_FILE="$BASE/.env"
SYMLINK="$BASE/current-client"

# Read ACTIVE_CLIENT from .env
if [ -f "$ENV_FILE" ]; then
  ACTIVE_CLIENT=$(grep "^ACTIVE_CLIENT=" "$ENV_FILE" | cut -d'=' -f2)
else
  ACTIVE_CLIENT=""
fi

echo "Current client: ${ACTIVE_CLIENT:-<not set>}"
echo "Symlink:        $SYMLINK"

if [ -L "$SYMLINK" ]; then
  TARGET=$(readlink -f "$SYMLINK")
  echo "Target:         $TARGET"
else
  echo "Target:         <symlink does not exist>"
fi
