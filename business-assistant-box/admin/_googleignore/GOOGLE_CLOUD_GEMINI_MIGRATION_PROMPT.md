# GOOGLE_CLOUD_GEMINI_MIGRATION_PROMPT.md

# Business Assistant Box — Google Cloud + Gemini Migration Build Prompt

---

You are migrating "Business Assistant Box" from a local Ollama-based stack to Google Cloud with Gemini as the primary AI provider. This migration prepares the product for the XPRIZE hackathon which requires: (1) at least one Google Cloud product, (2) AI-native operations, (3) real revenue within 90 days.

This prompt must be executed BEFORE the SaaS Sales Layer Build Prompt. The SaaS layer will build on top of this infrastructure.

---

## CURRENT STATE

- LLM: Ollama (qwen3:14b) running locally
- Embeddings: nomic-embed-text via Ollama (768 dimensions)
- Database: PostgreSQL with pgvector (local Docker)
- Workflow Engine: n8n (local Docker)
- Chat Interface: Open WebUI (local Docker)
- Hosting: Local machine / planned Digital Ocean
- RAG: Python scripts (index_vault.py, query_vault.py) using psycopg2 + Ollama embeddings
- Client isolation: per-client vault directories, ACTIVE_CLIENT env var

---

## TARGET STATE

- LLM: Gemini 2.0 Flash via Vertex AI API
- Embeddings: Vertex AI text-embedding-004 (768 dimensions — no schema change needed)
- Database: Cloud SQL for PostgreSQL with pgvector extension
- Workflow Engine: n8n on Compute Engine (Docker Compose)
- Chat Interface: Open WebUI on Compute Engine (Docker Compose)
- Hosting: Google Cloud Compute Engine (single VM, Docker Compose stack)
- RAG: Same Python scripts with Google provider added
- Monitoring: Cloud Logging + Cloud Monitoring

---

## WHAT TO BUILD

---

### 1. GEMINI LLM INTEGRATION

**Add Gemini as AI provider in the system.**

Update `.env` to support Google:
```env
AI_PROVIDER=google
GOOGLE_PROJECT_ID=your-project-id
GOOGLE_LOCATION=us-central1
GOOGLE_API_KEY=your-api-key
GEMINI_MODEL=gemini-2.0-flash
EMBEDDING_PROVIDER=google
EMBEDDING_MODEL=text-embedding-004
EMBEDDING_DIMENSIONS=768
```

**Open WebUI Configuration:**
- Open WebUI natively supports Gemini/OpenAI-compatible endpoints
- Configure via Open WebUI admin settings:
  - Add connection: Vertex AI endpoint OR use Google AI Studio API key
  - Model: gemini-2.0-flash
- Alternative: Use LiteLLM as a proxy between Open WebUI and Vertex AI if direct support is limited

**n8n Workflow Integration:**
- n8n has native Google Vertex AI nodes
- Update all workflow nodes that call LLM from Ollama HTTP Request → Vertex AI node
- For custom code nodes: use `@google-cloud/vertexai` npm package

---

### 2. EMBEDDING PROVIDER SWAP

**Update `vector-db/index_vault.py`:**

Add Google embedding provider to the existing `get_embedding()` function:

```python
def get_embedding(text):
    """Get embedding vector from configured provider."""
    if EMBEDDING_PROVIDER == "ollama":
        import requests
        resp = requests.post(
            f"{OLLAMA_BASE_URL}/api/embeddings",
            json={"model": EMBEDDING_MODEL, "prompt": text},
        )
        resp.raise_for_status()
        return resp.json()["embedding"]
    elif EMBEDDING_PROVIDER == "google":
        from google.cloud import aiplatform
        from vertexai.language_models import TextEmbeddingModel
        aiplatform.init(project=os.getenv("GOOGLE_PROJECT_ID"), location=os.getenv("GOOGLE_LOCATION"))
        model = TextEmbeddingModel.from_pretrained(EMBEDDING_MODEL)
        embeddings = model.get_embeddings([text])
        return embeddings[0].values
    else:
        raise NotImplementedError(f"Embedding provider \"{EMBEDDING_PROVIDER}\" not supported.")
```

**Update `vector-db/query_vault.py`:**

Same change — add the `elif EMBEDDING_PROVIDER == "google"` branch to its `get_embedding()` function.

**Key fact:** Vertex AI `text-embedding-004` outputs 768 dimensions by default. Your schema already uses `vector(768)`. No migration needed.

**Dependencies to add:**
```
google-cloud-aiplatform>=1.38.0
vertexai>=1.38.0
```

---

### 3. GOOGLE CLOUD INFRASTRUCTURE DEPLOYMENT

**Decision: Compute Engine (single VM, Docker Compose)**

Reasons: docker-compose already written, n8n is stateful, cheapest for 1-20 clients, fastest to deploy, mirrors local setup exactly.

```bash
# Provision VM
gcloud compute instances create bab-prod \
  --zone=us-central1-a \
  --machine-type=e2-standard-4 \
  --image-family=ubuntu-2404-lts-amd64 \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=100GB \
  --tags=http-server,https-server

# Firewall rules
gcloud compute firewall-rules create allow-http --allow tcp:80 --target-tags=http-server
gcloud compute firewall-rules create allow-https --allow tcp:443 --target-tags=http-server
```

Then SSH in and deploy the Docker Compose stack (Open WebUI, n8n, Cloud SQL Proxy, Traefik).

---

### 4. CLOUD SQL FOR POSTGRESQL

Replace local PostgreSQL with Cloud SQL:

```bash
# Create Cloud SQL instance with pgvector
gcloud sql instances create bab-db \
  --database-version=POSTGRES_16 \
  --tier=db-custom-2-4096 \
  --region=us-central1 \
  --storage-size=20GB \
  --database-flags=cloudsql.enable_pgvector=on

# Create database
gcloud sql databases create businessassistant --instance=bab-db

# Create user
gcloud sql users create admin --instance=bab-db --password=<generated>
```

Update DB_CONFIG in Python scripts:
```python
DB_CONFIG = {
    "host": "/cloudsql/PROJECT_ID:REGION:bab-db",  # Unix socket for Cloud SQL Proxy
    # OR for direct connection:
    "host": "CLOUD_SQL_PUBLIC_IP",
    "port": 5432,
    "user": "admin",
    "password": os.getenv("DB_PASSWORD"),
    "dbname": "businessassistant",
}
```

Run the existing `schema.sql` against Cloud SQL — no changes needed since pgvector extension is available.

---

### 5. DOCKER COMPOSE UPDATE FOR GOOGLE CLOUD

Create `docker-compose.gcloud.yml` that replaces Ollama with Gemini API calls:

