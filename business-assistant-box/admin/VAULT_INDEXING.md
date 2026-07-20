# RAG Indexing

## What Gets Indexed

`index_vault.py` reads `ACTIVE_CLIENT` from `.env` and indexes two paths:

| Path | Purpose |
|------|---------|
| `system/` | System prompts, identity, policies (shared across all clients) |
| `clients/{ACTIVE_CLIENT}/` | All client-specific knowledge and documents |

## Client Folder Structure

```
clients/insurance-agency/
├── BUSINESS_KNOWLEDGE.md      ← indexed
├── BUSINESS_PROFILE.md          ← indexed
├── FAQ.md                     ← indexed
├── OWNER_PREFERENCES.md       ← indexed
├── PROCEDURES/                ← indexed
│   ├── EMAIL.md
│   ├── CALENDAR.md
│   ├── DAILY_BRIEFING.md
│   ├── CUSTOMER_INTAKE.md
│   └── DOCUMENTS.md
├── MEMORY/                    ← indexed
│   ├── CUSTOMER_RULES.md
│   ├── VENDOR_RULES.md
│   ├── LEARNED_PATTERNS.md
│   ├── TODAY.md               ← auto-populated by daily-briefing workflow
│   └── OPEN_TASKS.md
└── DOCUMENTS/                 ← indexed (raw business documents)
    ├── contracts/
    ├── handbooks/
    ├── financials/
    ├── uploads/
    ├── websites/
    └── company-documents/
```

Everything under the active client folder is indexed — including all subdirectories.

## Supported File Types

| Extension | Extraction Method | Library |
|-----------|------------------|---------|
| `.md` | Plain text read | built-in |
| `.txt` | Plain text read | built-in |
| `.csv` | Plain text read | built-in |
| `.eml` | Plain text read | built-in |
| `.pdf` | Page text extraction | pymupdf (fitz) |
| `.docx` | Paragraph extraction | python-docx |
| `.xlsx` | Row-by-row with pipe separators | openpyxl |
| `.html` | Tag stripping, text only | beautifulsoup4 |

All extraction libraries are pre-installed in `vector-db/venv/`.

## How to Index

After adding or editing documents:

```bash
cd /home/ubuntu/.business-assistant-box/business-assistant-box
./vector-db/venv/bin/python3 ./vector-db/index_vault.py
```

This:
1. Deletes existing chunks for the active client
2. Reads all supported files from the index paths
3. Extracts text (handles PDF, DOCX, XLSX, HTML automatically)
4. Chunks text into ~512 character segments (prefers markdown `---` and `##` boundaries)
5. Prepends `[Source: {filename} for {client}]` to improve embedding relevance
6. Generates embeddings via Ollama (nomic-embed-text, 768 dimensions)
7. Stores chunks + embeddings in pgvector
8. **Rebuilds the ivfflat index** with `lists = sqrt(row_count)` for optimal performance

## Index Rebuild Behavior

The ivfflat index is automatically rebuilt at the end of every indexing run. The `lists` parameter is calculated dynamically:

```python
lists = max(1, min(int(row_count ** 0.5), row_count // 10))
```

This ensures the index works correctly regardless of dataset size. The `schema.sql` does NOT create the index — it's only created by `index_vault.py` after data exists.

**Why this matters:** ivfflat with `lists=100` and only 261 rows returns empty results. The index must have `lists << row_count`.

## DOCUMENTS/ Subdirectories

| Folder | What goes here |
|--------|---------------|
| `contracts/` | Client contracts, agreements, policies |
| `handbooks/` | Carrier handbooks, compliance guides, manuals |
| `financials/` | Financial statements, tax docs, reports |
| `uploads/` | Miscellaneous uploaded files |
| `websites/` | Scraped website content |
| `company-documents/` | General company documents, templates |

## Adding New Documents

1. Drop files into the appropriate `DOCUMENTS/` subdirectory
2. Supported: `.md`, `.txt`, `.pdf`, `.docx`, `.xlsx`, `.csv`, `.html`, `.eml`
3. Re-index:
   ```bash
   ./vector-db/venv/bin/python3 ./vector-db/index_vault.py
   ```
4. Verify:
   ```bash
   docker exec -i postgres psql -U admin businessassistant -t -c \
     "SELECT COUNT(*) FROM rag_chunks WHERE client_name = 'insurance-agency';"
   ```

## Switching Clients

When you run `switch_client.sh`:
1. Old client's chunks are flushed from pgvector
2. New client's files are indexed
3. RAG filter in OpenWebUI is updated

No manual re-indexing needed after a switch.

## What Is NOT Indexed

| Directory | Reason |
|-----------|--------|
| `admin/` | Build plans, scripts — not business knowledge |
| `logs/` | System output |
| `backups/` | Historical archives |
| `docker/` | Infrastructure config |
| `postgres/` | Database volume |
| `.git/` | Version control |
| `node_modules/` | Dependencies |
| `venv/` | Python virtual environment |

## Chunking Strategy

1. **Section-based splitting** — Text is first split on `\n---\n` and `\n## ` boundaries
2. **Size fallback** — Sections larger than 512 chars are split with 64-char overlap
3. **Context prefix** — Each chunk is embedded with `[Source: {filename} for {client}]` prepended

This preserves document structure and improves retrieval accuracy for section-level questions.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "Found 0 files to index" | Check `ACTIVE_CLIENT` in `.env` matches a directory in `clients/` |
| Embedding timeout | Ollama may be loading a model. Wait and retry. Timeout is 120s. |
| Index returns empty results | Run indexer again — it rebuilds the ivfflat index automatically |
| PDF not being picked up | Ensure file extension is `.pdf` (lowercase). Check file isn't empty. |
| DOCX extraction empty | File may be image-only (scanned). Convert to searchable PDF first. |
| "Skipping {file}: {error}" | Extraction failed — check file isn't corrupted |
| Chunks seem too small | Increase `chunk_size` parameter in `chunk_text()` (default: 512) |

## Configuration

All settings are in `.env`:

```bash
BASE_PATH=/home/ubuntu/.business-assistant-box/business-assistant-box
ACTIVE_CLIENT=insurance-agency
EMBEDDING_PROVIDER=ollama
EMBEDDING_MODEL=nomic-embed-text
OLLAMA_BASE_URL=http://localhost:11434
```

Database connection is hardcoded in `index_vault.py`:
```python
DB_CONFIG = {
    "host": "localhost",
    "port": 5432,
    "user": "admin",
    "password": "strongpassword",
    "dbname": "businessassistant",
}
```
