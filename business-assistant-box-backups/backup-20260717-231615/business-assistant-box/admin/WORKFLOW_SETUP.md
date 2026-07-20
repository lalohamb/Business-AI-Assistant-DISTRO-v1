# WORKFLOW_SETUP.md

## Overview

All n8n workflows are pre-built as JSON templates but require **credential configuration** before they'll function. No workflow will work out of the box — you must connect your business accounts.

---

## Prerequisites

- n8n running: `http://localhost:5678`
- Ollama running with models pulled (or `GOOGLE_API_KEY` set for Gemini)
- A Google Workspace or Gmail account for the business
- Google Cloud project with APIs enabled

---

## Step 1 — Google Cloud Setup (One-Time)

All email, calendar, docs, and sheets workflows use Google OAuth2.

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a project (e.g., "Business Assistant Box")
3. Enable these APIs:
   - Gmail API
   - Google Calendar API
   - Google Sheets API
   - Google Docs API
   - Google Drive API
4. Go to **Credentials → Create OAuth 2.0 Client ID**
   - Application type: Web application
   - Authorized redirect URI: `http://localhost:5678/rest/oauth2-credential/callback`
5. Note your **Client ID** and **Client Secret**

---

## Step 2 — Add Credentials in n8n

1. Open n8n: `http://localhost:5678`
2. Go to **Settings → Credentials → Add Credential**
3. Select **Google OAuth2 API**
4. Enter Client ID and Client Secret
5. Set scopes based on which workflows you need (see table below)
6. Click **Connect** — sign in with the business email
7. Name it clearly (e.g., "Acme Roofing Gmail")

You can create one credential with all scopes, or separate credentials per service.

### Recommended Scopes (All-in-One)

```
https://www.googleapis.com/auth/gmail.readonly
https://www.googleapis.com/auth/gmail.send
https://www.googleapis.com/auth/calendar.readonly
https://www.googleapis.com/auth/calendar.events
https://www.googleapis.com/auth/spreadsheets
https://www.googleapis.com/auth/documents
https://www.googleapis.com/auth/drive.file
```

---

## Step 3 — Connect Workflows to Credentials

For each workflow, open it in the n8n UI and update nodes that have placeholder credentials:

1. Open the workflow
2. Click on nodes with a ⚠️ warning (missing credentials)
3. Select your configured credential from the dropdown
4. Save the workflow

---

## Workflow Reference

### Standard Workflows (Core)

These ship with every install.

#### Email Triage

| Field | Value |
|-------|-------|
| File | `standard/email-triage.json` |
| Trigger | Every 5 minutes (polling) |
| Credentials | Gmail OAuth2 |
| Google Scopes | gmail.readonly, gmail.send |
| AI Provider | Ollama (default) |
| Setup Time | ~10 minutes |

**What it does:**
1. Polls Gmail for unread emails (last hour)
2. Sends each email to AI for classification (URGENT / ROUTINE / SPAM / REQUIRES_RESPONSE / INFORMATIONAL)
3. Drafts a response if needed
4. Routes urgent items to the Approval Router
5. Logs routine items

**To connect your business email:**
1. Open workflow in n8n
2. Click "Fetch Unread Emails" node
3. Under Credentials → OAuth2, select your Gmail credential
4. Save and activate

**To change which email address is monitored:**
The credential itself determines the account. To monitor a different address, create a new Google OAuth2 credential signed in with that email.

**To change polling frequency:**
Edit the "Every 5 Minutes" trigger node → change `minutesInterval` value.

---

#### Calendar Review

| Field | Value |
|-------|-------|
| File | `standard/calendar-review.json` |
| Trigger | Daily at 7:00 AM |
| Credentials | Google Calendar OAuth2 |
| Google Scopes | calendar.readonly, calendar.events |
| AI Provider | Ollama (default) |
| Setup Time | ~5 minutes |

**What it does:**
1. Pulls today's calendar events
2. Identifies conflicts or double-bookings
3. Generates a schedule summary
4. Suggests optimal scheduling adjustments

---

#### Daily Briefing

| Field | Value |
|-------|-------|
| File | `standard/daily-briefing.json` |
| Trigger | Weekdays at 6:30 AM |
| Credentials | Gmail OAuth2, Google Calendar OAuth2 |
| Google Scopes | gmail.readonly, calendar.readonly |
| AI Provider | Ollama (default) |
| Setup Time | ~10 minutes |