```yaml
version: "3.8"

services:
  traefik:
    image: traefik:v2.11
    command:
      - "--providers.docker=true"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"
      - "--certificatesresolvers.letsencrypt.acme.email=${ADMIN_EMAIL}"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - letsencrypt:/letsencrypt
    networks:
      - web

  openwebui:
    image: ghcr.io/open-webui/open-webui:main
    environment:
      - OPENAI_API_BASE_URL=https://generativelanguage.googleapis.com/v1beta
      - OPENAI_API_KEY=${GOOGLE_API_KEY}
      - WEBUI_AUTH=true
      - DATABASE_URL=postgresql://admin:${DB_PASSWORD}@${DB_HOST}:5432/openwebui
    volumes:
      - webui_data:/app/backend/data
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.webui.rule=Host(`${CLIENT_SUBDOMAIN}.${DOMAIN}`)"
      - "traefik.http.routers.webui.tls.certresolver=letsencrypt"
    networks:
      - web
      - internal

  n8n:
    image: n8nio/n8n
    environment:
      - N8N_HOST=${CLIENT_SUBDOMAIN}-n8n.${DOMAIN}
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://${CLIENT_SUBDOMAIN}-n8n.${DOMAIN}/
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=${DB_HOST}
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=admin
      - DB_POSTGRESDB_PASSWORD=${DB_PASSWORD}
      - GOOGLE_API_KEY=${GOOGLE_API_KEY}
    volumes:
      - n8n_data:/home/node/.n8n
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.n8n.rule=Host(`${CLIENT_SUBDOMAIN}-n8n.${DOMAIN}`)"
      - "traefik.http.routers.n8n.tls.certresolver=letsencrypt"
    networks:
      - web
      - internal

  cloud-sql-proxy:
    image: gcr.io/cloud-sql-connectors/cloud-sql-proxy:2
    command:
      - "${GOOGLE_PROJECT_ID}:${GOOGLE_LOCATION}:bab-db"
      - "--address=0.0.0.0"
      - "--port=5432"
    volumes:
      - ./service-account.json:/config/credentials.json:ro
    environment:
      - GOOGLE_APPLICATION_CREDENTIALS=/config/credentials.json
    networks:
      - internal

volumes:
  letsencrypt:
  webui_data:
  n8n_data:

networks:
  web:
  internal:
```

---

### 6. AUTHENTICATION & SERVICE ACCOUNT

```bash
# Create service account for the application
gcloud iam service-accounts create bab-app \
  --display-name="Business Assistant Box App"

# Grant permissions
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:bab-app@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/aiplatform.user"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:bab-app@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"

# Download key (for Docker deployment)
gcloud iam service-accounts keys create service-account.json \
  --iam-account=bab-app@${PROJECT_ID}.iam.gserviceaccount.com
```

---

### 7. UPDATED .env TEMPLATE

```env
# ==========================================
# Business Assistant Box — Google Cloud Config
# ==========================================

# AI Provider
AI_PROVIDER=google
GOOGLE_PROJECT_ID=your-project-id
GOOGLE_LOCATION=us-central1
GOOGLE_API_KEY=your-google-ai-api-key
GEMINI_MODEL=gemini-2.0-flash

# Embeddings
EMBEDDING_PROVIDER=google
EMBEDDING_MODEL=text-embedding-004
EMBEDDING_DIMENSIONS=768

# Database (Cloud SQL)
DB_HOST=cloud-sql-proxy
DB_PORT=5432
DB_USER=admin
DB_PASSWORD=generated-strong-password
DB_NAME=businessassistant

# Client
ACTIVE_CLIENT=demo-company
BASE_PATH=/opt/business-assistant-box

# Domain & Routing
DOMAIN=yourdomain.com
CLIENT_SUBDOMAIN=demo
ADMIN_EMAIL=admin@yourdomain.com

# Workflow Engine
WORKFLOW_ENGINE=n8n
N8N_BASE_URL=http://n8n:5678

# Features
RAG_ENABLED=true
DASHBOARD_ENABLED=true
OBSIDIAN_ENABLED=false
BUSINESS_BUTTONS_ENABLED=true
APPROVAL_REQUIRED_FOR_EMAIL_SEND=true

# Fallback (keep Ollama as optional local fallback)
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=qwen3:14b
LOCAL_LLM_ENABLED=false
```

---

### 8. RAG PIPELINE UPDATES

**index_vault.py changes:**
- Add `google` provider branch to `get_embedding()`
- Update DB_CONFIG to read from env vars (not hardcoded)
- Add batch embedding support (Vertex AI supports batching up to 250 texts per call for efficiency)

**query_vault.py changes:**
- Same `google` provider branch in `get_embedding()`
- Same DB_CONFIG env var update

**Batch embedding optimization for index_vault.py:**
```python
def get_embeddings_batch(texts):
    """Batch embed multiple texts (Google supports up to 250 per call)."""
    if EMBEDDING_PROVIDER == "google":
        from vertexai.language_models import TextEmbeddingModel
        model = TextEmbeddingModel.from_pretrained(EMBEDDING_MODEL)
        embeddings = model.get_embeddings(texts)
        return [e.values for e in embeddings]
    elif EMBEDDING_PROVIDER == "ollama":
        return [get_embedding(t) for t in texts]
```

This dramatically speeds up indexing (1 API call per 250 chunks vs 1 per chunk).

---

### 9. OPEN WEBUI → GEMINI CONNECTION

Open WebUI supports OpenAI-compatible APIs. Gemini exposes an OpenAI-compatible endpoint:

**Method 1 — Direct (Google AI Studio API key):**
- In Open WebUI admin → Connections → Add OpenAI-compatible
- Base URL: `https://generativelanguage.googleapis.com/v1beta/openai`
- API Key: Your Google AI API key
- Models will auto-populate (gemini-2.0-flash, etc.)

**Method 2 — Vertex AI (for production, IAM-based auth):**
- Use LiteLLM as a proxy:
```yaml
  litellm:
    image: ghcr.io/berriai/litellm:main-latest
    environment:
      - GOOGLE_APPLICATION_CREDENTIALS=/config/credentials.json
      - VERTEXAI_PROJECT=${GOOGLE_PROJECT_ID}
      - VERTEXAI_LOCATION=${GOOGLE_LOCATION}
    volumes:
      - ./service-account.json:/config/credentials.json:ro
      - ./litellm-config.yaml:/app/config.yaml:ro
    command: ["--config", "/app/config.yaml"]
    networks:
      - internal
```

`litellm-config.yaml`:
```yaml
model_list:
  - model_name: gemini-2.0-flash
    litellm_params:
      model: vertex_ai/gemini-2.0-flash
      vertex_project: your-project-id
      vertex_location: us-central1
  - model_name: text-embedding-004
    litellm_params:
      model: vertex_ai/text-embedding-004
      vertex_project: your-project-id
      vertex_location: us-central1
```

