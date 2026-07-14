# Business Assistant Box — Google Cloud Component Flowchart & Mapping

---

## System Flowchart (Google Cloud Architecture)

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              GOOGLE CLOUD PLATFORM                                   │
│                                                                                     │
│  ┌──────────────────────────────────────────────────────────────────────────────┐   │
│  │                        COMPUTE ENGINE VM (e2-standard-4)                      │   │
│  │                                                                              │   │
│  │  ┌─────────────┐    ┌──────────────┐    ┌──────────────┐                    │   │
│  │  │   Traefik   │───▶│  Open WebUI   │───▶│     n8n      │                    │   │
│  │  │  (Reverse   │    │  (Chat UI)    │    │ (Workflows)  │                    │   │
│  │  │   Proxy)    │    │  Port 3000    │    │  Port 5678   │                    │   │
│  │  └──────┬──────┘    └──────┬───────┘    └──────┬───────┘                    │   │
│  │         │                   │                    │                            │   │
│  │         │ HTTPS :443        │                    │                            │   │
│  │         │ HTTP  :80         │                    │                            │   │
│  │         ▼                   ▼                    ▼                            │   │
│  │  ┌─────────────┐    ┌──────────────┐    ┌──────────────┐                    │   │
│  │  │ Let's       │    │ Cloud SQL    │    │  RAG Scripts  │                    │   │
│  │  │ Encrypt     │    │   Proxy      │    │ index_vault   │                    │   │
│  │  │ (TLS Certs) │    │  Port 5432   │    │ query_vault   │                    │   │
│  │  └─────────────┘    └──────┬───────┘    └──────┬───────┘                    │   │
│  │                             │                    │                            │   │
│  │  ┌──────────────────────────┼────────────────────┘                           │   │
│  │  │  Docker Network          │                                                │   │
│  │  └──────────────────────────┼────────────────────────────────────────────────│   │
│  └─────────────────────────────┼────────────────────────────────────────────────┘   │
│                                │                                                     │
│  ┌─────────────────────────────▼────────────────────────────────────────────────┐   │
│  │                         CLOUD SQL (PostgreSQL 16 + pgvector)                   │   │
│  │                                                                              │   │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐                 │   │
│  │  │ businessassist │  │   rag_chunks   │  │  rag_documents │                 │   │
│  │  │ ant (main DB)  │  │  vector(768)   │  │  (metadata)    │                 │   │
│  │  └────────────────┘  └────────────────┘  └────────────────┘                 │   │
│  └──────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
│  ┌──────────────────────────────────────────────────────────────────────────────┐   │
│  │                         VERTEX AI / GEMINI API                                │   │
│  │                                                                              │   │
│  │  ┌────────────────────────┐    ┌─────────────────────────────┐              │   │
│  │  │  Gemini 2.0 Flash      │    │  text-embedding-004          │              │   │
│  │  │  (LLM — Chat/Reason)   │    │  (Embeddings — 768 dims)    │              │   │
│  │  └────────────────────────┘    └─────────────────────────────┘              │   │
│  └──────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
│  ┌──────────────────────────────────────────────────────────────────────────────┐   │
│  │                         SUPPORTING SERVICES                                   │   │
│  │                                                                              │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │   │
│  │  │ Cloud        │  │ Cloud        │  │ Cloud        │  │   IAM        │    │   │
│  │  │ Storage      │  │ Logging      │  │ Monitoring   │  │ (Service     │    │   │
│  │  │ (Backups)    │  │ (Audit)      │  │ (Dashboards) │  │  Accounts)   │    │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘    │   │
│  └──────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Data Flow Diagram

