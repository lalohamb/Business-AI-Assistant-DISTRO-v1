# CUSTOMER_INTAKE.md

## Purpose

Standardize onboarding a new business into Business Assistant Box.

---

## New Client Setup Workflow

Step 1: Create client folder
```bash
bash clients/templates/create_client.sh {client-slug}
```

Step 2: Fill in core files
- CLIENT_PROFILE.md — company info, personnel, services
- BUSINESS_KNOWLEDGE.md — processes, systems, terminology
- FAQ.md — common questions and answers
- OWNER_PREFERENCES.md — communication style, decision rules

Step 3: Add documents
- Place business documents in DOCUMENTS/ subfolders
- Supported: .md, .txt, .pdf, .docx, .xlsx, .csv, .html, .eml

Step 4: Set as active client
```bash
# Edit .env
ACTIVE_CLIENT={client-slug}
```

Step 5: Index documents
```bash
source /home/ubuntu/.business-assistant-box/venv/bin/activate
python3 vector-db/index_vault.py
```

Step 6: Verify
- Ask a question in Open WebUI that should be answered by the documents
- Confirm cited response with no hallucination

---

## Intake Summary Format

Client: {name}
Slug: {folder-name}
Documents Added: {count}
Chunks Indexed: {count}
Status: Active / Ready for review
