# RAG Indexer & Vault Documents

## Overview

`vector-db/index_vault.py` is the RAG (Retrieval-Augmented Generation) indexing script. It scans files from three source directories, extracts text content, splits it into chunks, generates embeddings via Ollama, and stores everything in PostgreSQL with pgvector for semantic search.

## What Gets Indexed

| Source | Purpose |
|--------|---------|
| `system/` | AI behavior rules (AGENTS, POLICIES, IDENTITY, etc.) |
| `clients/{ACTIVE_CLIENT}/` | Active client's business knowledge |
| `vault/` | Shared documents available to all clients |

## Supported File Formats

| Format | Extension | Library | Use Case |
|--------|-----------|---------|----------|
| Markdown | .md | built-in | Knowledge base files, procedures, notes |
| Plain text | .txt | built-in | Raw text, logs, exports |
| PDF | .pdf | pymupdf | Contracts, scanned docs, legal filings |
| Word | .docx | python-docx | Letters, reports, templates |
| Excel | .xlsx | openpyxl | Spreadsheets, financial data, lists |
| CSV | .csv | built-in | Exported data, contact lists, inventories |
| HTML | .html, .htm | beautifulsoup4 | Saved web pages, email exports |
| Email | .eml | built-in | Saved email messages |

## vault/company-documents/

This is the **shared knowledge** directory. Files placed here are indexed regardless of which client is active — unlike `clients/{name}/DOCUMENTS/` which is per-client.

### What to put here

- Employee handbooks
- Internal SOPs and policies
- Vendor agreements
- Insurance policies
- Reference material (industry regulations, compliance docs)
- Company-wide templates
- Saved emails or correspondence
- Financial reports (PDF or Excel)

### What NOT to put here

- Client-specific documents (use `clients/{name}/DOCUMENTS/` instead)
- Credentials, keys, or secrets
- Large binary files (images, video) — they can't be text-extracted

### vault/ subdirectories

```
vault/
├── company-documents/   # General company docs (SOPs, handbooks)
├── contracts/           # Signed contracts and agreements
├── financials/          # Financial reports, P&L, tax docs
├── handbooks/           # Employee/operations handbooks
├── uploads/             # Misc uploaded files
└── websites/            # Saved web content
```

All subdirectories under `vault/` are indexed. Organize however makes sense for your business.

## How It Works

```
Drop file into vault/company-documents/
  ↓
Run: ./venv/bin/python index_vault.py
  ↓
extract_text() parses file based on extension
  ↓
Text split into 512-char chunks (64-char overlap)
  ↓
Each chunk embedded via Ollama nomic-embed-text
  ↓
Chunks stored in PostgreSQL rag_chunks table
  ↓
User asks question in Open WebUI → RAG retrieves matching chunks
```

## Usage

```bash
cd /home/ubuntu/.business-assistant-box/business-assistant-box/vector-db
./venv/bin/python index_vault.py
```

Re-run after adding, editing, or removing files. The script deletes all existing chunks for the active client and re-indexes from scratch.

## Query

```bash
./venv/bin/python query_vault.py "what is our refund policy?"
```

Returns the top 5 most semantically similar chunks from the active client's indexed data.

## Excluded from Indexing

| Path/Pattern | Reason |
|--------------|--------|
| admin/ | Internal build docs, never exposed to AI |
| logs/ | Runtime logs |
| backups/ | Backup archives |
| docker/ | Container configs |
| postgres/ | Database volume |
| .git/ | Version control |
| venv/ | Python environment |
| .obsidian/ | Obsidian app config |
| .env | Contains credentials |
| *.key, *.pem | Cryptographic material |

## Dependencies

Installed in `vector-db/venv/`:

```
psycopg2-binary
python-dotenv
requests
pymupdf
python-docx
openpyxl
beautifulsoup4
```

The `csv` and `email` modules are Python built-ins (no install needed).

## Configuration

All settings read from `.env`:

| Variable | Purpose |
|----------|---------|
| BASE_PATH | Root project directory |
| ACTIVE_CLIENT | Which client to index |
| EMBEDDING_PROVIDER | ollama |
| EMBEDDING_MODEL | nomic-embed-text |
| OLLAMA_BASE_URL | http://localhost:11434 |
