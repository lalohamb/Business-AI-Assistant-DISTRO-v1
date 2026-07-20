# TOOLS.md

# Business Assistant Box

## Tool Registry

Purpose:

Define available tools, capabilities, restrictions, and usage guidelines.

This document is shared across all Business Assistant Box deployments.

---

# Tool Categories

1. Communication Tools
2. Calendar Tools
3. Knowledge Tools
4. Document Tools
5. Workflow Tools
6. Reporting Tools

---

# Email Tool

Purpose:

Read, summarize, categorize, and draft email responses.

Capabilities:

* Read inbox
* Categorize messages
* Prioritize messages
* Draft responses

Restrictions:

* Do not send emails automatically.
* Require user approval before sending.

Typical Uses:

* Daily email review
* Customer communication
* Vendor communication

---

# Calendar Tool

Purpose:

Review schedules and appointments.

Capabilities:

* Read calendar events
* Detect conflicts
* Generate daily schedule summaries

Restrictions:

* Do not create or modify appointments without approval.

Typical Uses:

* Daily Briefing
* Schedule Review
* Meeting Preparation

---

# Knowledge Vault Tool

Purpose:

Search company knowledge.

Sources:

* BUSINESS_PROFILE.md
* BUSINESS_KNOWLEDGE.md
* FAQ.md
* Vault Documents

Capabilities:

* Search documents
* Summarize findings
* Answer company-specific questions

Restrictions:

* Never fabricate information.
* State when information cannot be found.

Typical Uses:

* Company questions
* Policy lookup
* Product lookup

---

# Document Generation Tool

Purpose:

Create business documents.

Capabilities:

* Draft proposals
* Draft reports
* Draft letters
* Draft summaries

Restrictions:

* Draft only.
* Human review required.

Typical Uses:

* Sales proposals
* Executive summaries
* Meeting notes

---

# Customer Intake Tool

Purpose:

Process new customer inquiries.

Capabilities:

* Summarize inquiry
* Determine priority
* Recommend next steps

Restrictions:

* Do not commit pricing.
* Do not approve contracts.

Typical Uses:

* New lead processing
* Customer onboarding

---

# Daily Briefing Tool

Purpose:

Generate executive summary.

Sources:

* Calendar
* Email
* Open Tasks
* Runtime Memory

Output:

* Today's priorities
* Risks
* Opportunities
* Follow-ups

---

# Workflow Tool (n8n)

Purpose:

Execute business workflows.

Capabilities:

* Trigger automations
* Schedule tasks
* Route information

Restrictions:

* Require approval for sensitive actions.

Examples:

* Email review workflow
* Customer intake workflow
* Daily briefing workflow

---

# RAG Search Tool

Purpose:

Search indexed business documents.

Sources:

* PDFs
* Word Documents
* Spreadsheets
* Policies
* Financial Reports

Capabilities:

* Retrieve relevant information
* Provide source-based answers

Restrictions:

* Must cite source document when available.
* Do not invent missing information.

---

# Reporting Tool

Purpose:

Analyze business information.

Capabilities:

* Trend analysis
* KPI reporting
* Summary generation

Restrictions:

* Use available data only.
* Never estimate financial figures without supporting data.

---

# Escalation Rules

Immediately escalate:

* Legal matters
* Security incidents
* Financial approvals
* Contract approvals
* Regulatory issues

---

# Tool Priority Order

When answering questions:

1. BUSINESS_PROFILE.md
2. BUSINESS_KNOWLEDGE.md
3. FAQ.md
4. Runtime Memory
5. Vault Documents
6. RAG Search
7. User Input

Always prefer verified business information over assumptions.

---

# Human Approval Required

Always require approval before:

* Sending emails
* Scheduling appointments
* Deleting records
* Modifying business data
* Approving payments
* Approving contracts

---

# Last Updated

Date:

Updated By:

Notes:

