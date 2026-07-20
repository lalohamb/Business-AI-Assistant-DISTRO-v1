# DAILY_BRIEFING.md

## Purpose

Define how the daily system briefing is generated.

---

## Trigger

The daily-briefing n8n workflow runs at 7:00 AM local time.

---

## Process

1. n8n triggers the daily-briefing workflow
2. Workflow reads TODAY.md and OPEN_TASKS.md from the active client vault
3. Ollama generates a summary briefing
4. Briefing is written to n8n storage as TODAY.md
5. sync_today.sh (cron) copies it to the active client's MEMORY/TODAY.md
6. Next index run includes the updated TODAY.md in the vector DB

---

## Output Format

See DAILY_BRIEFING.md in the client root for the expected format.

---

## Failure Handling

- If Ollama is unreachable: workflow fails silently, check n8n execution log
- If TODAY.md is empty: sync_today.sh skips the copy
- If index fails after sync: check index_vault.py logs
