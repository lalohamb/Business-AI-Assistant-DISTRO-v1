# EMAIL.md

## Purpose

Define how email workflows operate in Business Assistant Box.

---

## Email Workflow (n8n)

The email-summary workflow:
1. Connects to configured IMAP inbox
2. Retrieves unread messages
3. Sends each to Ollama for categorization and summary
4. Outputs structured summary (sender, subject, category, urgency, summary)

---

## Configuration

Email credentials are stored in n8n credential manager (not in files).

Required n8n credentials:
- IMAP connection (host, port, user, password)
- SMTP connection (for draft responses)

---

## Categories

- Urgent — requires action within 24 hours
- Customer — client communications
- Vendor — supplier/service provider messages
- Accounting — invoices, receipts, billing
- Information — no action required

---

## Security Notes

- Email credentials never stored in plain text files
- .eml files in DOCUMENTS/ are indexed for knowledge (not live email)
- No emails are sent automatically without explicit workflow trigger
