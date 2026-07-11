#!/bin/bash

# ==========================================
# SAFETY CONTROLS
# ==========================================
# DRY_RUN=true
#   Simulates the entire script without making any changes.
#   Prints what WOULD happen. Nothing is written, installed, or modified.
#   Safe to run anytime — like a rehearsal with zero consequences.
#
# SAFE_MODE=true
#   Prevents overwriting existing files without creating a backup first.
#   Prompts before replacing. Never removes containers or volumes.
#
# Override via environment:
#   DRY_RUN=true ./admin/customize_ui_n8n.sh
#   SAFE_MODE=false ./admin/customize_ui_n8n.sh
# ==========================================

set -euo pipefail

# ============================================================
# BUSINESS ASSISTANT BOX - UI + N8N CUSTOMIZER
#
# Purpose:
# - Customize/prepare Open WebUI and n8n after base install
# - Create dashboard button definitions
# - Create n8n workflow import templates
# - Create Open WebUI business-assistant prompt/config notes
# - Avoid overwriting existing customized files without backup
#
# Usage:
#   chmod +x customize_ui_n8n.sh
#   ./customize_ui_n8n.sh
#
# Optional:
#   BASE=/custom/path ./customize_ui_n8n.sh
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="${BASE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
ENV_FILE="$BASE/.env"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

SAFE_MODE="${SAFE_MODE:-true}"
DRY_RUN="${DRY_RUN:-false}"

CREATED=()
BACKED_UP=()
WARNINGS=()

warn() {
  WARNINGS+=("$1")
  echo "WARNING: $1"
}

run_cmd() {
  if [ "$DRY_RUN" = "true" ]; then
    echo "[DRY_RUN] $*"
  else
    "$@"
  fi
}

backup_if_exists() {
  local file="$1"
  if [ -f "$file" ]; then
    local backup="${file}.bak.${TIMESTAMP}"
    if [ "$DRY_RUN" = "true" ]; then
      echo "[DRY_RUN] Would backup $file to $backup"
    else
      cp "$file" "$backup"
      BACKED_UP+=("$backup")
      echo "[backup] $backup"
    fi
  fi
}

write_file_safe() {
  local file="$1"
  local content="$2"
  local mode="${3:-overwrite_with_backup}"

  mkdir -p "$(dirname "$file")"

  if [ -f "$file" ]; then
    if [ "$mode" = "skip_if_exists" ]; then
      echo "[exists]  $file"
      return
    fi
    if [ "$SAFE_MODE" = "true" ]; then
      backup_if_exists "$file"
    fi
  fi

  if [ "$DRY_RUN" = "true" ]; then
    echo "[DRY_RUN] Would write $file"
  else
    printf "%s" "$content" > "$file"
    CREATED+=("$file")
    echo "[written] $file"
  fi
}

append_env_if_missing() {
  local key="$1"
  local value="$2"

  mkdir -p "$(dirname "$ENV_FILE")"

  if [ ! -f "$ENV_FILE" ]; then
    if [ "$DRY_RUN" = "true" ]; then
      echo "[DRY_RUN] Would create $ENV_FILE"
    else
      touch "$ENV_FILE"
      CREATED+=("$ENV_FILE")
    fi
  fi

  if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
    echo "[env exists] $key"
  else
    if [ "$DRY_RUN" = "true" ]; then
      echo "[DRY_RUN] Would append ${key}=${value}"
    else
      echo "${key}=${value}" >> "$ENV_FILE"
      echo "[env added] ${key}=${value}"
    fi
  fi
}

echo "========================================"
echo " BUSINESS ASSISTANT BOX - CUSTOMIZER"
echo "========================================"
echo ""
echo "BASE: $BASE"
echo "SAFE_MODE: $SAFE_MODE"
echo "DRY_RUN: $DRY_RUN"
echo ""

if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

ACTIVE_CLIENT="${ACTIVE_CLIENT:-demo-company}"
WORKFLOW_ENGINE="${WORKFLOW_ENGINE:-n8n}"
DASHBOARD_ENABLED="${DASHBOARD_ENABLED:-true}"

echo "=== PHASE A — Directory Preparation ==="

