# quickstart.md

## Overview

One command to set up a fresh machine end-to-end. Calls each setup script in order with the option to skip any phase.

---

## Usage

```bash
# Full install (default — executes everything for real)
sudo ./admin/quickstart.sh

# Preview mode — see what would happen without making changes
DRY_RUN=true sudo ./admin/quickstart.sh
```

---

## Phases

| Phase | Script | What It Does |
|-------|--------|--------------|
| 1 | install.sh | Docker, Ollama, PostgreSQL, n8n, Open WebUI |
| 2 | configure_credentials.sh | Creates Google OAuth2 credentials in n8n |
| 3 | configure_n8n.sh | Imports and activates workflows |
| 4 | post_install_client_setup.sh | Creates client vault from template |
| 5 | switch_client.sh | Activates a client |
| 6 | index_vault.py | Indexes client vault into RAG |
| 7 | post_install_verify.sh | Validates everything is working |

Each phase prompts `[y/skip/quit]` — you can skip any phase or quit entirely.

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DRY_RUN` | `false` | Set to `true` to preview without making changes |

### Dry Run Mode

```bash
DRY_RUN=true sudo ./admin/quickstart.sh
```

This simulates the entire quickstart:
- Shows which scripts would be called
- Shows which commands would execute
- Makes zero changes to the system
- Safe to run anytime, even on a production machine

### Normal Mode (Default)

```bash
sudo ./admin/quickstart.sh
```

`DRY_RUN=false` is the default — you don't need to set it explicitly.

---

## Behavior

- **Idempotent** — safe to re-run. Scripts skip already-completed steps (existing containers, existing credentials, etc.)
- **Failure handling** — if a phase fails, you're prompted to continue or stop
- **Skippable** — already ran install.sh? Skip Phase 1 and jump to credentials
- **Summary** — prints results of all phases at the end with service URLs

---

## Examples

```bash
# Fresh machine, full setup
sudo ./admin/quickstart.sh

# Already installed, just need credentials + workflows
sudo ./admin/quickstart.sh
# → skip Phase 1, run Phases 2-7

# Just want to see the plan
DRY_RUN=true sudo ./admin/quickstart.sh

# Re-run after fixing a failed phase
sudo ./admin/quickstart.sh
# → skip completed phases, run the one that failed
```

---

## Output

After completion, the script prints:

```
  Active Client: law-office
  n8n:           http://localhost:5678
  Open WebUI:    http://localhost:3000
  Ollama:        http://localhost:11434
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "Permission denied" | Run with `sudo` — Phase 1 installs system packages |
| Phase fails mid-way | Fix the issue, re-run quickstart, skip completed phases |
| Want to re-run one phase only | Run the individual script directly (e.g., `./admin/configure_n8n.sh`) |
| Skipped a phase by accident | Re-run quickstart and only run that phase |
