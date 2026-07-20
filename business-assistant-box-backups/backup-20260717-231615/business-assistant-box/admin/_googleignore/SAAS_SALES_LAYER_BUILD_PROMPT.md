# SAAS_SALES_LAYER_BUILD_PROMPT.md

# Business Assistant Box — SaaS Sales Layer Build Prompt

---

You are building the SaaS sales layer for "Business Assistant Box" — a private AI office assistant for small businesses. The product already has a landing page with pricing displayed. You are now building the backend systems that power self-serve signup, payment, provisioning, and management.

---

## EXISTING INFRASTRUCTURE

- Hosting: Digital Ocean (Coolify as PaaS)
- Per-client deployment: Isolated Docker Compose stacks via Coolify
- Routing: Traefik with wildcard SSL (*.yourdomain.com)
- Shared LLM: Ollama on shared Docker network OR external API (OpenRouter/Groq)
- Per-client services: Open WebUI, n8n, PostgreSQL (pgvector), RAG indexer
- Client onboarding script exists: `onboard_client.sh` (creates vault from template, deploys via Coolify API, runs RAG indexer)
- Client vault structure: `clients/{client_id}/` with PROCEDURES/, MEMORY/, OUTPUTS/, CLIENT_PROFILE.md, OWNER_PREFERENCES.md, BUSINESS_KNOWLEDGE.md, FAQ.md

---

## WHAT TO BUILD

Build the following components as a cohesive SaaS sales layer. Use Node.js/TypeScript (Next.js) for web apps, PostgreSQL for the sales/admin database (separate from client RAG databases), and shell/Python scripts for provisioning automation.

---

### 1. SELF-SERVE SIGNUP & PAYMENT (Starter + Pro only)

**Stripe Integration:**
- Create Stripe products:
  - `starter_monthly` — $149/mo
  - `starter_annual` — $124/mo (billed annually)
  - `pro_monthly` — $299/mo
  - `pro_annual` — $249/mo (billed annually)
  - Add-ons: extra_user_seat ($29/mo), additional_workflow ($99/mo), white_label_domain ($49/mo)
- Implement Stripe Checkout session creation from the landing page "Sign Up" buttons
- Collect: business name, owner name, email, desired subdomain, selected plan
- After successful payment → trigger provisioning webhook

**14-Day Free Trial:**
- Trial available on Starter and Pro plans
- No credit card required to start trial
- Trial limits: 10 documents max in vault, 1 workflow enabled (Daily Briefing only), 50 chat messages/day
- At day 10: email reminder that trial ends in 4 days
- At day 14: if no payment method added → freeze instance (read-only, no new chats)
- At day 21: if still no payment → archive instance, retain data 30 more days
- Stripe subscription created with `trial_period_days: 14` when card is added

**Webhook Flow (Stripe → Provisioning):**
```
Stripe checkout.session.completed webhook
  → Verify webhook signature
  → Extract: customer_email, plan_id, metadata (business_name, subdomain)
  → Insert tenant record into sales DB (status: provisioning)
  → Call Coolify API to deploy new Docker Compose stack:
      - CLIENT_ID = sanitized business name
      - CLIENT_SUBDOMAIN = chosen subdomain
      - DB_PASSWORD = generated (openssl rand -hex 16)
      - Plan-based config (doc limits, workflow count)
  → Wait for health check (poll subdomain until 200)
  → Update tenant record (status: active)
  → Send welcome email with:
      - Login URL: https://{subdomain}.yourdomain.com
      - Vault builder link: https://app.yourdomain.com/vault-builder
      - Getting started guide link
```

---

### 2. SELF-SERVE VAULT BUILDER

A web-based wizard that replaces the manual Obsidian editing for cloud tenants. Accessible at `https://app.yourdomain.com/vault-builder` after signup.

**Wizard Steps:**

Step 1 — Business Profile
- Business name, industry, location, number of employees
- Services offered (free text or multi-select by industry)
- Operating hours
- → Generates CLIENT_PROFILE.md

