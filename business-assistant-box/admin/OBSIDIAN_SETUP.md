# Obsidian Setup (Native)

## Launch

    obsidian &

## Vault Path

`/home/ubuntu/.business-assistant-box/business-assistant-box/current-client` → `clients/${ACTIVE_CLIENT}`

## First Time Setup

1. Run `obsidian &`
2. Select **Open folder as vault**
3. Choose: `/home/ubuntu/.business-assistant-box/business-assistant-box/current-client`

## Rules

Obsidian is the **Human Editable Business Brain**.

### Use Obsidian for:
- Client business knowledge
- FAQs
- Procedures
- Customer/vendor rules

### Do NOT use Obsidian for:
- admin/
- logs/
- docker/
- backups/
- System configuration

## Integration

The RAG indexer reads from the Obsidian vault path and indexes into PostgreSQL + pgvector.
Run `./vector-db/venv/bin/python3 ./vector-db/index_vault.py` after editing client documents.