```
USER (Browser)
  │
  │ HTTPS Request
  ▼
┌─────────────┐
│  TRAEFIK    │──── Let's Encrypt (auto TLS)
│  (Ingress)  │
└──────┬──────┘
       │
       ├──── Route: {client}.domain.com ────▶ Open WebUI
       │
       └──── Route: {client}-n8n.domain.com ─▶ n8n
              │
              ▼
┌──────────────────────────────────────────────────────────┐
│                    OPEN WEBUI                              │
│                                                          │
│  1. User types question                                  │
│  2. RAG Filter intercepts                                │
│  3. Embed question ──────────────────▶ Vertex AI         │
│     (text-embedding-004)              Embeddings API     │
│  4. Query pgvector ──────────────────▶ Cloud SQL         │
│     (similarity search)               (pgvector)        │
│  5. Inject context into prompt                           │
│  6. Send to LLM ─────────────────────▶ Gemini 2.0 Flash │
│  7. Return answer to user                                │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│                    N8N WORKFLOWS (15 total)                │
│                                                          │
│  STANDARD (all clients, 5 workflows):                    │
│  • Email Triage (5min poll) ──────────▶ Gemini API      │
│  • Calendar Review (daily 7AM) ───────▶ Gemini API      │
│  • Daily Briefing (weekdays 6:30AM) ──▶ Gemini API      │
│  • Approval Router (webhook gate) ────▶ Gemini API      │
│  • RAG Query (webhook) ───────────────▶ Gemini API      │
│                                                          │
│  SELECTABLE (client picks, 10 workflows):                │
│  • Document Drafting ─────────────────▶ Gemini API      │
│  • Customer Intake ───────────────────▶ Gemini API      │
│  • Invoice Generator ─────────────────▶ Gemini API      │
│  • Lead Follow-up ────────────────────▶ Gemini API      │
│  • Appointment Booking ───────────────▶ Gemini API      │
│  • Review Requester ──────────────────▶ Gemini API      │
│  • Expense Tracker ───────────────────▶ Gemini API      │
│  • Social Post Scheduler ─────────────▶ Gemini API      │
│  • Report Generator ──────────────────▶ Gemini API      │
│  • Voicemail Transcription ───────────▶ Gemini API      │
│                                                          │
│  All use {{$env.GOOGLE_API_KEY}} (per-tenant swap)       │
│  All sensitive outputs ───────────────▶ Approval Router  │
│  All persist state to ────────────────▶ Cloud SQL       │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│              APPROVAL ROUTER FLOW                          │
│                                                          │
│  Workflow output (draft/invoice/post)                     │
│       │                                                  │
│       ▼                                                  │
│  Approval Router (webhook)                               │
│       │                                                  │
│       ├── LOW risk ──────▶ Auto-approve → Execute        │
│       │                                                  │
│       └── HIGH risk ─────▶ Hold → Notify client          │
│                            (email/Slack)                  │
│                                 │                        │
│                                 ▼                        │
│                           Client approves/rejects        │
│                                 │                        │
│                                 └──▶ Execute or Discard  │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│                 RAG INDEXING PIPELINE                      │
│                                                          │
│  Cron / On-demand trigger                                │
│       │                                                  │
│       ▼                                                  │
│  index_vault.py                                          │
│       │                                                  │
│       ├── Read markdown files from clients/{client}/     │
│       │                                                  │
│       ├── Chunk text (500 tokens, 50 overlap)            │
│       │                                                  │
│       ├── Batch embed (250/call) ─────▶ Vertex AI       │
│       │   (text-embedding-004)          Embeddings      │
│       │                                                  │
│       └── Store vectors ──────────────▶ Cloud SQL       │
│           (rag_chunks table)            pgvector        │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│                 BACKUP PIPELINE                            │
│                                                          │
│  Cron (daily 2 AM)                                       │
│       │                                                  │
│       ├── pg_dump via Cloud SQL Proxy ─▶ Cloud SQL      │
│       │                                                  │
│       ├── tar vault/clients/system dirs                   │
│       │                                                  │
│       └── gsutil upload ──────────────▶ Cloud Storage   │
│           (30-day retention)            GCS Bucket      │
└──────────────────────────────────────────────────────────┘
```

---

## Google Cloud Component → Feature Mapping

### COMPUTE & HOSTING

| Google Cloud Component | BAB Feature | How It Works |
|------------------------|-------------|--------------|
| **Compute Engine** (e2-standard-4) | All Docker services hosting | Single VM runs Docker Compose stack (Traefik, Open WebUI, n8n, Cloud SQL Proxy). 4 vCPU / 16GB RAM. Ubuntu 24.04 LTS. Replaces local machine deployment. |
| **Compute Engine — Static IP** | Stable DNS endpoint | Reserved external IP attached to VM. DNS A-record points domain here. Survives VM restarts. |
| **Compute Engine — Firewall Rules** | Network security | Only ports 80 (HTTP) and 443 (HTTPS) open publicly. All other ports (5432, 5678, 3000) internal only. SSH via IAP or key-based. |
| **Compute Engine — Attached Service Account** | Keyless auth (production) | VM metadata provides credentials to Google SDK automatically. No key file needed for scripts running directly on host. |

