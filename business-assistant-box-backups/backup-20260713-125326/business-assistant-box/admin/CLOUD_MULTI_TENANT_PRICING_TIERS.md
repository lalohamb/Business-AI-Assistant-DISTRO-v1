# CLOUD_MULTI_TENANT_PRICING_TIERS.md

# Business Assistant Box — Service Models & Pricing

Three ways to run Business Assistant Box. Choose based on your technical comfort, budget, and control preference.

---

## Tier 1 — License the Code

**You run it. We give you the software.**

| | |
|---|---|
| **Model** | 1-year software license + updates |
| **Price** | $2,500/year |
| **Renewal** | $1,500/year (updates + support) |
| **Who it's for** | Technical teams, IT shops, MSPs who want to self-host or resell |

**What you get:**
- Full source code + Docker Compose stack
- All admin scripts (install, onboard, switch, backup, validate)
- RAG pipeline (index_vault.py, query_vault.py, schema)
- n8n workflow templates (all 6 business workflows)
- System intelligence files (AGENTS, POLICIES, PROMPTS, IDENTITY)
- Client template structure
- Documentation (architecture, deployment, troubleshooting)
- 1 year of updates via private repo access
- Email support for installation issues
- **Single-client license** — runs one business at a time

**Client limit:**
- License is locked to **1 active client** via `.license` file
- Scripts enforce the limit (switch_client.sh, post_install_client_setup.sh)
- To serve multiple clients, upgrade to Multi-Client License ($4,500/year)

**What you handle:**
- Your own hardware or cloud server
- Docker, PostgreSQL, Ollama setup
- LLM costs (self-hosted or API)
- Backups and maintenance

**Use cases:**
- Business owner with a technical partner who wants full control
- Single-location business that wants to own their AI stack
- Developer evaluating the platform before committing to cloud or rig

**Upgrade path:**
- Multi-Client License: $4,500/year (unlimited clients, same code)
- Or move to Cloud tier (we manage it for you)

---

## Tier 2 — Cloud (Managed SaaS)

**We run it. You use it.**

| | |
|---|---|
| **Model** | Monthly subscription, fully managed |
| **Who it's for** | Business owners who want it working without touching servers |

### Plans

| Plan | Price | Best For |
|------|-------|----------|
| **Starter** | $149/month | Solo operators, 1-2 employees |
| **Pro** | $299/month | Small business, 3-10 employees |
| **Enterprise** | $499–799/month | Multi-location, regulated, high-volume |

**What you get:**
- Private AI chat trained on your business knowledge
- Knowledge vault with RAG (AI answers from your documents)
- Automated workflows (email, calendar, briefings, documents)
- Custom subdomain with SSL (`yourname.ourdomain.com`)
- Nightly auto-indexing
- Daily automated backups
- 99.5% uptime SLA
- We handle all infrastructure, updates, and scaling

**What you handle:**
- Editing your business knowledge (plain text / markdown)
- Telling us what workflows you need
- Using the system

**Starter includes:**
- AI chat + knowledge vault (50 docs)
- 1 workflow
- Monthly re-index

**Pro includes:**
- Unlimited documents
- All 6 workflows
- Nightly re-index
- Memory + procedures + owner preferences

**Enterprise includes:**
- Dedicated infrastructure
- Custom workflows
- 5 user seats
- Priority support
- Custom domain

**Add-ons:**
| Add-On | Price |
|--------|-------|
| Onboarding & vault build | $500 one-time |
| Bulk document ingestion | $250 one-time |
| Additional workflow | $99/month |
| Extra user seat | $29/user/month |
| White-label domain | $49/month |

---

## Tier 3 — Custom Server Rig

**We build it. You own the hardware. We support it.**

| | |
|---|---|
| **Model** | One-time hardware + software build, optional support contract |
| **Who it's for** | Businesses that want everything on-premise, air-gapped, or fully private |

### Pricing

| Component | Price |
|-----------|-------|
| Hardware rig (built & configured) | $3,500–6,000 |
| Software license (1 year included) | Included |
| Installation & onboarding | Included |
| Annual support & updates | $1,500/year (optional) |