Then point Open WebUI to `http://litellm:4000` as the OpenAI base URL.

**Recommended for hackathon:** Method 1 (direct API key). Simpler, fewer moving parts.

---

### 10. N8N WORKFLOW TEMPLATE LIBRARY

No Ollama workflows exist to convert. The system was built fresh with 15 Gemini-native workflow templates stored in `n8n/workflows/`.

**Structure:**
```
n8n/workflows/
├── manifest.json                    ← Source of truth (metadata for all 15)
├── standard/                        ← Deployed to ALL clients (5)
│   ├── email-triage.json            (Gmail poll 5min → Gemini classify → label/draft)
│   ├── calendar-review.json         (Daily 7AM → check conflicts → notify)
│   ├── daily-briefing.json          (Weekdays 6:30AM → merge calendar+email → summary)
│   ├── approval-router.json         (Webhook gate → risk assess → hold or auto-approve)
│   └── rag-query.json               (Webhook → embed → pgvector → Gemini answer)
└── selectable/                      ← Client picks during onboarding (10)
    ├── document-drafting.json
    ├── customer-intake.json
    ├── invoice-generator.json
    ├── lead-followup.json
    ├── appointment-booking.json
    ├── review-requester.json
    ├── expense-tracker.json
    ├── social-post-scheduler.json
    ├── report-generator.json
    └── voicemail-transcription.json
```

**All workflows use this pattern for Gemini calls:**
```json
{
  "url": "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={{$env.GOOGLE_API_KEY}}",
  "method": "POST",
  "body": {
    "contents": [{"parts": [{"text": "..."}]}]
  }
}
```

**Credential placeholders (replaced per tenant during provisioning):**

| Placeholder | Service | Setup |
|-------------|---------|-------|
| `{{$env.GOOGLE_API_KEY}}` | Gemini API | Env var per n8n instance |
| `PG_CREDENTIAL_ID` | Cloud SQL (pgvector) | n8n Credentials UI |
| `GMAIL_CREDENTIAL_ID` | Gmail (read/send/label) | OAuth2 per client |
| `GCAL_CREDENTIAL_ID` | Google Calendar | OAuth2 per client |
| `SHEETS_CREDENTIAL_ID` | Google Sheets | OAuth2 per client |

**Approval Router:** All sensitive workflow outputs (drafts, invoices, social posts) route through `approval-router.json` webhook before execution. Low-risk = auto-approve. High-risk = hold for client review.

**Import during provisioning:**
```bash
# Import standard workflows (all clients)
for f in n8n/workflows/standard/*.json; do
  n8n import:workflow --input="$f"
done

# Import client-selected workflows
for workflow_id in $(jq -r '.[] | select(.tier=="selectable") | .file' manifest.json); do
  n8n import:workflow --input="n8n/workflows/selectable/$workflow_id"
done

# Activate all
curl -X PATCH http://localhost:5678/api/v1/workflows/{id} -d '{"active": true}'
```

---

### 11. COST ESTIMATION (Google Cloud)

| Service | Spec | Monthly Cost |
|---------|------|-------------|
| Compute Engine (e2-standard-4) | 4 vCPU, 16GB RAM | ~$97 |
| Cloud SQL (PostgreSQL) | db-custom-2-4096, 20GB | ~$51 |
| Gemini 2.0 Flash API | ~100K input tokens/day | ~$0-10 (free tier: 15 RPM / 1M TPD) |
| Vertex AI Embeddings | ~50K texts/month | ~$0-5 (free tier covers early clients) |
| Cloud Storage (backups) | 50GB | ~$1 |
| Static IP + DNS | 1 IP | ~$3 |
| **Total** | | **~$156-167/month** |

Comparable to the Digital Ocean plan (~$150/mo) but satisfies the hackathon's Google Cloud requirement.

**Free tier note:** Google Cloud offers $300 in free credits for new accounts. This covers ~2 months of the above infrastructure — enough for the hackathon period.

---

### 12. MIGRATION CHECKLIST

Execute in this order:

**Phase 1 — Google Cloud Setup (Day 1)**
- [ ] Create Google Cloud project
- [ ] Enable APIs: Vertex AI, Cloud SQL, Compute Engine, Cloud Storage
- [ ] Create service account with roles: aiplatform.user, cloudsql.client
- [ ] Download service account key
- [ ] Provision Cloud SQL instance with pgvector
- [ ] Run schema.sql against Cloud SQL
- [ ] Provision Compute Engine VM

**Phase 2 — Code Changes (Day 2)**
- [ ] Update index_vault.py: add Google embedding provider
- [ ] Update query_vault.py: add Google embedding provider
- [ ] Update DB_CONFIG in both scripts to use env vars
- [ ] Add requirements: google-cloud-aiplatform, vertexai
- [ ] Create docker-compose.gcloud.yml
- [ ] Create updated .env with Google config
- [ ] Test embedding generation locally against Vertex AI API

**Phase 3 — Deploy (Day 3)**
- [ ] SSH into Compute Engine VM
- [ ] Install Docker + Docker Compose
- [ ] Clone repo, copy .env and service-account.json
- [ ] Run docker-compose.gcloud.yml
- [ ] Configure Open WebUI → Gemini connection
- [ ] Import n8n workflows from template library (standard/ + selected selectable/)
- [ ] Configure n8n credentials (PostgreSQL, Gmail OAuth2, Calendar OAuth2, Sheets OAuth2)
- [ ] Activate all imported workflows
- [ ] Verify: chat works with Gemini responses
- [ ] Verify: RAG indexing works with Vertex AI embeddings
- [ ] Verify: n8n workflows trigger and call Gemini
- [ ] Verify: approval-router webhook responds correctly

**Phase 4 — DNS & SSL (Day 3-4)**
- [ ] Point domain to Compute Engine static IP
- [ ] Wildcard DNS: *.yourdomain.com → IP
- [ ] Traefik auto-provisions SSL via Let's Encrypt
- [ ] Test: https://demo.yourdomain.com loads Open WebUI

**Phase 5 — Validate (Day 4)**
- [ ] Index demo-company vault into Cloud SQL
- [ ] Ask business questions via chat — confirm RAG retrieval works
- [ ] Trigger n8n workflows — confirm Gemini generates responses
- [ ] Test approval-router: send high-risk output, verify hold behavior
- [ ] Test email-triage: send test email, verify classification
- [ ] Verify all 5 standard workflows active via n8n REST API
- [ ] Check Cloud Logging for API call logs (hackathon evidence)
- [ ] Screenshot Vertex AI usage dashboard (hackathon evidence)

---

### 13. HACKATHON EVIDENCE GENERATION

The hackathon requires "product evidence showing agent execution logs, API usage records, screenshots of dashboards."

Google Cloud provides this automatically:

