# PROCEDURES/referral-outreach.md

## Purpose

Define how OpenClaw identifies, contacts, and maintains relationships with referral partners who can send qualified debt leads to the business.

---

## What Is a Referral Partner

A referral partner is a professional who regularly encounters people with $10K+ in debt who need help. When their client can't move forward due to debt, they refer that person to us. In return, their client gets help and comes back to them ready to close.

---

## Target Partner Types

| Partner Type | Why They Refer | What They Get Back |
|---|---|---|
| Mortgage broker | Client denied due to debt/credit | Client returns ready to qualify for mortgage |
| Auto dealer / finance manager | Customer can't get financed | Customer returns able to get approved |
| Real estate agent | Buyer can't qualify | Buyer returns ready to purchase |
| Tax preparer / CPA | Client has IRS or back-tax debt | Client returns financially stable |
| Bankruptcy attorney | Client wants to avoid bankruptcy | Client gets alternative solution |

---

## How to Find Partners

OpenClaw will search for potential referral partners using:

- Google: "mortgage broker [city]", "auto dealer finance manager [city]", "tax preparer [city]"
- LinkedIn: local professionals in target partner categories
- Google Business Profile listings in the target area

Save identified prospects to:
`clients/credit-repair-co/OUTPUTS/referral-partners.csv`

Columns:
```
date_added, name, business, partner_type, phone, email, address, status, notes
```

Status values: `prospect`, `contacted`, `meeting-scheduled`, `active-partner`, `not-interested`

---

## Initial Outreach — Phone Script

Use this when calling a potential partner cold:

> "Hi [name], my name is [your name] with [company name]. I work with people who are dealing with $10,000 or more in debt — credit cards, personal loans, consolidation programs.
>
> I know you probably run into clients sometimes who want to move forward with a [mortgage / car / home purchase] but their debt situation is holding them back. Instead of losing that deal permanently, I work with those clients to get their debt under control and send them back to you ready to go.
>
> I'd love to grab 15 minutes to see if there's a fit. Would [day] or [day] work for a quick call?"

---

## Initial Outreach — Email Template

OpenClaw will draft partner outreach emails using this template and save to `OUTPUTS/drafts/referrals/`.

```
Subject: Turning your declined clients into future closings

Hi [name],

I help people with $10,000 or more in debt — credit cards, personal loans,
and consolidation programs — get their financial situation under control.

I work with a lot of people who've been declined for [mortgages / auto loans /
home purchases] because of their debt load. Rather than losing that client
permanently, I can work with them and send them back to you when they're ready.

I'd love to set up a quick 15-minute call to see if there's a fit. No cost to
you or your client — just a conversation.

Would [day] or [day] work?

[Your name]
[Company name]
[Phone]
[Website]
```

---

## What to Send After the First Conversation

OpenClaw will draft a follow-up package saved to `OUTPUTS/drafts/referrals/` containing:

1. A one-page partner overview — what the business does, who it helps, how long it takes
2. A simple referral process card — "just text me their name and number and I'll take it from there"
3. A thank-you email for the conversation

All drafts require human review before sending.

---

## How the Referral Process Works (Once Partner Is Active)

1. Partner texts or emails a referred client's name and phone number
2. OpenClaw logs the referral to `OUTPUTS/leads.csv` with status `new-hot` and source `referral-[partner name]`
3. OpenClaw drafts a warm outreach message to the referred client within the hour
4. Draft routes to human approval queue before any contact is made
5. Once enrolled, OpenClaw drafts a thank-you message back to the referring partner

---

## Partner Relationship Maintenance

OpenClaw will, when instructed, draft the following on a schedule:

| Task | Frequency | Output Location |
|------|-----------|-----------------|
| Check-in message to active partners | Monthly | `OUTPUTS/drafts/referrals/checkin-[date].md` |
| Thank-you when referral enrolls | Per enrollment | `OUTPUTS/drafts/referrals/thankyou-[partner]-[date].md` |
| Partner performance summary | Quarterly | `OUTPUTS/referral-report-[date].md` |

---

## Partner Contact Log

Maintain all partner records at:
`clients/credit-repair-co/OUTPUTS/referral-partners.csv`

Update status after every interaction. Notes field should capture:
- What was discussed
- Their level of interest
- Best time to follow up
- Any specific client types they typically refer

---

## Compliance Reminder

Referral fee arrangements involving consumer financial services may be regulated by state law.
Consult your compliance advisor before offering or accepting referral fees.
Never share client information with a referral partner without client consent.
All outreach drafts require human review before sending.
