# PROCEDURES/lead-generation.md

## Purpose

Define how the assistant identifies, qualifies, and routes potential credit repair leads found via web search.

---

## What Is a Qualified Lead

A qualified lead is a person who has publicly expressed one or more of the following:

* Bad credit or low credit score (mentions score below 620, or terms like "bad credit", "poor credit", "ruined credit")
* Denied for a loan, mortgage, apartment, or car due to credit
* Collections, charge-offs, repossessions, or judgments on their record
* Seeking help improving their credit
* Recently divorced or separated and dealing with credit fallout
* Recovering from bankruptcy and looking to rebuild

---

## Disqualify If

* The person is asking about business credit only (different service)
* The person already has a credit repair company
* The post is older than 30 days
* The post is from a competitor advertising their own services
* No contact method is available or implied

---

## Lead Scoring

Score each lead 1–10 based on the following:

| Signal | Points |
|--------|--------|
| Explicitly asks for credit repair help | +3 |
| Mentions specific negative item (collection, repo, etc.) | +2 |
| Mentions being denied for something (loan, apartment, car) | +2 |
| Provides location (local lead) | +1 |
| Mentions urgency (buying a house soon, needs car now) | +2 |

Leads scoring 6 or higher are considered qualified and should be logged.

---

## Search Sources

The following public sources may be searched for leads:

* Reddit: r/personalfinance, r/CRedit, r/povertyfinance — search for "credit repair", "bad credit help", "dispute collections"
* Craigslist: "services wanted" section in target city
* Facebook Groups: Public groups only — search "credit help", "credit repair [city]"
* Google: "[city] credit repair help forum" or "need credit repair [city]"

Do NOT scrape or access private groups, direct messages, or any source requiring login.

---

## Output Format

Write each qualified lead to:

`clients/credit-repair-co/OUTPUTS/leads.csv`

Columns:
```
date_found, source, name_or_handle, contact_info, summary, score, status
```

Status values: `new`, `contacted`, `enrolled`, `disqualified`

---

## After Logging a Lead

1. Write the lead to leads.csv with status = `new`
2. Draft an outreach message using a warm, non-pushy tone
3. Save the draft to `clients/credit-repair-co/OUTPUTS/drafts/`
4. Route to human for approval before any contact is made

---

## Outreach Tone Guidelines

* Lead with empathy — acknowledge their situation
* Briefly explain what credit repair is and that it is legal
* Do NOT promise score increases or specific outcomes (CROA compliance)
* Offer a free consultation or free credit review as the call to action
* Keep the message under 100 words

Example opener:
> "Hi [name] — I saw your post and wanted to reach out. Dealing with credit issues is stressful, and you're not alone. We help people review their credit reports and dispute items that shouldn't be there. If you'd like a free review, we're happy to take a look — no pressure."

---

## Compliance Reminder

All lead outreach is subject to CROA and CAN-SPAM rules.
No message may be sent without human approval.
Never make guarantees. Never suggest illegal tactics.
