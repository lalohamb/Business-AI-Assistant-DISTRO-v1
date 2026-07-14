# Business Assistant Box — Google Cloud Complete Build Task List

---

## PHASE 0 — PREREQUISITES (Complete Before Any Build Steps)

### 0-1. Development Environment (VS Code + Extensions)

- [ ] 0-1.1 — Install VS Code (if not already installed)
  ```bash
  sudo snap install code --classic
  ```
- [ ] 0-1.2 — Install required VS Code extensions:
  ```bash
  code --install-extension googlecloudtools.cloudcode
  code --install-extension ms-vscode-remote.remote-ssh
  code --install-extension ms-azuretools.vscode-docker
  code --install-extension ckolkman.vscode-postgres
  code --install-extension amazonwebservices.amazon-q-vscode
  ```

  | Extension | Purpose |
  |-----------|--------|
  | Cloud Code (Google) | GCP Explorer sidebar, deploy helpers, Cloud Logging viewer |
  | Remote - SSH | Edit files directly on GCP VM from VS Code |
  | Docker | Manage containers visually, compose support |
  | PostgreSQL | Query Cloud SQL directly from VS Code |
  | Amazon Q | AI assistant for build guidance |

- [ ] 0-1.3 — Open the project workspace in VS Code:
  ```bash
  code /home/laloahambrickday/Documents/.nativeblackbox/opt/business-assistant-box
  ```