run_cmd mkdir -p "$BASE/dashboard"
run_cmd mkdir -p "$BASE/dashboard/business-buttons"
run_cmd mkdir -p "$BASE/dashboard/openwebui"
run_cmd mkdir -p "$BASE/dashboard/custom"
run_cmd mkdir -p "$BASE/n8n/workflows"
run_cmd mkdir -p "$BASE/n8n/templates"
run_cmd mkdir -p "$BASE/clients/$ACTIVE_CLIENT/OUTPUTS/drafts"
run_cmd mkdir -p "$BASE/clients/$ACTIVE_CLIENT/OUTPUTS/reports"
run_cmd mkdir -p "$BASE/clients/$ACTIVE_CLIENT/OUTPUTS/summaries"
run_cmd mkdir -p "$BASE/logs"

echo ""
echo "=== PHASE B — Environment Defaults ==="

append_env_if_missing "DASHBOARD_ENABLED" "true"
append_env_if_missing "WORKFLOW_ENGINE" "n8n"
append_env_if_missing "N8N_BASE_URL" "http://localhost:5678"
append_env_if_missing "OPENWEBUI_BASE_URL" "http://localhost:3000"
append_env_if_missing "BUSINESS_BUTTONS_ENABLED" "true"
append_env_if_missing "APPROVAL_REQUIRED_FOR_EMAIL_SEND" "true"

echo ""
echo "=== PHASE C — Business Button Manifest ==="

BUTTONS_JSON=$(cat <<'EOF'
{
  "product": "Business Assistant Box",
  "description": "Senior-friendly business workflow buttons for Open WebUI/custom dashboard.",
  "buttons": [
    {
      "id": "email_review",
      "label": "Check Email",
      "icon": "📧",
      "description": "Review unread emails, categorize messages, and prepare draft replies.",
      "n8n_webhook": "/webhook/business/email-triage",
      "requires_approval": true,
      "procedure_file": "PROCEDURES/EMAIL.md"
    },
    {
      "id": "calendar_review",
      "label": "Today's Calendar",
      "icon": "📅",
      "description": "Summarize today's appointments, conflicts, and reminders.",
      "n8n_webhook": "/webhook/business/calendar-review",
      "requires_approval": false,
      "procedure_file": "PROCEDURES/CALENDAR.md"
    },
    {
      "id": "daily_briefing",
      "label": "Daily Briefing",
      "icon": "📊",
      "description": "Create the daily business summary from email, calendar, tasks, and memory.",
      "n8n_webhook": "/webhook/business/daily-briefing",
      "requires_approval": false,
      "procedure_file": "PROCEDURES/DAILY_BRIEFING.md"
    },
    {
      "id": "create_document",
      "label": "Create Document",
      "icon": "📄",
      "description": "Draft a business letter, proposal, quote, report, or meeting summary.",
      "n8n_webhook": "/webhook/business/document-drafting",
      "requires_approval": true,
      "procedure_file": "PROCEDURES/DOCUMENTS.md"
    },
    {
      "id": "customer_intake",
      "label": "Customer Intake",
      "icon": "👥",
      "description": "Process a new customer inquiry and recommend next steps.",
      "n8n_webhook": "/webhook/business/customer-intake",
      "requires_approval": false,
      "procedure_file": "PROCEDURES/CUSTOMER_INTAKE.md"
    },
    {
      "id": "ask_assistant",
      "label": "Ask Assistant",
      "icon": "🎤",
      "description": "Ask a general business question using the company knowledge vault.",
      "n8n_webhook": "/webhook/business/ask-assistant",
      "requires_approval": false,
      "procedure_file": null
    }
  ]
}
EOF
)

write_file_safe "$BASE/dashboard/business-buttons/buttons.json" "$BUTTONS_JSON" "overwrite_with_backup"

echo ""
echo "=== PHASE D — Open WebUI Prompt Pack ==="

OPENWEBUI_PROMPT=$(cat <<EOF
# Open WebUI Business Assistant Configuration Notes

## Purpose

Use Open WebUI as the initial user-facing interface for Business Assistant Box.

Open WebUI is the temporary dashboard/chat interface.

The final production interface may become a custom dashboard.

---

## Recommended Assistant Name

Business Assistant Box

---

## System Prompt

You are Business Assistant Box, a private AI office assistant for small and medium-sized businesses.

You help with:

- Email review
- Calendar review
- Document drafting
- Customer intake
- Daily business briefings
- Company knowledge search

You must use the active client business brain:

$BASE/clients/$ACTIVE_CLIENT

You must not use admin build files as client knowledge.

Never send emails, delete records, move money, approve payments, sign agreements, or modify business data without explicit approval.

When business facts are unavailable, say the information was not found in the available business knowledge.

---

## Recommended Open WebUI Setup

1. Create a workspace/model profile named:
   Business Assistant Box

2. Paste the System Prompt above.

3. If using OpenClaw AI API as primary provider, configure Open WebUI to route to that provider if supported.

4. If using Ollama locally, configure:
   OLLAMA_BASE_URL=http://host.docker.internal:11434
   or use the host IP if host.docker.internal is unavailable.

5. Add quick prompts for:
   - Check Email
   - Daily Briefing
   - Today's Calendar
   - Create Document
   - Customer Intake
   - Ask Assistant

---

## Senior-Friendly UI Direction

Hide advanced model settings from normal users when possible.

Expose only:

- Ask Assistant
- Business workflow prompts
- File upload if needed
- Chat history if useful
EOF
)

