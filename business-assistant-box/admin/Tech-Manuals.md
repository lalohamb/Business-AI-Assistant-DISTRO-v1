# Tech Manuals — Manual Installation Guide

> How to download and install each component of Business Assistant Box **without** `install.sh`.

---

## System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| OS | Ubuntu 22.04+ LTS | Ubuntu 24.04 LTS |
| RAM | 32 GB | 64 GB+ |
| Storage | 500 GB SSD | 1 TB NVMe SSD |
| GPU | NVIDIA 8 GB VRAM | NVIDIA 12+ GB VRAM |
| CPU | 4 cores | 8+ cores |
| Network | Internet for initial setup | Static IP for services |

---

## 1. Ubuntu System Packages

```bash
sudo apt --fix-broken install -y
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git nano vim unzip htop net-tools jq python3 python3-full python3-venv python3-pip
```

---

## 2. NVIDIA Drivers + CUDA

**Required for:** Ollama GPU inference

```bash
# Check if drivers are already installed
nvidia-smi

# If not installed:
sudo apt install -y nvidia-driver-535
sudo reboot

# Verify after reboot
nvidia-smi
nvidia-smi -L   # List GPUs with UUIDs
```

**Download (manual):** https://www.nvidia.com/en-us/drivers/

---

## 3. Docker

**Download:** https://docs.docker.com/engine/install/ubuntu/

```bash
# Option A: apt
sudo apt install -y docker.io docker-compose-v2

# Option B: official script
curl -fsSL https://get.docker.com | sh

# Post-install
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker
sudo systemctl enable docker.socket
sudo systemctl enable docker.service
sudo systemctl start docker

# Verify
docker --version
docker compose version
docker info
```

---

## 4. PostgreSQL + pgvector

**Image:** `pgvector/pgvector:pg16` (NOT `postgres:16` — that lacks pgvector)
**Docker Hub:** https://hub.docker.com/r/pgvector/pgvector

```bash
mkdir -p ~/.business-assistant-box/business-assistant-box/postgres/data

docker run -d --name postgres \
  --restart unless-stopped \
  -e POSTGRES_USER=admin \
  -e POSTGRES_PASSWORD=strongpassword \
  -e POSTGRES_DB=businessassistant \
  -p 5432:5432 \
  -v ~/.business-assistant-box/business-assistant-box/postgres/data:/var/lib/postgresql/data \
  pgvector/pgvector:pg16

# Wait for ready
docker exec -i postgres pg_isready -U admin

# Enable pgvector extension
docker exec -i postgres psql -U admin businessassistant -c "CREATE EXTENSION IF NOT EXISTS vector;"

# Verify
docker exec -i postgres psql -U admin businessassistant -c "SELECT extname FROM pg_extension WHERE extname='vector';"
```

### Deploy RAG Schema

```bash
docker exec -i postgres psql -U admin businessassistant << 'EOF'
CREATE TABLE IF NOT EXISTS rag_documents (
  id SERIAL PRIMARY KEY,
  client_name VARCHAR(255) NOT NULL,
  source_path TEXT NOT NULL,
  title VARCHAR(500),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS rag_chunks (
  id SERIAL PRIMARY KEY,
  document_id INTEGER REFERENCES rag_documents(id) ON DELETE CASCADE,
  client_name VARCHAR(255) NOT NULL,
  source_path TEXT NOT NULL,
  title VARCHAR(500),
  chunk_text TEXT NOT NULL,
  embedding vector(768),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chunks_client ON rag_chunks(client_name);
CREATE INDEX IF NOT EXISTS idx_chunks_embedding ON rag_chunks USING ivfflat (embedding vector_cosine_ops);
EOF
```

**Credentials:** admin / strongpassword / businessassistant / port 5432

---

## 5. Ollama

**Download:** https://ollama.com/download

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

### Configure for Docker Access

Ollama must listen on `0.0.0.0` so Docker containers (Open WebUI) can reach it:

```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf << 'EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
Environment="OLLAMA_NUM_PARALLEL=2"
Environment="OLLAMA_MAX_LOADED_MODELS=3"
EOF

sudo systemctl daemon-reload
sudo systemctl restart ollama
```

### Dual-GPU Setup (Pin Ollama to Inference GPU)

If you have a separate display GPU, pin Ollama to the high-VRAM card:

