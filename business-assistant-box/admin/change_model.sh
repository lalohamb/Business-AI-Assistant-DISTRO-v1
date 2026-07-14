#!/bin/bash
# ==========================================
# change_model.sh — Switch active Ollama chat model
# ==========================================
# Updates OLLAMA_MODEL in .env and pulls the model if not already available.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$BASE_PATH/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ .env not found at $ENV_FILE"
  exit 1
fi

CURRENT_MODEL=$(grep "^OLLAMA_MODEL=" "$ENV_FILE" | cut -d= -f2)

echo "=== Change Chat Model ==="
echo ""
echo "  Current model: ${CURRENT_MODEL:-not set}"
echo ""

# Show installed models
echo "  Installed models:"
ollama list 2>/dev/null | tail -n +2 | awk '{print "    " $1}'
echo ""

# Accept argument or prompt
if [ -n "$1" ]; then
  NEW_MODEL="$1"
else
  echo "  Common options:"
  echo "    qwen3:14b       — 14B, good balance (16GB RAM)"
  echo "    qwen3:8b        — 8B, faster (8GB RAM)"
  echo "    qwen3:30b       — 30B, best quality (32GB RAM)"
  echo "    llama3.1:8b     — Meta 8B, fast general-purpose"
  echo ""
  read -p "  New model name: " NEW_MODEL
fi

if [ -z "$NEW_MODEL" ]; then
  echo "❌ No model specified."
  exit 1
fi

if [ "$NEW_MODEL" = "$CURRENT_MODEL" ]; then
  echo "⚠️  Already set to $NEW_MODEL. No changes made."
  exit 0
fi

# Pull if not installed
if ! ollama list 2>/dev/null | grep -q "^$NEW_MODEL"; then
  echo ""
  echo "  Pulling $NEW_MODEL (this may take a while)..."
  if ! ollama pull "$NEW_MODEL"; then
    echo "❌ Failed to pull $NEW_MODEL."
    exit 1
  fi
fi

# Update .env
sed -i "s|^OLLAMA_MODEL=.*|OLLAMA_MODEL=$NEW_MODEL|" "$ENV_FILE"
echo ""
echo "  ✅ OLLAMA_MODEL set to $NEW_MODEL"
echo ""
echo "  Open WebUI will use this model when selected in the model dropdown."
echo "  To set as default in Open WebUI: Admin → Settings → Models → Default."
