# Test Matrix — Business Assistant Box

Generated: 2025-07-14
Purpose: Validate all user-facing scenarios for a flawless experience.

---

## How to Use This Document

Each scenario below has:
- **Preconditions** — what must be true before running
- **Command** — exact command to execute
- **Expected Result** — what success looks like
- **Known Gotchas** — things that can go wrong
- **Severity** — Critical (blocks usage), High (degrades experience), Medium (cosmetic/minor)

Run scenarios in order for a fresh machine. For updates, jump to the relevant section.

---

## SCENARIO 1 — Fresh Install (Clean Machine)

### 1.1 Pre-check on empty machine

| Field | Value |
|-------|-------|
| Precondition | No .env, no Docker, no Ollama |
| Command | `./admin/pre_check.sh` |
| Expected | All items show [✗] or ❌, exits with code 1, no crash |
| Known Gotchas | Script sources .env — if missing, must not crash (handled via defaults) |
| Severity | Medium |
| Status | ☐ |

### 1.2 Full install (interactive)

| Field | Value |
|-------|-------|
| Precondition | Ubuntu 22.04+, internet access, 16GB+ RAM |
| Command | `DRY_RUN=false SAFE_MODE=true bash ./admin/install.sh` |
| Expected | All 12 phases complete, summary shows ✅ for all services |
| Known Gotchas | (1) apt broken packages can stall Phase 1. (2) Docker socket permissions may require logout/login. (3) Ollama model pull can take 10-30 min on slow connections. (4) Phase 6A workflow import fails silently if n8n hasn't finished first-time init |
| Severity | Critical |
| Status | ☐ |

### 1.3 Full install (dry run)

| Field | Value |
|-------|-------|
| Precondition | Any state |
| Command | `DRY_RUN=true bash ./admin/install.sh` |
| Expected | No files created, no containers started, all phases print [DRY RUN] messages, exits cleanly |
| Known Gotchas | Some phases still call `source .env` — if .env missing, variables are empty but script should not crash |
| Severity | High |
| Status | ☐ |

### 1.4 Quickstart (end-to-end)

| Field | Value |
|-------|-------|
| Precondition | Clean machine OR post-uninstall |
| Command | `sudo ./admin/quickstart.sh` |
| Expected | All 7 phases offered, each can be skipped, summary printed at end |
| Known Gotchas | (1) Uses `set -euo pipefail` — any unset variable or failed command exits immediately. (2) Phase 2 (credentials) requires Google Cloud project — user may not have one yet |
| Severity | Critical |
| Status | ☐ |

---

## SCENARIO 2 — Post-Install Verification

### 2.1 Verify all services

| Field | Value |
|-------|-------|
| Precondition | install.sh completed |
| Command | `./admin/post_install_verify.sh` |
| Expected | All 10 tests pass, detailed build report printed |
| Known Gotchas | (1) Test 6 (WebUI→Ollama) may show "Not authenticated" if user hasn't created WebUI account yet — this is expected but confusing. (2) ss -tlnp may not show Ollama port if running as different user (handled via curl fallback) |
| Severity | High |
| Status | ☐ |

### 2.2a E2E Validation (phase-by-phase)

| Field | Value |
|-------|-------|
| Precondition | install.sh completed, all services running |
| Command | `./admin/e2e_validate.sh` or `./admin/e2e_validate.sh --no-pause` |
| Expected | 15 phases pass: .env, dirs, client content, Docker, PG+pgvector, Ollama, embedding gen, Python venv, WebUI container, RAG filter DB state, WebUI→Ollama, WebUI→pgvector, E2E RAG query, n8n, script integrity |
| Known Gotchas | (1) Phase 5 dimension check reads pg_attribute.atttypmod — may show empty if ivfflat index not yet built. (2) Phase 6 model check uses `awk '{print $1}'` on `ollama list` — model must match exactly including tag. (3) Phase 10 filter size comparison is approximate (±50 bytes tolerance). (4) Phase 13 E2E test loads embedding model — may be slow if model was unloaded |
| Severity | Critical |
| Status | ☐ |