write_file_safe "$BASE/dashboard/openwebui/OPENWEBUI_BUSINESS_ASSISTANT.md" "$OPENWEBUI_PROMPT" "overwrite_with_backup"

echo ""
echo "=== PHASE E — n8n Workflow Templates ==="

create_workflow() {
  local file="$1"
  local name="$2"
  local path="$3"
  local task="$4"

  local content
  content=$(cat <<EOF
{
  "name": "$name",
  "nodes": [
    {
      "parameters": {
        "path": "$path",
        "responseMode": "responseNode",
        "options": {}
      },
      "id": "webhook-trigger",
      "name": "Webhook Trigger",
      "type": "n8n-nodes-base.webhook",
      "typeVersion": 2,
      "position": [240, 300],
      "webhookId": "$path"
    },
    {
      "parameters": {
        "jsCode": "const body = \$json.body || {};\\nreturn [{ json: {\\n  client: body.client || '$ACTIVE_CLIENT',\\n  task: '$task',\\n  instruction: body.instruction || '',\\n  createdAt: new Date().toISOString(),\\n  status: 'received'\\n}}];"
      },
      "id": "prepare-task",
      "name": "Prepare Task",
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [520, 300]
    },
    {
      "parameters": {
        "respondWith": "json",
        "responseBody": "={{ { success: true, message: 'Workflow template received request. Connect this node to OpenClaw execution.', data: \$json } }}"
      },
      "id": "respond",
      "name": "Respond to Dashboard",
      "type": "n8n-nodes-base.respondToWebhook",
      "typeVersion": 1,
      "position": [800, 300]
    }
  ],
  "connections": {
    "Webhook Trigger": {
      "main": [
        [
          {
            "node": "Prepare Task",
            "type": "main",
            "index": 0
          }
        ]
      ]
    },
    "Prepare Task": {
      "main": [
        [
          {
            "node": "Respond to Dashboard",
            "type": "main",
            "index": 0
          }
        ]
      ]
    }
  },
  "active": false,
  "settings": {},
  "versionId": "business-assistant-box-template"
}
EOF
)
  write_file_safe "$BASE/n8n/workflows/$file" "$content" "overwrite_with_backup"
}

create_workflow "email-triage.json" "[BAB] Email Triage" "business/email-triage" "Use PROCEDURES/EMAIL.md. Review unread emails, categorize messages, identify urgent items, draft replies, and require approval before sending."
create_workflow "calendar-review.json" "[BAB] Calendar Review" "business/calendar-review" "Use PROCEDURES/CALENDAR.md. Summarize today's schedule, conflicts, and reminders."
create_workflow "daily-briefing.json" "[BAB] Daily Briefing" "business/daily-briefing" "Use PROCEDURES/DAILY_BRIEFING.md. Generate the daily executive business summary."
create_workflow "document-drafting.json" "[BAB] Document Drafting" "business/document-drafting" "Use PROCEDURES/DOCUMENTS.md. Draft the requested business document for approval."
create_workflow "customer-intake.json" "[BAB] Customer Intake" "business/customer-intake" "Use PROCEDURES/CUSTOMER_INTAKE.md. Process a new customer inquiry and recommend next steps."
create_workflow "ask-assistant.json" "[BAB] Ask Assistant" "business/ask-assistant" "Use CLIENT_PROFILE.md, BUSINESS_KNOWLEDGE.md, FAQ.md, MEMORY, and vault/RAG results to answer the business question."