- **Vertex AI → Metrics tab:** Shows API calls, latency, token usage per day
- **Cloud Logging:** Every Gemini API call is logged with request/response metadata
- **Cloud Monitoring:** Dashboards showing uptime, request volume, error rates
- **Cloud SQL Insights:** Query performance, connections, storage growth

Set up a Cloud Monitoring dashboard with:
- Gemini API calls per hour
- Embedding requests per day
- Cloud SQL active connections
- Compute Engine CPU/memory utilization

This dashboard IS your "AI running in production continuously" evidence.

---

### 14. KEEPING OLLAMA AS FALLBACK

Don't remove Ollama support. Keep it as a fallback for:
- Local development (no API costs while building)
- Offline demos
- Clients who want on-premise (Custom Rig tier)

The provider abstraction (`if EMBEDDING_PROVIDER == "ollama"` / `elif == "google"`) means both work simultaneously. Just change the .env to switch.

---

### 15. SHELL SCRIPT UPDATES FOR GCP

The existing admin scripts (`install.sh`, `configure_n8n.sh`, `pre_check.sh`, `post_install_client_setup.sh`) are designed for local Ubuntu + Docker. They work on a GCP Compute Engine VM with minor modifications. Update them to support `AI_PROVIDER=google` as a third option alongside `ollama` and `openclaw_api`.

**install.sh changes:**

Phase 0B — Add Google as provider option:
```bash
# Replace the AI provider prompt with:
read -p "Primary AI provider — [1] OpenClaw API, [2] Ollama, or [3] Google/Gemini? [1/2/3]: " ai_choice
case "$ai_choice" in
  1)
    AI_PROVIDER="openclaw_api"
    LOCAL_LLM_ENABLED="false"
    read -p "OpenClaw API Key: " OPENCLAW_API_KEY
    read -p "OpenClaw Model (default: leave blank): " OPENCLAW_MODEL
    ;;
  2)
    AI_PROVIDER="ollama"
    LOCAL_LLM_ENABLED="true"
    OPENCLAW_API_KEY=""
    OPENCLAW_MODEL=""
    ;;
  3)
    AI_PROVIDER="google"
    LOCAL_LLM_ENABLED="false"
    OPENCLAW_API_KEY=""
    OPENCLAW_MODEL=""
    read -p "Google Cloud Project ID: " GOOGLE_PROJECT_ID
    read -p "Google Cloud Location (default: us-central1): " GOOGLE_LOCATION
    GOOGLE_LOCATION="${GOOGLE_LOCATION:-us-central1}"
    read -p "Google API Key: " GOOGLE_API_KEY
    GEMINI_MODEL="gemini-2.0-flash"
    ;;
  *)
    AI_PROVIDER="google"
    LOCAL_LLM_ENABLED="false"
    ;;
esac

# Replace the embedding provider prompt with:
read -p "Embedding provider — [1] Ollama, [2] OpenClaw API, or [3] Google/Vertex AI? [1/2/3]: " embed_choice
case "$embed_choice" in
  1) EMBEDDING_PROVIDER="ollama"; EMBEDDING_MODEL="nomic-embed-text" ;;
  2) EMBEDDING_PROVIDER="openclaw_api"; EMBEDDING_MODEL="" ;;
  3) EMBEDDING_PROVIDER="google"; EMBEDDING_MODEL="text-embedding-004" ;;
  *) EMBEDDING_PROVIDER="google"; EMBEDDING_MODEL="text-embedding-004" ;;
esac
```

Phase 0B — Append Google vars to .env generation (add inside the `cat > "$ENV_FILE"` block):
```bash
GOOGLE_PROJECT_ID=${GOOGLE_PROJECT_ID:-}
GOOGLE_LOCATION=${GOOGLE_LOCATION:-us-central1}
GOOGLE_API_KEY=${GOOGLE_API_KEY:-}
GEMINI_MODEL=${GEMINI_MODEL:-gemini-2.0-flash}
```

Phase 3 — Skip local Docker postgres when using Cloud SQL:
```bash
# Add at the top of Phase 3:
DB_HOST="${DB_HOST:-localhost}"
if [ "$DB_HOST" != "localhost" ] && [ "$DB_HOST" != "cloud-sql-proxy" ]; then
  echo "DB_HOST=$DB_HOST — using remote database. Skipping local PostgreSQL container."
  echo "Testing remote connection..."
  if pg_isready -h "$DB_HOST" -p "${DB_PORT:-5432}" -U "${DB_USER:-admin}" 2>/dev/null; then
    echo "  ✅ Remote PostgreSQL reachable."
  else
    log_warn "Remote PostgreSQL not reachable at $DB_HOST:${DB_PORT:-5432}"
  fi
else
  # ... existing local Docker postgres logic ...
fi
```

Phase 4 — Skip Ollama when using Google:
```bash
# Replace the Ollama requirement check with:
if [ "$AI_PROVIDER" = "ollama" ] || [ "$LOCAL_LLM_ENABLED" = "true" ] || [ "$EMBEDDING_PROVIDER" = "ollama" ]; then
  echo "Ollama required by configuration."
  INSTALL_OLLAMA="y"
elif [ "$AI_PROVIDER" = "google" ] && [ "$EMBEDDING_PROVIDER" = "google" ]; then
  echo "Using Google/Gemini for LLM and embeddings. Ollama not required."
  INSTALL_OLLAMA="n"
  INSTALL_OLLAMA_DONE="skipped (google)"
else
  # ... existing prompt ...
fi
```

Phase 8 — Add Google dependencies to RAG venv:
```bash
# After existing pip installs, add:
if [ "$EMBEDDING_PROVIDER" = "google" ] || [ "$AI_PROVIDER" = "google" ]; then
  pip install --quiet google-cloud-aiplatform>=1.38.0 || log_warn "Failed to install google-cloud-aiplatform"
  pip install --quiet vertexai>=1.38.0 || log_warn "Failed to install vertexai"
fi
```

Phase 10 — Skip Ollama embedding warmup when using Google:
```bash
# Replace the pre-warm section with:
if [ "$EMBEDDING_PROVIDER" = "ollama" ]; then
  echo "Pre-warming embedding model (this may take 30-60s on first load)..."
  curl -s --max-time 120 http://localhost:11434/api/embeddings -d '{"model":"nomic-embed-text","prompt":"warmup"}' > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "  ✅ Embedding model loaded"
  else
    log_warn "Embedding model warmup timed out."
  fi
elif [ "$EMBEDDING_PROVIDER" = "google" ]; then
  echo "Using Google Vertex AI embeddings — no local warmup needed."
  echo "  Testing Vertex AI connectivity..."
  # Quick test via Python
  if [ -d "$RAG_VENV" ]; then
    source "$RAG_VENV/bin/activate"
    python3 -c "
import os
os.environ['GOOGLE_PROJECT_ID'] = '${GOOGLE_PROJECT_ID}'
os.environ['GOOGLE_LOCATION'] = '${GOOGLE_LOCATION}'
from google.cloud import aiplatform
from vertexai.language_models import TextEmbeddingModel
aiplatform.init(project='${GOOGLE_PROJECT_ID}', location='${GOOGLE_LOCATION}')
model = TextEmbeddingModel.from_pretrained('text-embedding-004')
result = model.get_embeddings(['test'])
print(f'  ✅ Vertex AI embeddings working ({len(result[0].values)} dimensions)')
" 2>/dev/null || log_warn "Vertex AI embedding test failed. Check service account credentials."
    deactivate
  fi
fi
```

