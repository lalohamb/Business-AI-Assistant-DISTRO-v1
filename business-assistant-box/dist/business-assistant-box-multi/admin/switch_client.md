# Switch Client

## Quick Switch

```bash
cd ~/.business-assistant-box/business-assistant-box
./admin/switch_client.sh <client-name>
```

Then re-index the RAG:

```bash
cd vector-db && ./venv/bin/python index_vault.py
```

Restart Obsidian to see the new vault.

## What the Script Does

1. Validates the client folder exists under `clients/`
2. Checks license tier and expiration
3. Backs up `.env`
4. Updates `ACTIVE_CLIENT` and `OBSIDIAN_VAULT_PATH` in `.env`
5. Replaces `current-client` symlink → `clients/<client-name>`
6. Updates `openclaw/client` symlink

## Available Clients

```bash
ls clients/ | grep -v templates
```

## Options

| Flag | Purpose |
|------|---------|
| `--force` | Switch even if validation warnings exist |

## Troubleshooting

### ❌ LICENSE EXPIRED

The `.license` file has a past expiration date.

```bash
cat .license
```

Update `EXPIRES=` to a future date, or contact support for renewal.

### ❌ CLIENT LIMIT REACHED (single-tier)

Single-client licenses only allow one client. Either:
- Upgrade `TIER=multi` in `.license`
- Or remove unused client folders from `clients/`

### ❌ Client directory not found

The client folder doesn't exist yet. Create it from the template:

```bash
cp -r clients/templates clients/<new-client-name>
```

Then fill in the markdown files before switching.

### Obsidian still shows old client

`current-client` must be a **symlink**, not a regular directory. Fix:

```bash
rm -rf current-client
./admin/switch_client.sh <client-name>
```

Then restart Obsidian (Ctrl+P → "Reload app without saving" or close/reopen).

### RAG returns old data after switching

You forgot to re-index. The vector database still has the previous client's chunks:

```bash
cd vector-db && ./venv/bin/python index_vault.py
```

This deletes old chunks for the active client and re-indexes from scratch.

### Validation failed (without --force)

The script runs `admin/test_client.sh` to check for missing files. Either:
- Fix the missing files (check which ones the test reports)
- Or bypass with `--force`:

```bash
./admin/switch_client.sh <client-name> --force
```

---

## Validating a Client: test_client.sh

Before switching, the system runs `test_client.sh` automatically. You can also run it manually:

```bash
./admin/test_client.sh <client-name>
```

This is a **read-only** script — it never modifies files.

### What It Tests

| Test | What It Checks |
|------|----------------|
| 1 — File Structure | Required files exist (`CLIENT_PROFILE.md`, `OWNER_PREFERENCES.md`, `BUSINESS_KNOWLEDGE.md`, `FAQ.md`, `PROCEDURES/*.md`, `MEMORY/*.md`, `OUTPUTS/` subdirs) |
| 2 — Content Quality | Files have real content (not just headers/placeholders). Minimum line counts enforced. |
| 3 — FAQ Entries | At least 10 `Q:` entries in `FAQ.md` |
| 4 — Company Identity | `Company Name` and `Industry` fields are filled in `CLIENT_PROFILE.md` |
| 5 — RAG Indexability | Enough `.md`/`.txt` files exist, total content is sufficient, embedding service (Ollama) is reachable |
| 6 — Differentiation | Files are not identical to `clients/templates/` (i.e., actually customized) |

### Result Levels

| Result | Meaning |
|--------|---------|
| ✅ READY | No issues. Safe to switch. |
| ⚠️ ACCEPTABLE | Minor warnings. Safe to switch without `--force`. |
| ⚠️ MARGINAL | Many warnings (>5). Switch requires `--force`. |
| ❌ NOT READY | Critical failures (missing required files or all files still template copies). Cannot switch. |

### Fixing a Failing Test

**Missing files:** Copy from templates and fill in:
```bash
cp clients/templates/PROCEDURES/EMAIL.md clients/<name>/PROCEDURES/EMAIL.md
```

**Content too thin:** Add real business info — processes, services, personnel, FAQ entries.

**Identical to templates:** Edit the files with actual company data. The test diffs against `clients/templates/` to catch unmodified copies.

**Embedding service not reachable:** Make sure Ollama is running:
```bash
curl http://localhost:11434/api/tags
```

---

### current-client is a directory instead of a symlink

This causes duplicates in Obsidian. Verify:

```bash
ls -la current-client
```

If it shows `drwx` (directory) instead of `lrwx` (symlink), remove and re-run:

```bash
rm -rf current-client
./admin/switch_client.sh <client-name>
```
