# META_AD_PUBLISHER_SETUP.md

## Overview

This document covers the full setup of the Meta Ad Publisher n8n workflow — the hands-free pipeline that takes an approved ad from OpenClaw and publishes it live to Facebook and/or Instagram.

---

## How the Full Pipeline Works

```
OpenClaw writes ad draft
    ↓
Saves to OUTPUTS/drafts/ads/
    ↓
Owner reviews draft (text, image, budget)
    ↓
Owner triggers webhook with approved payload
    ↓
n8n: Validate Payload
    ↓
n8n: Create Campaign (PAUSED)
    ↓
n8n: Create Ad Set (PAUSED)
    ↓
n8n: Create Ad Creative
    ↓
n8n: Create Ad (PAUSED)
    ↓
n8n: Send to Approval Router — owner gets final confirmation
    ↓
    ├── APPROVED → Ad set to ACTIVE → Goes live → Logged to published-ads.csv
    └── REJECTED → Ad stays PAUSED → No action taken
```

The ad is built in Meta's system in PAUSED state first. It only goes ACTIVE after the owner gives final approval in the Approval Router. This gives you a second checkpoint before money is spent.

---

## Prerequisites

Before this workflow will function you need:

- [ ] A Meta Business account
- [ ] A Facebook Page for the business
- [ ] A Meta Ad Account (found in Meta Business Suite → Ad Accounts)
- [ ] A Meta App with Marketing API access
- [ ] A long-lived Page Access Token or System User Token
- [ ] At least one Custom Audience built in Meta Ads Manager
- [ ] A hosted image URL for each ad (image must be publicly accessible)
- [ ] n8n running at `http://localhost:5678`
- [ ] Approval Router workflow active

---

## Step 1 — Create a Meta App

