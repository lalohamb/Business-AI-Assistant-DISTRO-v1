# DAILY_BRIEFING.md

## Purpose

Provide a daily system health and operations summary.

---

## Morning Briefing Format

Good Morning. Here is today's system status.

---

### System Health

| Service | Status | Notes |
|---------|--------|-------|
| Ollama | ✅ Running | Model loaded |
| Open WebUI | ✅ Running | Port 3000 |
| PostgreSQL | ✅ Running | Port 5432 |
| n8n | ✅ Running | Port 5678 |

---

### Index Status

Total chunks indexed:
Last index run:
Active client:

---

### Workflow Status

Workflows executed (last 24h):
Failed workflows:
Pending triggers:

---

### Tasks Requiring Attention

List items from OPEN_TASKS.md that are overdue or due today.

---

### Recommended Actions

1. Re-index if new documents were added
2. Check n8n execution log for failures
3. Review disk space (models are large)

---

End briefing with:

"Would you like me to help with any of these items?"
