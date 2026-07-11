# NEW_MACHINE_SETUP.md

# Business Assistant Box — Fresh Machine Installation

## Requirements

### Minimum Specs

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| OS | Ubuntu 22.04+ LTS | Ubuntu 24.04 LTS |
| RAM | 32 GB | 64 GB+ |
| Storage | 500 GB SSD | 1 TB NVMe SSD |
| GPU | NVIDIA with 8 GB VRAM | NVIDIA with 12+ GB VRAM |
| CPU | 8 cores | 16+ cores |
| Network | Internet access for initial setup | Static IP for services |

### GPU Requirement

A dedicated NVIDIA GPU is required for local LLM inference via Ollama. Without a GPU, model responses will be extremely slow or unusable.

**Tested configuration:**

| Component | Spec | Role |
|-----------|------|------|
| GPU 1 | NVIDIA GeForce RTX 2060 SUPER (8 GB VRAM) | LLM inference (Ollama) |
| GPU 2 | NVIDIA GeForce GTX 970 (4 GB VRAM) | Video output / display |
| CPU | Intel Xeon E5-2630 v2 @ 2.60 GHz (24 threads) | |
| RAM | 128 GB DDR3 | |
| Storage | 1 TB SSD | |
| OS | Ubuntu 24.04 LTS | |

### Dual-GPU Setup (Recommended)

This system uses a dedicated GPU for AI inference and a separate GPU for video/display output. This prevents display rendering from competing with LLM inference for VRAM.

| GPU | Purpose |
|-----|--------|
| Higher VRAM card (RTX 2060 SUPER) | Ollama / LLM inference only |
| Lower VRAM card (GTX 970) | Monitor output, desktop rendering |

**Why separate GPUs matter:**
- Display compositing uses VRAM — even idle desktops consume 200-500 MB
- During inference, Ollama needs maximum available VRAM for model layers
- A dedicated video GPU keeps the inference GPU fully available for AI workloads
- Prevents stuttering on both display and model responses

### Configuring Ollama to Use the Dedicated GPU

**Step 1 — Identify your GPUs:**
```bash
nvidia-smi -L
```
Example output:
```
GPU 0: NVIDIA GeForce GTX 970 (UUID: GPU-16b9b604-...)
GPU 1: NVIDIA GeForce RTX 2060 SUPER (UUID: GPU-6ef1a4a6-...)
```

**Step 2 — Create the Ollama override:**
```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf << 'EOF'
[Service]
Environment="CUDA_VISIBLE_DEVICES=GPU-6ef1a4a6-8765-e0ba-add8-57c7d161abb5"
EOF
```

Use the UUID of your inference GPU (the higher VRAM card). UUID is more reliable than index numbers since GPU ordering can change after reboot.

**Step 3 — Reload and restart:**
```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

**Step 4 — Verify the model runs on the correct GPU:**
```bash
# Start a model
ollama run llama3.2 "hello" --verbose

# In another terminal, check GPU usage
nvidia-smi
```

You should see VRAM usage increase on the inference GPU (RTX 2060 SUPER) and nothing on the video GPU (GTX 970):
```
+-----------------------------------------------+
| GPU 0: GTX 970         | 0MiB / 4096MiB       |  <-- video only
| GPU 1: RTX 2060 SUPER  | 2048MiB / 8192MiB    |  <-- model loaded here
+-----------------------------------------------+
```

**Step 5 — Test under load:**
```bash
# Run a heavier model and watch GPU memory
watch -n 1 nvidia-smi

# In another terminal
ollama run qwen3:14b "Summarize what a roofing company does"
```

Confirm:
- GPU 0 (video) stays near 0 MiB usage
- GPU 1 (inference) shows model memory allocation
- No OOM (out of memory) errors

### Troubleshooting GPU Assignment

| Problem | Fix |
|---------|-----|
| Model loads on wrong GPU | Check UUID in override.conf matches `nvidia-smi -L` output |
| Both GPUs show usage | Remove index-based config, use UUID instead |
| "CUDA out of memory" | Model too large for VRAM — use smaller quantization or model |
| GPU not detected after reboot | Run `nvidia-smi` to confirm drivers loaded, check `dmesg \| grep nvidia` |
| Override not taking effect | Verify: `systemctl show ollama \| grep Environment` |

**Check current Ollama GPU config:**
```bash
# View the override
cat /etc/systemd/system/ollama.service.d/override.conf