```bash
# Find GPU UUIDs
nvidia-smi -L
# Example: GPU 1: NVIDIA GeForce RTX 2060 SUPER (UUID: GPU-6ef1a4a6-8765-e0ba-add8-57c7d161abb5)

# Add to override.conf
sudo tee /etc/systemd/system/ollama.service.d/override.conf << 'EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
Environment="OLLAMA_NUM_PARALLEL=2"
Environment="OLLAMA_MAX_LOADED_MODELS=3"
Environment="CUDA_VISIBLE_DEVICES=GPU-6ef1a4a6-8765-e0ba-add8-57c7d161abb5"
EOF

sudo systemctl daemon-reload
sudo systemctl restart ollama
```

### Pull Models

```bash
# Primary chat model
ollama pull qwen3:14b

# Embedding model (REQUIRED for RAG)
ollama pull nomic-embed-text

# Optional models
ollama pull llama3.2
ollama pull qwen2.5-coder:7b

# Verify
ollama list
```

| Model | Size | Purpose |
|-------|------|---------|
| qwen3:14b | 9.3 GB | Primary chat LLM |
| nomic-embed-text | 274 MB | Embeddings (768 dims) |
| llama3.2 | 2 GB | Lightweight fallback (good for 8GB VRAM) |
| qwen2.5-coder:7b | 4.7 GB | Code tasks |

### Verify

```bash
systemctl status ollama
curl http://localhost:11434/api/version
ss -tlnp | grep 11434   # Should show 0.0.0.0:11434
ollama ps                # Shows loaded models + GPU/CPU split
```

---

## 6. Open WebUI

**Source:** https://github.com/open-webui/open-webui
**Image:** `ghcr.io/open-webui/open-webui:main`

```bash
mkdir -p ~/.business-assistant-box/business-assistant-box/dashboard

docker run -d --name openwebui \
  --restart unless-stopped \
  --add-host=host.docker.internal:host-gateway \
  -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
  -p 3000:8080 \
  -v ~/.business-assistant-box/business-assistant-box/dashboard:/app/backend/data \
  ghcr.io/open-webui/open-webui:main

# Install psycopg2 inside container (required for RAG filter)
docker exec openwebui pip install psycopg2-binary
```

**Access:** http://localhost:3000 — first user becomes admin.

### Verify Ollama Connectivity from Container

```bash
docker exec openwebui curl -sf http://host.docker.internal:11434/api/version
```

---

## 7. n8n

**Source:** https://github.com/n8n-io/n8n
**Image:** `n8nio/n8n`
**Docs:** https://docs.n8n.io/hosting/installation/docker/

```bash
mkdir -p ~/.business-assistant-box/business-assistant-box/n8n
sudo chown -R 1000:1000 ~/.business-assistant-box/business-assistant-box/n8n

docker run -d --name n8n \
  --restart unless-stopped \
  --add-host=host.docker.internal:host-gateway \
  -p 5678:5678 \
  -v ~/.business-assistant-box/business-assistant-box/n8n:/home/node/.n8n \
  n8nio/n8n
```

**Access:** http://localhost:5678 — first user becomes owner.

**Post-setup:**
1. Create owner account
2. Settings → API → Create API Key
3. Set `N8N_API_KEY=<your-key>` in `.env`
4. Create PostgreSQL credential: Host `host.docker.internal`, Port 5432, User `admin`, Password `strongpassword`, DB `businessassistant`

---

## 8. Python RAG Environment

```bash
cd ~/.business-assistant-box/business-assistant-box/vector-db

python3 -m venv venv
source venv/bin/activate

pip install --upgrade pip
pip install psycopg2-binary python-dotenv requests
pip install llama-index llama-index-readers-file
pip install pymupdf python-docx openpyxl beautifulsoup4

# Verify
python -c "import psycopg2, dotenv, requests"

deactivate
```

### Index Vault

```bash
./vector-db/venv/bin/python3 ./vector-db/index_vault.py
```

### Query Vault

```bash
./vector-db/venv/bin/python3 ./vector-db/query_vault.py "What services do we offer?"
```

---

## 9. Obsidian

**Download:** https://obsidian.md/download

