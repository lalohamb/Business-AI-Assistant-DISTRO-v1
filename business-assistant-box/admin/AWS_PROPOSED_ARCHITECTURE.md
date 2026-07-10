# AWS_PROPOSED_ARCHITECTURE.md

# Business Assistant Box — Cloud Multi-Tenant Architecture

## Overview

This document proposes a cloud-native architecture for deploying Business Assistant Box as a managed multi-tenant SaaS product on AWS, serving multiple clients simultaneously without the single-machine `ACTIVE_CLIENT` switching model.

---

## Architecture Approach

**Recommended: Pooled Infrastructure with Logical Tenant Isolation**

- Shared compute and database infrastructure
- Tenant isolation enforced at the data layer (Row-Level Security, S3 prefixes, IAM policies)
- Cost-effective, scales horizontally
- Each tenant gets a subdomain: `acme.yourdomain.com`

---

## High-Level Diagram

```
                    ┌─────────────────┐
                    │   Route 53      │
                    │ *.clientname.   │
                    │ yourdomain.com  │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │   ALB + WAF     │
                    │ (SSL termination│
                    │  + tenant routing)
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
     ┌────────▼──┐   ┌──────▼───┐   ┌─────▼─────┐
     │ ECS Fargate│   │ECS Fargate│   │ECS Fargate│
     │ Open WebUI │   │   n8n     │   │  Bedrock  │
     │ + Dashboard│   │ Workflows │   │  Proxy    │
     └────────┬───┘   └─────┬────┘   └─────┬─────┘
              │              │              │
              └──────────────┼──────────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
     ┌────────▼──┐   ┌──────▼───┐   ┌─────▼─────┐
     │ RDS Postgres│  │    S3     │   │  EFS      │
     │ + pgvector │  │ Vault docs│   │ Client    │
     │ (per-tenant│  │ per-tenant│   │ workspaces│
     │  schema)   │  │  prefix)  │   │           │
     └────────────┘  └──────────┘   └───────────┘
```

---

## Tenant Resolution

### Current Model (Single Machine)

```
.env → ACTIVE_CLIENT=demo-company → current-client symlink → all services follow
```

### Cloud Model (Per-Request)

```
Request → ALB → X-Tenant-ID header injected → Service resolves tenant context
```

### Tenant Registry (DynamoDB)

| tenant_id | subdomain | plan | s3_prefix | db_schema | status |
|-----------|-----------|------|-----------|-----------|--------|
| acme-roofing | acme | pro | acme-roofing/ | tenant_acme | active |
| law-office | lawfirm | enterprise | law-office/ | tenant_law | active |
| insurance-agency | insurance | pro | insurance-agency/ | tenant_insurance | active |

Resolution:
- ALB routes `acme.yourdomain.com` → target group
- ALB rule injects `X-Tenant-ID: acme-roofing` header
- Or: API Gateway Lambda authorizer resolves tenant from subdomain/token
- Every service reads tenant from request context, never from a global env var

---

## Compute Layer — ECS Fargate

### Service Mapping

| Current Container | Cloud Equivalent | Scaling Strategy |
|---|---|---|
| openwebui (port 3000) | ECS Service + ALB target group | Auto-scale by active sessions |
| n8n (port 5678) | ECS Service (shared) | 1 task + scale on workflow queue depth |
| obsidian (port 3010) | Web markdown editor or S3 presigned URLs | N/A (replaced) |
| postgres (port 5432) | RDS PostgreSQL + pgvector | Managed, Multi-AZ |
| ollama (port 11434) | Amazon Bedrock OR ECS on g5.xlarge spot | Per-request or GPU pool |

### ECS Task Definition (Concept)

```json
{
  "family": "business-assistant-webui",
  "containerDefinitions": [{
    "name": "openwebui",
    "image": "ghcr.io/open-webui/open-webui:main",
    "environment": [
      {"name": "OLLAMA_BASE_URL", "value": "http://bedrock-proxy.internal:11434"}
    ],
    "secrets": [
      {"name": "DB_PASSWORD", "valueFrom": "arn:aws:ssm:region:account:parameter/bab/db-password"}
    ],
    "portMappings": [{"containerPort": 8080}]
  }]
}
```