### AI & MACHINE LEARNING

| Google Cloud Component | BAB Feature | How It Works |
|------------------------|-------------|--------------|
| **Vertex AI — Gemini 2.0 Flash** | Primary LLM (chat, reasoning, drafting) | Receives user questions + RAG context via API. Generates business-aware responses. Called by Open WebUI (via OpenAI-compatible endpoint) and n8n workflows (via HTTP Request or native Vertex AI node). ~100K input tokens/day. |
| **Vertex AI — text-embedding-004** | Document embedding (768 dimensions) | Converts text chunks into vector representations for similarity search. Called by index_vault.py (batch: 250 texts/call) and query_vault.py (single query embedding). Output stored in Cloud SQL pgvector. |
| **Generative Language API** | Direct Gemini access (API key method) | OpenAI-compatible REST endpoint at `generativelanguage.googleapis.com/v1beta/openai`. Open WebUI connects directly using GOOGLE_API_KEY. Simpler than full Vertex AI SDK for chat. |

### DATABASE

| Google Cloud Component | BAB Feature | How It Works |
|------------------------|-------------|--------------|
| **Cloud SQL for PostgreSQL 16** | Primary database + vector store | Managed PostgreSQL with pgvector extension enabled. Stores: rag_documents (file metadata), rag_chunks (text + vector(768) embeddings), n8n workflow state, Open WebUI user data. Auto-patched, auto-backed-up by Google. |
| **Cloud SQL Proxy** (sidecar container) | Secure DB connectivity | Runs as Docker container. Provides encrypted tunnel from Compute Engine to Cloud SQL instance. Authenticates via service account. Exposes port 5432 to Docker network and host. |
| **Cloud SQL — pgvector extension** | Similarity search | Enables `<=>` cosine distance operator on vector columns. Powers RAG retrieval: "find chunks most similar to user's question embedding." No schema change from local setup (already vector(768)). |

### STORAGE

| Google Cloud Component | BAB Feature | How It Works |
|------------------------|-------------|--------------|
| **Cloud Storage** (Standard class) | Automated backups | Bucket `gs://bab-backups-{project}` stores daily database dumps and vault archives. 30-day retention policy enforced by backup script. Replaces local `backups/` directory. |
| **Cloud Storage — Uniform Bucket-Level Access** | Backup security | IAM-only access control (no per-object ACLs). Only the service account can read/write. Prevents accidental public exposure of client data. |

### NETWORKING & SECURITY

| Google Cloud Component | BAB Feature | How It Works |
|------------------------|-------------|--------------|
| **Cloud IAM — Service Account** | Application identity | `bab-app@{project}.iam.gserviceaccount.com` with roles: `aiplatform.user` (Gemini/embeddings), `cloudsql.client` (database access). Key file mounted into Docker containers. |
| **Cloud IAM — Workload Identity** (production) | Keyless container auth | Eliminates service account key files. Containers authenticate via VM metadata. Post-hackathon security upgrade. |
| **VPC Firewall Rules** | Port restriction | Only TCP 80/443 allowed from internet. Internal ports (5432, 5678, 3000, 3010) blocked externally. SSH via port 22 or IAP tunnel. |
| **Let's Encrypt via Traefik** | TLS certificates | Traefik auto-provisions and renews SSL certs. Google provides the static IP; Traefik handles ACME challenge on port 80. Wildcard DNS enables per-client subdomains. |

### OBSERVABILITY

| Google Cloud Component | BAB Feature | How It Works |
|------------------------|-------------|--------------|
| **Cloud Logging** | Centralized audit trail | Captures all Vertex AI API calls (request/response metadata), Cloud SQL queries, Compute Engine system logs. Provides hackathon evidence of "AI running in production." |
| **Cloud Monitoring** | Performance dashboards | Custom dashboard showing: Gemini API calls/hour, embedding requests/day, Cloud SQL connections, VM CPU/memory. Real-time alerting on failures. |
| **Cloud SQL Insights** | Database performance | Query-level performance metrics. Shows slow queries, connection pool usage, storage growth. Identifies RAG query bottlenecks. |
| **Vertex AI Metrics** | AI usage tracking | Token consumption, API latency, error rates per model. Proves continuous AI operation for hackathon judges. |