```bash
# Ubuntu/Debian (.deb)
OBSIDIAN_VERSION="1.8.9"
wget "https://github.com/obsidianmd/obsidian-releases/releases/download/v${OBSIDIAN_VERSION}/obsidian_${OBSIDIAN_VERSION}_amd64.deb" -O /tmp/obsidian.deb
sudo dpkg -i /tmp/obsidian.deb
sudo apt install -f -y
rm /tmp/obsidian.deb

# Launch and open vault
obsidian &
# Select "Open folder as vault" → ~/.business-assistant-box/business-assistant-box/current-client
```

**Releases page:** https://github.com/obsidianmd/obsidian-releases/releases

---

## 10. OpenClaw (Optional)

**Download:** https://get.openclaw.com

```bash
curl -fsSL https://get.openclaw.com | sh
openclaw --version
```

---

## 11. RAG Filter Registration (Post-Install)

After all services are running, register the RAG filter in Open WebUI:

```bash
# Option A: Use the script (prompts for WebUI admin credentials)
./admin/configure_rag_pipeline.sh

# Option B: Direct SQLite injection (bypasses API auth)
docker exec -i openwebui python3 -c "
import sqlite3, json, sys
code = sys.stdin.read()
conn = sqlite3.connect('/app/backend/data/webui.db')
cur = conn.cursor()
meta = json.dumps({'description': 'RAG filter', 'manifest': {'title': 'Business Knowledge RAG', 'author': 'NativeBlackBox', 'version': '1.2.0', 'type': 'filter'}})
cur.execute('SELECT id FROM function WHERE id=?', ('business_knowledge_rag',))
if cur.fetchone():
    cur.execute('UPDATE function SET content=?, meta=?, is_active=1, is_global=1 WHERE id=?', (code, meta, 'business_knowledge_rag'))
else:
    cur.execute('INSERT INTO function (id, user_id, name, type, content, meta, is_active, is_global, updated_at, created_at) VALUES (?, ?, ?, ?, ?, ?, 1, 1, datetime(\"now\"), datetime(\"now\"))', ('business_knowledge_rag', 'system', 'Business Knowledge RAG', 'filter', code, meta))
conn.commit()
conn.close()
print('OK')
" < dashboard/functions/business_rag_filter.py

# Restart to load
docker restart openwebui
```

---

## Service Summary

| Service | Port | Runtime | Image/Binary | Start Command |
|---------|------|---------|--------------|---------------|
| PostgreSQL | 5432 | Docker | pgvector/pgvector:pg16 | `docker start postgres` |
| Ollama | 11434 | systemd | ollama binary | `sudo systemctl start ollama` |
| Open WebUI | 3000 | Docker | ghcr.io/open-webui/open-webui:main | `docker start openwebui` |
| n8n | 5678 | Docker | n8nio/n8n | `docker start n8n` |
| Obsidian | — | Native | .deb package | `obsidian &` |
| OpenClaw | — | Native | binary | `openclaw` |

---

## Verify Everything

```bash
# All containers running
docker ps

# Ollama responding
curl -s http://localhost:11434/api/version

# Open WebUI responding
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000

# n8n responding
curl -s -o /dev/null -w "%{http_code}" http://localhost:5678

# pgvector extension active
docker exec -i postgres psql -U admin businessassistant -c "SELECT extname FROM pg_extension WHERE extname='vector';"

# RAG chunks indexed
docker exec -i postgres psql -U admin businessassistant -c "SELECT client_name, COUNT(*) FROM rag_chunks GROUP BY client_name;"

# Ollama GPU usage
nvidia-smi
ollama ps

# All ports listening
ss -tlnp | grep -E '(5432|5678|3000|11434)'
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Docker permission denied | `sudo usermod -aG docker $USER` then logout/login |
| Ollama only on 127.0.0.1 | Add `OLLAMA_HOST=0.0.0.0` to systemd override, restart |
| WebUI can't see Ollama models | Container needs `--add-host=host.docker.internal:host-gateway` |
| pgvector CREATE EXTENSION fails | Wrong image — use `pgvector/pgvector:pg16` not `postgres:16` |
| Embedding timeout | Increase to 120s; on 8GB VRAM use smaller chat model to avoid GPU swap |
| RAG returns no results | Check column names: `chunk_text`, `source_path`, `client_name` |
| CUDA out of memory | Use smaller model or check `CUDA_VISIBLE_DEVICES` UUID |
| n8n permission error | `sudo chown -R 1000:1000` on n8n data directory |
| PostgreSQL restart loop | Remove `postgres/data/*` and recreate container |
