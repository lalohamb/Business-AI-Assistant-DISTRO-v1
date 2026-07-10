# COMMANDS.md

## Business Assistant Box — Complete Command Reference

---

## Admin Scripts

```bash
# Install / reinstall the full system
sudo ./admin/install.sh

# Uninstall (interactive — selective or full)
./admin/uninstall.sh

# Switch active client
./admin/switch_client.sh <client-name>
./admin/switch_client.sh <client-name> --force

# Validate a client vault before switching
./admin/test_client.sh <client-name>

# List available clients
./admin/list_clients.sh

# Show current active client
./admin/current_client.sh

# Validate .env configuration
./admin/validate_env.sh

# Validate client structure
./admin/validate_client.sh <client-name>

# Post-install verification
./admin/post_install_verify.sh

# Post-install client setup
./admin/post_install_client_setup.sh

# Configure n8n workflows
./admin/configure_n8n.sh

# Configure RAG pipeline
./admin/configure_rag_pipeline.sh

# Customize n8n UI
./admin/customize_ui_n8n.sh

# Pre-install checks
./admin/pre_check.sh

# Package for distribution
./admin/zip_package.sh
```

---

## Docker

```bash
# View all running containers
docker ps

# View all containers (including stopped)
docker ps -a

# Start all services
docker compose up -d

# Stop all services
docker compose down

# Restart all services
docker compose restart

# Restart a single service
docker restart postgres
docker restart openwebui
docker restart n8n

# View container logs
docker logs postgres
docker logs n8n
docker logs openwebui

# Follow logs in real-time
docker logs -f n8n
docker logs -f postgres --tail 50

# Inspect a container
docker inspect postgres

# Check resource usage
docker stats

# Remove stopped containers
docker container prune -f

# Remove unused images
docker image prune -f

# Remove unused volumes (CAUTION: deletes data)
docker volume prune -f

# List volumes
docker volume ls

# Execute command inside container
docker exec -it postgres bash
docker exec -it n8n sh
docker exec -it openwebui bash
```

---

## PostgreSQL (pgvector)

```bash
# Connect to database
docker exec -it postgres psql -U admin -d businessassistant

# Connect with specific database
docker exec -it postgres psql -U admin -d postgres
```

### Inside psql:

```sql
-- List databases
\l

-- Connect to business assistant database
\c businessassistant

-- List tables
\dt

-- View RAG documents indexed
SELECT client_name, COUNT(*) FROM rag_documents GROUP BY client_name;

-- View RAG chunks per client
SELECT client_name, COUNT(*) FROM rag_chunks GROUP BY client_name;

-- View indexed files for active client
SELECT title, source_path, created_at FROM rag_documents WHERE client_name = 'law-office' ORDER BY created_at DESC;

-- Search chunks by keyword
SELECT title, chunk_text FROM rag_chunks WHERE client_name = 'law-office' AND chunk_text ILIKE '%settlement%' LIMIT 5;

-- Check vector extension
SELECT * FROM pg_extension WHERE extname = 'vector';

-- View table sizes
SELECT relname, pg_size_pretty(pg_total_relation_size(relid)) FROM pg_catalog.pg_statio_user_tables ORDER BY pg_total_relation_size(relid) DESC;

-- Delete all data for a client
DELETE FROM rag_chunks WHERE client_name = 'demo-company';
DELETE FROM rag_documents WHERE client_name = 'demo-company';

-- Reset entire RAG database
TRUNCATE rag_chunks CASCADE;
TRUNCATE rag_documents CASCADE;

-- Rebuild index after large changes
REINDEX INDEX idx_chunks_embedding;

-- Exit psql
\q
```

---

## Ollama

```bash
# Check if Ollama is running
curl http://localhost:11434/api/tags
systemctl status ollama

# Start / stop / restart Ollama service
sudo systemctl start ollama
sudo systemctl stop ollama
sudo systemctl restart ollama

# List installed models
ollama list

# Pull a model
ollama pull qwen3:14b
ollama pull nomic-embed-text

# Remove a model
ollama rm qwen3:14b

# Run interactive chat
ollama run qwen3:14b

# Test embedding endpoint
curl http://localhost:11434/api/embeddings -d '{"model":"nomic-embed-text","prompt":"test"}'

# Test generation endpoint
curl http://localhost:11434/api/generate -d '{"model":"qwen3:14b","prompt":"Hello","stream":false}'

# Show model info
ollama show qwen3:14b

# Check disk usage of models
du -sh ~/.ollama/models/

# View Ollama logs
journalctl -u ollama -f
journalctl -u ollama --since "1 hour ago"
```

---

## RAG / Vector Database

```bash
# Activate the venv
source vector-db/venv/bin/activate

# Or run directly with venv python
cd vector-db

# Index the active client's vault into pgvector
./venv/bin/python index_vault.py

# Query the RAG database
./venv/bin/python query_vault.py "What services do we offer?"
./venv/bin/python query_vault.py "Who is the owner?"

# Index a specific client (override env)
ACTIVE_CLIENT=acme-roofing ./venv/bin/python index_vault.py

# Install/update RAG dependencies
./venv/bin/pip install psycopg2-binary python-dotenv requests

# Recreate the venv from scratch
rm -rf vector-db/venv
python3 -m venv vector-db/venv
./vector-db/venv/bin/pip install psycopg2-binary python-dotenv requests

# Apply schema (first-time or reset)
docker exec -it postgres psql -U admin -d businessassistant -f /dev/stdin < vector-db/schema.sql
```

---

## n8n (Workflow Engine)