---

## Data Layer — Per-Tenant Isolation

### RDS PostgreSQL with pgvector

The existing `rag_chunks.client_name` column becomes the tenant key. Add Row-Level Security:

```sql
-- Enable RLS
ALTER TABLE rag_chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE rag_documents ENABLE ROW LEVEL SECURITY;

-- Policy: each connection can only see their tenant
CREATE POLICY tenant_isolation ON rag_chunks
  USING (client_name = current_setting('app.current_tenant'));

CREATE POLICY tenant_isolation ON rag_documents
  USING (client_name = current_setting('app.current_tenant'));
```

Each request sets `SET app.current_tenant = 'acme-roofing'` at connection time — no cross-tenant data leaks possible.

### S3 for Knowledge Vault

```
s3://bab-knowledge-vault/
├── acme-roofing/
│   ├── BUSINESS_KNOWLEDGE.md
│   ├── CLIENT_PROFILE.md
│   ├── OWNER_PREFERENCES.md
│   ├── FAQ.md
│   ├── PROCEDURES/
│   ├── MEMORY/
│   ├── OUTPUTS/
│   └── vault/
├── law-office/
│   └── ...
├── insurance-agency/
│   └── ...
└── templates/
    └── ...   (copied during onboarding)
```

IAM policy per tenant:

```json
{
  "Effect": "Allow",
  "Action": ["s3:GetObject", "s3:PutObject"],
  "Resource": "arn:aws:s3:::bab-knowledge-vault/${aws:PrincipalTag/tenant_id}/*"
}
```

---

## LLM Layer — Amazon Bedrock

### Replacing Ollama

| Current | Cloud Replacement |
|---------|-------------------|
| Ollama qwen3:14b (chat) | Bedrock Claude Haiku or Titan |
| Ollama nomic-embed-text (embeddings) | Bedrock Titan Embed Text v2 |
| Local GPU required | No GPU management, pay-per-request |

### Embedding Provider Addition

```python
import boto3
import json

def get_embedding_bedrock(text):
    client = boto3.client("bedrock-runtime")
    response = client.invoke_model(
        modelId="amazon.titan-embed-text-v2:0",
        body=json.dumps({"inputText": text})
    )
    return json.loads(response["body"].read())["embedding"]

def get_embedding(text):
    if EMBEDDING_PROVIDER == "ollama":
        # existing Ollama code
    elif EMBEDDING_PROVIDER == "bedrock":
        return get_embedding_bedrock(text)
```

### Chat LLM

Options:
1. Bedrock Converse API with a proxy that speaks Ollama-compatible format (Open WebUI unchanged)
2. Direct Bedrock integration via Open WebUI's API provider settings
3. Self-hosted Ollama on ECS g5.xlarge spot instances (cost-effective for high volume)

---

## Client Onboarding — Step Functions Workflow

Replaces `post_install_client_setup.sh` and `switch_client.sh` with automated provisioning:

```
New Client Signup
       │
       ▼
┌──────────────────┐
│ Lambda: Validate │
│ & Create Tenant  │
│ in DynamoDB      │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Lambda: Copy S3  │
│ templates/ → new │
│ tenant prefix    │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Lambda: Create   │
│ DB schema + RLS  │
│ + run initial    │
│ index_vault.py   │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Lambda: Register │
│ DNS record in    │
│ Route 53         │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Lambda: Send     │
│ welcome email    │
│ with credentials │
└──────────────────┘
```

---

## Secrets Management

### Current → Cloud Mapping

| Current | Cloud Replacement |
|---------|-------------------|
| `.env` file (global) | SSM Parameter Store (hierarchical) |
| API keys in `.env` | Secrets Manager (encrypted, rotatable) |
| `ACTIVE_CLIENT` env var | Request-scoped from ALB header |
| `OBSIDIAN_VAULT_PATH` | S3 bucket + prefix |