- [ ] 0-1.4 — Set up 3 terminal layout in VS Code (Ctrl+Shift+`):
  - Terminal 1: `gcloud` commands (GCP provisioning)
  - Terminal 2: Docker / local testing
  - Terminal 3: Logs / file watching
- [ ] 0-1.5 — Pin `admin/Googl-0002.md` as your checklist tab

### 0-2. GitHub Repository

- [ ] 0-2.1 — Initialize git (if not already done):
  ```bash
  cd /home/laloahambrickday/Documents/.nativeblackbox
  git init
  ```
- [ ] 0-2.2 — Verify `.gitignore` contains these entries:
  ```
  service-account.json
  *.json.key
  .env
  n8n/database.sqlite*
  n8n/database.sqlite-shm
  n8n/database.sqlite-wal
  node_modules/
  .next/
  __pycache__/
  *.pyc
  vector-db/venv/
  backups/
  logs/*.log
  ```
- [ ] 0-2.3 — Create GitHub repository:
  - Go to https://github.com/new
  - Name: `nativeblackbox` (or your preferred name)
  - Visibility: Private (share with judges later)
- [ ] 0-2.4 — Push initial commit:
  ```bash
  git add .
  git commit -m "Initial commit — Business Assistant Box"
  git branch -M main
  git remote add origin git@github.com:YOUR_USERNAME/nativeblackbox.git
  git push -u origin main
  ```
- [ ] 0-2.5 — Share repo with hackathon judges:
  - Settings → Collaborators → Add: `testing@devpost.com`
  - Settings → Collaborators → Add: `judging@hacker.fund`

### 0-3. Google Account & Billing

- [ ] 0-3.1 — Create or select a Google account for the project
- [ ] 0-3.2 — Navigate to https://console.cloud.google.com
- [ ] 0-3.3 — Set up a Billing Account (credit card required)
- [ ] 0-3.4 — Activate $300 free trial credits (new accounts only)
- [ ] 0-3.5 — Set a budget alert at $50, $100, $150 thresholds (Billing → Budgets & Alerts)

### 0-4. Install Local Tools

- [ ] 0-4.1 — Install Google Cloud SDK (`gcloud` CLI)
  ```bash
  curl https://sdk.cloud.google.com | bash
  exec -l $SHELL
  gcloud init
  ```
- [ ] 0-4.2 — Authenticate gcloud
  ```bash
  gcloud auth login
  ```
- [ ] 0-4.3 — Install `gsutil` (included with gcloud SDK)
- [ ] 0-4.4 — Install Docker locally (for testing compose files before deploy)
  ```bash
  docker --version  # verify already installed
  ```
- [ ] 0-4.5 — Install `jq` (JSON parsing for scripts)
  ```bash
  sudo apt install -y jq
  ```
- [ ] 0-4.6 — Install PostgreSQL client (for schema deployment and testing)
  ```bash
  sudo apt install -y postgresql-client
  ```
- [ ] 0-4.7 — Verify all tools:
  ```bash
  gcloud --version && docker --version && jq --version && psql --version && git --version
  ```

### 0-5. Google AI API Key (Needed Immediately)

- [ ] 0-5.1 — Go to https://aistudio.google.com/apikey
- [ ] 0-5.2 — Click "Create API Key" (free, no billing required for this step)
- [ ] 0-5.3 — Copy the key
- [ ] 0-5.4 — Add to local .env:
  ```bash
  sed -i 's/^GOOGLE_API_KEY=$/GOOGLE_API_KEY=your-actual-key-here/' /opt/business-assistant-box/.env
  ```
- [ ] 0-5.5 — Test the key works:
  ```bash
  curl -s "https://generativelanguage.googleapis.com/v1beta/models?key=YOUR_KEY" | jq '.models[0].name'
  ```
  Expected: `"models/gemini-2.0-flash"` or similar

**Why now?** This key enables the n8n workflows to work locally AND on GCP. The Gemini free tier (15 RPM / 1M tokens/day) is more than enough for development.

### 0-6. Domain & DNS

- [ ] 0-6.1 — Own or purchase a domain (e.g., yourdomain.com)
- [ ] 0-6.2 — Have access to DNS management (Cloudflare, Google Domains, Namecheap, etc.)
- [ ] 0-6.3 — Plan subdomain structure:
  - `demo.yourdomain.com` → Open WebUI (client chat)
  - `demo-n8n.yourdomain.com` → n8n (workflow engine)
  - `*.yourdomain.com` → wildcard for future clients
- [ ] 0-6.4 — (Optional) Set up DNS records early pointing to a placeholder IP
  - This starts propagation while you build — saves time later

### 0-7. Gather Required Information

- [ ] 0-7.1 — Choose a Google Cloud Project ID (globally unique, lowercase, hyphens allowed)
  - Example: `bab-prod-2024` or `business-assistant-box`
- [ ] 0-7.2 — Choose a region: `us-central1` (recommended — cheapest, most services)
- [ ] 0-7.3 — Choose a zone: `us-central1-a`
- [ ] 0-7.4 — Decide admin email for Let's Encrypt certificates
- [ ] 0-7.5 — Generate a strong DB password (32+ chars)
  ```bash
  openssl rand -base64 32
  ```
  Save this — you'll use it in Phase 3 and Phase 6.

### 0-8. Verify Local Environment is Running

- [ ] 0-8.1 — Confirm all local containers are up:
  ```bash
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
  ```
  Expected: `postgres`, `openwebui`, `n8n`, `obsidian` all showing "Up"

- [ ] 0-8.2 — Confirm n8n workflow templates exist:
  ```bash
  ls n8n/workflows/standard/ && ls n8n/workflows/selectable/ && cat n8n/workflows/manifest.json | python3 -c "import sys,json; print(f'{len(json.load(sys.stdin)["workflows"])} workflows in manifest')"
  ```
  Expected: 5 standard files, 10 selectable files, "15 workflows in manifest"

- [ ] 0-8.3 — Confirm .env has GOOGLE_API_KEY set:
  ```bash
  grep "^GOOGLE_API_KEY=" .env | grep -v "^GOOGLE_API_KEY=$" && echo "✅ Key set" || echo "❌ Key missing"
  ```

### 0-9. VS Code Remote-SSH Prep (For After VM is Created)

These steps are done AFTER Phase 5 (VM creation), but configure now:

- [ ] 0-9.1 — Add SSH config entry for the GCP VM (update IP after Phase 5):
  ```bash
  cat >> ~/.ssh/config << 'EOF'
  Host bab-prod
    HostName STATIC_IP_FROM_PHASE_5
    User your-username
    IdentityFile ~/.ssh/google_compute_engine
    StrictHostKeyChecking no
  EOF
  ```
- [ ] 0-9.2 — After Phase 5, connect: `Ctrl+Shift+P` → "Remote-SSH: Connect to Host" → `bab-prod`
- [ ] 0-9.3 — This gives you full VS Code editing directly on the production VM

---

**Phase 0 complete when:** VS Code is open with extensions installed, GitHub repo is pushed, Google API key is working, local containers are running, and you have your project ID + DB password ready.

**Estimated time:** 30-45 minutes

---

## PHASE 1 — Google Cloud Project & API Setup

### 1-1. Create Project

- [ ] 1-1.1 — Create the project
  ```bash
  gcloud projects create YOUR_PROJECT_ID --name="Business Assistant Box"
  ```
- [ ] 1-1.2 — Set as active project
  ```bash
  gcloud config set project YOUR_PROJECT_ID
  ```
- [ ] 1-1.3 — Link billing account
  ```bash
  gcloud billing accounts list
  gcloud billing projects link YOUR_PROJECT_ID --billing-account=BILLING_ACCOUNT_ID
  ```

### 1-2. Enable Required APIs

All of these must be enabled before any resources can be created:

- [ ] 1-2.1 — Vertex AI API (Gemini LLM + Embeddings)
  ```bash
  gcloud services enable aiplatform.googleapis.com
  ```
- [ ] 1-2.2 — Generative Language API (Gemini direct API key access)
  ```bash
  gcloud services enable generativelanguage.googleapis.com
  ```
- [ ] 1-2.3 — Cloud SQL Admin API
  ```bash
  gcloud services enable sqladmin.googleapis.com
  ```
- [ ] 1-2.4 — Compute Engine API
  ```bash
  gcloud services enable compute.googleapis.com
  ```
- [ ] 1-2.5 — Cloud Storage API
  ```bash
  gcloud services enable storage.googleapis.com
  ```
- [ ] 1-2.6 — Cloud Logging API
  ```bash
  gcloud services enable logging.googleapis.com
  ```
- [ ] 1-2.7 — Cloud Monitoring API
  ```bash
  gcloud services enable monitoring.googleapis.com
  ```
- [ ] 1-2.8 — IAM API
  ```bash
  gcloud services enable iam.googleapis.com
  ```
- [ ] 1-2.9 — Cloud Resource Manager API
  ```bash
  gcloud services enable cloudresourcemanager.googleapis.com
  ```
- [ ] 1-2.10 — Service Networking API (for Cloud SQL private IP, optional)
  ```bash
  gcloud services enable servicenetworking.googleapis.com
  ```
- [ ] 1-2.11 — Verify all APIs enabled
  ```bash
  gcloud services list --enabled --filter="NAME:(aiplatform OR generativelanguage OR sqladmin OR compute OR storage OR logging OR monitoring OR iam)"
  ```

### 1-3. Create Google AI API Key (for Gemini direct access)

- [ ] 1-3.1 — Go to https://aistudio.google.com/apikey
- [ ] 1-3.2 — Click "Create API Key"
- [ ] 1-3.3 — Select your project
- [ ] 1-3.4 — Copy the key — store securely (this is your `GOOGLE_API_KEY`)
- [ ] 1-3.5 — Test the key
  ```bash
  curl "https://generativelanguage.googleapis.com/v1beta/models?key=YOUR_API_KEY"
  ```
  Expected: JSON list of available models including `gemini-2.0-flash`

---

## PHASE 2 — IAM & Service Account

### 2-1. Create Service Account

- [ ] 2-1.1 — Create the service account
  ```bash
  gcloud iam service-accounts create bab-app \
    --display-name="Business Assistant Box App" \
    --description="Service account for BAB application services"
  ```
- [ ] 2-1.2 — Verify creation
  ```bash
  gcloud iam service-accounts list
  ```

### 2-2. Assign IAM Roles

- [ ] 2-2.1 — Vertex AI User (LLM + Embeddings)
  ```bash
  gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:bab-app@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/aiplatform.user"
  ```
- [ ] 2-2.2 — Cloud SQL Client (database connections)
  ```bash
  gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:bab-app@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/cloudsql.client"
  ```
- [ ] 2-2.3 — Cloud Storage Object Admin (backups read/write)
  ```bash
  gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:bab-app@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/storage.objectAdmin"
  ```
- [ ] 2-2.4 — Logs Writer (application logging)
  ```bash
  gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:bab-app@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/logging.logWriter"
  ```
- [ ] 2-2.5 — Monitoring Metric Writer (custom metrics)
  ```bash
  gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:bab-app@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/monitoring.metricWriter"
  ```

### 2-3. Generate Service Account Key

- [ ] 2-3.1 — Download key file
  ```bash
  gcloud iam service-accounts keys create service-account.json \
    --iam-account=bab-app@YOUR_PROJECT_ID.iam.gserviceaccount.com
  ```
- [ ] 2-3.2 — Verify key file exists and is valid JSON
  ```bash
  cat service-account.json | jq .client_email
  ```
- [ ] 2-3.3 — SECURITY: Add to .gitignore immediately
  ```bash
  echo "service-account.json" >> .gitignore
  echo "*.json.key" >> .gitignore
  ```
- [ ] 2-3.4 — Store a backup of the key in a secure location (password manager, not cloud storage)

---

## PHASE 3 — Cloud SQL (Database)

### 3-1. Provision Cloud SQL Instance

- [ ] 3-1.1 — Create PostgreSQL 16 instance with pgvector
  ```bash
  gcloud sql instances create bab-db \
    --database-version=POSTGRES_16 \
    --tier=db-custom-2-4096 \
    --region=us-central1 \
    --storage-size=20GB \
    --storage-auto-increase \
    --database-flags=cloudsql.enable_pgvector=on \
    --availability-type=zonal \
    --backup-start-time=04:00 \
    --enable-bin-log
  ```
  ⏱️ This takes 5-10 minutes.

- [ ] 3-1.2 — Verify instance is running
  ```bash
  gcloud sql instances describe bab-db --format="value(state)"
  ```
  Expected: `RUNNABLE`

### 3-2. Create Database & User

- [ ] 3-2.1 — Create the main database
  ```bash
  gcloud sql databases create businessassistant --instance=bab-db
  ```
- [ ] 3-2.2 — Create the n8n database
  ```bash
  gcloud sql databases create n8n --instance=bab-db
  ```
- [ ] 3-2.3 — Create the openwebui database
  ```bash
  gcloud sql databases create openwebui --instance=bab-db
  ```
- [ ] 3-2.4 — Create the admin user
  ```bash
  gcloud sql users create admin \
    --instance=bab-db \
    --password=YOUR_GENERATED_PASSWORD
  ```

### 3-3. Deploy Schema

- [ ] 3-3.1 — Get Cloud SQL connection name
  ```bash
  gcloud sql instances describe bab-db --format="value(connectionName)"
  ```
  Save this value: `YOUR_PROJECT_ID:us-central1:bab-db`

- [ ] 3-3.2 — Connect via Cloud SQL Proxy (local) to deploy schema
  ```bash
  # Download proxy
  curl -o cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.14.0/cloud-sql-proxy.linux.amd64
  chmod +x cloud-sql-proxy

  # Start proxy in background
  ./cloud-sql-proxy YOUR_PROJECT_ID:us-central1:bab-db &

  # Deploy schema
  PGPASSWORD=YOUR_PASSWORD psql -h 127.0.0.1 -U admin -d businessassistant -f vector-db/schema.sql
  ```

- [ ] 3-3.3 — Verify pgvector extension active
  ```bash
  PGPASSWORD=YOUR_PASSWORD psql -h 127.0.0.1 -U admin -d businessassistant -c "SELECT extname FROM pg_extension WHERE extname='vector';"
  ```

- [ ] 3-3.4 — Verify tables created
  ```bash
  PGPASSWORD=YOUR_PASSWORD psql -h 127.0.0.1 -U admin -d businessassistant -c "\dt"
  ```
  Expected: `rag_documents` and `rag_chunks` tables

- [ ] 3-3.5 — Kill the local proxy
  ```bash
  kill %1
  ```

---

## PHASE 4 — Cloud Storage (Backups)

### 4-1. Create Backup Bucket

- [ ] 4-1.1 — Create the bucket
  ```bash
  gcloud storage buckets create gs://bab-backups-YOUR_PROJECT_ID \
    --location=us-central1 \
    --default-storage-class=STANDARD \
    --uniform-bucket-level-access
  ```
- [ ] 4-1.2 — Verify bucket exists
  ```bash
  gcloud storage buckets list --filter="name:bab-backups"
  ```
- [ ] 4-1.3 — Set lifecycle rule (auto-delete after 90 days as safety net)
  ```bash
  cat > /tmp/lifecycle.json << 'EOF'
  {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {"age": 90}
      }
    ]
  }
  EOF
  gcloud storage buckets update gs://bab-backups-YOUR_PROJECT_ID --lifecycle-file=/tmp/lifecycle.json
  ```

---

## PHASE 5 — Compute Engine (VM)

### 5-1. Reserve Static IP

- [ ] 5-1.1 — Reserve external IP
  ```bash
  gcloud compute addresses create bab-ip \
    --region=us-central1
  ```
- [ ] 5-1.2 — Get the IP address
  ```bash
  gcloud compute addresses describe bab-ip --region=us-central1 --format="value(address)"
  ```
  Save this IP — you'll point DNS here.

### 5-2. Create Firewall Rules

- [ ] 5-2.1 — Allow HTTP (port 80)
  ```bash
  gcloud compute firewall-rules create allow-http \
    --allow=tcp:80 \
    --target-tags=http-server \
    --description="Allow HTTP for Let's Encrypt and redirect"
  ```
- [ ] 5-2.2 — Allow HTTPS (port 443)
  ```bash
  gcloud compute firewall-rules create allow-https \
    --allow=tcp:443 \
    --target-tags=https-server \
    --description="Allow HTTPS for all services"
  ```
- [ ] 5-2.3 — Verify rules
  ```bash
  gcloud compute firewall-rules list --filter="name:(allow-http OR allow-https)"
  ```

### 5-3. Create VM Instance

- [ ] 5-3.1 — Create the VM with attached service account
  ```bash
  gcloud compute instances create bab-prod \
    --zone=us-central1-a \
    --machine-type=e2-standard-4 \
    --image-family=ubuntu-2404-lts-amd64 \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=100GB \
    --boot-disk-type=pd-ssd \
    --tags=http-server,https-server \
    --address=bab-ip \
    --service-account=bab-app@YOUR_PROJECT_ID.iam.gserviceaccount.com \
    --scopes=cloud-platform \
    --metadata=startup-script='#!/bin/bash
      apt-get update
      apt-get install -y docker.io docker-compose-v2 git jq
      systemctl enable docker
      systemctl start docker
      usermod -aG docker $(logname 2>/dev/null || echo ubuntu)'
  ```
  ⏱️ Takes 1-2 minutes.

- [ ] 5-3.2 — Verify VM is running
  ```bash
  gcloud compute instances describe bab-prod --zone=us-central1-a --format="value(status)"
  ```
  Expected: `RUNNING`

- [ ] 5-3.3 — SSH into VM
  ```bash
  gcloud compute ssh bab-prod --zone=us-central1-a
  ```

- [ ] 5-3.4 — Verify Docker installed (may need to wait 1-2 min for startup script)
  ```bash
  docker --version
  docker compose version
  ```

### 5-4. Configure DNS

- [ ] 5-4.1 — In your DNS provider, create A records:
  - `yourdomain.com` → STATIC_IP
  - `*.yourdomain.com` → STATIC_IP (wildcard)
- [ ] 5-4.2 — Wait for DNS propagation (check with `dig`)
  ```bash
  dig demo.yourdomain.com +short
  ```
- [ ] 5-4.3 — Verify from VM
  ```bash
  curl -s ifconfig.me  # Should match your static IP
  ```

---

*Continued in next section...*


---

## PHASE 6 — Deploy Application to VM

### 6-1. Transfer Project Files

- [ ] 6-1.1 — From your local machine, copy the project to the VM
  ```bash
  gcloud compute scp --recurse \
    /opt/business-assistant-box bab-prod:/opt/ \
    --zone=us-central1-a \
    --exclude=".git,node_modules,postgres,backups,logs/*.log"
  ```
- [ ] 6-1.2 — Copy service account key to VM
  ```bash
  gcloud compute scp service-account.json bab-prod:/opt/business-assistant-box/ \
    --zone=us-central1-a
  ```
- [ ] 6-1.3 — SSH into VM
  ```bash
  gcloud compute ssh bab-prod --zone=us-central1-a
  ```
- [ ] 6-1.4 — Verify files landed
  ```bash
  ls /opt/business-assistant-box/
  ls /opt/business-assistant-box/service-account.json
  ```

### 6-2. Create Production .env

- [ ] 6-2.1 — Create the Google Cloud .env on the VM
  ```bash
  cat > /opt/business-assistant-box/.env << 'EOF'
  # ==========================================
  # Business Assistant Box — Google Cloud Config
  # ==========================================

  # AI Provider
  AI_PROVIDER=google
  GOOGLE_PROJECT_ID=YOUR_PROJECT_ID
  GOOGLE_LOCATION=us-central1
  GOOGLE_API_KEY=YOUR_GOOGLE_API_KEY
  GEMINI_MODEL=gemini-2.0-flash

  # Embeddings
  EMBEDDING_PROVIDER=google
  EMBEDDING_MODEL=text-embedding-004
  EMBEDDING_DIMENSIONS=768

  # Database (Cloud SQL via proxy)
  DB_HOST=cloud-sql-proxy
  DB_PORT=5432
  DB_USER=admin
  DB_PASSWORD=YOUR_DB_PASSWORD
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

  # Fallback
  LOCAL_LLM_ENABLED=false
  EOF
  ```
- [ ] 6-2.2 — Replace placeholders with real values
  ```bash
  sed -i 's/YOUR_PROJECT_ID/actual-project-id/g' /opt/business-assistant-box/.env
  sed -i 's/YOUR_GOOGLE_API_KEY/actual-api-key/g' /opt/business-assistant-box/.env
  sed -i 's/YOUR_DB_PASSWORD/actual-password/g' /opt/business-assistant-box/.env
  sed -i 's/yourdomain.com/actual-domain.com/g' /opt/business-assistant-box/.env
  ```
- [ ] 6-2.3 — Verify .env (no placeholders remaining)
  ```bash
  grep -n "YOUR_\|yourdomain" /opt/business-assistant-box/.env
  ```
  Expected: no output

### 6-3. Create docker-compose.gcloud.yml

- [ ] 6-3.1 — Create the compose file on the VM
  ```bash
  cat > /opt/business-assistant-box/docker-compose.gcloud.yml << 'YAML'
  version: "3.8"

  services:
    traefik:
      image: traefik:v2.11
      command:
        - "--providers.docker=true"
        - "--providers.docker.exposedbydefault=false"
        - "--entrypoints.web.address=:80"
        - "--entrypoints.websecure.address=:443"
        - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
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
      restart: unless-stopped

    cloud-sql-proxy:
      image: gcr.io/cloud-sql-connectors/cloud-sql-proxy:2
      command:
        - "${GOOGLE_PROJECT_ID}:${GOOGLE_LOCATION}:bab-db"
        - "--address=0.0.0.0"
        - "--port=5432"
      ports:
        - "5432:5432"
      volumes:
        - ./service-account.json:/config/credentials.json:ro
      environment:
        - GOOGLE_APPLICATION_CREDENTIALS=/config/credentials.json
      networks:
        - internal
      restart: unless-stopped

    openwebui:
      image: ghcr.io/open-webui/open-webui:main
      environment:
        - OPENAI_API_BASE_URL=https://generativelanguage.googleapis.com/v1beta/openai
        - OPENAI_API_KEY=${GOOGLE_API_KEY}
        - WEBUI_AUTH=true
        - DATABASE_URL=postgresql://admin:${DB_PASSWORD}@cloud-sql-proxy:5432/openwebui
      volumes:
        - webui_data:/app/backend/data
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.webui.rule=Host(`${CLIENT_SUBDOMAIN}.${DOMAIN}`)"
        - "traefik.http.routers.webui.tls.certresolver=letsencrypt"
        - "traefik.http.services.webui.loadbalancer.server.port=8080"
      networks:
        - web
        - internal
      depends_on:
        - cloud-sql-proxy
      restart: unless-stopped

    n8n:
      image: n8nio/n8n
      environment:
        - N8N_HOST=${CLIENT_SUBDOMAIN}-n8n.${DOMAIN}
        - N8N_PROTOCOL=https
        - WEBHOOK_URL=https://${CLIENT_SUBDOMAIN}-n8n.${DOMAIN}/
        - DB_TYPE=postgresdb
        - DB_POSTGRESDB_HOST=cloud-sql-proxy
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
        - "traefik.http.services.n8n.loadbalancer.server.port=5678"
      networks:
        - web
        - internal
      depends_on:
        - cloud-sql-proxy
      restart: unless-stopped

  volumes:
    letsencrypt:
    webui_data:
    n8n_data:

  networks:
    web:
    internal:
  YAML
  ```

### 6-4. Launch Docker Stack

- [ ] 6-4.1 — Navigate to project directory
  ```bash
  cd /opt/business-assistant-box
  ```
- [ ] 6-4.2 — Pull all images
  ```bash
  docker compose -f docker-compose.gcloud.yml pull
  ```
- [ ] 6-4.3 — Start all services
  ```bash
  docker compose -f docker-compose.gcloud.yml --env-file .env up -d
  ```
- [ ] 6-4.4 — Verify all containers running
  ```bash
  docker compose -f docker-compose.gcloud.yml ps
  ```
  Expected: 4 containers (traefik, cloud-sql-proxy, openwebui, n8n) all "Up"

- [ ] 6-4.5 — Check logs for errors
  ```bash
  docker compose -f docker-compose.gcloud.yml logs --tail=20
  ```
- [ ] 6-4.6 — Verify Cloud SQL Proxy connected
  ```bash
  docker compose -f docker-compose.gcloud.yml logs cloud-sql-proxy | tail -5
  ```
  Expected: "Ready for new connections"

---

## PHASE 7 — TLS & Connectivity Verification

### 7-1. Verify TLS Certificates

- [ ] 7-1.1 — Wait 1-2 minutes for Let's Encrypt provisioning
- [ ] 7-1.2 — Test Open WebUI HTTPS
  ```bash
  curl -sI https://demo.yourdomain.com | head -5
  ```
  Expected: `HTTP/2 200` or `HTTP/2 303` (redirect to login)

- [ ] 7-1.3 — Test n8n HTTPS
  ```bash
  curl -sI https://demo-n8n.yourdomain.com | head -5
  ```
  Expected: `HTTP/2 200`

- [ ] 7-1.4 — If TLS fails, check Traefik logs
  ```bash
  docker compose -f docker-compose.gcloud.yml logs traefik | grep -i "acme\|error\|challenge"
  ```

### 7-2. Verify Service Connectivity

- [ ] 7-2.1 — Test DB connectivity from host
  ```bash
  PGPASSWORD=YOUR_PASSWORD psql -h 127.0.0.1 -U admin -d businessassistant -c "SELECT 1;"
  ```
- [ ] 7-2.2 — Test Gemini API from VM
  ```bash
  source .env
  curl -s "https://generativelanguage.googleapis.com/v1beta/models?key=$GOOGLE_API_KEY" | jq '.models[0].name'
  ```
  Expected: `"models/gemini-2.0-flash"` or similar

- [ ] 7-2.3 — Test Open WebUI → Gemini (from inside container)
  ```bash
  docker exec $(docker ps -qf "name=openwebui") curl -s \
    "https://generativelanguage.googleapis.com/v1beta/openai/models" \
    -H "Authorization: Bearer $GOOGLE_API_KEY" | head -20
  ```

---

*Continued in next section...*


---

## PHASE 8 — RAG Pipeline (Embeddings + Indexing)

### 8-1. Install Python Dependencies on VM

- [ ] 8-1.1 — SSH into VM (if not already connected)
  ```bash
  gcloud compute ssh bab-prod --zone=us-central1-a
  cd /opt/business-assistant-box
  ```
- [ ] 8-1.2 — Install Python3 and venv
  ```bash
  sudo apt install -y python3 python3-venv python3-pip
  ```
- [ ] 8-1.3 — Create virtual environment
  ```bash
  python3 -m venv vector-db/venv
  source vector-db/venv/bin/activate
  ```
- [ ] 8-1.4 — Install base RAG dependencies
  ```bash
  pip install --quiet psycopg2-binary python-dotenv requests
  ```
- [ ] 8-1.5 — Install Google Cloud AI dependencies
  ```bash
  pip install --quiet google-cloud-aiplatform>=1.38.0 vertexai>=1.38.0
  ```
- [ ] 8-1.6 — Verify installation
  ```bash
  python3 -c "from vertexai.language_models import TextEmbeddingModel; print('OK')"
  ```

### 8-2. Update index_vault.py for Google Provider

- [ ] 8-2.1 — Edit `vector-db/index_vault.py` — replace `get_embedding()` function:
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
          raise NotImplementedError(f"Embedding provider '{EMBEDDING_PROVIDER}' not supported.")
  ```

- [ ] 8-2.2 — Add batch embedding function (after `get_embedding`):
  ```python
  def get_embeddings_batch(texts):
      """Batch embed multiple texts (Google supports up to 250 per call)."""
      if EMBEDDING_PROVIDER == "google":
          from google.cloud import aiplatform
          from vertexai.language_models import TextEmbeddingModel
          aiplatform.init(project=os.getenv("GOOGLE_PROJECT_ID"), location=os.getenv("GOOGLE_LOCATION"))
          model = TextEmbeddingModel.from_pretrained(EMBEDDING_MODEL)
          embeddings = model.get_embeddings(texts)
          return [e.values for e in embeddings]
      elif EMBEDDING_PROVIDER == "ollama":
          return [get_embedding(t) for t in texts]
  ```

- [ ] 8-2.3 — Replace hardcoded DB_CONFIG with env-var version:
  ```python
  DB_CONFIG = {
      "host": os.getenv("DB_HOST", "localhost"),
      "port": int(os.getenv("DB_PORT", "5432")),
      "user": os.getenv("DB_USER", "admin"),
      "password": os.getenv("DB_PASSWORD", "strongpassword"),
      "dbname": os.getenv("DB_NAME", "businessassistant"),
  }
  ```

- [ ] 8-2.4 — Add credential auto-detection at top of file:
  ```python
  import os
  if os.path.exists("/config/credentials.json"):
      os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "/config/credentials.json"
  ```

### 8-3. Update query_vault.py for Google Provider

- [ ] 8-3.1 — Apply same `get_embedding()` change as index_vault.py
- [ ] 8-3.2 — Apply same `DB_CONFIG` env-var change
- [ ] 8-3.3 — Apply same credential auto-detection block

### 8-4. Test Embedding Generation

- [ ] 8-4.1 — Test Google embeddings from VM
  ```bash
  source vector-db/venv/bin/activate
  source .env
  export GOOGLE_PROJECT_ID GOOGLE_LOCATION EMBEDDING_PROVIDER EMBEDDING_MODEL
  python3 -c "
  import os
  os.environ['GOOGLE_PROJECT_ID'] = os.getenv('GOOGLE_PROJECT_ID')
  os.environ['GOOGLE_LOCATION'] = os.getenv('GOOGLE_LOCATION')
  from google.cloud import aiplatform
  from vertexai.language_models import TextEmbeddingModel
  aiplatform.init(project=os.getenv('GOOGLE_PROJECT_ID'), location=os.getenv('GOOGLE_LOCATION'))
  model = TextEmbeddingModel.from_pretrained('text-embedding-004')
  result = model.get_embeddings(['Hello world test'])
  print(f'Dimensions: {len(result[0].values)}')
  print(f'First 5 values: {result[0].values[:5]}')
  "
  ```
  Expected: `Dimensions: 768`

### 8-5. Run Initial Vault Indexing

- [ ] 8-5.1 — Ensure DB is reachable from host (proxy exposes 5432)
  ```bash
  pg_isready -h 127.0.0.1 -p 5432 -U admin
  ```
- [ ] 8-5.2 — Set DB_HOST to localhost for host-side scripts
  ```bash
  export DB_HOST=localhost
  ```
- [ ] 8-5.3 — Run the indexer
  ```bash
  source vector-db/venv/bin/activate
  source .env
  export DB_HOST=localhost  # Override for host-side execution
  python3 vector-db/index_vault.py
  ```
- [ ] 8-5.4 — Verify chunks were indexed
  ```bash
  PGPASSWORD=$DB_PASSWORD psql -h 127.0.0.1 -U admin -d businessassistant -c \
    "SELECT client_name, COUNT(*) FROM rag_chunks GROUP BY client_name;"
  ```
  Expected: Row(s) showing chunk counts per client

- [ ] 8-5.5 — Test a RAG query
  ```bash
  python3 vector-db/query_vault.py "What services does the company offer?"
  ```
  Expected: Relevant chunks returned with similarity scores

---

## PHASE 9 — Open WebUI Configuration

### 9-1. Initial Admin Setup

- [ ] 9-1.1 — Open https://demo.yourdomain.com in browser
- [ ] 9-1.2 — Create admin account (first user becomes admin)
- [ ] 9-1.3 — Log in to admin panel

### 9-2. Connect Gemini as LLM

- [ ] 9-2.1 — Go to Admin → Settings → Connections
- [ ] 9-2.2 — Under "OpenAI API", add:
  - URL: `https://generativelanguage.googleapis.com/v1beta/openai`
  - API Key: Your GOOGLE_API_KEY
- [ ] 9-2.3 — Click "Verify Connection" — should show green checkmark
- [ ] 9-2.4 — Go to chat, verify model dropdown shows `gemini-2.0-flash`
- [ ] 9-2.5 — Send a test message: "Hello, what model are you?"
  Expected: Response mentioning Gemini

### 9-3. Register RAG Filter Function

- [ ] 9-3.1 — Go to Admin → Functions
- [ ] 9-3.2 — Click "Create Function"
- [ ] 9-3.3 — Paste contents of `dashboard/functions/business_rag_filter.py`
- [ ] 9-3.4 — Update Valves (function settings):
  - `pg_host` → `cloud-sql-proxy` (if WebUI is in Docker network) or the Cloud SQL IP
  - `pg_port` → `5432`
  - `pg_user` → `admin`
  - `pg_password` → your DB password
  - `pg_database` → `businessassistant`
  - `embedding_model` → `text-embedding-004`
  - `active_client` → `demo-company`
  - `enabled` → `true`
- [ ] 9-3.5 — Enable the function globally
- [ ] 9-3.6 — Test RAG: Ask "What is the company's main service?"
  Expected: Answer references vault content, not generic Gemini knowledge

---

*Continued in next section...*


---

## PHASE 10 — n8n Workflow Configuration

### 10-1. Initial n8n Setup

- [ ] 10-1.1 — Open https://demo-n8n.yourdomain.com in browser
- [ ] 10-1.2 — Create admin account (first user becomes owner)
- [ ] 10-1.3 — Go to Settings → API → Create API Key
- [ ] 10-1.4 — Save API key to .env on VM:
  ```bash
  echo "N8N_API_KEY=your-n8n-api-key" >> /opt/business-assistant-box/.env
  ```

### 10-2. Verify Workflow Template Library Exists

The workflow JSON templates are pre-built and live at `n8n/workflows/`. They are already configured for Gemini (no Ollama conversion needed).

- [ ] 10-2.1 — Verify template files are on the VM:
  ```bash
  ls /opt/business-assistant-box/n8n/workflows/standard/
  ls /opt/business-assistant-box/n8n/workflows/selectable/
  cat /opt/business-assistant-box/n8n/workflows/manifest.json | jq '.workflows | length'
  ```
  Expected:
  - `standard/` contains: `email-triage.json`, `calendar-review.json`, `daily-briefing.json`, `approval-router.json`, `rag-query.json`
  - `selectable/` contains: `document-drafting.json`, `customer-intake.json`, `invoice-generator.json`, `lead-followup.json`, `appointment-booking.json`, `review-requester.json`, `expense-tracker.json`, `social-post-scheduler.json`, `report-generator.json`, `voicemail-transcription.json`
  - Manifest shows `15` workflows

### 10-3. Create n8n Credentials

Before importing workflows, create the credentials they reference:

- [ ] 10-3.1 — Create PostgreSQL credential in n8n UI:
  - Go to Credentials → Add Credential → Postgres
  - Name: `Cloud SQL PostgreSQL`
  - Host: `cloud-sql-proxy` (or `localhost` if running locally)
  - Port: `5432`
  - Database: `businessassistant`
  - User: `admin`
  - Password: your DB password
  - Save and test connection

- [ ] 10-3.2 — Verify GOOGLE_API_KEY is passed to n8n container:
  ```bash
  docker exec $(docker ps -qf "name=n8n") printenv GOOGLE_API_KEY | head -c 10
  ```
  Expected: First 10 chars of your API key (confirms env var is available to `{{$env.GOOGLE_API_KEY}}` in workflows)

- [ ] 10-3.3 — (Optional) Create Gmail OAuth2 credential:
  - Only needed for email-triage, daily-briefing, lead-followup, invoice-generator, review-requester workflows
  - Go to Credentials → Add Credential → Google OAuth2 API
  - Requires: Client ID + Client Secret from Google Cloud Console → APIs & Services → Credentials → OAuth 2.0 Client
  - Scopes: `gmail.readonly`, `gmail.send`

- [ ] 10-3.4 — (Optional) Create Google Calendar OAuth2 credential:
  - Only needed for calendar-review, daily-briefing, appointment-booking workflows
  - Same OAuth2 client, add scopes: `calendar.readonly`, `calendar.events`

- [ ] 10-3.5 — (Optional) Create Google Sheets OAuth2 credential:
  - Only needed for customer-intake, invoice-generator, lead-followup, expense-tracker, report-generator, voicemail-transcription workflows
  - Same OAuth2 client, add scope: `spreadsheets`

**Note:** For hackathon demo, only the PostgreSQL credential (10-3.1) is required. The approval-router and rag-query workflows work with just GOOGLE_API_KEY + PostgreSQL. Gmail/Calendar/Sheets credentials are needed only for the full production workflows.

### 10-4. Import Standard Workflows (All Clients Get These)

- [ ] 10-4.1 — Import standard workflows via API:
  ```bash
  source .env
  echo "Importing standard workflows..."
  for f in n8n/workflows/standard/*.json; do
    RESULT=$(curl -s -X POST "https://${CLIENT_SUBDOMAIN}-n8n.${DOMAIN}/api/v1/workflows" \
      -H "X-N8N-API-KEY: $N8N_API_KEY" \
      -H "Content-Type: application/json" \
      -d @"$f")
    WF_NAME=$(echo "$RESULT" | jq -r '.name // "ERROR"')
    WF_ID=$(echo "$RESULT" | jq -r '.id // "FAILED"')
    echo "  ✅ $WF_NAME (id: $WF_ID) ← $f"
  done
  ```

- [ ] 10-4.2 — Or import via n8n UI:
  - Open n8n → Workflows → Import from File
  - Import each file from `n8n/workflows/standard/`:
    - `approval-router.json` ← import FIRST (other workflows call it)
    - `rag-query.json`
    - `email-triage.json`
    - `calendar-review.json`
    - `daily-briefing.json`

### 10-5. Import Selectable Workflows (Per Client Choice)

- [ ] 10-5.1 — Import selected workflows based on client needs:
  ```bash
  # Import specific selectable workflows (example: document-drafting + customer-intake)
  SELECTED=("document-drafting" "customer-intake" "invoice-generator")
  for wf in "${SELECTED[@]}"; do
    RESULT=$(curl -s -X POST "https://${CLIENT_SUBDOMAIN}-n8n.${DOMAIN}/api/v1/workflows" \
      -H "X-N8N-API-KEY: $N8N_API_KEY" \
      -H "Content-Type: application/json" \
      -d @"n8n/workflows/selectable/${wf}.json")
    WF_NAME=$(echo "$RESULT" | jq -r '.name // "ERROR"')
    echo "  ✅ $WF_NAME ← selectable/${wf}.json"
  done
  ```

- [ ] 10-5.2 — Or import ALL selectable workflows:
  ```bash
  for f in n8n/workflows/selectable/*.json; do
    RESULT=$(curl -s -X POST "https://${CLIENT_SUBDOMAIN}-n8n.${DOMAIN}/api/v1/workflows" \
      -H "X-N8N-API-KEY: $N8N_API_KEY" \
      -H "Content-Type: application/json" \
      -d @"$f")
    WF_NAME=$(echo "$RESULT" | jq -r '.name // "ERROR"')
    echo "  ✅ $WF_NAME ← $f"
  done
  ```

### 10-6. Update Credential IDs in Imported Workflows

The template JSONs use placeholder credential IDs (`PG_CREDENTIAL_ID`, `GMAIL_CREDENTIAL_ID`, etc.). After import, update them:

- [ ] 10-6.1 — Get your actual credential IDs from n8n:
  ```bash
  curl -s "https://${CLIENT_SUBDOMAIN}-n8n.${DOMAIN}/api/v1/credentials" \
    -H "X-N8N-API-KEY: $N8N_API_KEY" | jq '.data[] | {id, name, type}'
  ```

- [ ] 10-6.2 — For each workflow that uses PostgreSQL, update the credential reference:
  - Open workflow in n8n editor
  - Click the PostgreSQL node → Credential → select "Cloud SQL PostgreSQL"
  - Save

- [ ] 10-6.3 — For workflows using Gmail/Calendar/Sheets OAuth, update similarly

**Alternative (faster):** Before importing, sed-replace placeholder IDs in the JSON files:
  ```bash
  # Get your postgres credential ID
  PG_CRED_ID=$(curl -s "https://${CLIENT_SUBDOMAIN}-n8n.${DOMAIN}/api/v1/credentials" \
    -H "X-N8N-API-KEY: $N8N_API_KEY" | jq -r '.data[] | select(.type=="postgres") | .id')

  # Replace in all workflow files before import
  sed -i "s/PG_CREDENTIAL_ID/${PG_CRED_ID}/g" n8n/workflows/standard/*.json
  sed -i "s/PG_CREDENTIAL_ID/${PG_CRED_ID}/g" n8n/workflows/selectable/*.json
  ```

### 10-7. Activate & Test Workflows

- [ ] 10-7.1 — Activate all imported workflows:
  ```bash
  # Get all workflow IDs
  WORKFLOW_IDS=$(curl -s "https://${CLIENT_SUBDOMAIN}-n8n.${DOMAIN}/api/v1/workflows" \
    -H "X-N8N-API-KEY: $N8N_API_KEY" | jq -r '.data[].id')

  # Activate each
  for WF_ID in $WORKFLOW_IDS; do
    curl -s -X PATCH "https://${CLIENT_SUBDOMAIN}-n8n.${DOMAIN}/api/v1/workflows/${WF_ID}" \
      -H "X-N8N-API-KEY: $N8N_API_KEY" \
      -H "Content-Type: application/json" \
      -d '{"active": true}' | jq '{id: .id, name: .name, active: .active}'
  done
  ```

- [ ] 10-7.2 — Test webhook-triggered workflows (no OAuth needed):
  ```bash
  N8N_URL="https://${CLIENT_SUBDOMAIN}-n8n.${DOMAIN}"
  WEBHOOKS=("approval-router" "rag-query" "create-document" "customer-intake" "generate-invoice" "book-appointment" "request-review" "track-expense" "voicemail")

  echo "Testing webhook endpoints..."
  for wh in "${WEBHOOKS[@]}"; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
      -X POST "${N8N_URL}/webhook/business/${wh}" \
      -H "Content-Type: application/json" \
      -d '{"client":"demo-company","test":true}')
    echo "  business/${wh}: HTTP ${HTTP_CODE}"
  done
  ```
  Expected: All return `200` (webhook registered and responding)

- [ ] 10-7.3 — Test the approval-router specifically (core workflow):
  ```bash
  curl -s -X POST "${N8N_URL}/webhook/business/approval-router" \
    -H "Content-Type: application/json" \
    -d '{"type": "test", "message": "Hackathon validation", "requires_approval": true}' | jq .
  ```
  Expected: JSON response with `success: true`, `status: "pending"`, and a Gemini-generated summary

- [ ] 10-7.4 — Test the rag-query workflow:
  ```bash
  curl -s -X POST "${N8N_URL}/webhook/business/rag-query" \
    -H "Content-Type: application/json" \
    -d '{"query": "What services does the company offer?", "client": "demo-company"}' | jq .
  ```
  Expected: JSON response with `answer` (from Gemini + RAG context) and `sources` array

- [ ] 10-7.5 — Verify cron-triggered workflows are scheduled:
  ```bash
  curl -s "https://${CLIENT_SUBDOMAIN}-n8n.${DOMAIN}/api/v1/workflows" \
    -H "X-N8N-API-KEY: $N8N_API_KEY" | jq '.data[] | select(.active==true) | {name, active}'
  ```
  Expected: email-triage (every 5 min), calendar-review (daily 7AM), daily-briefing (weekdays 6:30AM) all show `active: true`

### 10-8. Workflow Architecture Reference

```
n8n/workflows/
├── manifest.json                    ← metadata: names, tiers, required credentials, schedules
├── standard/                        ← ALL clients get these (5 workflows)
│   ├── approval-router.json         ← webhook: gates sensitive actions for human review
│   ├── rag-query.json               ← webhook: embed → pgvector search → Gemini answer
│   ├── email-triage.json            ← cron 5min: Gmail poll → classify → draft response
│   ├── calendar-review.json         ← cron daily: check conflicts, suggest prep
│   └── daily-briefing.json          ← cron weekdays: compile priorities + action items
└── selectable/                      ← client picks based on business needs (10 workflows)
    ├── document-drafting.json       ← webhook: generate contracts/proposals/letters
    ├── customer-intake.json         ← webhook: process new client → Sheets → welcome email
    ├── invoice-generator.json       ← webhook: create invoice → log → approve → send
    ├── lead-followup.json           ← cron daily: nurture sequences for active leads
    ├── appointment-booking.json     ← webhook: check availability → book → confirm
    ├── review-requester.json        ← webhook: draft post-service review request
    ├── expense-tracker.json         ← webhook: receipt OCR (Gemini vision) → log
    ├── social-post-scheduler.json   ← cron MWF: generate social content from vault
    ├── report-generator.json        ← cron weekly: business summary with metrics
    └── voicemail-transcription.json ← webhook: audio → Gemini transcription → route
```

**Key design decisions:**
- All workflows use `{{$env.GOOGLE_API_KEY}}` — single credential swap per tenant
- All sensitive outputs route through approval-router (human gate)
- Workflows are Gemini-native (no Ollama conversion needed on GCP)
- Credential IDs are placeholders — replaced during provisioning per tenant
- Each workflow tagged `standard` or `selectable` for filtering

---

## PHASE 11 — Backup System

### 11-1. Create Backup Script on VM

- [ ] 11-1.1 — Create the backup script
  ```bash
  cat > /opt/business-assistant-box/admin/backup_to_gcs.sh << 'EOF'
  #!/bin/bash
  set -euo pipefail

  BASE_PATH="/opt/business-assistant-box"
  source "$BASE_PATH/.env"

  BUCKET="gs://bab-backups-${GOOGLE_PROJECT_ID}"
  TIMESTAMP=$(date +%Y%m%d-%H%M)
  CLIENT="${ACTIVE_CLIENT:-demo-company}"

  echo "[$(date)] Starting backup..."

  # 1. Database dump via proxy
  echo "  Dumping database..."
  PGPASSWORD="$DB_PASSWORD" pg_dump -h 127.0.0.1 -U "$DB_USER" "$DB_NAME" | gzip > /tmp/db-${TIMESTAMP}.sql.gz

  # 2. Vault archive
  echo "  Archiving vault..."
  tar czf /tmp/vault-${TIMESTAMP}.tar.gz -C "$BASE_PATH" clients/ vault/ system/

  # 3. Upload
  echo "  Uploading to ${BUCKET}..."
  gsutil -q cp /tmp/db-${TIMESTAMP}.sql.gz "${BUCKET}/${CLIENT}/db-${TIMESTAMP}.sql.gz"
  gsutil -q cp /tmp/vault-${TIMESTAMP}.tar.gz "${BUCKET}/${CLIENT}/vault-${TIMESTAMP}.tar.gz"

  # 4. Cleanup
  rm -f /tmp/db-${TIMESTAMP}.sql.gz /tmp/vault-${TIMESTAMP}.tar.gz

  # 5. Prune backups older than 30 days
  CUTOFF=$(date -d "30 days ago" +%Y%m%d 2>/dev/null || date -v-30d +%Y%m%d)
  gsutil ls "${BUCKET}/${CLIENT}/" 2>/dev/null | while read -r file; do
    FILE_DATE=$(echo "$file" | grep -oP '\d{8}' | head -1)
    if [ -n "$FILE_DATE" ] && [ "$FILE_DATE" -lt "$CUTOFF" ]; then
      gsutil -q rm "$file"
      echo "  Pruned: $file"
    fi
  done

  echo "[$(date)] Backup complete."
  EOF
  chmod +x /opt/business-assistant-box/admin/backup_to_gcs.sh
  ```

### 11-2. Install psql Client on VM (for pg_dump)

- [ ] 11-2.1 — Install PostgreSQL client
  ```bash
  sudo apt install -y postgresql-client
  ```
- [ ] 11-2.2 — Test pg_dump works
  ```bash
  source /opt/business-assistant-box/.env
  PGPASSWORD=$DB_PASSWORD pg_dump -h 127.0.0.1 -U $DB_USER $DB_NAME | head -5
  ```

### 11-3. Test Backup

- [ ] 11-3.1 — Run backup manually
  ```bash
  /opt/business-assistant-box/admin/backup_to_gcs.sh
  ```
- [ ] 11-3.2 — Verify files in bucket
  ```bash
  gsutil ls gs://bab-backups-YOUR_PROJECT_ID/demo-company/
  ```

### 11-4. Schedule Daily Backup

- [ ] 11-4.1 — Add cron job
  ```bash
  (crontab -l 2>/dev/null; echo "0 2 * * * /opt/business-assistant-box/admin/backup_to_gcs.sh >> /opt/business-assistant-box/logs/backup.log 2>&1") | crontab -
  ```
- [ ] 11-4.2 — Verify cron entry
  ```bash
  crontab -l | grep backup
  ```

---

## PHASE 12 — Monitoring & Logging

### 12-1. Verify Cloud Logging

- [ ] 12-1.1 — Go to https://console.cloud.google.com/logs
- [ ] 12-1.2 — Filter by resource: Compute Engine → bab-prod
- [ ] 12-1.3 — Verify VM startup logs appear
- [ ] 12-1.4 — Filter by API: `aiplatform.googleapis.com`
- [ ] 12-1.5 — Make a Gemini API call, verify it appears in logs

### 12-2. Create Monitoring Dashboard

- [ ] 12-2.1 — Go to https://console.cloud.google.com/monitoring/dashboards
- [ ] 12-2.2 — Click "Create Dashboard" → name: "Business Assistant Box"
- [ ] 12-2.3 — Add widgets:
  - **Compute Engine CPU** — Metric: `compute.googleapis.com/instance/cpu/utilization`
  - **Compute Engine Memory** — Metric: `compute.googleapis.com/instance/memory/balloon/ram_used`
  - **Cloud SQL Connections** — Metric: `cloudsql.googleapis.com/database/postgresql/num_backends`
  - **Cloud SQL Storage** — Metric: `cloudsql.googleapis.com/database/disk/bytes_used`
  - **Vertex AI Requests** — Metric: `aiplatform.googleapis.com/prediction/online/request_count`
- [ ] 12-2.4 — Save dashboard

### 12-3. Set Up Alerts

- [ ] 12-3.1 — Go to Monitoring → Alerting → Create Policy
- [ ] 12-3.2 — Alert: VM CPU > 80% for 5 minutes
- [ ] 12-3.3 — Alert: Cloud SQL storage > 80% capacity
- [ ] 12-3.4 — Alert: VM uptime check fails (HTTPS to demo.yourdomain.com)
- [ ] 12-3.5 — Set notification channel (email to ADMIN_EMAIL)

### 12-4. Vertex AI Metrics (Hackathon Evidence)

- [ ] 12-4.1 — Go to https://console.cloud.google.com/vertex-ai
- [ ] 12-4.2 — Navigate to Model Garden → Gemini → Usage
- [ ] 12-4.3 — Verify API calls are being logged
- [ ] 12-4.4 — Screenshot the usage dashboard (save for hackathon submission)

---

## PHASE 13 — Shell Script Updates

### 13-1. Update install.sh

- [ ] 13-1.1 — Add `[3] Google/Gemini` to AI provider prompt (Phase 0B)
- [ ] 13-1.2 — Add `[3] Google/Vertex AI` to embedding provider prompt
- [ ] 13-1.3 — Add GOOGLE_PROJECT_ID, GOOGLE_LOCATION, GOOGLE_API_KEY, GEMINI_MODEL to .env generation
- [ ] 13-1.4 — Skip local PostgreSQL Docker when DB_HOST != localhost (Phase 3)
- [ ] 13-1.5 — Skip Ollama install when AI_PROVIDER=google AND EMBEDDING_PROVIDER=google (Phase 4)
- [ ] 13-1.6 — Add `google-cloud-aiplatform` and `vertexai` to pip install (Phase 8)
- [ ] 13-1.7 — Replace Ollama warmup with Vertex AI connectivity test (Phase 10)

### 13-2. Update pre_check.sh

- [ ] 13-2.1 — Add Google API Key validation
- [ ] 13-2.2 — Add Google Project ID validation
- [ ] 13-2.3 — Add Gemini API connectivity test
- [ ] 13-2.4 — Skip Ollama check when using Google provider
- [ ] 13-2.5 — Add Google vars to configuration display

### 13-3. Update configure_n8n.sh

- [ ] 13-3.1 — Add `elif AI_PROVIDER=google` middleware check (Phase 3)
- [ ] 13-3.2 — Test Google API reachability via curl

### 13-4. Update configure_rag_pipeline.sh

- [ ] 13-4.1 — Replace hardcoded `host.docker.internal` with `$DB_HOST`
- [ ] 13-4.2 — Add Google embedding provider branch (skip Ollama test)
- [ ] 13-4.3 — Update end-to-end test for Google provider

### 13-5. Update post_install_verify.sh

- [ ] 13-5.1 — Wrap Ollama tests (1-4, 6-7) in provider check
- [ ] 13-5.2 — Add Google/Gemini API test block
- [ ] 13-5.3 — Update WebUI test for OpenAI-compatible URL
- [ ] 13-5.4 — Update PostgreSQL test for Cloud SQL Proxy

### 13-6. Update post_install_client_setup.sh

- [ ] 13-6.1 — Add Google embedding credential check (Phase 6)
- [ ] 13-6.2 — Skip Ollama reachability test when EMBEDDING_PROVIDER=google

### 13-7. Update customize_ui_n8n.sh

- [ ] 13-7.1 — Change workflow placeholder text from "OpenClaw" to "Gemini" when AI_PROVIDER=google
- [ ] 13-7.2 — Update IMPORT_NOTES.md generation with Gemini integration steps

### 13-8. Update .gitignore

- [ ] 13-8.1 — Ensure these entries exist:
  ```
  service-account.json
  *.json.key
  .env
  ```

---

## PHASE 14 — Final Validation & Acceptance

### 14-1. End-to-End Smoke Tests

- [ ] 14-1.1 — **Chat works**: Open https://demo.yourdomain.com → send message → get Gemini response
- [ ] 14-1.2 — **RAG works**: Ask a business-specific question → answer references vault content
- [ ] 14-1.3 — **n8n works**: Trigger webhook → workflow executes → Gemini generates response
- [ ] 14-1.4 — **DB works**: Query rag_chunks table → rows exist with embeddings
- [ ] 14-1.5 — **Backup works**: Run backup script → files appear in Cloud Storage
- [ ] 14-1.6 — **Monitoring works**: Check Cloud Monitoring dashboard → metrics flowing
- [ ] 14-1.7 — **TLS works**: All HTTPS endpoints have valid certificates

### 14-2. Security Checklist

- [ ] 14-2.1 — service-account.json NOT in git
- [ ] 14-2.2 — .env NOT in git
- [ ] 14-2.3 — Only ports 80/443 open in firewall
- [ ] 14-2.4 — Cloud SQL has no public IP (accessed only via proxy)
- [ ] 14-2.5 — Obsidian disabled or localhost-only
- [ ] 14-2.6 — n8n has authentication enabled
- [ ] 14-2.7 — Open WebUI has authentication enabled
- [ ] 14-2.8 — Service account has minimal required roles (no Owner/Editor)

### 14-3. Performance Baseline

- [ ] 14-3.1 — Measure chat response time (should be < 3 seconds)
- [ ] 14-3.2 — Measure RAG query time (should be < 1 second)
- [ ] 14-3.3 — Measure embedding generation (should be < 500ms per text)
- [ ] 14-3.4 — Check VM resource usage
  ```bash
  htop  # CPU should be < 30% idle
  df -h  # Disk should be < 50% used
  ```

### 14-4. Hackathon Evidence Collection

- [ ] 14-4.1 — Screenshot: Vertex AI usage dashboard showing API calls
- [ ] 14-4.2 — Screenshot: Cloud Monitoring dashboard with all metrics
- [ ] 14-4.3 — Screenshot: Cloud Logging showing Gemini API call logs
- [ ] 14-4.4 — Screenshot: Open WebUI chat with RAG-enhanced response
- [ ] 14-4.5 — Screenshot: n8n workflow execution history
- [ ] 14-4.6 — Screenshot: Cloud SQL Insights showing query activity
- [ ] 14-4.7 — Export: Cloud Logging query for "last 24h of AI API calls"

### 14-5. Document Completion

- [ ] 14-5.1 — Update ARCHITECTURE.md with Google Cloud deployment model
- [ ] 14-5.2 — Update DEPLOYMENT.md with GCP-specific instructions
- [ ] 14-5.3 — Update PROJECT_STATUS.md marking migration complete
- [ ] 14-5.4 — Create CHANGELOG.md entry for Google Cloud migration

---

## QUICK REFERENCE — All Credentials & Values

| Item | Where to Get | Where to Store |
|------|-------------|----------------|
| Google Project ID | `gcloud config get-value project` | .env → GOOGLE_PROJECT_ID |
| Google API Key | https://aistudio.google.com/apikey | .env → GOOGLE_API_KEY |
| Service Account Key | `gcloud iam service-accounts keys create` | service-account.json (never in git) |
| DB Password | `openssl rand -base64 32` | .env → DB_PASSWORD |
| Cloud SQL Connection | `gcloud sql instances describe bab-db` | docker-compose → cloud-sql-proxy command |
| Static IP | `gcloud compute addresses describe bab-ip` | DNS A record |
| n8n API Key | n8n UI → Settings → API | .env → N8N_API_KEY |
| Domain | Your registrar | .env → DOMAIN |
| Admin Email | You decide | .env → ADMIN_EMAIL |

---

## ESTIMATED TIMELINE

| Phase | Duration | Depends On |
|-------|----------|-----------|
| Prerequisites | 30 min | Nothing |
| Phase 1 (Project + APIs) | 15 min | Prerequisites |
| Phase 2 (IAM) | 10 min | Phase 1 |
| Phase 3 (Cloud SQL) | 15 min + 10 min wait | Phase 2 |
| Phase 4 (Cloud Storage) | 5 min | Phase 1 |
| Phase 5 (Compute Engine) | 10 min + DNS propagation | Phase 1, DNS access |
| Phase 6 (Deploy) | 30 min | Phases 3, 4, 5 |
| Phase 7 (TLS Verify) | 10 min | Phase 6, DNS |
| Phase 8 (RAG Pipeline) | 45 min | Phase 6 |
| Phase 9 (Open WebUI) | 20 min | Phase 7 |
| Phase 10 (n8n) | 30 min | Phase 7 |
| Phase 11 (Backups) | 15 min | Phase 6 |
| Phase 12 (Monitoring) | 20 min | Phase 6 |
| Phase 13 (Script Updates) | 60 min | Phase 8 |
| Phase 14 (Validation) | 30 min | All above |
| **TOTAL** | **~5-6 hours** (excluding DNS wait) | |

---

## ROLLBACK PLAN

If anything goes critically wrong:

1. **VM broken** → Delete and recreate (data is in Cloud SQL + Cloud Storage)
   ```bash
   gcloud compute instances delete bab-prod --zone=us-central1-a
   # Re-run Phase 5 + 6
   ```

2. **Cloud SQL corrupted** → Restore from automatic backup
   ```bash
   gcloud sql backups list --instance=bab-db
   gcloud sql backups restore BACKUP_ID --restore-instance=bab-db
   ```

3. **Vault data lost** → Restore from Cloud Storage
   ```bash
   gsutil cp gs://bab-backups-PROJECT_ID/demo-company/vault-LATEST.tar.gz /tmp/
   tar xzf /tmp/vault-LATEST.tar.gz -C /opt/business-assistant-box/
   ```

4. **API key compromised** → Revoke and regenerate
   ```bash
   # Revoke at https://aistudio.google.com/apikey
   # Generate new key
   # Update .env on VM
   # Restart Docker stack
   docker compose -f docker-compose.gcloud.yml --env-file .env up -d
   ```

5. **Full abort** → Delete all resources
   ```bash
   gcloud compute instances delete bab-prod --zone=us-central1-a
   gcloud sql instances delete bab-db
   gcloud storage rm -r gs://bab-backups-YOUR_PROJECT_ID
   gcloud compute addresses delete bab-ip --region=us-central1
   gcloud compute firewall-rules delete allow-http allow-https
   ```


---
---

## ⚠️ GAP ANALYSIS — WHAT WAS MISSING

The following phases are REQUIRED for a production SaaS launch on Google Cloud but were not covered in Phases 1-14 above.

---

## PHASE 15 — Multi-Tenant Architecture (SaaS Core)

The current build (Phases 1-14) deploys a SINGLE-TENANT instance. For SaaS (users sign up → get their own environment), you need multi-tenant provisioning.

### 15-1. Decide Tenant Isolation Model

- [ ] 15-1.1 — Choose isolation strategy for Google Cloud:

  | Strategy | Pros | Cons | Recommended For |
  |----------|------|------|-----------------|
  | **A: Shared VM, per-client Docker stack** | Cheapest, fast provisioning | Noisy neighbor, single point of failure | Hackathon / MVP (1-20 clients) |
  | **B: Shared Cloud SQL, per-client schema** | Cost-efficient DB, easy backup | Complex queries, schema drift risk | Starter/Pro tiers |
  | **C: Per-client Cloud SQL instance** | Full isolation | Expensive ($51/client/mo) | Enterprise tier only |
  | **D: Per-client VM** | Total isolation | Very expensive, slow provisioning | Custom Rig tier |

  **Recommended for launch:** Strategy A (shared VM) + Strategy B (shared Cloud SQL, per-client filtering via `client_name` column — already built into RAG schema)

- [ ] 15-1.2 — For shared Cloud SQL, create additional databases per tenant:
  ```bash
  # Automated in provisioning script:
  gcloud sql databases create "tenant_${CLIENT_ID}" --instance=bab-db
  ```
  OR use single `businessassistant` DB with `client_name` column filtering (current approach)

### 15-2. Tenant Provisioning Automation

- [ ] 15-2.1 — Create provisioning script: `admin/provision_tenant.sh`
  ```bash
  #!/bin/bash
  # Usage: ./provision_tenant.sh <client_id> <subdomain> <owner_email> <plan>
  CLIENT_ID="$1"
  SUBDOMAIN="$2"
  OWNER_EMAIL="$3"
  PLAN="$4"
  DB_PASSWORD=$(openssl rand -hex 16)

  # 1. Create client vault from template
  cp -r clients/templates/ clients/${CLIENT_ID}/
  sed -i "s/{{BUSINESS_NAME}}/${CLIENT_ID}/g" clients/${CLIENT_ID}/CLIENT_PROFILE.md

  # 2. Create tenant database (or just use shared DB with client_name filter)
  PGPASSWORD=$DB_PASSWORD psql -h 127.0.0.1 -U admin -d businessassistant -c \
    "INSERT INTO tenants (business_name, subdomain, owner_email, plan, db_password, status)
     VALUES ('${CLIENT_ID}', '${SUBDOMAIN}', '${OWNER_EMAIL}', '${PLAN}', '${DB_PASSWORD}', 'provisioning');"

  # 3. Add Traefik route (dynamic via Docker labels or file provider)
  # 4. Create Open WebUI user account for tenant
  # 5. Index vault for new tenant
  source vector-db/venv/bin/activate
  ACTIVE_CLIENT=${CLIENT_ID} python3 vector-db/index_vault.py

  # 6. Update tenant status
  PGPASSWORD=$DB_PASSWORD psql -h 127.0.0.1 -U admin -d businessassistant -c \
    "UPDATE tenants SET status='active', activated_at=NOW() WHERE subdomain='${SUBDOMAIN}';"

  echo "Tenant ${CLIENT_ID} provisioned at https://${SUBDOMAIN}.yourdomain.com"
  ```

- [ ] 15-2.2 — Create de-provisioning script: `admin/deprovision_tenant.sh`
- [ ] 15-2.3 — Create tenant health check script: `admin/check_tenant_health.sh`

### 15-3. SaaS Sales Database

- [ ] 15-3.1 — Create sales database in Cloud SQL
  ```bash
  gcloud sql databases create bab_saas --instance=bab-db
  ```
- [ ] 15-3.2 — Deploy SaaS schema (tenants, tenant_users, usage_events, provisioning_log, leads tables)
- [ ] 15-3.3 — Verify tables created

### 15-4. Per-Tenant Routing

- [ ] 15-4.1 — Configure Traefik for dynamic routing (file provider or Docker labels)
- [ ] 15-4.2 — Each tenant gets: `{subdomain}.yourdomain.com` → their Open WebUI instance
- [ ] 15-4.3 — For shared VM approach: single Open WebUI instance with multi-user support
  - Open WebUI supports multiple users natively
  - Each tenant = a user group with their own RAG context (filtered by `client_name`)
- [ ] 15-4.4 — Alternative: separate Open WebUI container per tenant (more isolation, more resources)

---

## PHASE 16 — Stripe Payment Integration

### 16-1. Stripe Setup

- [ ] 16-1.1 — Create Stripe account at https://stripe.com
- [ ] 16-1.2 — Get API keys (test mode first, then live)
- [ ] 16-1.3 — Create Products and Prices:
  ```bash
  # Run once via Stripe CLI or dashboard:
  # Starter Monthly: $149/mo
  # Starter Annual: $124/mo (billed $1,488/yr)
  # Pro Monthly: $299/mo
  # Pro Annual: $249/mo (billed $2,988/yr)
  ```
- [ ] 16-1.4 — Create Stripe webhook endpoint pointing to your provisioning API
- [ ] 16-1.5 — Configure webhook events to listen for:
  - `checkout.session.completed`
  - `customer.subscription.created`
  - `customer.subscription.updated`
  - `customer.subscription.deleted`
  - `invoice.payment_failed`
  - `invoice.paid`

### 16-2. Payment Flow Implementation

- [ ] 16-2.1 — Build Stripe Checkout session creation endpoint
- [ ] 16-2.2 — Build webhook handler that triggers provisioning
- [ ] 16-2.3 — Build trial signup flow (no card required, 14-day limit)
- [ ] 16-2.4 — Test end-to-end: signup → payment → provisioning → active tenant

---

## PHASE 17 — SaaS Application Layer (Next.js)

### 17-1. Vault Builder Wizard

- [ ] 17-1.1 — Build multi-step form (Business Profile → Preferences → FAQ → Procedures → Review)
- [ ] 17-1.2 — Implement markdown generation from form inputs
- [ ] 17-1.3 — Implement document upload (PDF/DOCX → text extraction → markdown)
- [ ] 17-1.4 — Implement "Build My Assistant" → triggers RAG indexing
- [ ] 17-1.5 — Deploy on Cloud Run or same Compute Engine VM

### 17-2. Customer Admin Portal

- [ ] 17-2.1 — Build authenticated dashboard (vault management, billing, usage)
- [ ] 17-2.2 — Integrate Stripe Customer Portal for billing self-service
- [ ] 17-2.3 — Build "Re-index Now" button
- [ ] 17-2.4 — Build team management (invite/remove users)
- [ ] 17-2.5 — Build data export endpoint

### 17-3. Internal Ops Dashboard

- [ ] 17-3.1 — Build tenant list with health indicators
- [ ] 17-3.2 — Build revenue dashboard (Stripe integration)
- [ ] 17-3.3 — Build manual provisioning form (Enterprise clients)
- [ ] 17-3.4 — Build tenant suspend/archive/delete actions
- [ ] 17-3.5 — Build health monitoring cron (check all tenants every 5 min)

### 17-4. Deploy SaaS Apps

- [ ] 17-4.1 — Option A: Deploy on same Compute Engine VM (Docker containers)
- [ ] 17-4.2 — Option B: Deploy on Cloud Run (auto-scaling, pay-per-request)
- [ ] 17-4.3 — Add Traefik routes:
  - `app.yourdomain.com` → vault-builder + customer-portal
  - `ops.yourdomain.com` → internal ops dashboard (IP-restricted)

---

## PHASE 18 — Email & Notifications

### 18-1. Transactional Email Setup

- [ ] 18-1.1 — Choose provider: Resend, SendGrid, or Google Workspace SMTP
- [ ] 18-1.2 — Configure SPF, DKIM, DMARC for your domain
- [ ] 18-1.3 — Build email templates:
  - Welcome email (with login URL + vault builder link)
  - Trial reminder (day 3, 7, 10, 13)
  - Trial expiring (day 14)
  - Payment failed
  - Subscription confirmed
  - Data export ready
- [ ] 18-1.4 — Implement email sending service
- [ ] 18-1.5 — Test deliverability (check spam score)

---

## PHASE 19 — Trial Lifecycle Automation

- [ ] 19-1 — Build trial state machine:
  ```
  signup → trial_active → (payment?) → active
                        → (no payment, day 14) → frozen
                        → (no payment, day 21) → archived
                        → (no payment, day 51) → deleted
  ```
- [ ] 19-2 — Implement freeze logic (stop chat, read-only vault)
- [ ] 19-3 — Implement archive logic (stop all containers, retain data)
- [ ] 19-4 — Implement cleanup logic (delete volumes after 51 days)
- [ ] 19-5 — Schedule via cron or n8n workflow on ops infrastructure

---
---

## 🚫 WHAT WILL NOT WORK — Google Cloud vs. Local Install

| Feature | Local Install (Ollama) | Google Cloud (Gemini) | Impact |
|---------|----------------------|----------------------|--------|
| **Offline operation** | ✅ Works without internet | ❌ Requires internet for all AI calls | Cannot demo without connectivity |
| **Zero API cost** | ✅ Free after hardware purchase | ❌ Pay per token (~$3-10/mo light use) | Ongoing cost per tenant |
| **Data stays on-premise** | ✅ Never leaves the machine | ⚠️ Text sent to Google API for processing | Must disclose in privacy policy; some regulated industries (legal, medical) may object |
| **Custom model fine-tuning** | ✅ Can fine-tune local models | ⚠️ Gemini fine-tuning is limited/expensive | Less customization per client |
| **Model switching freedom** | ✅ Any GGUF/Ollama model | ⚠️ Limited to Gemini family (or pay for others via Vertex) | Vendor lock-in risk |
| **Latency** | ✅ ~200ms local inference | ⚠️ ~500-1500ms API round-trip | Slightly slower chat responses |
| **Concurrent users** | ❌ Limited by local GPU/CPU | ✅ Google scales automatically | Better for multi-tenant SaaS |
| **Embedding consistency** | ✅ Same model always available | ⚠️ Google may deprecate text-embedding-004 | Must plan for model migration |
| **Obsidian editing** | ✅ Native browser UI on localhost | ⚠️ Only via SSH tunnel (laggy) | Admins use Vault Builder instead |
| **OpenClaw agent** | ✅ Runs locally | ❌ Not available on GCP (replaced by Gemini) | Agent behavior changes |
| **n8n local execution** | ✅ Calls localhost Ollama | ⚠️ Calls external API (adds latency + cost per workflow run) | Workflow costs increase |
| **RAG filter in WebUI** | ✅ Calls local Ollama for embeddings | ⚠️ Must call Google API from inside container (needs credentials mounted) | More complex container config |
| **Unlimited tokens** | ✅ No token limits locally | ❌ Gemini has rate limits (RPM/TPM quotas) | Must implement rate limiting per tenant |
| **GPU requirement** | ❌ Needs 12GB+ VRAM | ✅ No GPU needed (API-based) | Cheaper VM, no GPU droplet |

---

## ✅ WHAT THIS GOOGLE CLOUD BUILD WILL DO

### For End Users (Business Owners — SaaS Customers):

1. **Sign up online** → choose plan (Starter $149/mo or Pro $299/mo) or start 14-day free trial
2. **Build their AI assistant** → guided Vault Builder wizard (no technical skills needed)
3. **Chat with their AI** → Open WebUI at `{their-subdomain}.yourdomain.com`, powered by Gemini 2.0 Flash
4. **AI knows their business** → RAG retrieves from their vault (procedures, FAQ, client profiles, documents)
5. **Automate workflows** → n8n handles email triage, calendar, daily briefings, document drafting, customer intake
6. **Self-manage** → admin portal for vault editing, billing, team management, data export
7. **Scale without hardware** → no GPU, no server room, just a browser

### For You (Platform Operator):

1. **Automated provisioning** → Stripe payment triggers full environment creation (< 5 min)
2. **Multi-tenant on single VM** → 10-20 clients on one e2-standard-4 ($97/mo shared)
3. **Centralized monitoring** → Cloud Monitoring dashboard shows all tenant health
4. **Automated backups** → daily to Cloud Storage, 30-day retention
5. **Revenue tracking** → Stripe + ops dashboard shows MRR, churn, conversion
6. **Trial automation** → no manual intervention for trial → paid conversion
7. **Hackathon evidence** → Vertex AI metrics, Cloud Logging, monitoring dashboards prove "AI in production"

### Technical Capabilities:

| Capability | How It Works on GCP |
|-----------|-------------------|
| LLM Chat | Gemini 2.0 Flash via OpenAI-compatible API → Open WebUI |
| RAG Retrieval | text-embedding-004 (768 dims) → Cloud SQL pgvector → cosine similarity |
| Workflow Automation | n8n → HTTP Request to Gemini API → generates drafts/summaries |
| Multi-client isolation | `client_name` column in rag_chunks + per-tenant vault directories |
| Auto-scaling AI | Google handles Gemini scaling — no GPU management |
| TLS/HTTPS | Traefik + Let's Encrypt auto-provisioned |
| Backups | Daily pg_dump + vault tar → Cloud Storage |
| Monitoring | Cloud Logging + Cloud Monitoring + Vertex AI Metrics |
| Payment | Stripe Checkout → webhook → auto-provision |
| Trial management | Automated lifecycle (freeze day 14, archive day 21, delete day 51) |

---

## 🔧 ADDITIONAL MISSING TASKS (Production Hardening)

### PHASE 20 — Rate Limiting & Quotas

- [ ] 20-1 — Implement per-tenant rate limiting on Gemini API calls
  - Trial: 50 messages/day
  - Starter: 500 messages/day
  - Pro: 2000 messages/day
  - Enterprise: custom
- [ ] 20-2 — Implement token budget per tenant (prevent runaway costs)
- [ ] 20-3 — Add rate limiting middleware to n8n webhook endpoints
- [ ] 20-4 — Monitor Vertex AI quotas (default: 60 RPM for Gemini Flash)
- [ ] 20-5 — Request quota increase if needed:
  ```bash
  # Via Google Cloud Console → IAM & Admin → Quotas
  # Or: gcloud services quota update
  ```

### PHASE 21 — Security Hardening

- [ ] 21-1 — Enable Cloud SQL SSL-only connections
- [ ] 21-2 — Restrict Cloud SQL to private IP only (no public IP)
- [ ] 21-3 — Enable VPC firewall logging
- [ ] 21-4 — Set up Cloud Armor (DDoS protection) if using Load Balancer
- [ ] 21-5 — Implement webhook signature verification (Stripe)
- [ ] 21-6 — Add CORS headers to all API endpoints
- [ ] 21-7 — Implement input sanitization on Vault Builder forms
- [ ] 21-8 — Set Content Security Policy headers
- [ ] 21-9 — Enable audit logging for all admin actions
- [ ] 21-10 — Schedule quarterly service account key rotation

### PHASE 22 — Scaling Plan

- [ ] 22-1 — Document scaling triggers:
  | Trigger | Action |
  |---------|--------|
  | VM CPU > 70% sustained | Upgrade to e2-standard-8 |
  | > 20 tenants | Add second VM + load balancer |
  | Cloud SQL connections > 80% | Upgrade tier or add read replica |
  | Gemini RPM hitting quota | Request increase or add API key rotation |
  | Storage > 80GB | Increase disk or move vault to Cloud Storage |

- [ ] 22-2 — Create VM snapshot schedule (weekly)
  ```bash
  gcloud compute resource-policies create snapshot-schedule bab-weekly \
    --region=us-central1 \
    --max-retention-days=14 \
    --weekly-schedule-day-of-week=sunday \
    --start-time=03:00
  gcloud compute disks add-resource-policies bab-prod \
    --resource-policies=bab-weekly \
    --zone=us-central1-a
  ```

### PHASE 23 — Legal & Compliance

- [ ] 23-1 — Create Terms of Service (cover AI-generated content disclaimer)
- [ ] 23-2 — Create Privacy Policy (disclose data sent to Google Gemini API)
- [ ] 23-3 — Create Data Processing Agreement (for business clients)
- [ ] 23-4 — Add cookie consent banner to marketing site
- [ ] 23-5 — Implement data export endpoint (GDPR right to portability)
- [ ] 23-6 — Implement account deletion endpoint (GDPR right to erasure)
- [ ] 23-7 — Document data retention policy (30 days after cancellation)

---

## REVISED TOTAL TIMELINE (Full SaaS Launch)

| Phase | Duration | Priority |
|-------|----------|----------|
| Phases 1-14 (Infrastructure) | 5-6 hours | 🔴 Day 1 |
| Phase 15 (Multi-tenant) | 1 day | 🔴 Day 2 |
| Phase 16 (Stripe) | 1 day | 🔴 Day 2-3 |
| Phase 17 (SaaS Apps) | 5-7 days | 🔴 Week 2 |
| Phase 18 (Email) | 0.5 day | 🟡 Week 2 |
| Phase 19 (Trial Lifecycle) | 1 day | 🟡 Week 2 |
| Phase 20 (Rate Limiting) | 0.5 day | 🟡 Week 3 |
| Phase 21 (Security) | 1 day | 🟡 Week 3 |
| Phase 22 (Scaling) | 0.5 day | 🟢 Week 3 |
| Phase 23 (Legal) | 1 day | 🟢 Week 3 |
| **TOTAL** | **~3 weeks** | |

🔴 = Must have for launch
🟡 = Must have within 2 weeks of launch
🟢 = Must have before first paying customer

---

## REVISED MONTHLY COST (SaaS with 10 Tenants)

| Component | Cost | Notes |
|-----------|------|-------|
| Compute Engine (e2-standard-4) | $97 | Hosts all Docker services |
| Cloud SQL (db-custom-2-4096) | $51 | Shared across all tenants |
| Gemini API (10 tenants × ~$5) | $50 | Scales with usage |
| Vertex AI Embeddings | $10 | Indexing + queries |
| Cloud Storage | $2 | Backups |
| Static IP | $3 | DNS endpoint |
| Stripe fees (10 × $149 × 2.9%) | $43 | Payment processing |
| Email (Resend) | $20 | Transactional emails |
| Domain + DNS | $1 | Annual amortized |
| **Total Infrastructure** | **$277/mo** | |
| **Revenue (10 Starter clients)** | **$1,490/mo** | |
| **Gross Margin** | **$1,213/mo (81%)** | |