### DEVELOPER & ADMIN TOOLS

| Google Cloud Component | BAB Feature | How It Works |
|------------------------|-------------|--------------|
| **gcloud CLI** | Infrastructure provisioning | Creates VM, Cloud SQL, buckets, firewall rules, service accounts. All setup scripted via `gcloud` commands. |
| **gcloud compute ssh** | Secure VM access | SSH tunnel for admin access. Also enables localhost port forwarding for Obsidian (3010) and n8n (5678) when not publicly exposed. |
| **gsutil** | Backup operations | Uploads/downloads backup archives to Cloud Storage. Used in daily cron job (`backup_to_gcs.sh`). |

---

## Feature → Google Component Breakdown

### 1. Chat Interface (Open WebUI)

| Aspect | Google Component | Detail |
|--------|-----------------|--------|
| Hosting | Compute Engine | Docker container on VM |
| LLM Backend | Gemini 2.0 Flash | Via OpenAI-compatible endpoint |
| User DB | Cloud SQL | Stores user accounts, chat history |
| TLS | Let's Encrypt + Static IP | HTTPS via Traefik |
| Monitoring | Cloud Logging | Request logs |

### 2. RAG Pipeline (Knowledge Retrieval)

| Aspect | Google Component | Detail |
|--------|-----------------|--------|
| Embedding Generation | Vertex AI text-embedding-004 | 768-dim vectors, batch 250/call |
| Vector Storage | Cloud SQL + pgvector | Cosine similarity search |
| Document Source | Compute Engine filesystem | Markdown vault files |
| Query Execution | Vertex AI + Cloud SQL | Embed query → search → return chunks |
| Indexing Trigger | Compute Engine cron | Nightly or on-demand |

### 3. Workflow Automation (n8n)

| Aspect | Google Component | Detail |
|--------|-----------------|--------|
| Hosting | Compute Engine | Docker container on VM |
| AI Calls | Gemini API via `{{$env.GOOGLE_API_KEY}}` | All 15 workflows use HTTP Request nodes to Gemini |
| State Storage | Cloud SQL | n8n internal database |
| Webhook Ingress | Compute Engine + Traefik | Public HTTPS endpoints for triggers |
| Scheduling | n8n internal cron | Email poll (5min), calendar (7AM), briefing (6:30AM) |
| Template Library | Compute Engine filesystem | `n8n/workflows/` with manifest.json (5 standard + 10 selectable) |
| Credential Mgmt | n8n Credentials UI + env vars | Placeholders (PG_CREDENTIAL_ID, GMAIL_CREDENTIAL_ID, etc.) replaced per tenant |
| Approval Gate | Approval Router workflow | Sensitive outputs held for client review before execution |
| Import | n8n CLI or REST API | `n8n import:workflow --input=workflow.json` during provisioning |

### 4. Business Knowledge Vault

| Aspect | Google Component | Detail |
|--------|-----------------|--------|
| File Storage | Compute Engine disk | Markdown files in clients/{client}/ |
| Backup | Cloud Storage | Daily tar.gz archives |
| Editing (admin) | Compute Engine + SSH tunnel | Obsidian via localhost:3010 or vim |
| Indexing | Vertex AI + Cloud SQL | Embedded and stored as vectors |

### 5. Multi-Client Isolation

| Aspect | Google Component | Detail |
|--------|-----------------|--------|
| Data Separation | Cloud SQL | `client_name` column filters RAG queries |
| File Separation | Compute Engine disk | Separate directories per client |
| Routing | Traefik + DNS | Per-client subdomains |
| Backup Separation | Cloud Storage | Per-client prefixes in bucket |

### 6. Security & Authentication

| Aspect | Google Component | Detail |
|--------|-----------------|--------|
| App Identity | IAM Service Account | Scoped roles (aiplatform.user, cloudsql.client) |
| Network | VPC Firewall | Only 80/443 public |
| Secrets | .env + service-account.json | Key file never committed (gitignore) |
| DB Auth | Cloud SQL Proxy | Encrypted tunnel, IAM-authenticated |
| TLS | Let's Encrypt | Auto-provisioned certificates |
| Production Auth | Workload Identity Federation | Keyless (post-hackathon) |

