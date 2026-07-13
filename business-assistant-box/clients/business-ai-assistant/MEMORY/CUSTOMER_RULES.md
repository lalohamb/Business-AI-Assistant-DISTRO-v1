# CUSTOMER_RULES.md

## Purpose

Track client deployments and their specific configurations.

---

## Client Categories

Demo — example/template clients shipped with the system
Active — currently configured as ACTIVE_CLIENT
Inactive — configured but not currently active

---

## Active Clients

Client: insurance-agency (Pinnacle Insurance Group)
Contact: Sandra Mitchell
Category: Active
Configuration: ACTIVE_CLIENT=insurance-agency
Notes: 279 chunks indexed, all workflows active

Client: life-legacy-insurance (LifeLegacy Insurance)
Contact: Marcus D. Thompson
Category: Demo
Configuration: ACTIVE_CLIENT=life-legacy-insurance
Notes: Demo data, life insurance agency in Atlanta

Client: business-ai-assistant (this system)
Contact: Maintainer
Category: Demo
Configuration: ACTIVE_CLIENT=business-ai-assistant
Notes: Self-referential demo showing platform capabilities

---

## Communication Rules

- Each client folder is isolated — switching requires .env change + re-index
- Never mix documents between client vaults
- MEMORY files are client-specific and should not be shared

---

## Escalation Rules

- If indexing fails: check document format support
- If RAG returns wrong client data: verify ACTIVE_CLIENT in .env
- If workflows reference wrong business: recreate n8n container with correct env
