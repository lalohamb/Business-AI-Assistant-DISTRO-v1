# configure_credentials.md

## Overview

Automates Google OAuth2 credential creation in n8n. Creates all required credentials via the n8n API so you only need to do one manual step: sign in with the business Google account.

---

## Usage

```bash
# Interactive (prompts for Client ID and Secret)
./admin/configure_credentials.sh

# Non-interactive (pass values directly)
./admin/configure_credentials.sh --client-id YOUR_ID --client-secret YOUR_SECRET

# Preview without making changes
DRY_RUN=true ./admin/configure_credentials.sh

# Skip confirmation prompts
./admin/configure_credentials.sh --skip-prompt
```

---

## What It Does

| Phase | Action | Automated? |
|-------|--------|-----------|
| 1 | Verify n8n API is accessible | ✅ |
| 2 | Check for existing credentials (skip duplicates) | ✅ |
| 3 | Collect Google OAuth2 Client ID and Secret | ✅ (or prompted) |
| 4 | Create 5 credentials in n8n with correct scopes | ✅ |
| 5 | User signs in with business email in browser | ❌ Manual |
| 6 | Verify credentials were authorized | ✅ |
| 7 | Save credential map to `n8n/CREDENTIAL_MAP.md` | ✅ |

---

## Credentials Created

| Name | Scopes | Used By |
|------|--------|---------|
| Gmail OAuth2 | gmail.readonly, gmail.send | Email Triage, Daily Briefing, Invoice Generator, Lead Follow-Up, Review Requester, Report Generator |
| Google Calendar OAuth2 | calendar.readonly, calendar.events | Calendar Review, Daily Briefing, Appointment Booking |
| Google Sheets OAuth2 | spreadsheets | Customer Intake, Invoice Generator, Lead Follow-Up, Expense Tracker, Report Generator |
| Google Docs OAuth2 | documents, drive.file | Document Drafting |
| Google Drive OAuth2 | drive.file, drive.readonly | Expense Tracker, Voicemail Transcription |

---

## Prerequisites

### 1. n8n running with API key

```bash
docker ps | grep n8n
grep N8N_API_KEY .env
```

### 2. Google Cloud OAuth2 Client

If you don't have one yet:

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create or select a project
3. Enable APIs:
   - Gmail API
   - Google Calendar API
   - Google Sheets API
   - Google Docs API
   - Google Drive API
4. Go to **Credentials → Create OAuth 2.0 Client ID**
5. Application type: **Web application**
6. Add authorized redirect URI:
   ```
   http://localhost:5678/rest/oauth2-credential/callback
   ```
7. Copy the Client ID and Client Secret

---

## The Manual Step

After the script creates credentials, you must authorize them in the browser:

1. Open `http://localhost:5678`
2. Go to **Settings → Credentials**
3. Click each credential (Gmail OAuth2, Google Calendar OAuth2, etc.)
4. Click **Connect**
5. Sign in with the business email (e.g., info@acmeroofing.com)
6. Grant permissions
7. Repeat for each credential

This is required by Google's security model — tokens can only be issued through interactive browser sign-in.

---

## Full Setup Sequence

```bash
# 1. Create credentials and authorize
./admin/configure_credentials.sh

# 2. Import and activate workflows
./admin/configure_n8n.sh

# 3. Assign credentials to workflow nodes in n8n UI
#    (Email nodes → Gmail OAuth2, Calendar nodes → Google Calendar OAuth2, etc.)

# 4. Test
curl -X POST http://localhost:5678/webhook/business/email-triage \
  -H 'Content-Type: application/json' \
  -d '{"test": true}'
```

---

## Changing the Business Email

To monitor a different email address:

1. Open n8n → Settings → Credentials
2. Click the Gmail OAuth2 credential
3. Click **Reconnect**
4. Sign in with the new email address

No need to re-run the script — the credential structure stays the same, only the authorized account changes.

---

## Multiple Business Emails

To monitor more than one email (e.g., info@ and support@):

1. Run the script again with `--skip-prompt` — it will skip existing credentials
2. Manually create a second Gmail OAuth2 credential in n8n UI
3. Authorize with the second email
4. Duplicate the Email Triage workflow and assign the second credential

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "API key invalid or missing" | Set `N8N_API_KEY` in `.env`. Generate in n8n: Settings → API → Create Key |
| "Cannot reach n8n" | Ensure n8n is running: `docker start n8n` |
| Credential created but Connect fails | Check redirect URI in Google Cloud Console matches: `http://localhost:5678/rest/oauth2-credential/callback` |
| "Access blocked: app not verified" | In Google Cloud Console → OAuth consent screen → add your email as a test user |
| Token expires after 7 days | Google limits unverified apps. Publish the OAuth consent screen or re-authorize weekly |
| "Scope has changed" error | Delete the credential in n8n and re-run the script |
| Credential works but workflow fails | Open the workflow node and select the credential from the dropdown — it may not be linked yet |
| Want to revoke access | Go to https://myaccount.google.com/permissions and remove the app |

---

## Output

After running, the script saves a credential map to:

```
n8n/CREDENTIAL_MAP.md
```

This documents which credentials exist, their scopes, and which workflows use them.