### 7. Backup & Recovery

| Aspect | Google Component | Detail |
|--------|-----------------|--------|
| DB Dumps | Cloud SQL Proxy → Cloud Storage | Daily pg_dump, gzipped, uploaded |
| File Archives | Compute Engine → Cloud Storage | Daily tar of vault/clients/system |
| Retention | Cloud Storage + script logic | 30-day rolling window |
| Bucket Security | IAM Uniform Access | Service account only |

### 8. Monitoring & Evidence

| Aspect | Google Component | Detail |
|--------|-----------------|--------|
| API Logs | Cloud Logging | Every Gemini/embedding call logged |
| Dashboards | Cloud Monitoring | Custom metrics dashboard |
| DB Metrics | Cloud SQL Insights | Query performance, connections |
| AI Metrics | Vertex AI Metrics Tab | Token usage, latency, calls/day |
| Uptime | Cloud Monitoring Uptime Checks | Alerts on service failure |

---

## Authentication Flow

```
┌─────────────────────────────────────────────────────────┐
│              AUTHENTICATION PATHS                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  PATH A: Scripts on VM (preferred)                      │
│  ─────────────────────────────────                      │
│  Python script                                          │
│       │                                                 │
│       └── google SDK auto-discovers ──▶ VM Metadata    │
│           (no key file needed)          Service Acct   │
│                                                         │
│  PATH B: Docker containers                              │
│  ─────────────────────────────                          │
│  Container                                              │
│       │                                                 │
│       └── GOOGLE_APPLICATION_CREDENTIALS                │
│           = /config/credentials.json                    │
│                │                                        │
│                └── Mounted from host ──▶ service-       │
│                    service-account.json   account.json  │
│                                                         │
│  PATH C: Open WebUI → Gemini (API Key)                  │
│  ─────────────────────────────────────                  │
│  Open WebUI                                             │
│       │                                                 │
│       └── OPENAI_API_BASE_URL + GOOGLE_API_KEY          │
│           (OpenAI-compatible endpoint)                  │
│                │                                        │
│                └── Direct HTTPS ──▶ generativelanguage  │
│                                     .googleapis.com    │
│                                                         │
│  PATH D: n8n → Gemini                                   │
│  ────────────────────                                   │
│  n8n workflow node                                      │
│       │                                                 │
│       ├── Option 1: HTTP Request + API Key (preferred)  │
│       │   URL: generativelanguage.googleapis.com/v1beta │
│       │   Auth: {{$env.GOOGLE_API_KEY}} in query param  │
│       │   (all 15 workflow templates use this method)   │
│       │                                                 │
│       └── Option 2: Native Vertex AI Node               │
│           (service account auth — future upgrade)       │
│                                                         │
│  PATH E: n8n → Google Workspace (OAuth2)                │
│  ───────────────────────────────────────                │
│  n8n credential (per tenant)                            │
│       │                                                 │
│       └── OAuth2 tokens stored in n8n DB                │
│           Scopes: gmail.modify, calendar.events,        │
│                   spreadsheets, drive.file              │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Cost Breakdown by Component

| Google Component | Monthly Cost | What It Powers |
|------------------|-------------|----------------|
| Compute Engine (e2-standard-4) | ~$97 | All Docker services |
| Cloud SQL (db-custom-2-4096, 20GB) | ~$51 | PostgreSQL + pgvector |
| Gemini 2.0 Flash API | ~$0–10 | Chat responses, workflow AI (free tier: 15 RPM / 1M TPD) |
| Vertex AI Embeddings | ~$0–5 | RAG indexing + queries (free tier covers early clients) |
| Cloud Storage (50GB) | ~$1 | Backups |
| Static IP | ~$3 | DNS endpoint |
| Cloud Logging/Monitoring | Free tier | Observability |
| **TOTAL** | **~$156–167/mo** | Full production system |

---

## Deployment Sequence (Component Activation Order)

```
Step 1: IAM & Service Account
         └── Create project, enable APIs, create SA, download key

Step 2: Cloud SQL
         └── Provision instance, enable pgvector, run schema.sql

Step 3: Cloud Storage
         └── Create backup bucket

Step 4: Compute Engine
         └── Create VM, attach SA, configure firewall