**What it does:**
1. Pulls unread emails and today's calendar
2. Queries RAG for open tasks and business context
3. Compiles priorities, risks, and action items
4. Outputs a morning briefing summary
5. **Writes briefing to `n8n/storage/TODAY.md`** for RAG indexing

**Auto-sync to client MEMORY:**
The `admin/sync_today.sh` script copies `n8n/storage/TODAY.md` to `clients/{ACTIVE_CLIENT}/MEMORY/TODAY.md` and re-indexes. Add to crontab:
```
35 6 * * 1-5 /home/ubuntu/.business-assistant-box/business-assistant-box/admin/sync_today.sh
```

---

#### Approval Router

| Field | Value |
|-------|-------|
| File | `standard/approval-router.json` |
| Trigger | Webhook (called by other workflows) |
| Credentials | Ollama |
| Google Scopes | None |
| Setup Time | ~5 minutes |

**What it does:**
1. Receives actions that need human approval (email sends, document submissions)
2. Holds the action pending approval
3. Notifies the owner
4. Executes or discards based on response

---

#### RAG Query

| Field | Value |
|-------|-------|
| File | `standard/rag-query.json` |
| Trigger | Webhook |
| Credentials | Ollama, PostgreSQL |
| Google Scopes | None |
| Setup Time | ~5 minutes |

**What it does:**
1. Receives a question via webhook
2. Embeds the question using nomic-embed-text
3. Queries pgvector for relevant business context
4. Returns enriched context for the LLM

---

#### Ask Assistant

| Field | Value |
|-------|-------|
| File | `standard/ask-assistant.json` |
| Trigger | Webhook |
| Credentials | Ollama, PostgreSQL |
| Google Scopes | None |
| Setup Time | ~5 minutes |

**What it does:**
1. Client-facing chat endpoint
2. Embeds question, retrieves RAG context
3. Generates answer via Ollama with business knowledge
4. Returns response

---

### Selectable Workflows (Per Business Type)

These are optional — enable based on your client's needs.

#### Document Drafting

| Field | Value |
|-------|-------|
| File | `selectable/document-drafting.json` |
| Trigger | Webhook |
| Credentials | Ollama, Google Docs OAuth2 |
| Google Scopes | docs, drive.file |
| Business Types | Legal, real estate, insurance, general |
| Setup Time | ~15 minutes |

---

#### Customer Intake

| Field | Value |
|-------|-------|
| File | `selectable/customer-intake.json` |
| Trigger | Webhook |
| Credentials | Ollama, Google Sheets OAuth2 |
| Google Scopes | spreadsheets, forms.responses.readonly |
| Business Types | All |
| Setup Time | ~15 minutes |

---

#### Invoice Generator

| Field | Value |
|-------|-------|
| File | `selectable/invoice-generator.json` |
| Trigger | Webhook |
| Credentials | Ollama, Google Sheets OAuth2, Gmail OAuth2 |
| Google Scopes | spreadsheets, gmail.send |
| Business Types | Roofing, legal, general |
| Setup Time | ~15 minutes |

---

#### Lead Follow-Up

| Field | Value |
|-------|-------|
| File | `selectable/lead-followup.json` |
| Trigger | Weekdays at 9:00 AM |
| Credentials | Ollama, Gmail OAuth2, Google Sheets OAuth2 |
| Google Scopes | gmail.send, spreadsheets |
| Business Types | Real estate, insurance, roofing, general |
| Setup Time | ~20 minutes |

---

#### Appointment Booking

| Field | Value |
|-------|-------|
| File | `selectable/appointment-booking.json` |
| Trigger | Webhook |
| Credentials | Ollama, Google Calendar OAuth2, Gmail OAuth2 |
| Google Scopes | calendar.events, gmail.send |
| Business Types | Legal, tax, insurance, general |
| Setup Time | ~15 minutes |

---

#### Review Requester

| Field | Value |
|-------|-------|
| File | `selectable/review-requester.json` |
| Trigger | Webhook |
| Credentials | Ollama, Gmail OAuth2 |
| Google Scopes | gmail.send |
| Business Types | Roofing, legal, tax, general |
| Setup Time | ~10 minutes |

