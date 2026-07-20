# OpenClaw.md

## What Is OpenClaw

OpenClaw is an optional AI agent layer that can serve as the primary AI provider for Business Assistant Box. It provides a cloud-hosted LLM API as an alternative (or complement) to running Ollama locally.

When configured, OpenClaw handles:
- LLM inference (chat, reasoning, summarization)
- Embedding generation (alternative to local nomic-embed-text)
- Agent execution within n8n workflows

---

## Current Status

**⏸️ Deferred** — The system currently uses Ollama as the primary AI provider. OpenClaw workspace exists but no API key is configured.

---

## Capabilities

OpenClaw is more than an LLM API — it is an **agent** that can:

| Capability | Description |
|------------|-------------|
| Chat / Reasoning | Standard LLM inference (like Ollama) |
| Web Search | Search the internet and return results in context |
| Execute Local Programs | Run commands, scripts, and executables on the host machine |
| File Operations | Read, write, and modify files on the local filesystem |
| Tool Use | Call external APIs, databases, and services |

### Local Execution

OpenClaw runs as a **daemon/service** on the host machine. Once installed and running, it has direct access to execute programs on the local system. This means:

- Run bash scripts and shell commands
- Launch local applications
- Interact with the filesystem (create, edit, delete files)
- Call system utilities (curl, python, git, etc.)
- Execute n8n workflows via webhook triggers

The service runs persistently in the background, similar to how Ollama runs as a systemd service.

### Web Search

OpenClaw has a **built-in web search tool** — no external API configuration needed. This enables:

- Looking up current pricing, regulations, or news
- Researching competitors or vendors
- Verifying facts that aren't in the local knowledge vault
- Pulling live data into business workflows

### Permissions & Tool Configuration

OpenClaw manages its own tool permissions through its **install-time configuration**. When you install OpenClaw, it sets up a manifest that defines which tools and capabilities are available (local execution, web search, file access, etc.).

The Business Assistant Box layers additional restrictions on top via:
- `system/POLICIES.md` — what the AI is allowed to do
- `system/TOOLS.md` — registered tools and approval requirements
- `.env` → `APPROVAL_REQUIRED_FOR_EMAIL_SEND=true` — human-in-the-loop enforcement
- `OPENCLAW_WORKSPACE_PATH` — constrains file access to the project directory

### Ollama vs OpenClaw Execution Model

```
Ollama:    User → LLM → text response (no system access)
                  ↓
             n8n executes actions (separate step, human approval)

OpenClaw:  User → Agent → can search web + execute locally + respond
                         (still governed by POLICIES.md approval rules)
```

---

## Architecture Role

```
User → Open WebUI → Ollama (local)        ← current setup
User → Open WebUI → OpenClaw API (cloud)   ← alternative
User → n8n workflow → OpenClaw API          ← for automated tasks
```

OpenClaw can be used:
1. **Instead of Ollama** — fully cloud-based inference (no GPU needed)
2. **Alongside Ollama** — Ollama for local chat, OpenClaw for workflow automation
3. **As a fallback** — if local GPU is overloaded, route to cloud

---

## Directory Structure

```
openclaw/
├── client@    → symlink to active client (updated by switch_client.sh)
└── .gitkeep
```

The `client` symlink gives OpenClaw access to the active client's knowledge vault for context-aware responses.

---

## Configuration

### .env Variables

```bash
OPENCLAW_API_KEY=         # Your API key from OpenClaw
OPENCLAW_MODEL=           # Model to use (leave blank for default)
OPENCLAW_WORKSPACE_PATH=/home/ubuntu/.business-assistant-box/business-assistant-box/openclaw
```

### Setting Up OpenClaw

**Step 1 — Install the CLI:**
```bash
curl -fsSL https://get.openclaw.com | sh
```

Or let the installer handle it:
```bash
./admin/install.sh   # Phase 6B installs OpenClaw
```

**Step 2 — Get an API key:**

Obtain from your OpenClaw account dashboard. Set it in `.env`:
```bash
OPENCLAW_API_KEY=your-key-here
```

**Step 3 — Set as AI provider:**

During install, select option [1] when prompted:
```
Primary AI provider — [1] OpenClaw API or [2] Ollama? [1/2]: 1
```

Or manually edit `.env`:
```bash
AI_PROVIDER=openclaw_api
```

**Step 4 — Verify:**
```bash
openclaw --version
```

---

## How It Integrates

### With n8n Workflows

When `AI_PROVIDER=openclaw_api` in `.env`, the n8n workflow configuration script (`configure_n8n.sh`) wires workflow nodes to call the OpenClaw API instead of Ollama. Workflows use the `OPENCLAW_API_KEY` for authentication.

### With switch_client.sh

When you switch clients, the script automatically updates the `openclaw/client` symlink to point to the new client folder:
```
openclaw/client → clients/<active-client>
```

This gives OpenClaw access to the client's business knowledge for context-aware responses.

### With Embeddings

OpenClaw can also serve as the embedding provider:
```bash
EMBEDDING_PROVIDER=openclaw_api
```

This removes the dependency on local Ollama for embedding generation.

---

## When to Use OpenClaw vs Ollama

| Scenario | Use |
|----------|-----|
| Need web search | OpenClaw (Ollama has no internet access) |
| Need to execute local programs | OpenClaw (Ollama cannot run commands) |
| Need autonomous multi-step tasks | OpenClaw (agent with tool use) |
| No GPU available | OpenClaw (cloud) |
| Privacy-critical data | Ollama (local, nothing leaves machine) |
| Need larger models (70B+) | OpenClaw (cloud has more compute) |
| Automated workflows (n8n) | Either — OpenClaw avoids local GPU contention |
| Offline / air-gapped | Ollama only |
| Cost-sensitive (already have GPU) | Ollama (free after hardware) |
| Simple Q&A from knowledge vault | Either — Ollama is faster locally |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `openclaw: command not found` | Reinstall: `curl -fsSL https://get.openclaw.com \| sh` |
| Workflows fail with auth error | Check `OPENCLAW_API_KEY` is set in `.env` |
| `Could not reach get.openclaw.com` | Check internet connectivity, try again later |
| Slow responses from API | Network latency — consider switching to Ollama for interactive chat |
| Want to switch back to Ollama | Set `AI_PROVIDER=ollama` in `.env`, restart n8n |

---

## Switching Between Providers

**To OpenClaw:**
```bash
sed -i 's/AI_PROVIDER=ollama/AI_PROVIDER=openclaw_api/' .env
# Set your API key
sed -i 's/OPENCLAW_API_KEY=.*/OPENCLAW_API_KEY=your-key-here/' .env
docker restart n8n
```

**Back to Ollama:**
```bash
sed -i 's/AI_PROVIDER=openclaw_api/AI_PROVIDER=ollama/' .env
docker restart n8n
```

No re-indexing needed — RAG embeddings are independent of the chat provider.
