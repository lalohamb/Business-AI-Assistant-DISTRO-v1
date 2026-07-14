# BUSINESS_KNOWLEDGE.md

## Purpose

Maintain operational knowledge about the Business Assistant Box platform.

---

## System Architecture

### Components

| Service | Port | Purpose |
|---------|------|---------|
| Open WebUI | 3000 | Chat interface |
| Ollama | 11434 | Local LLM inference |
| PostgreSQL + pgvector | 5432 | Vector database for RAG |
| n8n | 5678 | Workflow automation |

### Data Flow

1. User places documents in `clients/{ACTIVE_CLIENT}/DOCUMENTS/`
2. `index_vault.py` extracts text, generates embeddings via Ollama, stores in pgvector
3. User asks a question in Open WebUI
4. `business_rag_filter.py` queries pgvector for top-k relevant chunks
5. Chunks are prepended to the prompt with anti-hallucination instructions
6. Ollama generates a grounded, cited response

---

## File Structure

```
business-assistant-box/
├── admin/           # install.sh, configure scripts, sync_today.sh
├── clients/         # Per-business knowledge vaults
│   ├── templates/   # Blank scaffolding for new clients
│   └── {client}/    # Active client data
├── dashboard/       # Open WebUI config, functions, webui.db
├── docker/          # docker-compose.yml, container configs
├── n8n/workflows/   # Standard + selectable automation workflows
├── system/          # Shared system-level documents
└── vector-db/       # schema.sql, index_vault.py
```

---

## Key Configuration

| Variable | Location | Purpose |
|----------|----------|---------|
| ACTIVE_CLIENT | .env | Which client folder to index |
| OLLAMA_MODEL | .env | Default model for all workflows |
| OLLAMA_BASE_URL | .env | Ollama endpoint |
| top_k | business_rag_filter.py | Number of chunks retrieved (default: 8) |

---

## Supported Document Formats

- Markdown (.md)
- Plain text (.txt)
- PDF (.pdf) — via pymupdf
- Word (.docx) — via python-docx
- Excel (.xlsx) — via openpyxl
- CSV (.csv) — built-in
- HTML (.html) — via beautifulsoup4
- Email (.eml) — built-in email parser

---

## Workflow Catalog

### Standard (always active)
1. daily-briefing — Morning executive summary
2. email-summary — Categorize and summarize inbox
3. calendar-review — Flag conflicts and prep
4. document-draft — Generate business documents
5. customer-intake — New lead processing
6. task-tracker — Update OPEN_TASKS.md

### Selectable (enable per client)
7. invoice-review — Parse and flag invoices
8. contract-summary — Summarize legal documents
9. social-media-draft — Generate posts
10. meeting-notes — Transcribe and summarize
11. expense-report — Categorize expenses
12. competitor-watch — Monitor industry news
13. hiring-screen — Resume screening
14. inventory-alert — Stock level monitoring
15. client-followup — Automated check-ins
16. report-generator — Weekly/monthly reports

---

## Maintenance Procedures

### Re-index documents
```bash
source /home/ubuntu/.business-assistant-box/venv/bin/activate
python3 vector-db/index_vault.py
```

### Restart services
```bash
cd docker && docker compose restart
```

### Update RAG filter in WebUI
```bash
bash admin/configure_rag_pipeline.sh
```

### Add a new client
```bash
bash clients/templates/create_client.sh my-new-business
# Then edit the files and set ACTIVE_CLIENT in .env
```

---

## Troubleshooting Quick Reference

| Symptom | Cause | Fix |
|---------|-------|-----|
| "I don't have that information" | Document not indexed | Re-run index_vault.py |
| Hallucinated answers | RAG filter not active | Check function is enabled in WebUI |
| Slow responses | Model too large for hardware | Switch to smaller model |
| n8n workflows fail | OLLAMA_MODEL not set | Recreate container with env var |
| ivfflat error | lists > row_count | Re-index (auto-fixes) |

---

## Internal Knowledge

### Anti-Hallucination Design
- RAG prefix forces model to only use retrieved context
- If answer not in context, model must say "I don't have that information"
- All responses should cite source file name

### Security Model
- All data stays on local machine
- No telemetry or external API calls (unless user configures Gemini)
- WebUI accessible only on localhost:3000 by default
- PostgreSQL not exposed externally

### Performance Tuning
- top_k=8 balances relevance vs context window size
- ivfflat index rebuilt dynamically: lists = sqrt(row_count)
- Chunk size: 500 tokens with 50-token overlap
- Embedding model: nomic-embed-text (via Ollama)