Step 5: Docker Stack (on VM)
         └── Deploy docker-compose.gcloud.yml
             ├── Traefik (ingress)
             ├── Cloud SQL Proxy (DB tunnel)
             ├── Open WebUI (chat)
             └── n8n (workflows)

Step 6: DNS & TLS
         └── Point domain → static IP, Traefik provisions certs

Step 7: RAG Indexing
         └── Run index_vault.py → Vertex AI embeddings → Cloud SQL

Step 8: Monitoring
         └── Configure Cloud Monitoring dashboard

Step 9: Backups
         └── Enable daily cron → Cloud Storage
```

---

## Workflow Template Library Architecture

```
n8n/workflows/
├── manifest.json                    ← Source of truth (all 15 workflows metadata)
├── standard/                        ← Deployed to ALL clients
│   ├── email-triage.json            (Gmail poll → Gemini classify → label/draft)
│   ├── calendar-review.json         (Daily 7AM → check conflicts → notify)
│   ├── daily-briefing.json          (Weekdays 6:30AM → merge calendar+email → summary)
│   ├── approval-router.json         (Webhook gate → risk assess → hold or auto-approve)
│   └── rag-query.json               (Webhook → embed → pgvector search → Gemini answer)
└── selectable/                      ← Client picks during onboarding
    ├── document-drafting.json       (Webhook → Gemini draft → approval-router)
    ├── customer-intake.json         (Form webhook → extract fields → CRM/Sheets)
    ├── invoice-generator.json       (Webhook → Gemini format → Sheets → approval)
    ├── lead-followup.json           (Daily 9AM → check stale leads → draft email)
    ├── appointment-booking.json     (Webhook → check availability → confirm/suggest)
    ├── review-requester.json        (Weekly → find completed jobs → send review link)
    ├── expense-tracker.json         (Email poll → extract receipt → categorize → Sheets)
    ├── social-post-scheduler.json   (Weekly → Gemini generate → approval → queue)
    ├── report-generator.json        (Monthly 1st → aggregate metrics → PDF/email)
    └── voicemail-transcription.json (Webhook → Gemini transcribe → summarize → notify)
```

### Credential Placeholders (replaced per tenant during provisioning)

| Placeholder | What It Connects | Setup Method |
|-------------|-------------------|--------------|
| `{{$env.GOOGLE_API_KEY}}` | Gemini API (LLM calls) | Environment variable per n8n instance |
| `PG_CREDENTIAL_ID` | Cloud SQL (pgvector queries) | n8n Credentials UI or API |
| `GMAIL_CREDENTIAL_ID` | Gmail (read/send/label) | OAuth2 consent flow per client |
| `GCAL_CREDENTIAL_ID` | Google Calendar (read/write events) | OAuth2 consent flow per client |
| `SHEETS_CREDENTIAL_ID` | Google Sheets (CRM, invoices, expenses) | OAuth2 consent flow per client |

### Provisioning Flow (new client)

```
1. Read manifest.json → get standard + client-selected workflows
2. For each workflow JSON:
   a. sed replace credential placeholders with tenant-specific IDs
   b. n8n import:workflow --input=<modified>.json
3. Activate all imported workflows
4. Verify via n8n REST API: GET /workflows → confirm active count
```

---

## Local Feature → Google Replacement Summary

| Local Component | Google Cloud Replacement | Migration Complexity |
|-----------------|--------------------------|---------------------|
| Ollama (LLM) | Gemini 2.0 Flash via Vertex AI | Low — API swap |
| Ollama (Embeddings) | Vertex AI text-embedding-004 | Low — same 768 dims |
| PostgreSQL (Docker) | Cloud SQL for PostgreSQL | Medium — proxy setup |
| Local filesystem backups | Cloud Storage | Low — gsutil script |
| Self-signed / no TLS | Let's Encrypt via Traefik | Low — auto-provisioned |
| No monitoring | Cloud Logging + Monitoring | Low — automatic |
| Manual SSH | gcloud compute ssh + IAP | Low — better security |
| Local-only access | Static IP + DNS + Firewall | Medium — networking |
| .env credentials only | IAM Service Accounts | Medium — role scoping |
| Obsidian (public port) | Obsidian (localhost + SSH tunnel) | Low — port binding change |
| n8n (0 workflows, SQLite) | n8n (15 templates, Cloud SQL) | Low — import from manifest |
| No approval gate | Approval Router workflow | Low — included in standard set |
