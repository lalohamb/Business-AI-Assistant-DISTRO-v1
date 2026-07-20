# CHANGELOG.md

# Business Assistant Box

## Change Log

Purpose:

Track all project changes.

---

## Version 0.4

Date: 2026-07-14

Security & Reliability Hardening

Changes:

### Security

* **PostgreSQL bound to localhost only** — Changed `-p 5432:5432` to `-p 127.0.0.1:5432:5432` in `install.sh`. Prevents remote network access to the database with default credentials. Docker containers still reach it via `host.docker.internal`.
* **`.env` set to chmod 600 on creation** — `install.sh` now sets owner-only permissions immediately after writing `.env`. `validate_env.sh` warns if permissions are incorrect.
* **`change_password.sh` added** — Admin script to change PostgreSQL password. Updates both the running container and `.env` in one step.
* **`change_model.sh` added** — Admin script to switch Ollama chat model. Pulls if not installed, updates `.env`.
* **`update_containers.sh` added** — Pulls latest Docker images and recreates containers preserving data volumes.
* **Pre-flight system check integrated** — `install.sh` now runs `system_minreq_check.sh` before Phase 0. Aborts if minimum requirements not met (user can override).
* **Workflow force-update flag** — `FORCE_WORKFLOWS=true ./admin/install.sh` re-imports workflow JSONs even if they already exist in n8n (for shipping updated versions).
* **psycopg2 persistence** — `update_containers.sh` now reinstalls `psycopg2-binary` in the OpenWebUI container after recreation, preventing RAG filter breakage.

Reason: Default install exposed PostgreSQL on all interfaces with known password "strongpassword". Any machine on the same network could connect.

Impact: No functional change for local usage. Remote BI tools must use SSH tunnel.

---

## Version 0.3

Date: 2026-07-12

Major Fixes & Improvements Session

Changes:

### Bug Fixes

* **Port 3000 crash-loop** — install.sh Phase 12 used `datetime("now")` for SQLite timestamps, but Open WebUI expects Unix integers. Fixed in `install.sh` and `configure_rag_pipeline.sh` to use `int(time.time())`.
* **RAG query returning empty results** — ivfflat index was created with default `lists=100` but only 261 rows existed. Recreated with `lists=16`. Fixed `schema.sql` to comment out premature index creation. `index_vault.py` now rebuilds the index after data insertion with dynamic `lists=sqrt(row_count)`.
* **psycopg2 lost on container recreation** — Added `requirements: psycopg2-binary` to RAG filter frontmatter so Open WebUI auto-installs it on every startup. Updated `install.sh` with the same frontmatter.

### RAG Pipeline Improvements

* **Anti-hallucination prefix** — Changed RAG filter context prefix from "answer normally" to "Use ONLY the following verified business knowledge. Cite the source file. If the answer is not in the context below, say 'I don't have that information in our records.'"
* **Increased top_k from 5 to 8** — More context chunks retrieved per query for better multi-topic answers.
* **System prompt configured** — Added persistent system prompt to Open WebUI config DB defining the assistant's identity, rules, and staff context. Also added to `install.sh` so new installs get it automatically.
* **Multi-format indexing** — `index_vault.py` now supports `.pdf`, `.docx`, `.xlsx`, `.csv`, `.html`, `.eml` in addition to `.md` and `.txt`. Extraction uses pymupdf, python-docx, openpyxl, beautifulsoup4 (all pre-installed in venv).

### Workflow Changes

* **All 16 workflows converted from Gemini to Ollama** — No `GOOGLE_API_KEY` required. All workflows now call `http://host.docker.internal:11434/api/generate` with local `qwen3:14b`.
* **Model configurable via environment variable** — Workflows use `($env.OLLAMA_MODEL || 'qwen3:14b')`. Change model for all workflows by setting `OLLAMA_MODEL` in the n8n container environment.
* **n8n container recreated** with `-e OLLAMA_MODEL=qwen3:14b` passed in.
* **Daily briefing writes TODAY.md** — Added Code node that writes briefing output to `n8n/storage/TODAY.md`. Sync script (`admin/sync_today.sh`) copies to client MEMORY and re-indexes.

### Content Added

* **3 sample documents** in `clients/insurance-agency/DOCUMENTS/`:
  - `company-documents/carrier-appointments.md`
  - `handbooks/employee-handbook-summary.md`
  - `contracts/service-agreement-template.md`
* **Populated TODAY.md** with realistic daily operational data
* **Populated OPEN_TASKS.md** with realistic task tracking data
* **Total indexed chunks: 279** (up from 261)

### Documentation

* Created `admin/Ollama-to-Gemini.md` — explains workflow model config and how to revert to Gemini
* Created `admin/sync_today.sh` — cron-compatible script for daily TODAY.md sync

Reason: Multiple issues preventing the assistant from functioning correctly — crash loops, empty RAG results, hallucination, missing identity, non-functional workflows.

Impact: All 12 E2E tests pass. Assistant now has persistent identity, anti-hallucination guardrails, real operational data, and all workflows can run locally without external API keys.

Notes: Two workflows (expense-tracker, voicemail-transcription) lose multimodal features (image OCR, audio transcription) without Gemini. Text-based analysis still works. See `admin/Ollama-to-Gemini.md` for revert instructions.

---

## Version 0.2

Date: 2026-07-10

RAG Filter Fix

Changes:

* Fixed RAG filter SQL query — columns were `content`/`source` but actual schema uses `chunk_text`/`source_path`
* Updated Valves class to use `pydantic.BaseModel` with `Field()` (required by newer OpenWebUI)
* Increased Ollama embedding timeout from 30s to 120s (GPU model swapping causes delays)
* Added SQLite fallback in configure_rag_pipeline.sh — if API registration fails, updates DB directly
* Fixed e2e test timeout (was 10s, now 120s)
* Root cause: filter was silently failing due to (1) wrong column names and (2) embedding timeout on 8GB GPU

Reason: RAG pipeline returned no business context — model answered from training data only

Impact: RAG filter now correctly retrieves and injects business knowledge into prompts

Notes: On 8GB GPU, use smaller chat models (llama3.2, qwen) to avoid embedding timeout

---

## Version 0.1

Date: 2026-07-09

Initial Project Setup

Changes:

* Created workspace
* Created project files
* Defined architecture

---

## Version Template

Version:

Date:

Changes:

Reason:

Approved By:

Impact:

Notes:

---

## Rules

Every change must be logged.

Include:

* What changed
* Why it changed
* Who approved it

No undocumented changes.
