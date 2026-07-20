# Enforcement Levels

| Level | How It Works | Pros | Cons |
|-------|-------------|------|------|
| Honor system | License file exists but nothing checks it | Zero friction, tracks who has what | No enforcement |
| Offline validation | install.sh checks license format/signature locally (e.g., HMAC-signed payload) | No server needed, works air-gapped | Can be bypassed by editing code |
| Phone-home | System pings your server on install or periodically to validate | Full control, can revoke licenses | Requires you to run a validation server |



My Recommendation
Start with offline signed licenses — good balance of real protection without infrastructure overhead:

package.sh generates a JSON payload ({id, issued_at, version, customer}) and signs it with a secret key (HMAC-SHA256)

The signed token goes into the package as LICENSE

install.sh verifies the signature before proceeding — if invalid, it exits

You keep a local licenses.json ledger tracking every issued license

## This means:

1. Each package is uniquely traceable

2. Install won't proceed without a valid license

3. No server infrastructure needed

4. You can upgrade to phone-home later if needed

## Questions Before I Build It
Who are you packaging for? (Paying customers, beta testers, yourself?)

Do you want a customer name/email baked into each license?

Should expired/revoked licenses be a thing, or just "issued = valid forever"?

Where do you want the license ledger stored? (Local file in the project, or somewhere else?)


---

## ISSUE #3 — License vs install.sh Client Directory Conflict (DISABLED — PENDING FIX)

**Status:** License checks commented out in `switch_client.sh` and `post_install_client_setup.sh` (2025-07-14)

### The Bug

`install.sh` Phase 0 creates directories for ALL demo clients regardless of license tier:

```
clients/demo-company/
clients/law-office/
clients/insurance-agency/
clients/acme-roofing/
```

Meanwhile, `license_check.sh` has a function `count_active_clients()` that counts every directory inside `clients/` (excluding `templates/`). It uses this count to enforce license limits.

So a fresh single-license install immediately has 4 directories → `count_active_clients()` returns 4 → `switch_client.sh` blocks the user with "Single-client license. Cannot switch between multiple clients." even though only 1 client is actually in use.

### Where the conflict lives

| File | What it does |
|------|-------------|
| `install.sh` line ~482 | Creates all 4 client dirs in a loop for scaffolding |
| `license_check.sh` line ~53 | `count_active_clients()` counts dirs in `clients/` minus `templates` |
| `switch_client.sh` line ~39 | Calls `count_active_clients()`, blocks if count > 1 for single-tier |
| `post_install_client_setup.sh` line ~124 | Sources `license_check.sh` and calls `check_license` before onboarding |

### What was disabled

```bash
# In switch_client.sh (lines 36-47):
# License check — disabled pending fix for directory-count bug (issue #3)
# source "$SCRIPT_DIR/license_check.sh"
# check_license
# if [ "$LICENSE_TIER" = "single" ]; then
#   CURRENT_COUNT=$(count_active_clients)
#   ...blocks user...
# fi

# In post_install_client_setup.sh (lines 123-125):
# License check — disabled pending fix for directory-count bug (issue #3)
# source "$SCRIPT_DIR/license_check.sh"
# check_license
```

### Fix Options (when ready to re-enable)

**Option A (recommended):** Change `count_active_clients()` to only count clients that have actually been indexed (e.g., check for data in the `rag_documents` PostgreSQL table, or check if the client has any files in `DOCUMENTS/`). Empty scaffolding directories would not count as "active."

**Option B:** Don't create demo client directories during install for single-license users. Only create the directory for the one client they selected as `ACTIVE_CLIENT`. Downside: single-license users lose the ability to browse demo folder structures as reference.

### Impact while disabled

With license checks commented out, there is NO enforcement of client limits. Any user can switch between all clients freely regardless of license tier. This is acceptable during development but must be resolved before commercial release.