1. Go to [developers.facebook.com](https://developers.facebook.com)
2. Click **My Apps → Create App**
3. Select **Business** as the app type
4. Name it (e.g., "Credit Repair Ad Publisher")
5. Connect it to your Meta Business account
6. Under **Add Products**, add **Marketing API**
7. Under **App Review**, request these permissions:
   - `ads_management`
   - `ads_read`
   - `pages_read_engagement`
8. Note your **App ID** and **App Secret**

---

## Step 2 — Get a Long-Lived Access Token

A short-lived token expires in 1 hour. You need a long-lived token (60 days) or a System User Token (never expires — recommended for automation).

### Option A — System User Token (Recommended)

1. Go to Meta Business Suite → **Settings → Users → System Users**
2. Create a System User with **Admin** role
3. Click **Generate New Token**
4. Select your app
5. Select scopes: `ads_management`, `ads_read`, `pages_read_engagement`
6. Copy the token — store it securely

### Option B — Long-Lived User Token

```bash
# Exchange short-lived token for long-lived (valid 60 days)
curl "https://graph.facebook.com/v19.0/oauth/access_token
  ?grant_type=fb_exchange_token
  &client_id=YOUR_APP_ID
  &client_secret=YOUR_APP_SECRET
  &fb_exchange_token=YOUR_SHORT_LIVED_TOKEN"
```

---

## Step 3 — Add Meta Credential in n8n

1. Open n8n: `http://localhost:5678`
2. Go to **Settings → Credentials → Add Credential**
3. Select **HTTP Header Auth**
4. Name it: `Meta API Token`
5. Header Name: `Authorization`
6. Header Value: `Bearer YOUR_ACCESS_TOKEN`
7. Save

---

## Step 4 — Find Your IDs

You need these IDs before triggering the workflow:

### Ad Account ID
```bash
curl "https://graph.facebook.com/v19.0/me/adaccounts?access_token=YOUR_TOKEN"
# Returns: act_XXXXXXXXXX — use the number after act_
```

### Page ID
```bash
curl "https://graph.facebook.com/v19.0/me/accounts?access_token=YOUR_TOKEN"
# Returns list of pages you manage — note the id field
```

### Audience ID
1. Go to Meta Ads Manager → **Audiences**
2. Create a Saved Audience matching your debt lead profile:
   - Age 25–55
   - Interests: debt relief, personal finance, credit repair, debt consolidation
   - Location: your target area
3. Note the Audience ID from the URL or audience list

---

## Step 5 — Import and Configure the Workflow

1. Open n8n: `http://localhost:5678`
2. Go to **Workflows → Import**
3. Import: `n8n/workflows/selectable/meta-ad-publisher.json`
4. Open each node with a ⚠️ warning and connect the `Meta API Token` credential
5. In the **Create Ad Set** node, update `geo_locations` to your target city:
```json
"geo_locations": {
  "cities": [{"key": "CITY_KEY", "name": "Your City", "region": "Your State"}]
}
```
6. Save and **Activate** the workflow

---

## Step 6 — Trigger the Workflow

Once active, trigger it by POSTing to the webhook URL:

```
POST http://localhost:5678/webhook/meta-ad-publisher
```

### Required Payload Fields

```json
{
  "campaign_type": "Awareness",
  "primary_text": "Carrying $10,000 or more in credit card debt? There are legal options...",
  "headline": "Free Debt Relief Consultation",
  "description": "No pressure. No commitment.",
  "cta_button": "LEARN_MORE",
  "image_url": "https://yourdomain.com/images/ad-image-001.jpg",
  "destination_url": "https://yourdomain.com/free-consultation",
  "page_id": "YOUR_PAGE_ID",
  "audience_id": "YOUR_AUDIENCE_ID",
  "ad_account_id": "YOUR_AD_ACCOUNT_ID",
  "platform": "both",
  "daily_budget_cents": 2000
}
```

- `platform` — `facebook`, `instagram`, or `both`
- `daily_budget_cents` — in cents (2000 = $20.00/day)
- `cta_button` — Meta values: `LEARN_MORE`, `GET_QUOTE`, `CONTACT_US`, `SIGN_UP`

### How OpenClaw Triggers This

Once OpenClaw has a draft approved by the owner, it calls the webhook directly:

```bash
curl -X POST http://localhost:5678/webhook/meta-ad-publisher \
  -H "Content-Type: application/json" \
  -d @clients/credit-repair-co/OUTPUTS/drafts/ads/approved-payload.json
```

OpenClaw saves the approved payload as `approved-payload.json` after the owner confirms. The workflow takes it from there.

---

## What Gets Created in Meta

For each run the workflow creates:

| Object | Status | Notes |
|--------|--------|-------|
| Campaign | PAUSED | Named with campaign type + date |
| Ad Set | PAUSED | Targeting + budget attached |
| Ad Creative | N/A | Copy + image assembled |
| Ad | PAUSED → ACTIVE | Only goes ACTIVE after owner approves in Approval Router |

---

## Published Ads Log

Every successfully published ad is logged to:

`clients/credit-repair-co/OUTPUTS/published-ads.csv`

Columns:
```
timestamp, campaign_id, ad_id, headline, daily_budget_dollars, status
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Invalid OAuth access token` | Token expired — regenerate in Meta Business Suite |
| `Unsupported request - method type: post` | Check API version in URL — use v19.0 |
| `Ad account must be on an allowed list` | Your app needs Marketing API access approved — check App Review |
| `Must specify special ad category` | Already handled — workflow sets `CREDIT` category automatically |
| `Image URL not accessible` | Image must be publicly hosted — check URL is reachable without login |
| `Audience not found` | Verify audience ID in Meta Ads Manager → Audiences |
| Approval Router never fires | Check Approval Router workflow is active and webhook URL is correct |
| Ad stays PAUSED after approval | Check Activate Ad node — verify ad_id is passing correctly |

---

## Security Notes

- Never put your Meta access token in a workflow export you share
- Store the token only in n8n's encrypted credential store
- System User Tokens do not expire but should be rotated periodically
- The workflow always creates ads in PAUSED state first — no money is spent until the owner approves
- Daily budget is set at the ad set level — Meta will never spend more than the daily cap

---

## Meta Special Ad Category — Credit

Because this business offers credit repair services, all campaigns **must** use the `CREDIT` special ad category. This is already set in the workflow. It affects:

- Available targeting options (some demographic targeting is restricted)
- Ad delivery — Meta applies fair lending rules
- Reporting — some breakdowns are unavailable

This is a legal requirement under the Equal Credit Opportunity Act. The workflow handles it automatically.

---

## Estimated Setup Time

~45 minutes for first-time setup including Meta App creation and token generation.
~5 minutes per ad once the workflow is configured and running.
