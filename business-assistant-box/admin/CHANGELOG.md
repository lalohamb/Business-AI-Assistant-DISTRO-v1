# CHANGELOG.md

# Business Assistant Box

## Change Log

Purpose:

Track all project changes.

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

Date:

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

