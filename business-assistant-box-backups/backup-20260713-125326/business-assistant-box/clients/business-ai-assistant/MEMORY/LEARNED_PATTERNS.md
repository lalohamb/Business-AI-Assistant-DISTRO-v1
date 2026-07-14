# LEARNED_PATTERNS.md

## Purpose

Capture operational patterns that improve system reliability.

---

## Pattern Format

Date:
Observation:
Evidence:
Recommended Action:
Approved:

---

## Entries

Date: 2025-01-15
Observation: ivfflat index fails when lists >= row_count
Evidence: CREATE INDEX failed with 100 lists on 279 rows
Recommended Action: Auto-calculate lists as sqrt(row_count), minimum 1
Approved: Yes

---

Date: 2025-01-15
Observation: n8n env vars require container recreation, not just restart
Evidence: docker restart did not pick up new OLLAMA_MODEL value
Recommended Action: Always use docker rm + docker run for env var changes
Approved: Yes

---

Date: 2025-01-15
Observation: WebUI function table must be synced when filter file changes on disk
Evidence: Editing .py file alone had no effect until DB was updated
Recommended Action: Always run configure_rag_pipeline.sh after filter changes
Approved: Yes

---

Date: 2025-01-15
Observation: psycopg2 must be in filter frontmatter requirements for persistence across WebUI restarts
Evidence: Filter failed after container restart until package was re-installed
Recommended Action: Keep `requirements: psycopg2-binary` in filter frontmatter
Approved: Yes

---

## Monthly Review

Review patterns monthly. Remove obsolete information. Retain verified behavior.
