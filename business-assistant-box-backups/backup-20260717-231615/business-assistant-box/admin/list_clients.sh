#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="${BASE:-$(cd "$SCRIPT_DIR/.." && pwd)}"

echo "Available clients:"
for d in "$BASE/clients"/*/; do
  [ -d "$d" ] || continue
  name=$(basename "$d")
  [ "$name" = "templates" ] && continue
  [[ "$name" == .* ]] && continue
  echo "  - $name"
done
