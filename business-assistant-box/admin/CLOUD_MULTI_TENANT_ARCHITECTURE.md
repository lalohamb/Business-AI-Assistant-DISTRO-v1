# CLOUD_MULTI_TENANT_ARCHITECTURE.md

# Business Assistant Box — Multi-Tenant Cloud Deployment (Digital Ocean + Coolify)

## Strategy

Deploy one **Coolify** instance on a Digital Ocean droplet. Each client gets its own isolated Docker Compose stack managed through Coolify's UI. Shared LLM service handles embeddings/inference for all clients.

---

## Infrastructure Layout

```
┌─────────────────────────────────────────────────────┐
│  Digital Ocean Droplet (8 CPU / 32GB RAM)            │
│  Coolify Self-Hosted PaaS                           │
│                                                     │
│  ┌─────────────────────────────────────────────┐    │
│  │ Traefik (auto-managed by Coolify)           │    │
│  │ SSL via Let's Encrypt                       │    │
│  │ Routes: *.yourdomain.com → correct stack    │    │
│  └──────────────────┬──────────────────────────┘    │
│                     │                               │
│  ┌──────────────────┼──────────────────────┐        │
│  │                  │                      │        │
│  ▼                  ▼                      ▼        │
│  [acme-roofing]  [law-office]  [insurance]          │
│  ├─ openwebui    ├─ openwebui   ├─ openwebui       │
│  ├─ n8n          ├─ n8n         ├─ n8n             │
│  ├─ postgres     ├─ postgres    ├─ postgres        │
│  └─ volumes      └─ volumes     └─ volumes         │
│                                                     │
│  ┌─────────────────────────────────────────────┐    │
│  │ Shared: Ollama (or external LLM API)        │    │
│  │ Internal network, accessible by all stacks  │    │
│  └─────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘

Optional: GPU Droplet ($1.99/hr) for Ollama
Alternative: Use OpenRouter/OpenClaw/Groq API (no GPU needed)
```

---

## Per-Client Docker Compose

Each client deployed as a Coolify "Service" using this compose template:

```yaml
# docker-compose.client.yml — deployed per client via Coolify
version: "3.8"

services:
  openwebui:
    image: ghcr.io/open-webui/open-webui:main
    environment:
      - OLLAMA_BASE_URL=${OLLAMA_URL:-http://ollama:11434}
      - WEBUI_AUTH=true
    volumes:
      - webui_data:/app/backend/data
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${CLIENT_ID}-webui.rule=Host(`${CLIENT_SUBDOMAIN}.yourdomain.com`)"
      - "traefik.http.routers.${CLIENT_ID}-webui.tls.certresolver=letsencrypt"
    networks:
      - internal
      - shared

  n8n:
    image: n8nio/n8n
    environment:
      - N8N_HOST=${CLIENT_SUBDOMAIN}-n8n.yourdomain.com
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://${CLIENT_SUBDOMAIN}-n8n.yourdomain.com/
    volumes:
      - n8n_data:/home/node/.n8n
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${CLIENT_ID}-n8n.rule=Host(`${CLIENT_SUBDOMAIN}-n8n.yourdomain.com`)"
      - "traefik.http.routers.${CLIENT_ID}-n8n.tls.certresolver=letsencrypt"
    networks:
      - internal
      - shared

  postgres:
    image: pgvector/pgvector:pg16
    environment:
      - POSTGRES_USER=admin
      - POSTGRES_PASSWORD=${DB_PASSWORD}
      - POSTGRES_DB=businessassistant
    volumes:
      - pg_data:/var/lib/postgresql/data
    networks:
      - internal

  rag-indexer:
    image: python:3.11-slim
    command: ["python", "/app/index_vault.py"]
    environment:
      - ACTIVE_CLIENT=${CLIENT_ID}
      - EMBEDDING_PROVIDER=${EMBEDDING_PROVIDER:-ollama}
      - EMBEDDING_MODEL=${EMBEDDING_MODEL:-nomic-embed-text}
      - OLLAMA_BASE_URL=${OLLAMA_URL:-http://ollama:11434}
      - DB_HOST=postgres
    volumes:
      - client_vault:/vault
      - ./vector-db:/app
    networks:
      - internal
      - shared
    profiles: ["indexer"]  # only runs on-demand

volumes:
  webui_data:
  n8n_data:
  pg_data:
  client_vault:

networks:
  internal:
  shared:
    external: true
    name: bab-shared
```

---

## Shared LLM Service (Separate Coolify Stack)

```yaml
# docker-compose.shared.yml
version: "3.8"

services:
  ollama:
    image: ollama/ollama
    volumes:
      - ollama_models:/root/.ollama
    deploy:
      resources:
        reservations:
          memory: 16G
    networks:
      - bab-shared

volumes:
  ollama_models:

networks:
  bab-shared:
    name: bab-shared
    driver: bridge
```

Or skip Ollama entirely and use an API:

```env
# Per-client .env in Coolify
OLLAMA_URL=https://api.openrouter.ai/v1  # or OpenClaw, Groq, etc.
EMBEDDING_PROVIDER=openai_compatible
```

---

## Client Onboarding Flow

### Manual (via Coolify UI):
1. Create new Project in Coolify → name it `client-{id}`
2. Add Docker Compose service → paste template
3. Set environment variables (CLIENT_ID, CLIENT_SUBDOMAIN, DB_PASSWORD)
4. Deploy
5. Upload client vault files via SFTP or S3 sync
6. Run RAG indexer: `docker compose --profile indexer up rag-indexer`

