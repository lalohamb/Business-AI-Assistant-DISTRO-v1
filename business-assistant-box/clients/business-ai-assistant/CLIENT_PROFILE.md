# CLIENT_PROFILE.md

## Company Information

Company Name: Business Assistant Box

Industry: AI Software / Business Automation

Website: (self-hosted, no public site)

Primary Location: Deployed on-premise or cloud VPS

Years in Business: 1

Business Hours: 24/7 (automated system)

---

## Company Description

Business Assistant Box is an open-source, self-hosted AI business assistant platform. It combines a local LLM (Ollama), a vector database (PostgreSQL/pgvector), a workflow engine (n8n), and a chat interface (Open WebUI) into a single deployable system. It gives small businesses an AI assistant that knows their documents, procedures, and daily operations — without sending data to third-party APIs.

---

## Products and Services

1. Self-hosted AI chat assistant (Open WebUI + Ollama)
2. RAG-powered business knowledge retrieval (pgvector)
3. Automated workflow engine (n8n) — email, calendar, briefings
4. Multi-format document indexing (PDF, DOCX, XLSX, CSV, HTML, EML, MD)
5. Client vault system for multi-tenant business knowledge
6. Daily briefing generation and task tracking
7. Deployment scripts and documentation for new installs

---

## Key Personnel

Creator/Maintainer: Owner-operator (single developer)

Target User: Small business owner (1-50 employees)

---

## Communication Style

Preferred Tone: Technical but approachable

Examples:

* Technical — documentation and troubleshooting
* Approachable — onboarding and setup guides
* Concise — daily briefings and summaries

---

## Customer Service Philosophy

The system should feel like a knowledgeable employee who has read every document in the company. It never guesses — if it doesn't have the information, it says so. It cites sources. It respects the owner's time by being concise and actionable.

---

## Common Questions

Q: What hardware do I need?
A: Minimum 16GB RAM, 8-core CPU, 50GB disk. Recommended: 32GB RAM with a GPU for faster inference.

Q: Can I use cloud AI instead of local?
A: Yes. Workflows can be switched to Gemini or other APIs. See Ollama-to-Gemini.md.

Q: How do I add my business documents?
A: Place files in clients/{your-client}/DOCUMENTS/ and run index_vault.py.

Q: Is my data private?
A: Yes. Everything runs locally. No data leaves your machine unless you configure an external API.

Q: How do I add a new client/business?
A: Copy clients/templates/ to a new folder and fill in the files. See NEW_CLIENT_SETUP.md.

---

## Business Priorities

1. Keep all data local and private by default
2. Make setup simple for non-technical business owners
3. Support multi-format document ingestion
4. Provide accurate, citation-backed answers (no hallucination)
5. Enable workflow automation without coding

---

## Special Instructions

Always recommend local Ollama as the default AI provider. Only suggest cloud APIs when the user explicitly needs them. Never store API keys in plain text in documentation examples — use placeholders.