---

**configure_n8n.sh changes:**

Phase 3 — Add Google middleware check:
```bash
# Add after the openclaw_api elif block:
elif [ "$AI_PROVIDER" = "google" ]; then
  echo -n "  Google/Gemini API: "
  if [ -z "$GOOGLE_API_KEY" ]; then
    log_warn "Cannot verify — GOOGLE_API_KEY not set"
  else
    GOOGLE_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
      "https://generativelanguage.googleapis.com/v1beta/models?key=$GOOGLE_API_KEY" 2>/dev/null || echo "000")
    if [ "$GOOGLE_CODE" = "200" ]; then
      log_ok "Reachable (HTTP $GOOGLE_CODE)"
      MIDDLEWARE_REACHABLE="true"
    elif [ "$GOOGLE_CODE" = "401" ] || [ "$GOOGLE_CODE" = "403" ]; then
      log_error "Authentication failed — check GOOGLE_API_KEY"
    elif [ "$GOOGLE_CODE" = "000" ]; then
      log_warn "Cannot reach Google AI API — network issue"
    else
      log_warn "Google AI API returned HTTP $GOOGLE_CODE"
    fi
  fi
```

---

**pre_check.sh changes:**

Service validation — Add Google provider check:
```bash
# Add after the OpenClaw API check block:
if [ "$AI_PROVIDER" = "google" ]; then
  echo -n "Google API Key: "
  if [ -n "$GOOGLE_API_KEY" ] && [ "$GOOGLE_API_KEY" != "" ]; then
    echo "✅ Set"
  else
    echo "❌ Missing"
    FAIL=true
  fi

  echo -n "Google Project ID: "
  if [ -n "$GOOGLE_PROJECT_ID" ] && [ "$GOOGLE_PROJECT_ID" != "" ]; then
    echo "✅ $GOOGLE_PROJECT_ID"
  else
    echo "❌ Missing"
    FAIL=true
  fi

  echo -n "Gemini API connectivity: "
  GEMINI_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    "https://generativelanguage.googleapis.com/v1beta/models?key=$GOOGLE_API_KEY" 2>/dev/null || echo "000")
  if [ "$GEMINI_CODE" = "200" ]; then
    echo "✅ Reachable"
  else
    echo "❌ HTTP $GEMINI_CODE"
    FAIL=true
  fi
fi

# Update the Ollama check to skip when Google is provider:
if [ "$AI_PROVIDER" = "ollama" ] || [ "$LOCAL_LLM_ENABLED" = "true" ] || ([ "$EMBEDDING_PROVIDER" = "ollama" ] && [ "$AI_PROVIDER" != "google" ]); then
  echo -n "Ollama (required by config): "
  systemctl is-active ollama 2>/dev/null | grep -q "^active" && echo "✅ Running" || { echo "❌ Not running"; FAIL=true; }
else
  echo "Ollama: SKIPPED (not required — using $AI_PROVIDER)"
fi
```

Configuration display — Add Google vars:
```bash
# Add to the Configuration echo block:
echo "  Google Project:    ${GOOGLE_PROJECT_ID:-not set}"
echo "  Google Location:   ${GOOGLE_LOCATION:-not set}"
echo "  Gemini Model:      ${GEMINI_MODEL:-not set}"
```

---

**post_install_client_setup.sh changes:**

Phase 6 — Update embedding provider check for indexing:
```bash
# Replace the Ollama embeddings check with:
if [ "${EMBEDDING_PROVIDER:-ollama}" = "ollama" ]; then
  echo -n "  Ollama (embeddings): "
  OLLAMA_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${OLLAMA_BASE_URL}/api/tags" 2>/dev/null || echo "000")
  if [ "$OLLAMA_CODE" = "200" ]; then
    log_ok "Reachable"
  else
    log_error "Not reachable — embeddings will fail"
    READY_TO_INDEX=false
  fi
elif [ "${EMBEDDING_PROVIDER:-}" = "google" ]; then
  echo -n "  Google Vertex AI (embeddings): "
  if [ -n "${GOOGLE_API_KEY:-}" ] || [ -f "${BASE}/service-account.json" ]; then
    log_ok "Credentials available"
  else
    log_error "No GOOGLE_API_KEY or service-account.json found — embeddings will fail"
    READY_TO_INDEX=false
  fi
fi
```

---

**Summary of script changes:**

| Script | Change | Effort |
|--------|--------|--------|
| install.sh | Add `[3] Google` to provider prompts, skip local postgres/ollama, add google pip deps | ~30 min |
| configure_n8n.sh | Add `elif google` middleware check | ~10 min |
| pre_check.sh | Add Google API validation, skip Ollama check | ~15 min |
| post_install_client_setup.sh | Add Google embedding credential check | ~10 min |
| switch_client.sh | No changes needed | 0 |
| list_clients.sh | No changes needed | 0 |
| license_check.sh | No changes needed | 0 |

All changes are additive `elif` branches — existing Ollama and OpenClaw paths remain untouched.

---

## CONSTRAINTS

- Gemini 2.0 Flash is the primary LLM for all production workloads.
- Vertex AI text-embedding-004 is the primary embedding model.
- All infrastructure runs on Google Cloud (Compute Engine + Cloud SQL minimum).
- Ollama remains available as a local development/fallback option but is NOT used in production.
- The existing RAG schema (vector(768)) must NOT change — text-embedding-004 outputs 768 dimensions by default.
- All existing client vault files, system files, and n8n workflow logic remain unchanged.
- The migration must be completable in 3-4 days by one person.
- After this migration, the SaaS Sales Layer Build Prompt executes next — it will reference Google Cloud infrastructure instead of Digital Ocean.

---

### 16. ADDITIONAL SCRIPT UPDATES (MISSED IN SECTION 15)

These scripts also need GCP-awareness but were not covered above.

---

**configure_rag_pipeline.sh changes:**

This script hardcodes `host.docker.internal` for PostgreSQL and Ollama connections inside the WebUI container. On GCP with Cloud SQL Proxy, the DB host is `cloud-sql-proxy` (another container on the same Docker network), and embeddings come from Google API (no Ollama needed).