### Hardware Specs

| Config | Specs | Handles |
|--------|-------|---------|
| **Standard** ($3,500) | 16GB RAM, 8-core CPU, 1TB SSD, no GPU | API-based LLM (OpenRouter, Groq, OpenClaw) |
| **Pro** ($4,500) | 32GB RAM, 12-core CPU, 2TB SSD, RTX 3060 12GB | Local 7B-14B models via Ollama |
| **Max** ($6,000) | 64GB RAM, 16-core CPU, 2TB SSD, RTX 4090 24GB | Local 14B-70B models, fast inference |

**What you get:**
- Pre-built server hardware (mini PC or rackmount, your choice)
- Ubuntu 24.04 LTS installed and hardened
- Full Business Assistant Box deployed and tested
- PostgreSQL + pgvector configured
- Ollama with models pulled (if GPU config)
- n8n with all 6 workflows configured
- Open WebUI configured and themed
- Client vault built from your documents
- 1-hour onboarding walkthrough
- Network configuration guide
- 1 year software updates
- Hardware warranty (manufacturer's)

**What you handle:**
- Plugging it into your network
- Power and internet
- Physical security
- LLM API costs (if no GPU) or electricity (if GPU)

**Optional ongoing support:**

| Support Level | Price | Includes |
|---------------|-------|----------|
| Basic | $99/month | Email support, quarterly updates pushed remotely |
| Priority | $199/month | Same-day support, monthly updates, remote monitoring |
| Managed | $399/month | We fully manage it remotely — updates, backups, troubleshooting |

---

## Comparison

| | License (Single) | License (Multi) | Cloud | Custom Rig |
|---|---|---|---|---|
| **Upfront cost** | $2,500 | $4,500 | $0 | $3,500–6,000 |
| **Monthly cost** | $0 (you pay infra) | $0 (you pay infra) | $149–799 | $0–399 (support optional) |
| **Year 1 total** | $2,500 + infra | $4,500 + infra | $1,788–9,588 | $3,500–6,000 |
| **Year 2+ total** | $1,500 renewal | $2,500 renewal | Same monthly | $1,500 renewal (optional) |
| **Client limit** | 1 | Unlimited | Per plan | Per license included |
| **Technical skill** | High | High | None | Low (plug and play) |
| **Data location** | Your choice | Your choice | Our cloud (DO) | Your office |
| **Can resell** | No | Yes | No | No (per-business) |
| **Best for** | Single business, self-host | MSPs, IT shops, agencies | Business owners | Privacy-first, air-gap |

---

## Bundle Deals

| Bundle | What's Included | Price |
|--------|----------------|-------|
| **MSP Starter Pack** | Multi-client license + 5-client cloud setup + onboarding | $6,000/year |
| **Office-in-a-Box** | Pro rig + multi-client license + 1yr managed support + vault build | $7,000 all-in |
| **Franchise Kit** | Multi-client license + 3 custom rigs + deployment docs | $15,000 |

---

## FAQ

**Can I switch between tiers?**
Yes. Start with Cloud, move to a Custom Rig later. Or license the code after using Cloud to understand the system. We'll migrate your data.

**Can I resell with the License tier?**
The single-client license ($2,500/yr) is for one business only. To deploy for multiple clients or resell, you need the Multi-Client License ($4,500/yr). No per-seat royalties on multi-client — you set your own pricing.

**How is the client limit enforced?**
A `.license` file in the project root controls the tier. Admin scripts (switch_client.sh, post_install_client_setup.sh) check this file before allowing additional clients. The code is open — we trust our customers, but the license terms are legally binding.

**Do I need a GPU?**
No. All tiers work with API-based LLMs (OpenRouter, Groq, OpenClaw). GPU only needed if you want fully offline/private inference.

**What about updates?**
- License: pull from private repo (while license active)
- Cloud: automatic, zero-downtime
- Custom Rig: pushed remotely (with support contract) or manual

**What if my rig hardware fails?**
Standard manufacturer warranty applies. With managed support, we ship a replacement and restore from backup.