# Confirm Ollama sees it
systemctl show ollama | grep CUDA
```

**Single-GPU systems:** Will work but expect reduced VRAM available for models. Close unnecessary GUI applications during heavy inference.

**GPU notes:**
- 8 GB VRAM runs llama3.2, qwen2.5-coder:7b, and phi3 comfortably
- qwen3:14b requires offloading layers across GPUs or to CPU (slower)
- 12+ GB VRAM recommended for 14B+ parameter models at full speed
- Multi-GPU setups work — Ollama will split layers across GPUs
- NVIDIA drivers + CUDA toolkit must be installed (install.sh handles this)
- AMD GPUs are not currently tested

**Verify GPU is detected:**
```bash
nvidia-smi
```

**If no GPU available:** You can still run with CPU-only Ollama, but expect 5-10x slower responses. Set smaller models:
```bash
ollama pull qwen3:4b   # lighter model for CPU-only
```

---

## Step 0 — Get the Project

Choose one method to get the project files onto the new machine:

### Option A: Git Clone

```bash
git clone <your-repo-url> /opt/business-assistant-box
cd /opt/business-assistant-box
```

### Option B: Copy from Backup/USB

```bash
cp -r /media/usb/business-assistant-box /opt/business-assistant-box
cd /opt/business-assistant-box
```

### Option C: SCP from Another Machine

```bash
scp -r user@source-machine:/path/to/business-assistant-box /opt/business-assistant-box
cd /opt/business-assistant-box
```

### Option D: Download Archive

```bash
wget https://your-server/business-assistant-box.tar.gz
tar -xzf business-assistant-box.tar.gz -C /opt/
cd /opt/business-assistant-box
```

> **Note:** You can put the project anywhere. All scripts auto-detect their location. `/opt/business-assistant-box` is the recommended convention.

---

## Step 1 — Make Scripts Executable

```bash
chmod +x admin/*.sh
```

---

## Step 2 — Run the Installer

```bash
./admin/install.sh
```

This will:
- Create the full directory scaffold
- Prompt for AI provider configuration (OpenClaw API or Ollama)
- Generate `.env` with paths specific to THIS machine
- Install Ubuntu tools, Docker, PostgreSQL, Ollama, OpenClaw, Open WebUI, n8n
- Set up pgvector, RAG schema, Python venv
- Optionally install Obsidian

Each phase prompts to continue or abort.

### Preview First (Optional)

To see what will happen without making changes:

```bash
DRY_RUN=true ./admin/install.sh
```

---

## Step 3 — Generate Workflow Templates

```bash
./admin/customize_ui_n8n.sh
```

Creates n8n workflow JSON files, dashboard buttons, and Open WebUI configuration.

---

## Step 4 — Configure n8n Workflows

```bash
./admin/configure_n8n.sh
```

Imports workflows into n8n, activates them, tests webhooks.

> **Requires:** n8n running + API key (generate in n8n Settings → API, then set `N8N_API_KEY` in `.env`)

---

## Step 5 — Onboard a Client

```bash
./admin/post_install_client_setup.sh
```

Prompts for client name(s), copies templates, creates vault directories, indexes into RAG.

---

## Step 6 — Test & Activate Client

```bash
./admin/test_client.sh demo-company
./admin/switch_client.sh demo-company
```

---

## Step 7 — Validate Everything

```bash
./admin/validate_env.sh
./admin/pre_check.sh
```

Both should show ✅ PASS (or minimal warnings for optional items like N8N_API_KEY).

---

## Summary of Commands

```bash
# Full install sequence:
chmod +x admin/*.sh
./admin/install.sh
./admin/customize_ui_n8n.sh
./admin/configure_n8n.sh
./admin/post_install_client_setup.sh
./admin/test_client.sh <client>
./admin/switch_client.sh <client>
./admin/validate_env.sh
./admin/pre_check.sh
```

---

## Portability

All scripts auto-detect the project root directory. You can install to any path:

```
/opt/business-assistant-box          ← recommended
~/business-assistant-box             ← home directory
/srv/bab                             ← custom path
```

No hardcoded paths. The `.env` file is generated at install time with correct paths for the current machine.

---

## After Installation

| Service | Access |
|---------|--------|
| Open WebUI | http://SERVER_IP:3000 |
| n8n | http://SERVER_IP:5678 |
| Dashboard | http://SERVER_IP:8088 (via python3 -m http.server) |
| PostgreSQL | localhost:5432 |
| Ollama | localhost:11434 |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Permission denied on scripts | `chmod +x admin/*.sh` |
| Docker permission denied | Logout/login after install, or `sudo usermod -aG docker $USER` |
| .env has wrong paths | Delete `.env` and rerun `./admin/install.sh` (Phase 0B recreates it) |
| Services not starting | `docker ps -a` to check containers, `docker start <name>` to restart |
| Ollama not found | Rerun Phase 4 of install.sh |
| pgvector fails | Ensure container uses `pgvector/pgvector:pg16` not `postgres:16` |

---

## Migrating Client Data

To bring client data from another machine:

```bash
# On source machine:
tar -czf client-backup.tar.gz clients/ vault/ system/ .env

# On new machine:
tar -xzf client-backup.tar.gz -C /opt/business-assistant-box/

# Update .env paths (or delete .env and let install.sh regenerate):
./admin/switch_client.sh <client-name>
./admin/validate_env.sh
```

Then re-index RAG:
```bash
source vector-db/venv/bin/activate
python3 vector-db/index_vault.py
```