Step 2 — Update pgvector connectivity test:
```bash
# Replace the hardcoded host.docker.internal connection with env-aware:
DB_HOST="${DB_HOST:-host.docker.internal}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-admin}"
DB_PASSWORD="${DB_PASSWORD:-strongpassword}"
DB_NAME="${DB_NAME:-businessassistant}"

RAG_TEST=$(_docker exec openwebui python3 -c "
import psycopg2
try:
    conn = psycopg2.connect(host='${DB_HOST}', port=${DB_PORT}, user='${DB_USER}', password='${DB_PASSWORD}', dbname='${DB_NAME}')
    cur = conn.cursor()
    cur.execute('SELECT COUNT(*) FROM rag_chunks')
    count = cur.fetchone()[0]
    conn.close()
    print(f'OK:{count}')
except Exception as e:
    print(f'FAIL:{e}')
" 2>&1)
```

Step 3 — Replace Ollama embedding test with provider-aware test:
```bash
if [ "${EMBEDDING_PROVIDER:-ollama}" = "ollama" ]; then
  # Existing Ollama embedding test
  EMBED_TEST=$(_docker exec openwebui python3 -c "
import requests
try:
    resp = requests.post('http://host.docker.internal:11434/api/embeddings', json={'model': 'nomic-embed-text', 'prompt': 'test'}, timeout=120)
    resp.raise_for_status()
    emb = resp.json().get('embedding', [])
    print(f'OK:{len(emb)}')
except Exception as e:
    print(f'FAIL:{e}')
" 2>&1)
elif [ "${EMBEDDING_PROVIDER:-}" = "google" ]; then
  echo "  Using Google Vertex AI for embeddings — testing API key..."
  EMBED_TEST=$(curl -s -o /dev/null -w "OK:%{http_code}" \
    "https://generativelanguage.googleapis.com/v1beta/models?key=${GOOGLE_API_KEY}" 2>/dev/null || echo "FAIL:000")
  if echo "$EMBED_TEST" | grep -q "OK:200"; then
    EMBED_TEST="OK:768"
    echo "  ✅ Google API reachable (768 dimensions)"
  else
    echo "  ❌ Google API not reachable"
  fi
fi
```

Step 7 — Update end-to-end test to use correct DB host and embedding provider:
```bash
# Replace hardcoded host.docker.internal and Ollama calls with:
if [ "${EMBEDDING_PROVIDER:-ollama}" = "google" ]; then
  echo "  End-to-end RAG test requires Google SDK in container. Skipping container-based test."
  echo "  Verify manually: python3 vector-db/query_vault.py \"test question\""
else
  # Existing Ollama-based E2E test with DB_HOST variable substitution
  E2E_TEST=$(_docker exec openwebui python3 -c "
import psycopg2, requests
resp = requests.post('http://host.docker.internal:11434/api/embeddings', json={'model': 'nomic-embed-text', 'prompt': 'test query'}, timeout=10)
embedding = resp.json()['embedding']
conn = psycopg2.connect(host='${DB_HOST}', port=${DB_PORT}, user='${DB_USER}', password='${DB_PASSWORD}', dbname='${DB_NAME}')
cur = conn.cursor()
cur.execute('SELECT title, chunk_text, 1 - (embedding <=> %s::vector) AS similarity FROM rag_chunks WHERE client_name = %s ORDER BY embedding <=> %s::vector LIMIT 3', (embedding, '${ACTIVE_CLIENT}', embedding))
results = cur.fetchall()
conn.close()
for title, chunk, sim in results:
    print(f'  [{sim:.3f}] {title}: {chunk[:100]}...')
" 2>&1)
fi
```

Also update the RAG filter function file (`dashboard/functions/business_rag_filter.py`) to read DB connection from environment variables instead of hardcoded values.

---

**post_install_verify.sh changes:**

This script is heavily Ollama-focused (Tests 1-4 and 6-7 all test Ollama). On GCP with Google provider:

Wrap Tests 1-4 and 6-7 in a provider check:
```bash
# At the top, after loading .env:
AI_PROVIDER="${AI_PROVIDER:-ollama}"
EMBEDDING_PROVIDER="${EMBEDDING_PROVIDER:-ollama}"

# Replace Tests 1-4 with:
if [ "$AI_PROVIDER" = "ollama" ] || [ "$EMBEDDING_PROVIDER" = "ollama" ] || [ "$LOCAL_LLM_ENABLED" = "true" ]; then
  # === TEST 1-4: Existing Ollama tests (unchanged) ===
  ...
else
  echo "=== TEST 1-4 — Ollama (SKIPPED — using $AI_PROVIDER) ==="
  echo "  Ollama not required. Skipping Ollama service tests."
  echo ""
fi
```

Add a new test for Google API connectivity:
```bash
# === TEST — Google/Gemini API ===
if [ "$AI_PROVIDER" = "google" ]; then
  echo "=== TEST — Google/Gemini API ==="
  echo -n "  API Key set: "
  if [ -n "${GOOGLE_API_KEY:-}" ]; then
    pass "Yes (${#GOOGLE_API_KEY} chars)"
  else
    fail "GOOGLE_API_KEY not set"
  fi

  echo -n "  Gemini API reachable: "
  GEMINI_HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
    "https://generativelanguage.googleapis.com/v1beta/models?key=$GOOGLE_API_KEY" 2>/dev/null || echo "000")
  if [ "$GEMINI_HTTP" = "200" ]; then
    pass "HTTP 200"
  else
    fail "HTTP $GEMINI_HTTP"
  fi

  echo -n "  Service account: "
  if [ -f "$BASE_PATH/service-account.json" ]; then
    pass "Found at $BASE_PATH/service-account.json"
  else
    warn "service-account.json not found (needed for Vertex AI SDK and Cloud SQL Proxy)"
  fi
  echo ""
fi
```

Update Test 5 (Open WebUI) — replace Ollama URL check with provider-aware check:
```bash
# Inside Test 5, replace the OLLAMA_BASE_URL check with:
if [ "$AI_PROVIDER" = "google" ]; then
  WEBUI_API_URL=$(_docker inspect openwebui --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep "OPENAI_API_BASE_URL" | cut -d= -f2)
  if [ -n "$WEBUI_API_URL" ]; then
    pass "OPENAI_API_BASE_URL set to: $WEBUI_API_URL"
  else
    warn "OPENAI_API_BASE_URL not set — WebUI may not reach Gemini"
  fi
else
  # Existing OLLAMA_BASE_URL check
  ...
fi
```