---

#### Expense Tracker

| Field | Value |
|-------|-------|
| File | `selectable/expense-tracker.json` |
| Trigger | Webhook |
| Credentials | Ollama, Google Drive OAuth2, Google Sheets OAuth2 |
| Google Scopes | drive.file, spreadsheets |
| Business Types | Roofing, general |
| Setup Time | ~20 minutes |

---

#### Social Post Scheduler

| Field | Value |
|-------|-------|
| File | `selectable/social-post-scheduler.json` |
| Trigger | Mon/Wed/Fri at 8:00 AM |
| Credentials | Ollama |
| Google Scopes | None |
| Business Types | All |
| Setup Time | ~10 minutes |

---

#### Report Generator

| Field | Value |
|-------|-------|
| File | `selectable/report-generator.json` |
| Trigger | Mondays at 7:00 AM |
| Credentials | Ollama, Google Sheets OAuth2, Gmail OAuth2 |
| Google Scopes | spreadsheets, gmail.send |
| Business Types | All |
| Setup Time | ~15 minutes |

---

#### Voicemail Transcription

| Field | Value |
|-------|-------|
| File | `selectable/voicemail-transcription.json` |
| Trigger | Webhook |
| Credentials | Ollama, Google Drive OAuth2 |
| Google Scopes | drive.readonly |
| Business Types | Legal, roofing, insurance, general |
| Setup Time | ~20 minutes |

---

## Connecting a Business Email (Quick Reference)

```bash
# 1. Ensure Google Cloud project has Gmail API enabled
# 2. Create OAuth2 credential with redirect URI:
#    http://localhost:5678/rest/oauth2-credential/callback
# 3. In n8n UI: Settings → Credentials → Add → Google OAuth2 API
# 4. Enter Client ID + Secret, set gmail scopes, click Connect
# 5. Sign in with the business email (e.g., info@acmeroofing.com)
# 6. Open Email Triage workflow → update credential in Fetch node
# 7. Activate workflow
```

To monitor **multiple email addresses**, create a separate credential for each and duplicate the workflow.

---

## Using Ollama vs Gemini for AI Nodes

The email-triage workflow currently uses Gemini (`GOOGLE_API_KEY`). To switch to local Ollama:

1. Open the "Gemini — Classify Email" node
2. Change the URL from the Gemini endpoint to:
   ```
   http://localhost:11434/api/generate
   ```
3. Update the request body to Ollama's format:
   ```json
   {"model": "llama3.2", "prompt": "...", "stream": false}
   ```
4. Save

Or keep Gemini for classification (faster, no local GPU load) and Ollama for everything else.

---

## Activating Workflows

```bash
# List all workflows
curl -s -H "Authorization: Bearer $N8N_API_KEY" \
  http://localhost:5678/api/v1/workflows | jq '.data[] | {id, name, active}'

# Activate a workflow
curl -X PATCH -H "Authorization: Bearer $N8N_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"active": true}' \
  http://localhost:5678/api/v1/workflows/<id>
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Workflow shows ⚠️ on nodes | Missing credentials — click node and select configured credential |
| "Token has been expired or revoked" | Re-authenticate: Settings → Credentials → click credential → Reconnect |
| Emails not being fetched | Check Gmail API is enabled in Google Cloud Console |
| "403 Forbidden" on Gmail | Scopes insufficient — recreate credential with correct scopes |
| Workflow not triggering | Ensure workflow is toggled ON (active) |
| Polling too frequent / API quota | Increase `minutesInterval` in the schedule trigger node |
| Wrong email account monitored | The OAuth credential determines the account — create new credential for different email |
| n8n can't reach Ollama | Check Ollama is running: `curl http://localhost:11434/api/tags` |
| Gemini returns 400 | Workflows no longer use Gemini by default. See `admin/Ollama-to-Gemini.md` to revert |
| Approval never arrives | Check Approval Router workflow is active and webhook URL is correct |

---

## Security Notes

- OAuth tokens are stored encrypted in n8n's database
- Never share n8n workflow exports that contain credential IDs with untrusted parties
- `APPROVAL_REQUIRED_FOR_EMAIL_SEND=true` ensures no email is sent without human confirmation
- Review the Approval Router workflow to understand the approval flow before activating email-sending workflows
