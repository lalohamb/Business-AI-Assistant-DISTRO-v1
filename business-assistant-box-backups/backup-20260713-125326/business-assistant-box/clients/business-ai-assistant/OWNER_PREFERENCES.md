# OWNER_PREFERENCES.md

## Purpose

Store preferences for how the Business Assistant Box operates.

---

## Communication Preferences

Preferred Response Tone: Technical, concise, actionable

Preferred Response Length: Short paragraphs. Bullet points for lists. No filler.

Preferred Error Messages: Include the exact command to fix the problem.

---

## Decision Rules

- Always prefer local/private over cloud/external
- Always prefer open-source over proprietary
- Never expose ports beyond localhost without explicit user action
- Never store real credentials in example files — use placeholders
- Default to the most conservative (safe) option when ambiguous

---

## Documentation Preferences

- Every feature must have a corresponding doc update
- Troubleshooting docs must include: Symptom → Cause → Fix → Diagnostic Command
- Code comments only where behavior is non-obvious
- README stays high-level; details go in docs/ folder

---

## Development Preferences

- Shell scripts must be idempotent (safe to re-run)
- Python scripts use the project venv at /home/ubuntu/.business-assistant-box/venv/
- Docker containers use named volumes (not bind mounts for data)
- Environment variables over hardcoded values
- All SQL must handle "already exists" gracefully

---

## Learned Preferences

Owner prefers fixing root causes over workarounds.

Owner prefers sequential issue resolution (one at a time, verify, move on).

Owner wants thorough documentation for troubleshooting.

Owner prefers changes synced to install.sh so new installs get fixes automatically.