Update Test 6 (WebUI ↔ Ollama) — skip or replace when using Google:
```bash
if [ "$AI_PROVIDER" = "google" ]; then
  echo "=== TEST 6 — WebUI → Gemini Connectivity ==="
  # Test via Open WebUI's model list endpoint
  WEBUI_HTTP=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://localhost:3000 2>/dev/null)
  if [ "$WEBUI_HTTP" = "200" ] || [ "$WEBUI_HTTP" = "303" ]; then
    pass "WebUI responding (Gemini connection configured via admin UI)"
  else
    fail "WebUI not responding (HTTP $WEBUI_HTTP)"
  fi
else
  # Existing Ollama connectivity test
  ...
fi
```

Update Test 8 (PostgreSQL) — handle Cloud SQL:
```bash
echo "=== TEST 8 — PostgreSQL ==="
DB_HOST="${DB_HOST:-localhost}"

if [ "$DB_HOST" = "localhost" ] || [ "$DB_HOST" = "cloud-sql-proxy" ]; then
  # Check Docker container (local postgres or cloud-sql-proxy)
  CONTAINER_NAME="postgres"
  [ "$DB_HOST" = "cloud-sql-proxy" ] && CONTAINER_NAME="cloud-sql-proxy"

  if _docker ps --filter "name=^${CONTAINER_NAME}$" --filter "status=running" --format "{{.Names}}" 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
    pass "$CONTAINER_NAME container is running"
  else
    fail "$CONTAINER_NAME container is NOT running"
  fi
else
  # Remote Cloud SQL — test direct connection
  echo -n "  Cloud SQL ($DB_HOST): "
  if pg_isready -h "$DB_HOST" -p "${DB_PORT:-5432}" -U "${DB_USER:-admin}" 2>/dev/null; then
    pass "Reachable"
  else
    fail "Not reachable at $DB_HOST:${DB_PORT:-5432}"
  fi
fi
```

---

**customize_ui_n8n.sh changes:**

The n8n workflow templates generated in Phase E contain placeholder nodes that reference "OpenClaw execution." On GCP, these should reference Gemini instead.

Update the `create_workflow()` function's response message:
```bash
# Change the respondWith body from:
"responseBody": "={{ { success: true, message: 'Workflow template received request. Connect this node to OpenClaw execution.', data: $json } }}"

# To (provider-aware):
if [ "$AI_PROVIDER" = "google" ]; then
  EXECUTION_NOTE="Connect this node to Gemini via HTTP Request or n8n Google Vertex AI node."
else
  EXECUTION_NOTE="Connect this node to OpenClaw execution."
fi
"responseBody": "={{ { success: true, message: 'Workflow template received. ${EXECUTION_NOTE}', data: $json } }}"
```

Update the IMPORT_NOTES.md generation to reference Gemini:
```bash
# Add to the "Next Integration Step" section:
if [ "$AI_PROVIDER" = "google" ]; then
  INTEGRATION_NOTES="
## Next Integration Step

Replace the placeholder response with one of:

- n8n Google Vertex AI node (native, handles auth via service account)
- HTTP Request node calling Gemini API:
  POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\$GOOGLE_API_KEY
- Code node using @google-cloud/vertexai npm package"
else
  INTEGRATION_NOTES="
## Next Integration Step

Replace the placeholder response with one of:

- Execute Command node calling OpenClaw CLI
- HTTP Request node calling OpenClaw gateway/API
- Local middleware endpoint that calls OpenClaw"
fi
```

---

### 17. SECURITY & GITIGNORE

The `service-account.json` file contains GCP credentials and must NEVER be committed to the repository.

Add to `.gitignore`:
```
service-account.json
*.json.key
```

Verify the existing `.gitignore` already excludes `.env` (it does based on the project structure).

For production (post-hackathon), migrate from service account key files to:
- **Workload Identity Federation** (keyless auth for Compute Engine)
- **Attached service account** on the VM (SDK auto-discovers, no key file needed)

For hackathon speed, the key file approach is acceptable.

---

### 18. BACKUP STRATEGY FOR GCP

Replace local `backups/` directory with Cloud Storage:

```bash
# backup_to_gcs.sh — daily cron job
#!/bin/bash
set -euo pipefail

BASE_PATH="/opt/business-assistant-box"
BUCKET="gs://bab-backups-${GOOGLE_PROJECT_ID}"
TIMESTAMP=$(date +%Y%m%d)
ACTIVE_CLIENT="${ACTIVE_CLIENT:-demo-company}"

# Load env
source "$BASE_PATH/.env"

# 1. Database dump
echo "Dumping database..."
if [ "$DB_HOST" = "cloud-sql-proxy" ] || [ "$DB_HOST" = "localhost" ]; then
  docker exec postgres pg_dump -U admin businessassistant | gzip > /tmp/db-${TIMESTAMP}.sql.gz
else
  PGPASSWORD="$DB_PASSWORD" pg_dump -h "$DB_HOST" -U "$DB_USER" "$DB_NAME" | gzip > /tmp/db-${TIMESTAMP}.sql.gz
fi

# 2. Vault files
echo "Archiving vault..."
tar czf /tmp/vault-${TIMESTAMP}.tar.gz -C "$BASE_PATH" clients/ vault/ system/

# 3. Upload to Cloud Storage
echo "Uploading to $BUCKET..."
gsutil cp /tmp/db-${TIMESTAMP}.sql.gz "${BUCKET}/${ACTIVE_CLIENT}/db-${TIMESTAMP}.sql.gz"
gsutil cp /tmp/vault-${TIMESTAMP}.tar.gz "${BUCKET}/${ACTIVE_CLIENT}/vault-${TIMESTAMP}.tar.gz"

# 4. Cleanup local
rm -f /tmp/db-${TIMESTAMP}.sql.gz /tmp/vault-${TIMESTAMP}.tar.gz

# 5. Retention: delete backups older than 30 days
gsutil ls "${BUCKET}/${ACTIVE_CLIENT}/" | while read -r file; do
  FILE_DATE=$(echo "$file" | grep -oP '\d{8}' | tail -1)
  if [ -n "$FILE_DATE" ]; then
    DAYS_OLD=$(( ($(date +%s) - $(date -d "$FILE_DATE" +%s)) / 86400 ))
    if [ "$DAYS_OLD" -gt 30 ]; then
      gsutil rm "$file"
    fi
  fi
done

echo "Backup complete."
```

Create the Cloud Storage bucket:
```bash
gcloud storage buckets create gs://bab-backups-${GOOGLE_PROJECT_ID} \
  --location=us-central1 \
  --default-storage-class=STANDARD \
  --uniform-bucket-level-access
```

Add to crontab on the Compute Engine VM:
```bash
# Daily at 2 AM
0 2 * * * /opt/business-assistant-box/admin/backup_to_gcs.sh >> /opt/business-assistant-box/logs/backup.log 2>&1
```

---

### 19. GOOGLE_APPLICATION_CREDENTIALS CLARIFICATION

Two authentication paths exist. The prompt must clarify which to use:

