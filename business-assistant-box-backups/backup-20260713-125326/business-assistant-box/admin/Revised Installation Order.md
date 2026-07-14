# Revised Installation Order

## Phase 1 — Ubuntu Server

**Recommended Hardware:**
- AMD 8845HS
- 32GB RAM
- 1TB NVMe SSD

### Install Ubuntu 24.04 LTS

Update:
```bash
sudo apt update
sudo apt upgrade -y
sudo reboot
```

Install tools:
```bash
sudo apt install -y \
  curl \
  wget \
  git \
  nano \
  vim \
  unzip \
  htop \
  net-tools \
  jq
```

## Phase 2 — Docker

Install Docker:
```bash
curl -fsSL https://get.docker.com | sh
```

Add user:
```bash
sudo usermod -aG docker $USER
```

Logout/Login.

Verify:
```bash
docker ps
```

Install Compose:
```bash
docker compose version
```

## Phase 3 — Directory Structure

Create:
```bash
mkdir -p ~/business-assistant-box
cd ~/business-assistant-box
```

Structure:
```
business-assistant-box/
├── docker/
├── openclaw/
├── n8n/
├── postgres/
├── webui/
├── rag/
├── vault/
├── clients/
└── backups/
```

## Phase 4 — PostgreSQL

Create `docker-compose.yml`:
```yaml
postgres:
  image: postgres:16
  container_name: postgres
  restart: unless-stopped
  environment:
    POSTGRES_USER: admin
    POSTGRES_PASSWORD: strongpassword
    POSTGRES_DB: businessassistant
  ports:
    - "5432:5432"
  volumes:
    - ./postgres:/var/lib/postgresql/data
```

Start:
```bash
docker compose up -d
```

Verify:
```bash
docker ps
```

## Phase 5 — Ollama

Install:
```bash
curl -fsSL https://ollama.com/install.sh | sh
```

Start:
```bash
ollama serve
```

New terminal — install model:
```bash
ollama pull qwen3:14b
```

Optional:
```bash
ollama pull gemma3:12b
```

Verify:
```bash
ollama list
```

## Phase 6 — OpenClaw

Install OpenClaw according to the current release documentation and initialize a workspace.

Create:
```
~/business-assistant-box/workspace/
├── AGENTS.md
├── POLICIES.md
├── IDENTITY.md
├── MEMORY.md
├── CLIENT_PROFILE.md
├── PROCEDURES/
├── MEMORY/
└── OUTPUTS/
```

Use the files we already built.

## Phase 7 — Open WebUI

Docker:
```yaml
openwebui:
  image: ghcr.io/open-webui/open-webui:main
  container_name: openwebui
  restart: unless-stopped
  ports:
    - "3000:8080"
  volumes:
    - ./webui:/app/backend/data
```

Start:
```bash
docker compose up -d
```

Access: `http://SERVER_IP:3000`

Connect Ollama — Provider: `http://host.docker.internal:11434` or local IP.

## Phase 8 — n8n

Add:
```yaml
n8n:
  image: n8nio/n8n
  container_name: n8n
  restart: unless-stopped
  ports:
    - "5678:5678"
  volumes:
    - ./n8n:/home/node/.n8n
```

Start:
```bash
docker compose up -d
```

Access: `http://SERVER_IP:5678`

Create admin account.

## Phase 9 — Demo Client

```
clients/demo-company/
├── CLIENT_PROFILE.md
├── FAQ.md
├── BUSINESS_KNOWLEDGE.md
├── PROCEDURES/
│   ├── EMAIL.md
│   ├── CALENDAR.md
│   └── DOCUMENTS.md
├── MEMORY/
│   ├── LEARNED_PATTERNS.md
│   └── OPEN_TASKS.md
└── OUTPUTS/
```

Now OpenClaw has a clean business brain.

## Phase 10 — RAG (pgvector)

Install pgvector:
```bash
docker exec -it postgres bash
```

Connect:
```sql
psql -U admin businessassistant
```

Enable:
```sql
CREATE EXTENSION vector;
```

Create tables:
- `documents`
- `chunks`
- `embeddings`

## Phase 11 — Index Obsidian Vault

Install:
```bash
python3 -m venv venv
source venv/bin/activate

pip install llama-index
pip install llama-index-readers-file
pip install psycopg2-binary
```

Create `index_obsidian.py`

Purpose:
```
Read Vault → Chunk Documents → Generate Embeddings → Store In PostgreSQL
```

Run nightly via `cron` or `n8n`.

## Phase 12 — Dashboard

**Version 1:** Use Open WebUI.

**Version 2:** Build custom with:
- Next.js
- Tailwind
- ShadCN

Dashboard features:
- 📧 Check Email
- 📅 Calendar
- 📄 Create Document
- 👥 Customer Intake
- 📊 Daily Briefing
- 🎤 Ask Assistant

## Phase 13 — Email Integration

- For Microsoft 365: Azure App Registration
- For Google: Google OAuth

Store credentials in Secrets Manager or `.env`.

> Never inside markdown.

## Phase 14 — First Demo Dataset

Before showing a client, load:
- Company Website
- Employee Handbook
- FAQ
- Sample Customer Emails
- Product Catalog
- Sample Financial Reports
- Policies
- Procedures

Into: **Obsidian Vault** → Index.

Now when someone asks "What does our company do?" the answer comes from:

```
Vault → RAG → AI
```

Not from model memory.
