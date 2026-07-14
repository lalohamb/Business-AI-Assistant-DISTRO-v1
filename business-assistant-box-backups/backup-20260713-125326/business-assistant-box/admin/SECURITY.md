# SECURITY.md

# Business Assistant Box Security Policy

## Security Objectives

Protect:

* Customer Data
* Company Data
* Credentials
* Financial Information
* Business Knowledge

---

## Credential Policy

Never store:

* Passwords
* API Keys
* OAuth Secrets
* Tokens

inside:

* Markdown Files
* Source Code
* Documentation

Store only in:

* .env files
* Secret stores
* Password manager

---

## OpenClaw Policy

OpenClaw may:

* Read business data
* Summarize information
* Draft content

OpenClaw may NOT:

* Move money
* Send payments
* Approve contracts
* Delete data

without explicit approval.

---

## Dashboard Policy

All users require authentication.

Roles:

Admin

Manager

Employee

Viewer

---

## Firewall Policy

Allow:

22 SSH

80 HTTP

443 HTTPS

Block all other unnecessary ports.

---

## Database Policy

Restrict access.

Database must never be publicly exposed.

---

## Backup Policy

Daily Backup

Weekly Full Backup

Monthly Archive

Verify backups regularly.

---

## Logging Policy

Record:

User

Action

Timestamp

Result

Store audit logs.

---

## Email Policy

Never automatically send:

* Legal notices
* Contracts
* Financial approvals

without review.

---

## Demonstration Mode

When demonstrating:

Use sample data.

Never expose client data.

Never use production credentials.

---

## Incident Response

If a security issue is suspected:

1. Stop affected services.
2. Preserve logs.
3. Identify scope.
4. Notify owner.
5. Document findings.
6. Apply remediation.

Security is more important than convenience.