**On Compute Engine VM with attached service account (preferred):**
- The Google SDK auto-discovers credentials from the VM metadata
- No `service-account.json` needed on the host
- Python scripts just call `aiplatform.init(project=..., location=...)` and it works
- BUT: Docker containers don't inherit VM metadata unless you pass the token

**In Docker containers (required for Cloud SQL Proxy, optional for Python):**
- Mount `service-account.json` into the container
- Set `GOOGLE_APPLICATION_CREDENTIALS=/config/credentials.json`
- This is what `docker-compose.gcloud.yml` already does for cloud-sql-proxy

**For the RAG Python scripts (index_vault.py, query_vault.py):**
- If running directly on the VM (not in Docker): no key file needed, SDK auto-discovers
- If running inside the `rag-indexer` Docker container: mount the key file
- Add to both scripts:
```python
import os
# Set credentials path if running in Docker
if os.path.exists("/config/credentials.json"):
    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "/config/credentials.json"
```

**For the .env:**
```env
# Only needed if running Python scripts in Docker or on a machine without attached SA
GOOGLE_APPLICATION_CREDENTIALS=/opt/business-assistant-box/service-account.json
```

---

### 21. OBSIDIAN ON GCP (OPTIONAL — ADMIN ONLY)

The current local setup runs Obsidian as a Docker container (`lscr.io/linuxserver/obsidian`) accessible at port 3010 for browser-based markdown editing. On GCP, this is set to `OBSIDIAN_ENABLED=false` by default because:

- VNC-over-browser to a remote VM is laggy for editing
- Exposes unnecessary attack surface if port is public
- Cloud customers use the Vault Builder wizard instead (SaaS layer)
- You can edit vault files via SSH + nano/vim directly on the VM

**If you still want Obsidian for your own admin editing on GCP:**

Add to `docker-compose.gcloud.yml` (bind to localhost only — never expose publicly):
```yaml
  obsidian:
    image: lscr.io/linuxserver/obsidian:latest
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Chicago
    ports:
      - "127.0.0.1:3010:3000"  # localhost only — access via SSH tunnel
    volumes:
      - ./clients/${ACTIVE_CLIENT}:/vault
      - ./docker/obsidian-config:/config
    networks:
      - internal
```

**Access via SSH tunnel (secure, no public port):**
```bash
gcloud compute ssh bab-prod -- -L 3010:localhost:3010
# Then open http://localhost:3010 in your local browser
```

**Do NOT:**
- Add a Traefik route for Obsidian (no public subdomain)
- Expose port 3010 in GCP firewall rules
- Give customers access to Obsidian (they use Vault Builder)

**When to use Obsidian on GCP:**
- Initial vault setup for a new client (before Vault Builder exists)
- Quick edits to system files or procedures
- Debugging RAG issues by reviewing indexed content visually

**When NOT to use Obsidian on GCP:**
- Customer-facing editing (use Vault Builder)
- Production operations (use n8n + Open WebUI)
- Anything that could be done via `vim` over SSH

**install.sh behavior:**
- If `OBSIDIAN_ENABLED=false` in `.env`, Phase 9 (Obsidian Docker) is skipped entirely
- If you later set `OBSIDIAN_ENABLED=true` and re-run, it will create the container with localhost-only binding
- Update Phase 9 to use `127.0.0.1:3010:3000` instead of `3010:3000` when `DB_HOST != localhost` (indicates cloud deployment)

```bash
# Add to install.sh Phase 9, inside the docker run command:
if [ "${DB_HOST:-localhost}" != "localhost" ]; then
  # Cloud deployment — bind Obsidian to localhost only (SSH tunnel access)
  OBSIDIAN_PORT_BINDING="127.0.0.1:3010:3000"
  echo "  Cloud deployment detected — Obsidian bound to localhost only."
  echo "  Access via: gcloud compute ssh $(hostname) -- -L 3010:localhost:3010"
else
  # Local deployment — bind to all interfaces
  OBSIDIAN_PORT_BINDING="3010:3000"
fi

_docker run -d --name obsidian \
  --restart unless-stopped \
  -e PUID=$(id -u) \
  -e PGID=$(id -g) \
  -e TZ=$(cat /etc/timezone 2>/dev/null || echo "America/Chicago") \
  -p "$OBSIDIAN_PORT_BINDING" \
  -p 127.0.0.1:3011:3001 \
  -v "$BASE_PATH/docker/obsidian-config:/config" \
  -v "${RESOLVED_VAULT}:/vault" \
  lscr.io/linuxserver/obsidian:latest
```

---

### 20. DB_HOST CONSISTENCY CHECK

The `docker-compose.gcloud.yml` uses `cloud-sql-proxy` as a sidecar container. The Python scripts and shell scripts must all resolve to the same host.

**Rule:**
- Inside Docker network: `DB_HOST=cloud-sql-proxy` (containers talk to the proxy container)
- Outside Docker (running scripts directly on VM): `DB_HOST=localhost` (proxy exposes port 5432 to host via port mapping)

Update `docker-compose.gcloud.yml` to expose proxy port to host:
```yaml
  cloud-sql-proxy:
    image: gcr.io/cloud-sql-connectors/cloud-sql-proxy:2
    command:
      - "${GOOGLE_PROJECT_ID}:${GOOGLE_LOCATION}:bab-db"
      - "--address=0.0.0.0"
      - "--port=5432"
    ports:
      - "5432:5432"  # Expose to host for scripts running outside Docker
    volumes:
      - ./service-account.json:/config/credentials.json:ro
    environment:
      - GOOGLE_APPLICATION_CREDENTIALS=/config/credentials.json
    networks:
      - internal
```

This means:
- `.env` for Docker services: `DB_HOST=cloud-sql-proxy`
- `.env` for host scripts (index_vault.py run directly): `DB_HOST=localhost`

Resolve by making Python scripts check both:
```python
DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": int(os.getenv("DB_PORT", "5432")),
    "user": os.getenv("DB_USER", "admin"),
    "password": os.getenv("DB_PASSWORD", "strongpassword"),
    "dbname": os.getenv("DB_NAME", "businessassistant"),
}
```

This replaces the current hardcoded `DB_CONFIG` in both `index_vault.py` and `query_vault.py`.

---

## DEPENDENCIES ON SAAS SALES LAYER

After this prompt is complete, the SaaS Sales Layer prompt needs these updates:
- Replace all "Digital Ocean" references with "Google Cloud"
- Replace "Coolify" with direct Docker Compose on Compute Engine (or use Cloud Run)
- Replace "DO Spaces" with "Cloud Storage" for backups
- Replace "Ollama shared service" with "Gemini API (shared API key)"
- Provisioning script calls `gcloud` instead of `doctl`
- Health monitoring uses Cloud Monitoring instead of custom polling

These changes are noted here so the SaaS Sales Layer prompt can be updated accordingly before execution.
