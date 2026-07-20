# DOCUMENTS.md

## Purpose

Define how documents are managed and indexed in Business Assistant Box.

---

## Document Storage Structure

```
clients/{ACTIVE_CLIENT}/DOCUMENTS/
├── company-documents/   # Policies, procedures, org charts
├── contracts/           # Service agreements, vendor contracts
├── financials/          # Reports, budgets, invoices
├── handbooks/           # Employee handbooks, training materials
├── uploads/             # Misc files dropped by user
└── websites/            # Scraped or saved web content
```

---

## Indexing Process

1. Place file in appropriate DOCUMENTS/ subfolder
2. Run: `python3 vector-db/index_vault.py`
3. Script scans `system/` and `clients/{ACTIVE_CLIENT}/`
4. Text extracted based on file extension
5. Text chunked (500 tokens, 50-token overlap)
6. Embeddings generated via Ollama (nomic-embed-text)
7. Stored in pgvector with source file path as metadata
8. ivfflat index rebuilt with lists=sqrt(row_count)

---

## Supported Formats

| Extension | Extractor |
|-----------|-----------|
| .md, .txt | Direct read |
| .pdf | pymupdf |
| .docx | python-docx |
| .xlsx | openpyxl (all sheets) |
| .csv | csv module |
| .html | beautifulsoup4 |
| .eml | email.parser |

---

## Quality Standards

- Documents should be factual and current
- Remove outdated versions before re-indexing
- Use descriptive filenames (they become source citations)
- Large documents (100+ pages) work fine but increase index time
