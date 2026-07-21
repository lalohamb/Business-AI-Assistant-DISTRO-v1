# PROCEDURES/lead-generation.md

## Purpose

Define how the assistant identifies, qualifies, and routes potential credit repair leads found via web search.

---

## What Is a Qualified Lead

A qualified lead must meet AT LEAST ONE of the following debt thresholds:

* **$10,000+ in credit card debt** — mentions high credit card balances, maxed out cards, or multiple card debt totaling $10K or more
* **$10,000+ in personal unsecured debt** — mentions personal loans, medical debt, payday loans, or other unsecured debt totaling $10K or more
* **Combined debt totaling $10,000+** — credit card + unsecured debt combined equals or exceeds $10K (neither alone needs to hit $10K)
* **Already in a debt consolidation program** — mentions a debt management plan (DMP), debt consolidation loan, or working with a consolidation company
* **Paying $250+/month toward debt** — mentions a monthly debt payment of $250 or more (minimum payments, consolidation payments, or payment plans)

A lead does NOT need to meet all five — any single qualifying signal above is enough to log the lead.

---

## Disqualify If

* Total debt is clearly under $10,000 and no consolidation program is mentioned
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
| $10K+ credit card debt confirmed | +3 |
| $10K+ personal unsecured debt confirmed | +3 |
| Combined debt hits $10K threshold | +2 |
| Already in a debt consolidation program | +3 |
| Paying $250+/month toward debt | +2 |
| Mentions wanting to get out of debt faster | +1 |
| Mentions being denied for something (loan, apartment, car) | +1 |
| Provides location (local lead) | +1 |
| Mentions urgency (buying a house soon, needs car now) | +2 |

Leads scoring 6 or higher are considered qualified and should be logged.
Leads scoring 8 or higher are HIGH PRIORITY — flag status as `new-hot`.

---

## Search Sources

The following public sources may be searched for leads:

* Reddit: r/personalfinance, r/CRedit, r/povertyfinance, r/debtfree — search for "debt consolidation", "$10000 in debt", "credit card debt help", "paying off debt", "debt management plan"
* Craigslist: "services wanted" section in target city
* Facebook Groups: Public groups only — search "debt help", "debt consolidation [city]", "credit card debt relief"
* Google: "[city] debt consolidation help forum", "need help with credit card debt", "how to get out of $10000 debt"
* Quora / public forums: Questions about managing $10K+ debt, consolidation programs, or high monthly debt payments

Do NOT scrape or access private groups, direct messages, or any source requiring login.

---

## Output Format

Write each qualified lead to:

`clients/credit-repair-co/OUTPUTS/leads.csv`

Columns:
```
date_found, source, name_or_handle, contact_info, debt_type, debt_amount_estimate, monthly_payment_estimate, in_consolidation_program, summary, score, status
```

- `debt_type` — values: `credit_card`, `unsecured`, `combined`, `unknown`
- `debt_amount_estimate` — dollar amount if mentioned, otherwise `unknown`
- `monthly_payment_estimate` — dollar amount if mentioned, otherwise `unknown`
- `in_consolidation_program` — values: `yes`, `no`, `unknown`

Status values: `new`, `new-hot`, `contacted`, `enrolled`, `disqualified`

---

## Delivery to Owner

After each search session, OpenClaw will:

1. Write all qualified leads to `OUTPUTS/leads.csv`
2. Generate a session summary report saved to `OUTPUTS/lead-report-[date].md` containing:
   - Total leads found
   - Number of `new-hot` leads
   - Breakdown by debt type
   - Top 3 leads with full detail
3. Trigger the n8n `lead-followup.json` webhook for any `new-hot` leads immediately
4. For standard `new` leads, batch and trigger the webhook once per session

The owner receives leads through:
- The `OUTPUTS/leads.csv` file (full list, always current)
- The `OUTPUTS/lead-report-[date].md` session summary (human-readable)
- n8n approval queue — outreach drafts waiting for human approval before any contact is made

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
