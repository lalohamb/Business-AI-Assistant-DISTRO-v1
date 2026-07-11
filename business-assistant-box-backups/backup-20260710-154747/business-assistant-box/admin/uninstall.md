# Uninstall

## Quick Usage

```bash
cd ~/.business-assistant-box/business-assistant-box
./admin/uninstall.sh
```

The script is interactive — it prompts for mode selection and confirmation before removing anything.

## Modes

| Mode | Description |
|------|-------------|
| **Selective** | Choose which components to remove individually |
| **Full** | Remove everything for a clean reinstall |

## Components (Selective Mode)

You'll be prompted y/n for each:

| # | Component | What Gets Removed |
|---|-----------|-------------------|
| 1 | Docker containers | postgres, openwebui, n8n, openclaw containers |
| 2 | Docker volumes | Unused/dangling volumes (prune) |
| 3 | Docker images | pgvector, open-webui, n8n images |
| 4 | Ollama | Binary, models (~/.ollama), systemd service, ollama user |
| 5 | Docker engine | docker-ce/docker.io packages, /var/lib/docker |
| 6 | Python RAG venv | vector-db/venv/ directory |
| 7 | Runtime data | postgres/, dashboard/, docker/, n8n/ (keeps workflows), logs/, backups/ |
| 8 | System cleanup | apt autoremove + apt clean |

## What Is Always Preserved

The uninstaller never removes:

- `admin/` — install scripts and docs
- `system/` — agent rules, policies, prompts
- `clients/` — all business knowledge vaults
- `vault/` — shared documents
- `n8n/workflows/` — workflow JSON exports
- `vector-db/*.py`, `*.sql` — RAG scripts and schema
- `.env` — configuration
- SSH keys, system packages, network config

## Backup Option

Before removal begins, the script asks if you want a backup. If yes, it copies the entire `business-assistant-box/` directory to:

```
~/.business-assistant-box/business-assistant-box-backups/backup-YYYYMMDD-HHMMSS/
```

## Reinstalling After Uninstall

```bash
# 1. Full install
sudo ./admin/install.sh

# 2. Connect RAG pipeline (after creating WebUI admin account)
sudo ./admin/configure_rag_pipeline.sh

# 3. Verify
sudo ./admin/post_install_verify.sh
```

Since client data, workflows, and config are preserved, a reinstall restores the system to working state without losing business data.

## Common Scenarios

### Reset RAG only (keep everything else)

Select only component 6 (Python RAG venv). Then reinstall:

```bash
cd vector-db
python3 -m venv venv
./venv/bin/pip install psycopg2-binary python-dotenv requests
./venv/bin/python index_vault.py
```

### Reset Docker services (keep data)

Select components 1-3 (containers, volumes, images). Then reinstall:

```bash
sudo ./admin/install.sh
```

### Full wipe for clean machine

Select mode 2 (Full). This removes all services, models, and runtime data but keeps your business knowledge intact for reinstall.

---

## Troubleshooting

### Permission denied

The script needs sudo for Docker, Ollama, and apt operations:

```bash
sudo ./admin/uninstall.sh
```

Or ensure your user is in the `docker` group:

```bash
groups | grep docker
```

### Docker containers won't stop

Force-kill stuck containers manually:

```bash
docker kill postgres openwebui n8n 2>/dev/null
docker rm -f postgres openwebui n8n 2>/dev/null
```

Then re-run the uninstaller.

### Ollama service still running after uninstall

Check if the service file persists:

```bash
sudo systemctl status ollama
sudo rm -f /etc/systemd/system/ollama.service
sudo systemctl daemon-reload
```

### Disk space not freed after removing Docker

Docker may still hold overlay data:

```bash
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
```

### "command not found: docker" but images still on disk

Docker was partially removed. Clean up manually:

```bash
sudo apt purge -y docker-ce docker-ce-cli containerd.io
sudo rm -rf /var/lib/docker /var/lib/containerd /etc/docker
```

### Ollama models taking up space after uninstall

Models live in `~/.ollama/models/`. If the uninstaller missed them:

```bash
rm -rf ~/.ollama
```

### Backup is too large

The backup copies everything including runtime data. To make a lighter backup before uninstalling:

```bash
tar czf ~/bab-backup.tar.gz \
  --exclude='postgres' \
  --exclude='docker' \
  --exclude='logs' \
  --exclude='venv' \
  ~/.business-assistant-box/business-assistant-box/{admin,system,clients,vault,n8n/workflows,vector-db/*.py,vector-db/*.sql,.env}
```

### Want to remove everything including client data

The uninstaller intentionally preserves `clients/` and `system/`. To fully delete:

```bash
rm -rf ~/.business-assistant-box
```

⚠️ This is irreversible. All business knowledge, workflows, and config will be gone.