### Automated (CLI script):

```bash
#!/bin/bash
# onboard_client.sh — provision a new client stack

CLIENT_ID="$1"
SUBDOMAIN="$2"
DB_PASSWORD=$(openssl rand -hex 16)

# 1. Create client vault from template
mkdir -p /data/clients/${CLIENT_ID}
cp -r /data/clients/templates/* /data/clients/${CLIENT_ID}/

# 2. Deploy via Coolify API
curl -X POST https://coolify.yourdomain.com/api/v1/services \
  -H "Authorization: Bearer ${COOLIFY_API_TOKEN}" \
  -d '{
    "project_id": "new",
    "name": "'${CLIENT_ID}'",
    "docker_compose": "...",
    "environment": {
      "CLIENT_ID": "'${CLIENT_ID}'",
      "CLIENT_SUBDOMAIN": "'${SUBDOMAIN}'",
      "DB_PASSWORD": "'${DB_PASSWORD}'",
      "OLLAMA_URL": "http://ollama:11434"
    }
  }'

# 3. Wait for healthy, then index
sleep 30
docker compose -p ${CLIENT_ID} --profile indexer up rag-indexer

echo "Client ${CLIENT_ID} live at https://${SUBDOMAIN}.yourdomain.com"
```

---

## Domain Routing

| Client | Chat URL | n8n URL |
|--------|----------|---------|
| acme-roofing | acme.yourdomain.com | acme-n8n.yourdomain.com |
| law-office | lawfirm.yourdomain.com | lawfirm-n8n.yourdomain.com |
| insurance | insurance.yourdomain.com | insurance-n8n.yourdomain.com |

DNS: Wildcard A record `*.yourdomain.com` → Droplet IP
Coolify/Traefik handles per-subdomain routing + SSL.

---

## Digital Ocean Infrastructure

### Minimum (1-5 clients, no local LLM):
- 1x Droplet: 8 vCPU / 16GB RAM / 320GB SSD ($96/mo)
- DO Spaces for backups ($5/mo)
- External LLM API (pay-per-use)
- **Total: ~$101/mo + LLM usage**

### Growth (5-15 clients, local LLM):
- 1x Droplet: 16 vCPU / 32GB RAM ($192/mo) — app services
- 1x GPU Droplet: g5.xlarge equivalent ($~350/mo) — Ollama
- DO Managed PostgreSQL ($30/mo) — shared, replaces per-client postgres
- DO Spaces ($5/mo)
- **Total: ~$577/mo**

### Alternative (no GPU, API-only):
- 1x Droplet: 8 vCPU / 32GB RAM ($144/mo)
- OpenRouter/Groq API (~$0.50-2/client/day)
- **Total: ~$150/mo + API costs**

---

## Migration from Current Setup

### What Stays the Same:
- Client vault structure (`clients/{name}/`)
- RAG indexing scripts (index_vault.py, query_vault.py)
- n8n workflows (export JSON, import into new stack)
- Open WebUI configuration
- System prompts and agent behavior files

### What Changes:

| Current | Cloud |
|---------|-------|
| `ACTIVE_CLIENT` in global .env | Per-stack env var (always set, never switches) |
| `current-client` symlink | Direct volume mount to client dir |
| Ollama on localhost | Shared Ollama container on internal network OR API |
| Manual `switch_client.sh` | Each client is its own stack — no switching |
| Single machine, one client at a time | All clients running simultaneously |
| Manual install.sh | Coolify deploys from compose template |

---

## Backup Strategy

```bash
# Per-client backup (cron daily)
for client in $(ls /data/clients/); do
  # DB dump
  docker compose -p ${client} exec postgres pg_dump -U admin businessassistant \
    | gzip > /backups/${client}/db-$(date +%Y%m%d).sql.gz

  # Vault files
  tar czf /backups/${client}/vault-$(date +%Y%m%d).tar.gz /data/clients/${client}/

  # Upload to DO Spaces
  s3cmd put /backups/${client}/* s3://bab-backups/${client}/
done
```

---

## Security

| Concern | Solution |
|---------|----------|
| Client data isolation | Separate Docker networks + volumes per client |
| Database isolation | Separate PostgreSQL container per client (Option 1) |
| Secrets | Coolify encrypted env vars (not in git) |
| SSL | Auto via Traefik + Let's Encrypt |
| Access control | Open WebUI built-in auth per stack |
| Network exposure | Only Traefik (443/80) exposed; all services on internal networks |
| Backups | Automated to DO Spaces with retention policy |

---

## Scaling Decisions

| Trigger | Action |
|---------|--------|
| > 10 clients on one droplet | Add second droplet, move clients via Coolify |
| High LLM latency | Switch to faster API or add GPU droplet |
| Client needs dedicated resources | Deploy their stack on isolated droplet |
| Enterprise client | Dedicated droplet + managed DB + custom domain |

---

## Quick Start

```bash
# 1. Provision droplet
doctl compute droplet create bab-prod \
  --size s-8vcpu-32gb --image ubuntu-24-04-x64 --region nyc1

# 2. Install Coolify
curl -fsSL https://cdn.coolify.io/install.sh | bash

# 3. Access Coolify dashboard
# https://your-droplet-ip:8000

# 4. Create shared network + LLM service
docker network create bab-shared
# Deploy shared ollama stack OR configure API keys

# 5. Deploy first client
# Use Coolify UI or onboard_client.sh script
```