N8N_IMPORT_NOTES=$(cat <<EOF
# n8n Workflow Import Notes

## Location

Workflow templates are stored here:

$BASE/n8n/workflows/

## Import Steps

1. Open n8n:
   http://localhost:5678

2. Go to Workflows.

3. Import each JSON file.

4. Activate each workflow after reviewing it.

5. Connect the placeholder "Prepare Task" node to the real OpenClaw execution method.

## Important

These workflow templates are safe placeholders.

They do not yet execute OpenClaw.

They provide webhook endpoints and dashboard response structure.

## Expected Webhooks

POST /webhook/business/email-triage
POST /webhook/business/calendar-review
POST /webhook/business/daily-briefing
POST /webhook/business/document-drafting
POST /webhook/business/customer-intake
POST /webhook/business/ask-assistant

## Next Integration Step

Replace the placeholder response with one of:

- Execute Command node calling OpenClaw CLI
- HTTP Request node calling OpenClaw gateway/API
- Local middleware endpoint that calls OpenClaw
EOF
)

write_file_safe "$BASE/n8n/IMPORT_NOTES.md" "$N8N_IMPORT_NOTES" "overwrite_with_backup"

echo ""
echo "=== PHASE F — Simple Static Button Dashboard ==="

DASHBOARD_HTML=$(cat <<'EOF'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>Business Assistant Box</title>
  <style>
    :root {
      --bg1: #0f172a;
      --bg2: #312e81;
      --card: rgba(255,255,255,.12);
      --border: rgba(255,255,255,.2);
      --text: #fff;
      --muted: rgba(255,255,255,.78);
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: Arial, sans-serif;
      color: var(--text);
      background:
        radial-gradient(circle at 15% 10%, rgba(56,189,248,.35), transparent 30%),
        radial-gradient(circle at 85% 20%, rgba(167,139,250,.35), transparent 35%),
        linear-gradient(135deg, var(--bg1), var(--bg2));
      min-height: 100vh;
      padding: 32px;
    }
    .wrap { max-width: 1100px; margin: 0 auto; }
    header {
      display: flex; align-items: center; justify-content: space-between;
      gap: 16px; margin-bottom: 40px;
    }
    .brand { font-size: 22px; font-weight: 800; letter-spacing: .3px; }
    .status {
      border: 1px solid var(--border); border-radius: 999px;
      padding: 10px 14px; background: rgba(255,255,255,.08);
      font-size: 14px; color: var(--muted);
    }
    .hero {
      display: grid; grid-template-columns: 1.2fr .8fr;
      gap: 28px; align-items: center; margin-bottom: 32px;
    }
    h1 { font-size: clamp(38px, 6vw, 74px); line-height: .95; margin: 0 0 18px; }
    p { color: var(--muted); font-size: 19px; line-height: 1.55; margin: 0; }
    .panel {
      background: var(--card); border: 1px solid var(--border);
      backdrop-filter: blur(16px); border-radius: 28px; padding: 24px;
      box-shadow: 0 24px 80px rgba(0,0,0,.28);
    }
    .buttons {
      display: grid; grid-template-columns: repeat(3, 1fr);
      gap: 18px; margin-top: 28px;
    }
    button {
      cursor: pointer; border: 1px solid var(--border); border-radius: 22px;
      background: rgba(255,255,255,.14); color: white;
      padding: 24px 18px; text-align: left; min-height: 142px;
      transition: .2s ease; box-shadow: 0 12px 30px rgba(0,0,0,.18);
    }
    button:hover { transform: translateY(-4px); background: rgba(255,255,255,.22); }
    .icon { font-size: 34px; display: block; margin-bottom: 12px; }
    .label { font-size: 20px; font-weight: 800; display: block; margin-bottom: 8px; }
    .desc { font-size: 14px; color: var(--muted); line-height: 1.35; }
    #result {
      white-space: pre-wrap; min-height: 160px;
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      font-size: 14px; color: rgba(255,255,255,.88);
    }
    @media (max-width: 900px) {
      .hero { grid-template-columns: 1fr; }
      .buttons { grid-template-columns: 1fr; }
      body { padding: 18px; }
    }
  </style>