Step 2 — Owner Preferences
- Communication style (formal/casual/direct)
- Response length preference
- Signature line for emails
- Timezone
- → Generates OWNER_PREFERENCES.md

Step 3 — FAQ & Knowledge
- "What questions do your customers ask most?" (textarea, AI-assisted to structure into FAQ.md)
- Upload existing documents (PDF, DOCX, TXT) — extracted and stored in vault/
- Paste website URL → scrape key pages into vault/websites/
- → Generates FAQ.md, populates vault/

Step 4 — Procedures
- Select which workflows to enable (based on plan)
- For each enabled workflow, guided questions:
  - Email: "What email address? What's your reply style? Auto-draft or just categorize?"
  - Calendar: "What calendar system? Business hours? Booking rules?"
  - Customer Intake: "What info do you collect from new customers?"
  - Daily Briefing: "What time? What should it include?"
  - Documents: "What types of documents do you create most?"
- → Generates PROCEDURES/*.md files

Step 5 — Review & Index
- Show generated files in preview (editable)
- "Build My Assistant" button
- Triggers RAG indexing (calls provisioning API → runs index_vault.py for this tenant)
- Shows progress bar → "Your assistant is ready!"

**Technical Implementation:**
- Next.js app with multi-step form
- Authenticated via session token (created at signup)
- File generation: server-side markdown templating from form inputs
- File storage: SFTP or Coolify volume API to push files into client's Docker volume
- Document upload: accept PDF/DOCX/TXT, extract text server-side (pdf-parse, mammoth), store as .md in vault/
- Website scrape: server-side fetch + readability extraction, store as .md
- After wizard completion: trigger `docker compose --profile indexer up rag-indexer` via Coolify API

---

### 3. SELF-SERVE ADMIN PORTAL

Accessible at `https://app.yourdomain.com/dashboard` for paying customers.

**Features:**

- **Vault Management**
  - View/edit all vault files (markdown editor, browser-based)
  - Upload new documents (PDF/DOCX/TXT → auto-extracted to markdown)
  - Delete documents
  - "Re-index Now" button (triggers RAG re-index on demand)
  - Document count + limit display (Starter: 50 docs, Pro: unlimited)

- **Account & Billing**
  - Current plan display
  - Upgrade/downgrade buttons (→ Stripe Customer Portal)
  - Add-on management
  - Billing history (from Stripe)
  - Cancel subscription (with data export option)

- **Usage Metrics**
  - Chat messages this month
  - Workflows executed this month
  - Documents indexed
  - Last re-index timestamp
  - Storage used

- **Team Management** (Pro and above)
  - Invite users by email
  - Remove users
  - Role: admin / member (members can chat, admins can edit vault)
  - Seat count vs. limit

- **Workflow Status**
  - Which workflows are enabled
  - Last execution time per workflow
  - Enable/disable toggles (within plan limits)

- **Data Export**
  - "Export All My Data" → generates ZIP of vault files + DB dump
  - Available anytime (no lock-in policy)

**Technical Implementation:**
- Next.js app with authentication (email magic link or password)
- API routes that proxy to:
  - Coolify API (container status, restart)
  - Stripe API (billing, subscriptions)
  - Client's PostgreSQL (usage metrics via read-only queries)
  - Client's Docker volume (vault file CRUD)
- Tenant context resolved from authenticated user → tenant_id mapping in sales DB

---

### 4. INTERNAL OPERATIONS DASHBOARD

Accessible at `https://ops.yourdomain.com` (IP-restricted or admin-authenticated).

**Features:**

- **Tenant List**
  - All tenants: name, subdomain, plan, status, signup date, MRR contribution
  - Status indicators: active, trial, frozen, archived
  - Quick actions: restart stack, force re-index, impersonate, suspend

- **Provisioning Queue**
  - New signups pending provisioning
  - Failed provisioning (with error logs)
  - Retry button

- **Health Monitoring**
  - Per-tenant: Open WebUI status, n8n status, PostgreSQL status, last chat timestamp
  - Alerts: tenant down > 5 min, disk usage > 80%, failed workflows
  - Coolify container status integration

- **Revenue Dashboard**
  - MRR total + per-plan breakdown
  - Trial → paid conversion rate
  - Churn rate (monthly)
  - Revenue chart (last 12 months)
  - Stripe data integration

- **Usage Analytics**
  - Per-tenant: chat messages, workflows run, documents indexed, storage
  - Aggregate: total chats/day, busiest times, most-used workflows
  - Identify upsell opportunities (Starter tenants hitting limits)

- **Tenant Management**
  - Manual provisioning form (for Enterprise clients onboarded via sales)
  - Plan override (upgrade/downgrade without Stripe for comps/deals)
  - Suspend/unsuspend tenant
  - Delete tenant (with confirmation + 30-day data retention)
  - View tenant vault files (read-only)

- **System Health**
  - Droplet CPU/RAM/disk usage
  - Shared Ollama status + model loaded
  - Coolify status
  - Backup status (last successful backup per tenant)

**Technical Implementation:**
- Next.js app with admin-only auth (hardcoded admin emails or separate admin table)
- Pulls from: sales PostgreSQL DB, Coolify API, Stripe API, Digital Ocean API
- Background cron jobs:
  - Every 5 min: health check all tenant endpoints
  - Every hour: sync Stripe subscription status
  - Daily: usage aggregation + trial expiry checks
  - Daily: backup verification

---

### 5. SALES PIPELINE (Enterprise + Custom Rig)

Enterprise and Custom Rig tiers are NOT self-serve. They require human sales interaction.

**Landing Page Integration:**
- Enterprise "Contact Sales" button → Calendly booking link
- Custom Rig "Get a Quote" button → Calendly booking link
- Calendly event type: "Business Assistant Box — Discovery Call" (30 min)
- Calendly collects: business name, industry, number of employees, what they need most, budget range

**After Booking (Manual Workflow):**
1. Discovery call happens (Calendly sends reminder + calendar invite)
2. Sales rep fills out proposal using CLOUD_MULTI_TENANT_PROPOSAL_TEMPLATE.md
3. Proposal sent via email (PDF or link)
4. If accepted: manual provisioning via Internal Ops Dashboard
5. Onboarding call scheduled (separate Calendly event: "Onboarding — 60 min")
6. Client vault built manually (or via vault builder with rep assisting)
7. Status tracked in sales DB (lead → qualified → proposal → closed-won/lost)

**Sales DB Schema (leads table):**
```sql
CREATE TABLE leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_name TEXT NOT NULL,
  contact_name TEXT,
  contact_email TEXT NOT NULL,
  phone TEXT,
  industry TEXT,
  employee_count INTEGER,
  tier TEXT CHECK (tier IN ('enterprise', 'custom_rig')),
  status TEXT CHECK (status IN ('new', 'qualified', 'proposal_sent', 'negotiation', 'closed_won', 'closed_lost')),
  calendly_event_id TEXT,
  notes TEXT,
  proposal_sent_at TIMESTAMP,
  closed_at TIMESTAMP,
  monthly_value DECIMAL(10,2),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

**Internal Ops Dashboard — Sales Tab:**
- View all leads by status (kanban or table view)
- Move leads between stages
- Log notes after calls
- Track: days in pipeline, close rate, average deal size
- Generate proposal from template (fill in client name, plan, price, add-ons)

---

### 6. SALES DATABASE SCHEMA (Central)

This is the operational database for the SaaS layer itself (NOT the per-client RAG databases).

```sql
-- Tenants (paying customers)
CREATE TABLE tenants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_name TEXT NOT NULL,
  subdomain TEXT UNIQUE NOT NULL,
  owner_email TEXT NOT NULL,
  owner_name TEXT,
  plan TEXT CHECK (plan IN ('trial', 'starter', 'pro', 'enterprise')) NOT NULL,
  billing_cycle TEXT CHECK (billing_cycle IN ('monthly', 'annual')),
  status TEXT CHECK (status IN ('provisioning', 'active', 'trial', 'frozen', 'suspended', 'archived')) DEFAULT 'provisioning',
  stripe_customer_id TEXT,
  stripe_subscription_id TEXT,
  coolify_project_id TEXT,
  coolify_service_id TEXT,
  db_password TEXT NOT NULL,
  doc_limit INTEGER DEFAULT 10,
  workflow_limit INTEGER DEFAULT 1,
  seat_limit INTEGER DEFAULT 1,
  trial_started_at TIMESTAMP,
  trial_ends_at TIMESTAMP,
  activated_at TIMESTAMP,
  frozen_at TIMESTAMP,
  archived_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Tenant users (team members)
CREATE TABLE tenant_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES tenants(id),
  email TEXT NOT NULL,
  name TEXT,
  role TEXT CHECK (role IN ('admin', 'member')) DEFAULT 'member',
  invited_at TIMESTAMP DEFAULT NOW(),
  accepted_at TIMESTAMP,
  UNIQUE(tenant_id, email)
);

-- Usage tracking
CREATE TABLE usage_events (
  id BIGSERIAL PRIMARY KEY,
  tenant_id UUID REFERENCES tenants(id),
  event_type TEXT NOT NULL, -- 'chat_message', 'workflow_run', 'document_indexed', 'rag_query'
  metadata JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Provisioning log
CREATE TABLE provisioning_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES tenants(id),
  step TEXT NOT NULL,
  status TEXT CHECK (status IN ('pending', 'running', 'completed', 'failed')),
  error_message TEXT,
  started_at TIMESTAMP DEFAULT NOW(),
  completed_at TIMESTAMP
);

-- Leads (Enterprise/Custom Rig sales pipeline)
CREATE TABLE leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_name TEXT NOT NULL,
  contact_name TEXT,
  contact_email TEXT NOT NULL,
  phone TEXT,
  industry TEXT,
  employee_count INTEGER,
  tier TEXT CHECK (tier IN ('enterprise', 'custom_rig')),
  status TEXT CHECK (status IN ('new', 'qualified', 'proposal_sent', 'negotiation', 'closed_won', 'closed_lost')),
  calendly_event_id TEXT,
  notes TEXT,
  proposal_sent_at TIMESTAMP,
  closed_at TIMESTAMP,
  monthly_value DECIMAL(10,2),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

---

### 7. AUTOMATED LIFECYCLE EVENTS

Build these as cron jobs or n8n workflows running on the ops infrastructure:

**Trial Management:**
- Day 0: Welcome email + vault builder link
- Day 3: "How's it going?" check-in email (if vault not built yet, nudge)
- Day 7: "You've used X chats this week" engagement email
- Day 10: "Trial ends in 4 days" + upgrade CTA
- Day 13: "Last day tomorrow" urgent email
- Day 14: Freeze instance if no payment (set status=frozen, stop Open WebUI container)
- Day 21: Archive instance (stop all containers, retain volumes)
- Day 51: Delete archived data (destroy volumes, remove DNS)

**Subscription Events (Stripe webhooks):**
- `customer.subscription.created` → activate tenant, remove trial limits
- `customer.subscription.updated` → adjust plan limits (doc_limit, workflow_limit, seat_limit)
- `customer.subscription.deleted` → freeze tenant, send "we're sorry to see you go" + data export link
- `invoice.payment_failed` → email warning, retry 3x over 7 days, then freeze
- `invoice.paid` → unfreeze if previously frozen for payment failure

**Plan Limits Enforcement:**
| Plan | doc_limit | workflow_limit | seat_limit | chat_limit/day |
|------|-----------|---------------|------------|----------------|
| trial | 10 | 1 | 1 | 50 |
| starter | 50 | 1 | 1 | unlimited |
| pro | unlimited (99999) | 6 | 3 | unlimited |
| enterprise | unlimited | unlimited | 5+ | unlimited |

---

### 8. RECOMMENDED BUILD ORDER

Build in this sequence. Each phase is deployable and testable independently.

**Phase 1 — Sales Database + Stripe Integration (Week 1)**
- Set up sales PostgreSQL database on Digital Ocean managed DB
- Create schema (tenants, tenant_users, usage_events, provisioning_log, leads)
- Implement Stripe product/price creation (one-time setup script)
- Build Stripe Checkout session API endpoint (Next.js API route)
- Build Stripe webhook handler (checkout.session.completed, subscription events)
- Connect landing page "Sign Up" buttons to Stripe Checkout
- Result: People can pay. You get a webhook with their info.

**Phase 2 — Automated Provisioning (Week 2)**
- Build provisioning service (Node.js) that:
  - Receives tenant info from Stripe webhook
  - Calls Coolify API to deploy client stack
  - Waits for health check
  - Updates tenant status in sales DB
  - Sends welcome email (use Resend or AWS SES)
- Build trial provisioning (same flow, no Stripe, email-triggered)
- Test: sign up → stack deployed → subdomain live within 5 minutes
- Result: Self-serve signup works end-to-end for Starter and Pro.

**Phase 3 — Self-Serve Vault Builder (Week 3-4)**
- Build Next.js multi-step wizard app
- Implement markdown file generation from form inputs
- Implement document upload + text extraction (pdf-parse, mammoth)
- Implement file push to tenant Docker volumes (via Coolify API or SSH)
- Implement "Re-index" trigger (runs rag-indexer container)
- Optional: website scraping endpoint
- Result: New customers can build their AI's knowledge without technical skills.

**Phase 4 — Self-Serve Admin Portal (Week 4-5)**
- Build authenticated Next.js dashboard
- Implement vault file browser/editor (markdown CRUD)
- Implement Stripe Customer Portal redirect (billing management)
- Implement usage metrics display (query tenant's PostgreSQL)
- Implement team management (invite/remove users)
- Implement data export endpoint
- Result: Customers manage their own account without contacting you.

**Phase 5 — Internal Operations Dashboard (Week 5-6)**
- Build admin-authenticated Next.js dashboard
- Implement tenant list with status/health indicators
- Implement Coolify + DO API integration for health monitoring
- Implement Stripe revenue dashboard
- Implement manual provisioning form (for Enterprise onboarding)
- Implement tenant suspend/archive/delete actions
- Build background health check cron (every 5 min)
- Result: You can operate the business from a single pane of glass.

**Phase 6 — Trial Lifecycle Automation (Week 6-7)**
- Build email sequence (day 0, 3, 7, 10, 13, 14 triggers)
- Implement trial freeze logic (day 14: stop containers)
- Implement trial archive logic (day 21: stop all, retain data)
- Implement trial cleanup (day 51: destroy)
- Implement payment failure handling (warn → retry → freeze)
- Use n8n on ops infrastructure for scheduling, or Node.js cron
- Result: Trials convert or clean up automatically. No manual babysitting.

**Phase 7 — Sales Pipeline for Enterprise (Week 7-8)**
- Set up Calendly event types (Discovery Call 30min, Onboarding 60min)
- Add Calendly links to landing page Enterprise/Custom Rig sections
- Build leads table + kanban/table view in Internal Ops Dashboard
- Implement Calendly webhook → create lead in sales DB
- Build proposal generator (populate template from lead data)
- Result: Enterprise leads are tracked and proposals are generated quickly.

**Phase 8 — Hardening & Polish (Week 8-9)**
- Rate limiting on all APIs
- Error handling + retry logic on provisioning
- Monitoring alerts (tenant down, provisioning failed, payment failed)
- Backup verification automation
- Load testing (simulate 20 concurrent tenants)
- Security audit: webhook signature verification, input sanitization, auth on all endpoints
- Result: Production-ready SaaS that won't break at 3 AM.

---

### 9. DIRECTORY STRUCTURE FOR SAAS LAYER

```
saas-layer/
├── apps/
│   ├── marketing/              # Landing page (already exists)
│   ├── signup/                 # Stripe checkout + trial signup
│   ├── vault-builder/         # Self-serve vault wizard
│   ├── customer-portal/       # Self-serve admin dashboard
│   └── ops-dashboard/         # Internal operations
├── services/
│   ├── provisioning/          # Tenant provisioning service
│   │   ├── provision.ts       # Coolify API integration
│   │   ├── health-check.ts    # Poll tenant endpoints
│   │   └── cleanup.ts         # Archive/delete tenants
│   ├── billing/               # Stripe webhook handlers
│   │   ├── webhooks.ts        # Handle Stripe events
│   │   └── plans.ts           # Plan limits + enforcement
│   ├── lifecycle/             # Trial + subscription automation
│   │   ├── trial-emails.ts    # Drip email sequences
│   │   ├── trial-freeze.ts    # Freeze/archive logic
│   │   └── usage-check.ts     # Limit enforcement
│   └── vault/                 # Vault file management
│       ├── generate.ts        # Markdown generation from form
│       ├── upload.ts          # Document extraction + storage
│       ├── push.ts            # Push files to tenant volume
│       └── reindex.ts         # Trigger RAG re-indexing
├── db/
│   ├── schema.sql             # Sales database schema
│   ├── migrations/            # Schema migrations
│   └── seed.sql               # Test data
├── scripts/
│   ├── setup-stripe.ts        # One-time Stripe product creation
│   ├── onboard-enterprise.sh  # Manual Enterprise provisioning
│   └── backup-all.sh          # Backup all tenant data
├── .env.example
├── docker-compose.saas.yml    # Ops infrastructure stack
└── README.md
```

---

### 10. ENVIRONMENT VARIABLES (.env for SaaS layer)

```env
# Database (sales/ops DB — NOT client DBs)
DATABASE_URL=postgresql://admin:password@db-host:5432/bab_saas

# Stripe
STRIPE_SECRET_KEY=sk_live_xxx
STRIPE_WEBHOOK_SECRET=whsec_xxx
STRIPE_STARTER_MONTHLY_PRICE_ID=price_xxx
STRIPE_STARTER_ANNUAL_PRICE_ID=price_xxx
STRIPE_PRO_MONTHLY_PRICE_ID=price_xxx
STRIPE_PRO_ANNUAL_PRICE_ID=price_xxx

# Coolify
COOLIFY_API_URL=https://coolify.yourdomain.com
COOLIFY_API_TOKEN=xxx
COOLIFY_SHARED_NETWORK=bab-shared
OLLAMA_SHARED_URL=http://ollama:11434

# Digital Ocean
DO_API_TOKEN=xxx
DO_SPACES_KEY=xxx
DO_SPACES_SECRET=xxx
DO_SPACES_BUCKET=bab-backups
DO_SPACES_REGION=nyc3

# Email (Resend or SES)
EMAIL_PROVIDER=resend
RESEND_API_KEY=re_xxx
EMAIL_FROM=hello@yourdomain.com

# Calendly (Enterprise sales)
CALENDLY_WEBHOOK_SECRET=xxx
CALENDLY_DISCOVERY_CALL_URL=https://calendly.com/yourname/discovery-call
CALENDLY_ONBOARDING_URL=https://calendly.com/yourname/onboarding

# App URLs
APP_URL=https://app.yourdomain.com
OPS_URL=https://ops.yourdomain.com
MARKETING_URL=https://yourdomain.com

# Auth
JWT_SECRET=xxx
ADMIN_EMAILS=you@yourdomain.com

# Tenant defaults
DEFAULT_DOMAIN=yourdomain.com
TRIAL_DAYS=14
FREEZE_AFTER_DAYS=14
ARCHIVE_AFTER_DAYS=21
DELETE_AFTER_DAYS=51
```

---

## CONSTRAINTS

- Starter and Pro are FULLY self-serve. No human intervention required from signup to active assistant.
- Enterprise and Custom Rig require human sales (Calendly → call → proposal → manual provisioning).
- All tenant data is isolated (separate Docker volumes, separate PostgreSQL containers per tenant).
- The vault builder must be usable by non-technical business owners (no markdown knowledge required).
- Trial must be functional enough to demonstrate value (limited but working AI assistant).
- The internal ops dashboard must show real-time health of all tenants.
- Stripe is the single source of truth for billing state. Sales DB syncs from Stripe webhooks.
- All provisioning must be idempotent (safe to retry on failure).
- Backup every tenant daily to DO Spaces.
- Send no more than 1 email per day to trial users (no spam).
