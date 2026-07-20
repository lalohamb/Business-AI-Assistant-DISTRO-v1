#!/bin/bash
# ==========================================
# update_containers.sh — Pull latest images and recreate containers
# ==========================================
# Preserves all data volumes. Only recreates containers with newer images.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$BASE_PATH/.env"

# Docker wrapper
_docker() {
  if docker info &>/dev/null; then
    docker "$@"
  else
    sudo docker "$@"
  fi
}

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ .env not found at $ENV_FILE"
  exit 1
fi

source "$ENV_FILE"

echo "=== Update Containers ==="
echo ""

CONTAINERS=(
  "postgres|pgvector/pgvector:pg16"
  "openwebui|ghcr.io/open-webui/open-webui:main"
  "n8n|n8nio/n8n"
)

UPDATED=0

for entry in "${CONTAINERS[@]}"; do
  NAME="${entry%%|*}"
  IMAGE="${entry##*|}"

  echo "── $NAME ($IMAGE)"

  # Pull latest
  OLD_DIGEST=$(_docker inspect --format '{{.Image}}' "$NAME" 2>/dev/null)
  echo "  Pulling latest..."
  _docker pull "$IMAGE" --quiet 2>/dev/null

  # Check if container exists
  if ! _docker ps -a --filter "name=^${NAME}$" --format "{{.Names}}" | grep -q "^${NAME}$"; then
    echo "  Container does not exist. Skipping (run install.sh to create)."
    echo ""
    continue
  fi

  # Compare digests
  NEW_DIGEST=$(_docker inspect --format '{{.Id}}' "$IMAGE" 2>/dev/null)
  if [ "$OLD_DIGEST" = "$NEW_DIGEST" ] && [ -n "$OLD_DIGEST" ]; then
    echo "  Already up to date."
    echo ""
    continue
  fi

  # Get current container config for recreation
  echo "  New image available. Recreating..."

  case "$NAME" in
    postgres)
      _docker stop postgres && _docker rm postgres
      _docker run -d --name postgres \
        --restart unless-stopped \
        -e POSTGRES_USER=${PG_USER:-admin} \
        -e POSTGRES_PASSWORD=${PG_PASSWORD:-strongpassword} \
        -e POSTGRES_DB=${PG_DATABASE:-businessassistant} \
        -p 127.0.0.1:5432:5432 \
        -v "$BASE_PATH/postgres/data:/var/lib/postgresql/data" \
        "$IMAGE"
      ;;
    openwebui)
      _docker stop openwebui && _docker rm openwebui
      _docker run -d --name openwebui \
        --restart unless-stopped \
        --add-host=host.docker.internal:host-gateway \
        -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
        -p 3000:8080 \
        -v "$BASE_PATH/dashboard:/app/backend/data" \
        "$IMAGE"
      # Reinstall psycopg2 (required by RAG filter, lost on container recreation)
      echo "  Waiting for OpenWebUI to be ready..."
      for i in $(seq 1 30); do
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null)
        if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "303" ]; then
          break
        fi
        sleep 3
      done
      echo "  Installing psycopg2-binary..."
      _docker exec openwebui pip install psycopg2-binary --quiet 2>/dev/null
      if _docker exec openwebui python3 -c "import psycopg2" 2>/dev/null; then
        echo "  ✅ psycopg2 verified."
      else
        echo "  ⚠️  psycopg2 install failed. RAG filter will attempt auto-install on first load."
      fi
      ;;
    n8n)
      _docker stop n8n && _docker rm n8n
      _docker run -d --name n8n \
        --restart unless-stopped \
        --add-host=host.docker.internal:host-gateway \
        -p 5678:5678 \
        -v "$BASE_PATH/n8n:/home/node/.n8n" \
        "$IMAGE"
      ;;
  esac

  echo "  ✅ $NAME recreated with latest image."
  UPDATED=$((UPDATED + 1))
  echo ""
done

echo "── Summary: $UPDATED container(s) updated."
