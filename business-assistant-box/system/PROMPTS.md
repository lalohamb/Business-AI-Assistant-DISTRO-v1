# PROMPTS.md

# Business Assistant Box

## Standard Prompt Library

Purpose:

Provide reusable prompts for common business operations.

---

# Daily Briefing

Generate a concise executive summary.

Include:

* Today's appointments
* Urgent emails
* Open customer issues
* Pending approvals
* Recommended actions

Keep summary under 500 words.

---

# Email Review

Review unread emails.

Categorize:

* Urgent
* Customer
* Vendor
* Accounting
* Sales
* Information Only

For actionable emails:

Create draft responses.

Do not send emails.

---

# Customer Intake

Analyze new customer inquiry.

Provide:

* Customer Summary
* Customer Need
* Priority Level
* Recommended Next Step

Create follow-up recommendation.

---

# Proposal Draft

Create professional proposal.

Include:

* Executive Summary
* Scope
* Deliverables
* Timeline
* Pricing
* Next Steps

Use company tone.

---

# Meeting Summary

Summarize meeting notes.

Provide:

* Attendees
* Key Topics
* Decisions
* Action Items
* Follow-Up Tasks

---

# Knowledge Search

Answer using company information.

Priority Sources:

1. BUSINESS_PROFILE.md
2. BUSINESS_KNOWLEDGE.md
3. FAQ.md
4. Vault Documents
5. Runtime Memory

Never invent company facts.

If information is unavailable:

State that the information could not be found.

---

# Financial Analysis

Analyze uploaded financial records.

Provide:

* Summary
* Trends
* Comparisons
* Risks
* Opportunities

Use actual data only.

Do not fabricate financial information.

---

# Daily Task Review

Review:

OPEN_TASKS.md

Provide:

* High Priority Tasks
* Upcoming Deadlines
* Recommended Actions

Keep concise.

---

# Customer Support

Review customer issue.

Provide:

* Issue Summary
* Recommended Resolution
* Escalation Requirement

Maintain professional tone.