### Parameter Hierarchy

```
/bab/global/embedding-model       → "amazon.titan-embed-text-v2:0"
/bab/global/embedding-provider    → "bedrock"
/bab/global/db-host               → "bab-prod.xxx.rds.amazonaws.com"
/bab/global/rag-enabled           → "true"
/bab/tenants/acme-roofing/plan    → "pro"
/bab/tenants/acme-roofing/n8n-key → (SecureString)
/bab/tenants/law-office/plan      → "enterprise"
```

---

## Networking & Security

```
┌─────────────────────────────────────────────────┐
│                    VPC                            │
│                                                  │
│  ┌──────────────┐  Public Subnets               │
│  │     ALB      │  (only ALB faces internet)    │
│  └──────┬───────┘                               │
│         │                                        │
│  ┌──────▼───────┐  Private Subnets              │
│  │  ECS Tasks   │  (WebUI, n8n, RAG indexer)    │
│  └──────┬───────┘                               │
│         │                                        │
│  ┌──────▼───────┐  Isolated Subnets             │
│  │  RDS + Cache │  (no internet access)         │
│  └──────────────┘                               │
└─────────────────────────────────────────────────┘
```

### Security Rules (from SECURITY.md → AWS equivalents)

| SECURITY.md Rule | AWS Implementation |
|------------------|-------------------|
| Database never publicly exposed | RDS in isolated subnet, no public IP |
| Credentials only in .env/secret stores | Secrets Manager + SSM Parameter Store |
| Client data isolated | RLS + S3 prefix policies + IAM |
| Email sending requires approval | SES with approval workflow via Step Functions |
| Audit logs required | CloudTrail + CloudWatch Logs |
| Daily/weekly/monthly backups | RDS automated snapshots + S3 versioning + lifecycle |
| Authentication required | ALB + Cognito or custom auth |

### Additional Cloud Security

- WAF on ALB: rate limiting, bot protection, geo-blocking
- Security groups: ECS → RDS only on 5432
- VPC endpoints for S3, Bedrock, Secrets Manager (no internet egress needed)
- KMS encryption for RDS, S3, and Secrets Manager

---

## Monitoring & Operations

| Concern | AWS Service |
|---------|-------------|
| Container health | ECS + CloudWatch Container Insights |
| RAG pipeline failures | CloudWatch Logs + Metric Alarms |
| Tenant usage/billing | Custom CloudWatch metrics per tenant_id |
| Backup verification | RDS automated snapshots + S3 versioning |
| Audit trail | CloudTrail |
| Performance tracing | X-Ray |
| Alerting | SNS → email/Slack on failures |

---

## Infrastructure as Code (Proposed Layout)

```
infrastructure/
├── terraform/
│   ├── modules/
│   │   ├── networking/       # VPC, subnets, ALB, WAF
│   │   ├── compute/          # ECS services, task definitions
│   │   ├── database/         # RDS pgvector, security groups
│   │   ├── storage/          # S3 buckets, EFS, lifecycle
│   │   ├── dns/              # Route 53 hosted zone, records
│   │   ├── secrets/          # Secrets Manager, SSM parameters
│   │   ├── monitoring/       # CloudWatch dashboards, alarms
│   │   └── tenant/           # Per-tenant provisioning module
│   ├── environments/
│   │   ├── dev.tfvars
│   │   ├── staging.tfvars
│   │   └── prod.tfvars
│   └── main.tf
└── docker/
    ├── openwebui/Dockerfile
    ├── n8n/Dockerfile
    ├── bedrock-proxy/Dockerfile
    └── docker-compose.cloud.yml
```

---

## Cost Model (Estimated — 10 Tenants)

