# PROJECT_STATUS.md

## Business Assistant Box

### Current Project Status

Project Name: Business Assistant Box

Project Owner: Lalo Ahambrick Day

Primary Goal: Build a private AI Office Assistant appliance for small and medium-sized businesses.

---

## Current Phase

Current Phase: Phase 10 — Multi-Client Demo & Production Readiness

Phase Description: Core infrastructure fully deployed. RAG pipeline operational with 3 indexed clients. Multi-client switching automated. License upgraded to multi-tier. System ready for end-to-end demonstration.

---

## Overall Progress

Phase 1 - Base OS
Status: ✅ Complete
Notes: Ubuntu 24.04 LTS running on Linux x86_64. Dual-GPU system (RTX 2060 SUPER for inference, GTX 970 for video).

Phase 2 - Infrastructure
Status: ✅ Complete
Notes: Docker running with 3 containers (postgres, openwebui, n8n). Structured workspace deployed at ~/.business-assistant-box/business-assistant-box.

Phase 3 - AI Layer
Status: ✅ Complete
Notes: Ollama active with 5 models: qwen3:14b, llama3.2, qwen2.5-coder:7b, phi3, nomic-embed-text. GPU pinned to RTX 2060 SUPER via systemd override. Open WebUI healthy on port 3000.

Phase 4 - OpenClaw
Status: ⏸️ Deferred
Notes: Workspace directory exists. No API key configured. Using Ollama as primary AI provider.

Phase 5 - Automation
Status: ✅ Complete
Notes: n8n running on port 5678. Workflow manifests and templates in place. API key configured.

Phase 6 - Database
Status: ✅ Complete
Notes: PostgreSQL with pgvector running on port 5432. RAG schema deployed with 768-dim vector index. 3 clients indexed (290 total chunks).

Phase 7 - Knowledge Vault
Status: ✅ Complete
Notes: Vault structure created. 4 client vaults populated (demo-company, acme-roofing, insurance-agency, law-office) with full business knowledge, procedures, memory, and FAQ. System intelligence files in place. Obsidian vault configured via current-client symlink. Note: insurance-agency vault populated but not yet indexed into RAG.

Phase 8 - RAG
Status: ✅ Complete
Notes: index_vault.py and query_vault.py functional. Python venv with psycopg2-binary, python-dotenv, requests. Embedding via nomic-embed-text (Ollama). All 3 active clients indexed and queryable.

Phase 9 - Dashboard
Status: ⏸️ Paused
Notes: Open WebUI serving as primary chat interface. Dedicated dashboard apps (Next.js) built previously but not actively running. May revisit for custom business UI.

Phase 10 - Multi-Client Demo
Status: 🔧 In Progress
Notes: Multi-client switching operational via switch_client.sh. License upgraded to multi-tier. Demo data created for all clients. Documentation updated. Ready for live workflow demonstration.

---

## Running Services

| Service | Container | Port | Status |
|---------|-----------|------|--------|
| PostgreSQL + pgvector | postgres | 5432 | Up |
| Open WebUI | openwebui | 3000 | Up (healthy) |
| n8n | n8n | 5678 | Up |
| Ollama | (native/systemd) | 11434 | Active |

---

## Installed Models

| Model | Size | Purpose |
|-------|------|---------|
| llama3.2 | 2.0 GB | Primary chat (fits in 8 GB VRAM) |
| qwen3:14b | 9.3 GB | Advanced reasoning (multi-GPU) |
| qwen2.5-coder:7b | 4.7 GB | Code generation |
| phi3 | 2.2 GB | Lightweight tasks |
| nomic-embed-text | 274 MB | RAG embeddings (768 dim) |

---

## Client Status

| Client | Indexed Chunks | Status |
|--------|---------------|--------|
| demo-company | 124 | ✅ Complete |
| acme-roofing | 82 | ✅ Complete |
| law-office | 84 | ✅ Active |
| insurance-agency | 279 | ✅ Active (current) |

Active Client: insurance-agency

---

## Hardware

| Component | Spec | Role |
|-----------|------|------|
| GPU 1 | NVIDIA RTX 2060 SUPER (8 GB) | LLM inference |
| GPU 2 | NVIDIA GTX 970 (4 GB) | Video/display |
| CPU | Intel Xeon E5-2630 v2 (24 threads) | General compute |
| RAM | 128 GB DDR3 | |
| Storage | 1 TB SSD (810 GB free) | |

---

## Active Configuration

- AI Provider: Ollama
- LLM Model: qwen3:14b (configurable via OLLAMA_MODEL env var)
- Embedding Model: nomic-embed-text (768 dimensions)
- Active Client: insurance-agency
- License Tier: multi (expires 2027-06-02)
- RAG Enabled: true (top_k=8, anti-hallucination prefix)
- System Prompt: Configured (persistent identity in Open WebUI)
- Workflow Engine: n8n (all workflows use local Ollama)
- Approval Required for Email: true
- File Types Indexed: .md, .txt, .pdf, .docx, .xlsx, .csv, .html, .eml

---

## Completed This Session (2026-07-12)

- ✅ Fixed Open WebUI crash-loop (integer timestamps in SQLite)
- ✅ Fixed RAG empty results (ivfflat index lists=16, auto-rebuild after indexing)
- ✅ Fixed psycopg2 persistence (frontmatter requirements)
- ✅ Set anti-hallucination RAG prefix
- ✅ Increased top_k from 5 to 8
- ✅ Configured persistent system prompt in Open WebUI
- ✅ Added multi-format indexing (PDF, DOCX, XLSX, CSV, HTML, EML)
- ✅ Converted all 16 n8n workflows from Gemini to local Ollama
- ✅ Made workflow model configurable via OLLAMA_MODEL env var
- ✅ Added sample documents to DOCUMENTS/ (carrier appointments, handbook, service agreement)
- ✅ Populated TODAY.md and OPEN_TASKS.md with operational data
- ✅ Added daily-briefing write-back to TODAY.md
- ✅ Created sync_today.sh for cron-based TODAY.md sync
- ✅ Created Ollama-to-Gemini.md documentation
- ✅ Updated CHANGELOG.md, TROUBLESHOOTING.md, VAULT_INDEXING.md, WORKFLOW_SETUP.md
- ✅ All 12 E2E tests passing

---

## Active Blockers

- None critical

---

## Open Issues

- No live email/calendar integration (n8n workflows need Google OAuth2 credentials wired)
- Dashboard apps (Next.js) not actively running — using Open WebUI instead
- OpenClaw deferred (no API key)
- expense-tracker and voicemail-transcription lose multimodal features without Gemini
- DOCUMENTS/ still mostly sample data — needs real business documents
- sync_today.sh not yet added to crontab

---

## Next Milestones

1. Wire n8n workflows to live email (Google OAuth2 credentials)
2. Add real business documents to DOCUMENTS/ and re-index
3. Add sync_today.sh to crontab for automated daily briefing persistence
4. Test client switching in production with Obsidian vault reload
5. Package for distribution (zip_package.sh)
6. Consider HNSW index for larger document sets (>5000 chunks)

---

## Last Updated

Date: 2026-07-12

Updated By: Amazon Q / Edward Hambrick

Notes: Major fixes session — crash-loop fix, RAG pipeline improvements, all workflows converted to local Ollama, documentation overhaul. All 12 E2E tests passing.
