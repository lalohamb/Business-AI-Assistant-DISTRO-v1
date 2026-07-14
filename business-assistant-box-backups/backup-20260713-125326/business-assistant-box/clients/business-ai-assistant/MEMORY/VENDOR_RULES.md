# VENDOR_RULES.md

## Purpose

Track upstream dependencies and their status.

---

## Dependencies

Vendor: Ollama
Type: Local AI runtime
Version: Latest
Notes: Self-hosted, no API key needed. Models downloaded locally.

Vendor: Open WebUI
Type: Chat interface
Version: Latest (Docker image)
Notes: Community edition, MIT license

Vendor: PostgreSQL + pgvector
Type: Vector database
Version: PostgreSQL 16 + pgvector 0.7+
Notes: Official Docker image with pgvector extension

Vendor: n8n
Type: Workflow automation
Version: Latest (Docker image)
Notes: Community edition, fair-code license

---

## Python Libraries

| Package | Purpose | Install Location |
|---------|---------|-----------------|
| psycopg2-binary | PostgreSQL driver | venv + filter frontmatter |
| pymupdf | PDF extraction | venv |
| python-docx | DOCX extraction | venv |
| openpyxl | XLSX extraction | venv |
| beautifulsoup4 | HTML extraction | venv |
| requests | HTTP calls to Ollama | venv |

---

## Escalation Rules

- If Ollama model download fails: check disk space and internet
- If pgvector extension missing: verify Docker image includes it
- If n8n community nodes needed: install via n8n UI settings
