# CLIENT_ROUTING.md

# Business Assistant Box — Client Workspace Routing

## Concept

All services (OpenClaw, Obsidian, n8n, RAG) point to a single symlink:

```
current-client → clients/{ACTIVE_CLIENT}/
```

The user never needs to manually configure paths for each service. Change the active client once, everything follows.

---

## The current-client Symlink

```
<BASE_PATH>/current-client → <BASE_PATH>/clients/{ACTIVE_CLIENT}/
```

This is the single routing point for the entire system.

---

## Who Uses current-client

| Service | How it references the active client |
|---------|-------------------------------------|
| OpenClaw | `openclaw/client` → symlink to same target as current-client |
| Obsidian | Opens `OBSIDIAN_VAULT_PATH` which points to `current-client` |
| n8n | Workflows use `ACTIVE_CLIENT` from .env |
| RAG indexer | `index_vault.py` reads `ACTIVE_CLIENT` from .env, indexes `clients/{ACTIVE_CLIENT}/` |
| pre_check.sh | Validates only the `ACTIVE_CLIENT` directory |
| Dashboard | Sends `ACTIVE_CLIENT` in webhook payloads |

---

## Why This Design

- **One change switches everything** — no manual reconfiguration per service
- **No path duplication** — all services reference the same symlink or .env variable
- **Safe switching** — switch_client.sh validates, backs up .env, updates symlinks atomically
- **Obsidian friendly** — open the vault at `current-client`, it always shows the right business brain

---

## Scripts

### list_clients.sh

Lists valid client directories (excludes `templates` and hidden folders).

```bash
./admin/list_clients.sh
```

### current_client.sh

Shows the active client and where the symlink points.

```bash
./admin/current_client.sh
```

### validate_client.sh

Checks a client has all required files.

```bash
./admin/validate_client.sh demo-company
```

Exit 0 = valid. Exit 1 = missing files.

### switch_client.sh

Switches the active client.

```bash
./admin/switch_client.sh demo-company
./admin/switch_client.sh acme-roofing --force
```

What it does:
1. Confirms client directory exists
2. Runs validation (stop on failure unless `--force`)
3. Backs up .env
4. Updates `ACTIVE_CLIENT` and `OBSIDIAN_VAULT_PATH` in .env
5. Updates `current-client` symlink
6. Updates `openclaw/client` symlink
7. Prints next steps

---

## .env Variables

```
ACTIVE_CLIENT=insurance-agency
OBSIDIAN_VAULT_PATH=<BASE_PATH>/current-client
OPENCLAW_WORKSPACE_PATH=<BASE_PATH>/openclaw
```

`OBSIDIAN_VAULT_PATH` always points to `current-client` (the symlink), not directly to a client folder. This means it never needs updating when you switch clients — the symlink target changes instead.

---

## How RAG Indexes the Active Client

`index_vault.py` reads `ACTIVE_CLIENT` from .env and indexes:
- `system/`
- `clients/{ACTIVE_CLIENT}/`

After switching clients, re-index:
```bash
./vector-db/venv/bin/python3 ./vector-db/index_vault.py
```

---

## Why admin/ Is Never Indexed

| Directory | Reason |
|-----------|--------|
| admin/ | Build plans, scripts, checklists — not business knowledge |
| logs/ | System output, not client context |
| backups/ | Historical archives |
| docker/ | Infrastructure config |
| postgres/ | Database volume |

These directories contain operational data, not information the AI should use to answer business questions. Including them would pollute the knowledge base with installation steps, troubleshooting notes, and system configuration.

---

## Switching Workflow

```
./admin/list_clients.sh                    # See available clients
./admin/validate_client.sh acme-roofing    # Check it's ready
./admin/switch_client.sh acme-roofing      # Switch (auto re-indexes RAG)
./admin/pre_check.sh                       # Verify system state
```