```bash
# Access n8n UI
# Browser: http://localhost:5678

# View logs
docker logs n8n
docker logs -f n8n --tail 100

# Restart n8n
docker restart n8n

# List workflows via API
curl -s -H "Authorization: Bearer $N8N_API_KEY" http://localhost:5678/api/v1/workflows | jq '.data[].name'

# Activate a workflow via API
curl -X PATCH -H "Authorization: Bearer $N8N_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"active": true}' \
  http://localhost:5678/api/v1/workflows/<workflow-id>

# Export all workflows
curl -s -H "Authorization: Bearer $N8N_API_KEY" http://localhost:5678/api/v1/workflows > n8n/workflows/export.json

# Import a workflow
curl -X POST -H "Authorization: Bearer $N8N_API_KEY" \
  -H "Content-Type: application/json" \
  -d @n8n/workflows/my-workflow.json \
  http://localhost:5678/api/v1/workflows

# Check n8n health
curl -s http://localhost:5678/healthz

# Enter n8n container shell
docker exec -it n8n sh

# View n8n environment
docker exec n8n env | grep -i n8n
```

---

## Open WebUI

```bash
# Access Open WebUI
# Browser: http://localhost:3000

# View logs
docker logs openwebui
docker logs -f openwebui --tail 100

# Restart
docker restart openwebui

# Check health
curl -s http://localhost:3000/api/health

# Enter container shell
docker exec -it openwebui bash
```

---

## Obsidian

```bash
# Launch Obsidian (if installed as AppImage)
obsidian &

# Vault location
# ~/.business-assistant-box/business-assistant-box/current-client

# Check what current-client points to
ls -la current-client

# Force vault reload (from within Obsidian)
# Ctrl+P → "Reload app without saving"

# Check for duplicate files in vault
find current-client -name "*.md" | sort | uniq -d
```

---

## System Health

```bash
# CPU usage
htop
top -bn1 | head -20

# Memory
free -h

# Disk space
df -h
du -sh ~/.business-assistant-box/

# Disk usage by component
du -sh ~/.business-assistant-box/business-assistant-box/postgres/
du -sh ~/.business-assistant-box/business-assistant-box/vector-db/venv/
du -sh ~/.ollama/

# Check all service ports
ss -tlnp | grep -E '(5432|5678|3000|11434)'

# Check if services are responding
curl -s http://localhost:11434/api/tags > /dev/null && echo "Ollama: UP" || echo "Ollama: DOWN"
curl -s http://localhost:5678/healthz > /dev/null && echo "n8n: UP" || echo "n8n: DOWN"
curl -s http://localhost:3000/api/health > /dev/null && echo "WebUI: UP" || echo "WebUI: DOWN"
docker exec postgres pg_isready -U admin > /dev/null 2>&1 && echo "Postgres: UP" || echo "Postgres: DOWN"
```

---

## Client Management

```bash
# List all clients
ls clients/ | grep -v templates

# Create a new client from template
cp -r clients/templates clients/<new-client-name>

# Switch client (full process)
./admin/switch_client.sh <client-name>
cd vector-db && ./venv/bin/python index_vault.py

# Check active client
grep ACTIVE_CLIENT .env

# Compare client to template (check customization)
diff clients/<client-name>/CLIENT_PROFILE.md clients/templates/CLIENT_PROFILE.md

# Count indexed chunks per client
docker exec -it postgres psql -U admin -d businessassistant -c "SELECT client_name, COUNT(*) FROM rag_chunks GROUP BY client_name;"
```

---

## Backup & Recovery

```bash
# Manual backup of client data
tar czf ~/bab-clients-backup-$(date +%Y%m%d).tar.gz clients/

# Backup entire system
tar czf ~/bab-full-backup-$(date +%Y%m%d).tar.gz \
  --exclude='postgres' --exclude='venv' --exclude='docker' \
  ~/.business-assistant-box/business-assistant-box/

# Backup PostgreSQL database
docker exec postgres pg_dump -U admin businessassistant > backups/db-$(date +%Y%m%d).sql

# Restore PostgreSQL database
docker exec -i postgres psql -U admin -d businessassistant < backups/db-YYYYMMDD.sql

# Backup n8n workflows
curl -s -H "Authorization: Bearer $N8N_API_KEY" http://localhost:5678/api/v1/workflows > backups/workflows-$(date +%Y%m%d).json
```

---

## Emergency Commands

```bash
# Stop everything
docker compose down
sudo systemctl stop ollama

# Start everything
sudo systemctl start ollama
docker compose up -d

# Restart everything
sudo systemctl restart ollama
docker compose restart

# Kill a stuck container
docker kill <container-name>
docker rm -f <container-name>

# Reset PostgreSQL (DESTROYS ALL DATA)
docker stop postgres
docker rm postgres
docker volume rm $(docker volume ls -q | grep postgres)
docker compose up -d postgres
docker exec -i postgres psql -U admin -d businessassistant < vector-db/schema.sql

# Reset n8n (DESTROYS WORKFLOW STATE)
docker stop n8n
docker rm n8n
docker compose up -d n8n

# Full system restart (nuclear option)
docker compose down
sudo systemctl restart ollama
docker compose up -d
cd vector-db && ./venv/bin/python index_vault.py
```

---

## Environment & Configuration

```bash
# View current config
cat .env

# Edit config
nano .env

# Validate config
./admin/validate_env.sh

# Check license
cat .license

# Test embedding service connectivity
curl -s http://localhost:11434/api/embeddings -d '{"model":"nomic-embed-text","prompt":"test"}' | head -c 100
```

---

## Rules

- Only run commands you understand
- Always back up before destructive operations
- Test in selective mode before full uninstall
- Re-index RAG after any client switch or vault content change
- Restart Obsidian after switching clients
