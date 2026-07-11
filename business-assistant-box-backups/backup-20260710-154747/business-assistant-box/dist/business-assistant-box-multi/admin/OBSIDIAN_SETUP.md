# Obsidian Setup

## Vault Path

`/home/laloahambrickday/Downloads/.nativeblackbox/opt/business-assistant-box/current-client`

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
Run `python vector-db/index_vault.py` after editing vault contents.