### 2.2b Validate environment

| Field | Value |
|-------|-------|
| Precondition | .env exists |
| Command | `./admin/validate_env.sh` |
| Expected | All required keys show ✅, optional keys show ⚠️, paths verified |
| Known Gotchas | OPENCLAW_WORKSPACE_PATH may not exist if user chose Ollama-only — shows ⚠️ (acceptable) |
| Severity | Medium |
| Status | ☐ |

### 2.3 Pre-check (post-install)

| Field | Value |
|-------|-------|
| Precondition | Full install complete, services running |
| Command | `./admin/pre_check.sh` |
| Expected | "✅ PASS — Startup approved" |
| Known Gotchas | CLIENT_PATH variable used before definition (line references $CLIENT_PATH in DOCUMENTS validation before it's set from ACTIVE_CLIENT) |
| Severity | Medium |
| Status | ☐ |

---

## SCENARIO 3 — Client Management

### 3.1 Switch client (existing, populated)

| Field | Value |
|-------|-------|
| Precondition | Target client exists with content, services running |
| Command | `./admin/switch_client.sh insurance-agency` |
| Expected | .env updated, symlink created, RAG re-indexed, filter deployed, OpenWebUI restarted, is_global=1 enforced |
| Known Gotchas | (1) Calls test_client.sh first — if client has few files, validation warns and blocks without --force. (2) Flushes ALL other clients' chunks from DB (by design, but surprising). (3) OpenWebUI restart takes 15-60s — script waits but user may think it hung. (4) Runs `ollama stop` before indexing to free VRAM. (5) PG credentials passed via env vars to inline Python (safe for special chars). (6) Re-enforces is_global=1 after WebUI restart (startup can reset it) |
| Severity | Critical |
| Status | ☐ |

### 3.2 Switch client (new, empty)

| Field | Value |
|-------|-------|
| Precondition | Client directory exists but only has template files |
| Command | `./admin/switch_client.sh new-client` |
| Expected | Fails validation (template-identical files), requires --force |
| Known Gotchas | Error message doesn't clearly explain WHY it failed — user sees "❌ NOT READY" without actionable guidance on what to fill in first |
| Severity | High |
| Status | ☐ |

### 3.3 Switch client with --force

| Field | Value |
|-------|-------|
| Precondition | Client exists, validation would fail |
| Command | `./admin/switch_client.sh new-client --force` |
| Expected | Proceeds despite warnings, indexes whatever content exists |
| Known Gotchas | If client has zero .md content, indexer reports "Found 0 files to index" — not an error but RAG will have no knowledge |
| Severity | Medium |
| Status | ☐ |

### 3.4 Onboard new client

| Field | Value |
|-------|-------|
| Precondition | install.sh completed |
| Command | `./admin/post_install_client_setup.sh` |
| Expected | Prompts for client names, creates directories from templates, optionally indexes |
| Known Gotchas | (1) Single-client license blocks onboarding >1 client. (2) SAFE_MODE skips existing clients silently — user may not realize nothing happened. (3) Phase 6 indexing prompt appears even if Ollama is down |
| Severity | High |
| Status | ☐ |

### 3.5 List clients

| Field | Value |
|-------|-------|
| Precondition | clients/ directory exists |
| Command | `./admin/list_clients.sh` |
| Expected | Lists all client directories with active indicator |
| Known Gotchas | None known |
| Severity | Low |
| Status | ☐ |

### 3.6 Test client readiness

| Field | Value |
|-------|-------|
| Precondition | Client directory exists |
| Command | `./admin/test_client.sh insurance-agency` |
| Expected | 6 tests run, clear pass/warn/fail result |
| Known Gotchas | (1) FAQ check expects "Q:" prefix — if user uses different format (##, **, etc.), count is 0. (2) Template comparison fails if templates/ was deleted |
| Severity | Medium |
| Status | ☐ |

---

## SCENARIO 4 — RAG / Embedding Operations

### 4.1 Index client documents

| Field | Value |
|-------|-------|
| Precondition | PostgreSQL running, Ollama running, embedding model pulled |
| Command | `./vector-db/venv/bin/python3 ./vector-db/index_vault.py` |
| Expected | "Found N files to index", each file logged, "Indexing complete" |
| Known Gotchas | (1) Deletes ALL existing chunks for active client before re-indexing (full rebuild, not incremental). (2) If chat model is loaded in VRAM, embedding model must swap in — causes 7-min delays on 8GB GPU. Run `ollama stop <model>` first. (3) Uses `load_dotenv(override=True)` — always reads fresh .env values. (4) Large files (>50KB) produce many chunks — can be slow |
| Severity | Critical |
| Status | ☐ |

### 4.2 Query RAG

| Field | Value |
|-------|-------|
| Precondition | Client indexed, embedding model available |
| Command | `./vector-db/venv/bin/python3 ./vector-db/query_vault.py "What does this company do?"` |
| Expected | Top 5 results with similarity scores and source paths |
| Known Gotchas | (1) If no chunks exist, prints "No results found" — not an error. (2) First query after model unload takes 30-60s |
| Severity | High |
| Status | ☐ |

### 4.3 Switch embedding model

| Field | Value |
|-------|-------|
| Precondition | Current model working, services running |
| Command | `./admin/switch_embedding.sh` |
| Expected | 5-step process: pull model, update .env, rebuild tables, re-index, sync filter |
| Known Gotchas | (1) DROPS all RAG tables — any custom columns/indexes are lost permanently. (2) Model pull can take 5-20 min. (3) If OpenWebUI container is stopped, Step 5 fails but doesn't block. (4) ivfflat index creation may fail if <100 rows (PostgreSQL requirement) — shows as warning in logs but doesn't break queries |
| Severity | Critical |
| Status | ☐ |

### 4.4 Switch embedding (with arguments)

| Field | Value |
|-------|-------|
| Precondition | Services running |
| Command | `./admin/switch_embedding.sh snowflake-arctic-embed:335m 1024` |
| Expected | Skips interactive menu, proceeds directly with specified model/dims |
| Known Gotchas | (1) No validation that model name is valid — if typo, ollama pull fails at Step 1. (2) Deploys filter directly to WebUI DB (bypasses configure_rag_pipeline.sh). (3) Runs `ollama stop` before indexing to free VRAM |
| Severity | Medium |
| Status | ☐ |

### 4.5 Configure RAG pipeline

| Field | Value |
|-------|-------|
| Precondition | OpenWebUI running, PostgreSQL running, Ollama running |
| Command | `./admin/configure_rag_pipeline.sh` |
| Expected | 9 steps complete, end-to-end test shows similarity scores |
| Known Gotchas | (1) Requires WebUI admin email/password interactively — no way to pass via env (cannot be called from other scripts). (2) Step 5 API registration often fails (OpenWebUI API quirks) — falls back to direct SQLite write. (3) Toggle endpoint may toggle OFF if already ON — script toggles twice as workaround. (4) Not referenced by any other script — standalone utility only. (5) PG credentials are bash-interpolated into inline Python (breaks if password has special chars) |
| Severity | Medium (standalone utility, not required for normal operation) |
| Status | ☐ |

### 4.6 Move document and re-index

| Field | Value |
|-------|-------|
| Precondition | Document exists in client folder, already indexed |
| Command | Move file, then `./vector-db/venv/bin/python3 ./vector-db/index_vault.py` |
| Expected | Old path removed (full rebuild), new path indexed |
| Known Gotchas | If file moved OUTSIDE the client directory tree, it won't be found by indexer (INDEX_PATHS only covers system/ and clients/ACTIVE_CLIENT/) |
| Severity | Medium |
| Status | ☐ |

---

## SCENARIO 5 — Model Management

### 5.1 Change chat model

| Field | Value |
|-------|-------|
| Precondition | Ollama running |
| Command | (1) `ollama pull qwen3:8b` (2) Edit .env: `OLLAMA_MODEL=qwen3:8b` (3) Select in OpenWebUI model dropdown |
| Expected | New model available in chat |
| Known Gotchas | (1) .env OLLAMA_MODEL is only used by install.sh (for initial pull) — NOT by OpenWebUI at runtime. WebUI has its own model selection per-conversation. (2) Old model stays loaded in VRAM until manually stopped (`ollama stop <model>`) or 5-min idle timeout. (3) On 8GB VRAM: chat model + embedding model must fit together, or model swapping causes 7-min delays |
| Severity | Medium (not a missing script — just edit .env + select in UI) |
| Status | ☐ |

### 5.2 Pull additional model

| Field | Value |
|-------|-------|
| Precondition | Ollama running |
| Command | `ollama pull gemma3:12b` |
| Expected | Model downloaded, appears in `ollama list` and OpenWebUI selector |
| Known Gotchas | (1) Large models (14B+) need 16GB+ RAM. (2) If disk full, pull fails silently mid-download. (3) OpenWebUI may need page refresh to show new model |
| Severity | Low |
| Status | ☐ |

### 5.3 Remove model

| Field | Value |
|-------|-------|
| Precondition | Model exists |
| Command | `ollama rm modelname` |
| Expected | Model removed, disk space freed |
| Known Gotchas | If model is currently loaded (ollama ps shows it), must stop first or rm will fail |
| Severity | Low |
| Status | ☐ |

---

## SCENARIO 6 — Credential & Password Management

### 6.1 Configure Google OAuth2

| Field | Value |
|-------|-------|
| Precondition | n8n running, API key set in .env |
| Command | `./admin/configure_credentials.sh` |
| Expected | 5 credentials created, user prompted to authorize in browser |
| Known Gotchas | (1) Requires Google Cloud project with OAuth consent screen configured — many users won't have this. (2) If N8N_API_KEY not set, script exits at Phase 1. (3) Redirect URI must exactly match Google Cloud Console config |
| Severity | High |
| Status | ☐ |

### 6.2 Change PostgreSQL password (NO SCRIPT EXISTS)

| Field | Value |
|-------|-------|
| Precondition | PostgreSQL running |
| Command | Manual multi-step process |
| Expected | Password updated in: .env, Docker container, RAG filter valves, index_vault.py reads from .env |
| Known Gotchas | (1) Docker container password is set at FIRST creation only — changing .env alone does NOT change the container's password. (2) Must `ALTER USER admin PASSWORD 'newpass'` inside container, then update .env, then restart OpenWebUI. (3) RAG filter has hardcoded default "strongpassword" — if user changes PG password but doesn't update filter valves in WebUI Admin, RAG breaks silently |
| Severity | Critical — MISSING SCRIPT |
| Status | ☐ |

### 6.3 Change n8n API key

| Field | Value |
|-------|-------|
| Precondition | n8n running |
| Command | (1) Generate new key in n8n UI: Settings → API. (2) Update .env: `N8N_API_KEY=new-key` |
| Expected | configure_n8n.sh and other scripts use new key |
| Known Gotchas | Old key immediately invalid — any running automations using old key will fail |
| Severity | Medium |
| Status | ☐ |

### 6.4 Rotate OpenClaw API key

| Field | Value |
|-------|-------|
| Precondition | AI_PROVIDER=openclaw_api |
| Command | Update .env: `OPENCLAW_API_KEY=new-key` |
| Expected | n8n workflows pick up new key on next execution |
| Known Gotchas | n8n caches environment — may need container restart: `docker restart n8n` |
| Severity | Medium |
| Status | ☐ |

---

## SCENARIO 7 — n8n Workflow Management

### 7.1 Configure n8n (full)

| Field | Value |
|-------|-------|
| Precondition | n8n running, API key set |
| Command | `./admin/configure_n8n.sh` |
| Expected | 8 phases: verify, env, middleware, import, activate, webhooks, test, report |
| Known Gotchas | (1) Phase 5 only activates workflows with "[BAB]" or "Business Assistant" in name — renamed workflows are ignored. (2) Phase 7 webhook tests may return 500 if credentials not yet authorized. (3) Report file overwrites without backup |
| Severity | High |
| Status | ☐ |

### 7.2 Import new workflow manually

| Field | Value |
|-------|-------|
| Precondition | n8n running |
| Command | Place JSON in `n8n/workflows/standard/` or `selectable/`, run `./admin/configure_n8n.sh` |
| Expected | New workflow imported and activated |
| Known Gotchas | (1) Workflow JSON must have a "name" field. (2) If workflow with same name exists, import is skipped (no update). (3) Credential IDs in JSON won't match target system — nodes show "credential not found" |
| Severity | Medium |
| Status | ☐ |

### 7.3 Update existing workflow

| Field | Value |
|-------|-------|
| Precondition | Workflow already imported |
| Command | No automated path — must delete in n8n UI first, then re-import |
| Expected | Updated workflow active |
| Known Gotchas | configure_n8n.sh skips existing workflows by name — no "update" mode exists. User must delete old workflow in UI, then re-run script |
| Severity | High — MISSING FEATURE |
| Status | ☐ |

---

## SCENARIO 8 — Uninstall & Reinstall

### 8.1 Selective uninstall

| Field | Value |
|-------|-------|
| Precondition | System installed |
| Command | `./admin/uninstall.sh` → choose [1] Selective |
| Expected | User picks components, backup offered, selected items removed, clients/admin/workflows preserved |
| Known Gotchas | (1) Removing Docker engine while containers exist leaves orphaned data. (2) Removing Ollama deletes ALL models including ones used by other projects |
| Severity | High |
| Status | ☐ |

### 8.2 Full uninstall

| Field | Value |
|-------|-------|
| Precondition | System installed |
| Command | `./admin/uninstall.sh` → choose [2] Full |
| Expected | Everything removed except admin/, system/, clients/, n8n/workflows/, vector-db scripts, .env |
| Known Gotchas | (1) Backup prompt — if user says no and regrets, data is gone. (2) Docker engine removal may fail if other containers exist from other projects |
| Severity | Critical |
| Status | ☐ |

### 8.3 Reinstall after uninstall

| Field | Value |
|-------|-------|
| Precondition | uninstall.sh completed (selective or full) |
| Command | `bash ./admin/install.sh` |
| Expected | Detects existing .env (skips creation), recreates containers, re-indexes |
| Known Gotchas | (1) If .env has stale BASE_PATH from old location, script overrides with detected path — correct behavior. (2) PostgreSQL data dir was deleted — container starts fresh, RAG tables must be recreated. (3) OpenWebUI data dir was deleted — user must create new admin account |
| Severity | Critical |
| Status | ☐ |

---

## SCENARIO 9 — Obsidian Integration

### 9.1 Enable Obsidian (during install)

| Field | Value |
|-------|-------|
| Precondition | Fresh install, user selects "y" for Obsidian |
| Command | Handled by install.sh Phase 9 |
| Expected | .deb downloaded and installed, vault symlink created |
| Known Gotchas | (1) Requires GUI/desktop environment — headless servers can't use Obsidian. (2) .deb install may fail on non-Debian systems. (3) Obsidian version hardcoded (1.8.9) — may become stale |
| Severity | Medium |
| Status | ☐ |

### 9.2 Open vault after client switch

| Field | Value |
|-------|-------|
| Precondition | Obsidian installed, client switched |
| Command | `obsidian &` → open vault at `current-client/` |
| Expected | Vault shows new client's files |
| Known Gotchas | (1) If Obsidian was already open, it caches the old vault — must close and reopen. (2) Symlink change not detected by running Obsidian instance |
| Severity | Medium |
| Status | ☐ |

---

## SCENARIO 10 — Edge Cases & Error Recovery

### 10.1 Install with no internet

| Field | Value |
|-------|-------|
| Precondition | No network connectivity |
| Command | `bash ./admin/install.sh` |
| Expected | apt update fails, Docker install fails, Ollama pull fails — each with clear error |
| Known Gotchas | Script continues to next phase on failure (user prompted) — may leave system in partial state |
| Severity | Medium |
| Status | ☐ |

### 10.2 Install with insufficient RAM (<8GB)

| Field | Value |
|-------|-------|
| Precondition | Machine with <8GB RAM |
| Command | `bash ./admin/install.sh` |
| Expected | Install succeeds but model loading fails at runtime (OOM) |
| Known Gotchas | No pre-flight RAM check in install.sh — system_minreq_check.sh exists but is not called automatically |
| Severity | High |
| Status | ☐ |

### 10.3 Docker daemon won't start

| Field | Value |
|-------|-------|
| Precondition | Docker installed but daemon crashed |
| Command | `bash ./admin/install.sh` (Phase 2) |
| Expected | Script attempts PID cleanup, socket restart, 60s retry loop, full restart cycle |
| Known Gotchas | If /var/lib/docker is corrupted, no amount of restarts will fix it — user needs manual intervention |
| Severity | Medium |
| Status | ☐ |

### 10.4 PostgreSQL data corruption

| Field | Value |
|-------|-------|
| Precondition | postgres container stuck in restart loop |
| Command | install.sh Phase 3 handles this |
| Expected | Detects restart loop after 10 attempts, recreates with clean data dir |
| Known Gotchas | ALL existing RAG data is lost on recreation — no warning beyond the action message |
| Severity | High |
| Status | ☐ |

### 10.5 OpenWebUI container auto-updates

| Field | Value |
|-------|-------|
| Precondition | OpenWebUI image updated (docker pull or watchtower) |
| Command | Container recreated with new image |
| Expected | RAG filter and psycopg2 must be re-deployed |
| Known Gotchas | (1) psycopg2 is installed at runtime in container — lost on image update. (2) Filter is stored in SQLite (mounted volume) so it persists, but psycopg2 import fails. (3) No automatic detection/repair for this scenario |
| Severity | Critical — NO AUTOMATED RECOVERY |
| Status | ☐ |

### 10.6 Ollama model evicted from VRAM

| Field | Value |
|-------|-------|
| Precondition | Model was loaded, system idle for >5 min |
| Command | User asks question in WebUI |
| Expected | Model reloads (30-60s delay), then responds |
| Known Gotchas | First response after idle is very slow — user may think system is broken. No loading indicator in WebUI beyond spinner |
| Severity | Low |
| Status | ☐ |

### 10.7 Disk full during indexing

| Field | Value |
|-------|-------|
| Precondition | <1GB free disk space |
| Command | `./vector-db/venv/bin/python3 ./vector-db/index_vault.py` |
| Expected | psycopg2 raises disk full error |
| Known Gotchas | Partial index may be committed (no transaction wrapping per-file). Re-run after freeing space will do full rebuild (DELETE + re-insert) |
| Severity | Medium |
| Status | ☐ |

### 10.8 License enforcement on multi-client attempt

| Field | Value |
|-------|-------|
| Precondition | .license has TIER=single, multiple client dirs exist |
| Command | `./admin/switch_client.sh other-client` |
| Expected | "❌ Single-client license. Cannot switch between multiple clients." |
| Known Gotchas | install.sh creates 5 client directories regardless of license — count_active_clients() counts ALL dirs in clients/ except templates. This means a fresh single-license install immediately has 4+ "clients" and switch is blocked |
| Severity | Critical — BUG |
| Status | ☐ |

---

## SCENARIO 11 — Security Considerations

### 11.1 Default credentials exposure

| Field | Value |
|-------|-------|
| Precondition | Fresh install with defaults |
| Concern | PG password "strongpassword" is in .env, install.sh, RAG filter source, and schema comments |
| Risk | If machine is network-accessible, PostgreSQL on port 5432 has known credentials |
| Mitigation Needed | (1) Bind PostgreSQL to localhost only (currently 0.0.0.0:5432). (2) Generate random password during install. (3) Add change_password.sh script |
| Severity | Critical |
| Status | ☐ |

### 11.2 .env file permissions

| Field | Value |
|-------|-------|
| Precondition | .env created by install.sh |
| Concern | .env contains API keys — should be 600 permissions |
| Risk | Other users on shared machine can read credentials |
| Mitigation Needed | `chmod 600 .env` after creation |
| Severity | High |
| Status | ☐ |

### 11.3 OpenWebUI exposed without auth

| Field | Value |
|-------|-------|
| Precondition | Fresh install, port 3000 open |
| Concern | First visitor becomes admin — if machine is on public network, attacker could claim admin |
| Risk | Full access to AI assistant and business knowledge |
| Mitigation Needed | Document that user MUST create admin account immediately after install |
| Severity | Critical |
| Status | ☐ |

---

## SCENARIO 12 — Update/Upgrade Paths

### 12.1 Update OpenWebUI image

| Field | Value |
|-------|-------|
| Precondition | openwebui container running |
| Command | `docker pull ghcr.io/open-webui/open-webui:main && docker stop openwebui && docker rm openwebui && <recreate command from install.sh>` |
| Expected | New version running, data preserved (mounted volume), RAG filter intact |
| Known Gotchas | (1) psycopg2 lost — must reinstall: `docker exec openwebui pip install psycopg2-binary`. (2) Filter code persists in SQLite but may need is_global re-enforcement. (3) No update script exists — user must know the full docker run command |
| Severity | High — MISSING SCRIPT |
| Status | ☐ |

### 12.2 Update n8n image

| Field | Value |
|-------|-------|
| Precondition | n8n container running |
| Command | `docker pull n8nio/n8n && docker stop n8n && docker rm n8n && <recreate>` |
| Expected | New version, workflows preserved (mounted volume) |
| Known Gotchas | (1) n8n major version upgrades may require DB migration — container handles this on startup. (2) Credentials are stored in n8n's internal DB (mounted) — preserved |
| Severity | Medium |
| Status | ☐ |

### 12.3 Update Ollama

| Field | Value |
|-------|-------|
| Precondition | Ollama installed |
| Command | `curl -fsSL https://ollama.com/install.sh \| sh` |
| Expected | Binary updated, service restarted, models preserved |
| Known Gotchas | (1) OLLAMA_HOST=0.0.0.0 config in systemd may be overwritten — must re-apply. (2) Models are NOT deleted on update |
| Severity | Medium |
| Status | ☐ |

### 12.4 Update Business Assistant Box scripts

| Field | Value |
|-------|-------|
| Precondition | New version of admin scripts available |
| Command | No automated update mechanism exists |
| Expected | User manually replaces admin/ scripts |
| Known Gotchas | (1) No version tracking in scripts. (2) .env format may change between versions. (3) No migration script for schema changes |
| Severity | High — MISSING FEATURE |
| Status | ☐ |

---

## Summary of Missing Scripts/Features

| Gap | Impact | Effort to Fix |
|-----|--------|---------------|
| `change_password.sh` | Users stuck with default "strongpassword" | 1-2 hours |
| `change_model.sh` (chat model) | Users must manually edit .env + know WebUI behavior | 30 min |
| `update_containers.sh` | No safe way to update Docker images | 1 hour |
| Workflow update mode in configure_n8n.sh | Can't push workflow changes without manual delete | 1 hour |
| License vs install.sh client directory conflict | Single-license users blocked immediately | 30 min |
| PostgreSQL bind to localhost | Security exposure on networked machines | 15 min |
| .env chmod 600 | Credential exposure on shared machines | 5 min |
| system_minreq_check.sh integration | No RAM/disk pre-flight in install.sh | 15 min |
| psycopg2 persistence after WebUI update | RAG breaks silently on container recreation | 30 min |
| `e2e_validate.sh` automation in CI | No automated regression testing | 30 min |

---

## Test Execution Log

| Date | Tester | Scenarios Run | Pass | Fail | Notes |
|------|--------|---------------|------|------|-------|
| | | | | | |

---

## Revision History

| Date | Change |
|------|--------|
| 2025-07-14 | Initial creation — all scenarios documented |
| 2025-07-15 | Added e2e_validate.sh (Scenario 2.2a). Updated RAG scenarios with VRAM/override insights. Added configure_rag_pipeline.sh limitations. Added RAG_TOP_K to .env. Fixed install.sh heredoc expansion bug. |
