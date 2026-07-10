# CHANGELOG.md

# Business Assistant Box

## Change Log

Purpose:

Track all project changes.

---

## Version 0.2

Date: 2026-07-09

RAG Filter Fix

Changes:

* Fixed RAG filter SQL query — columns were `content`/`source` but actual schema uses `chunk_text`/`source_path`
* Updated Valves class to use `pydantic.BaseModel` with `Field()` (required by newer OpenWebUI)
* Root cause: filter was silently failing on every query due to `UndefinedColumn` error swallowed by bare `except`

Reason: RAG pipeline returned no business context — model answered from training data only

Impact: RAG filter now correctly retrieves and injects business knowledge into prompts

Notes: After install, function must be updated in OpenWebUI UI or via API with valid token

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

