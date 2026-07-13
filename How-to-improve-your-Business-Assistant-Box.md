Here's how you can improve your Business Assistant Box's knowledge and AI quality:

1. Add More Client-Specific Knowledge
The AI pulls knowledge from these key files in clients/{ACTIVE_CLIENT}/:

CLIENT_PROFILE.md — Company name, industry, team members, contact info

BUSINESS_KNOWLEDGE.md — Products/services, pricing, policies, processes

FAQ.md — Common questions and answers your business handles

OWNER_PREFERENCES.md — Tone, communication style, decision patterns

The more detailed and accurate these files are, the better the AI responds. Fill them out thoroughly.

2. Add Documents to the Vault
Drop files into these directories and re-index:

Location	Use For
clients/{client}/DOCUMENTS/	Client-specific docs (contracts, invoices, correspondence)
vault/company-documents/	Shared docs across all clients (SOPs, handbooks, policies)
vault/contracts/	Signed agreements
vault/financials/	P&L, tax docs, reports
Supported formats: .md, .txt, .pdf, .docx, .xlsx, .csv, .html, .eml

After adding files, re-index:

./vector-db/venv/bin/python3 ./vector-db/index_vault.py

Copy

Insert at cursor
bash
3. Build Out the MEMORY/ Folder
Files in clients/{client}/MEMORY/ teach the AI learned patterns:

CUSTOMER_RULES.md — How to handle specific customers

VENDOR_RULES.md — Vendor preferences and contacts

LEARNED_PATTERNS.md — Recurring decisions the AI should remember

OPEN_TASKS.md — Active tasks/projects

4. Improve Procedures
Files in clients/{client}/PROCEDURES/ define how the AI handles workflows:

EMAIL.md — Email triage rules

CALENDAR.md — Scheduling logic

CUSTOMER_INTAKE.md — New customer onboarding steps

DAILY_BRIEFING.md — What to include in daily summaries

5. Tune the RAG Pipeline
A few things you could improve in the indexing:

Increase chunk size — Currently 512 chars with 64 overlap. For business documents, try 1024/128 for better context retention.

Add the vault/ path to INDEX_PATHS — Currently index_vault.py only indexes system/ and clients/{ACTIVE_CLIENT}/. The vault/ shared directory isn't in INDEX_PATHS. You'd need to add:

os.path.join(BASE_PATH, "vault"),

Copy

Insert at cursor
python
Support more file types — The get_files() function only collects .md and .txt files, but the docs say PDF/DOCX/XLSX are supported. The extraction logic for those formats may need to be added to the indexer.

6. Upgrade the Embedding Model
nomic-embed-text is decent but you could try:

mxbai-embed-large — Better accuracy, slightly slower

snowflake-arctic-embed — Good for business/enterprise content

Quick Wins Summary
Fill out CLIENT_PROFILE.md and BUSINESS_KNOWLEDGE.md completely

Drop real business documents into vault/ or clients/{client}/DOCUMENTS/

Fix index_vault.py to include the vault/ path and support PDF/DOCX extraction

Re-run the indexer after every knowledge update

Write detailed procedures for your most common workflows