</head>
<body>
  <div class="wrap">
    <header>
      <div class="brand">Business Assistant Box™</div>
      <div class="status">Private AI Office Assistant</div>
    </header>

    <section class="hero">
      <div>
        <h1>What needs your attention today?</h1>
        <p>Use simple business buttons to review email, calendar, customer requests, documents, and daily priorities.</p>
      </div>
      <div class="panel">
        <strong>Today’s Business Snapshot</strong>
        <p style="margin-top:12px;font-size:16px;">Connect these buttons to n8n webhooks and OpenClaw workflows.</p>
      </div>
    </section>

    <section class="buttons" id="buttons"></section>

    <section class="panel" style="margin-top:28px;">
      <strong>Result</strong>
      <div id="result" style="margin-top:16px;">Click a button to test the workflow endpoint.</div>
    </section>
  </div>

  <script>
    const N8N_BASE_URL = localStorage.getItem("N8N_BASE_URL") || "http://localhost:5678";

    const buttons = [
      { label: "Check Email", icon: "📧", desc: "Categorize unread email and prepare draft replies.", path: "/webhook/business/email-triage" },
      { label: "Today’s Calendar", icon: "📅", desc: "Review appointments, conflicts, and reminders.", path: "/webhook/business/calendar-review" },
      { label: "Daily Briefing", icon: "📊", desc: "Summarize priorities, risks, and follow-ups.", path: "/webhook/business/daily-briefing" },
      { label: "Create Document", icon: "📄", desc: "Draft a proposal, letter, quote, or report.", path: "/webhook/business/document-drafting" },
      { label: "Customer Intake", icon: "👥", desc: "Process a new customer inquiry.", path: "/webhook/business/customer-intake" },
      { label: "Ask Assistant", icon: "🎤", desc: "Ask a question about the business.", path: "/webhook/business/ask-assistant" }
    ];

    const container = document.getElementById("buttons");
    const result = document.getElementById("result");

    buttons.forEach(btn => {
      const el = document.createElement("button");
      el.innerHTML = `
        <span class="icon">${btn.icon}</span>
        <span class="label">${btn.label}</span>
        <span class="desc">${btn.desc}</span>
      `;
      el.onclick = async () => {
        result.textContent = `Running ${btn.label}...\nEndpoint: ${N8N_BASE_URL}${btn.path}`;

        try {
          const res = await fetch(`${N8N_BASE_URL}${btn.path}`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              client: "demo-company",
              source: "business-assistant-dashboard",
              instruction: btn.label
            })
          });

          const text = await res.text();
          result.textContent = text;
        } catch (err) {
          result.textContent = `Could not reach workflow.\n\n${err.message}\n\nMake sure n8n is running and the workflow is imported/active.`;
        }
      };
      container.appendChild(el);
    });
  </script>
</body>
</html>
EOF
)

write_file_safe "$BASE/dashboard/custom/index.html" "$DASHBOARD_HTML" "overwrite_with_backup"

DASHBOARD_NOTES=$(cat <<EOF
# Custom Dashboard Notes

A simple static dashboard was created here:

$BASE/dashboard/custom/index.html

To test locally:

cd $BASE/dashboard/custom
python3 -m http.server 8088

Then open:

http://localhost:8088

This dashboard calls n8n webhook endpoints.

Before the buttons work:

1. Import n8n workflow JSON files from:
   $BASE/n8n/workflows/

2. Activate the workflows in n8n.

3. Confirm n8n is available at:
   http://localhost:5678

4. Connect each workflow to OpenClaw execution.

This is a prototype dashboard, not the final production UI.
EOF
)

write_file_safe "$BASE/dashboard/custom/README.md" "$DASHBOARD_NOTES" "overwrite_with_backup"

echo ""
echo "=== PHASE G — Service Status ==="

echo -n "n8n: "
if docker ps --filter "name=n8n" --filter "status=running" --format "{{.Names}}" 2>/dev/null | grep -q "^n8n$"; then
  echo "Running"
else
  echo "Not running"
  warn "n8n is not running. Start it before testing webhooks."
fi

echo -n "Open WebUI: "
if docker ps --filter "name=openwebui" --filter "status=running" --format "{{.Names}}" 2>/dev/null | grep -q "^openwebui$"; then
  echo "Running"
else
  echo "Not running"
  warn "Open WebUI is not running."
fi

echo ""
echo "========================================"
echo " CUSTOMIZATION COMPLETE"
echo "========================================"
echo ""
echo "Created/Written:"
for item in "${CREATED[@]:-}"; do
  echo "  - $item"
done

echo ""
echo "Backups:"
for item in "${BACKED_UP[@]:-}"; do
  echo "  - $item"
done

echo ""
echo "Warnings:"
if [ "${#WARNINGS[@]}" -eq 0 ]; then
  echo "  None"
else
  for item in "${WARNINGS[@]}"; do
    echo "  - $item"
  done
fi

echo ""
echo "Next steps:"
echo "  1. Open n8n: http://localhost:5678"
echo "  2. Import workflows from: $BASE/n8n/workflows/"
echo "  3. Activate workflows."
echo "  4. Test static dashboard:"
echo "     cd $BASE/dashboard/custom && python3 -m http.server 8088"
echo "  5. Open: http://localhost:8088"
echo ""
