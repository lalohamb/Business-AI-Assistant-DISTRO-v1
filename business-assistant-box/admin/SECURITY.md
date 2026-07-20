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

* .env files (chmod 600 — owner-only access)
* Secret stores
* Password manager

The `.env` file is created with `chmod 600` during install. If permissions are
incorrect, `validate_env.sh` will warn. Fix with:

    chmod 600 .env

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

PostgreSQL is bound to `0.0.0.0:5432` (all interfaces on the host). This is required
so Docker containers (openwebui, n8n) can reach it via `host.docker.internal`.
Binding to `127.0.0.1` breaks the RAG pipeline — containers connect via the Docker
bridge (172.17.0.1), not localhost.

To prevent external network exposure, use a firewall to block port 5432 from
outside the machine:

    sudo ufw deny 5432
    sudo ufw allow from 172.17.0.0/16 to any port 5432

If you need remote access (e.g. external BI tool), use an SSH tunnel:

    ssh -L 5432:localhost:5432 user@your-server

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