| Resource | Monthly Cost (approx) |
|----------|----------------------|
| ECS Fargate (3 services, 0.5 vCPU / 1GB each) | $80–150 |
| RDS db.t4g.medium (pgvector, Multi-AZ) | $60–120 |
| Bedrock Titan Embed (embeddings) | $5–20 |
| Bedrock Claude Haiku (chat) | $20–100 |
| S3 (knowledge vault, Intelligent-Tiering) | $2–5 |
| ALB + WAF | $30–40 |
| Route 53 + DNS | $5 |
| Secrets Manager + SSM | $5 |
| CloudWatch (logs + metrics) | $10–20 |
| **Total (10 tenants)** | **~$220–460/month** |

### Alternative: Self-Hosted LLM

- One `g5.xlarge` spot instance (~$400/month) running Ollama handles unlimited requests
- Better for high-volume tenants, worse for low-usage deployments
- Hybrid approach: Bedrock for embeddings, self-hosted for chat

### Per-Tenant Pricing Guidance

At 10 tenants: ~$22–46/tenant/month infrastructure cost
Suggested retail: $99–299/tenant/month depending on plan tier

---

## Migration Path

### Phase 1 — Containerize (Current → Docker Compose Cloud-Ready)

- Create `docker-compose.cloud.yml` with all services
- Externalize all config from `.env` to environment variables
- Test full stack on a single EC2 instance
- Timeline: 1–2 weeks

### Phase 2 — Pilot Cloud Deployment (2–3 Clients)

- Deploy to single EC2 or ECS with siloed approach (one stack per client)
- Add SSL via ACM + ALB
- Validate data isolation, backup, and recovery
- Timeline: 2–3 weeks

### Phase 3 — Multi-Tenant Pooled Architecture

- Implement tenant registry (DynamoDB)
- Add ALB routing rules + subdomain resolution
- Implement RLS in PostgreSQL
- Move knowledge vault to S3
- Build onboarding Step Function
- Timeline: 4–6 weeks

### Phase 4 — Production Hardening

- Replace Ollama with Bedrock (or add as option)
- Add CloudWatch monitoring + alarms
- Implement WAF rules
- Add Cognito authentication
- Build admin dashboard for tenant management
- Timeline: 3–4 weeks

---

## What Stays the Same

The core markdown-driven architecture is preserved:

- `system/AGENTS.md`, `POLICIES.md`, `IDENTITY.md` → still governs AI behavior
- `clients/{tenant}/` folder structure → same layout, lives in S3
- `PROCEDURES/*.md`, `MEMORY/*.md` → same files, same purpose
- `index_vault.py` chunking and embedding logic → same algorithm, different providers
- Security boundaries from `SECURITY.md` → enforced by IAM instead of filesystem permissions
- Multi-client isolation → upgraded from symlink switching to true simultaneous multi-tenancy

The product remains a "deployable private AI employee" — the cloud just changes where it lives and how it scales to serve many businesses at once.

---

## Deployment Models (Updated)

| Model | Use Case | Infrastructure |
|-------|----------|---------------|
| On-Premise Appliance | High-security single client | Current architecture (unchanged) |
| Private Cloud (single tenant) | Managed service, one client per VM | EC2 + Docker Compose |
| Multi-Tenant SaaS | Managed service, many clients | This architecture (ECS + RDS + S3 + Bedrock) |
| Hybrid | Local data + cloud AI | On-prem data, Bedrock API for LLM |

---

## Decision Log

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Tenant isolation model | Pooled with RLS | Cost-effective at scale, existing `client_name` column supports it |
| LLM provider | Bedrock (primary), Ollama (fallback) | No GPU management, pay-per-use, existing `.env` AI_PROVIDER supports swapping |
| Knowledge storage | S3 | Durable, cheap, IAM-integrated, versioned |
| Workflow engine | Keep n8n | Already built workflows, runs well in containers |
| Markdown editor | S3 presigned URLs or web editor | Obsidian Docker doesn't scale multi-tenant |
| IaC tool | Terraform | Multi-provider, modular, team-friendly |
| Onboarding automation | Step Functions | Orchestrates multiple Lambda steps, retries, visibility |
