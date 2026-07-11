# system_minreq_check.md

# System Minimum Requirements Check

**Script:** `system_minreq_check.sh`

**Purpose:** Validate current system resources against Business Assistant Box requirements before installation.

**Runs:** Anytime (read-only, no modifications)

---

## CPU Requirements

| Tier | Cores | Use Case |
|------|-------|----------|
| Minimum | 4 | Runs all containers, small models only (≤8B) |
| Recommended | 8+ | Full stack with 14B models, concurrent RAG indexing |

### What Consumes CPU

| Service | CPU Impact | Notes |
|---------|-----------|-------|
| Ollama (CPU inference) | High | Dominates when GPU VRAM is insufficient — model layers spill to CPU |
| RAG indexing (Python) | Medium | Embedding generation + chunking during vault indexing |
| PostgreSQL | Low | Query execution, vector similarity search |
| n8n | Low | Workflow orchestration, webhook handling |
| Open WebUI | Low | Frontend serving |
| Docker overhead | Low | Container runtime |

### If CPU Check Fails (< 4 cores)

The system will not run the full stack reliably. Options:

1. **Upgrade hardware** — Any modern 4+ core CPU (Intel i5/Ryzen 5 or better)

2. **Reduce workload** — Use a smaller model that requires fewer CPU cycles:
   ```bash
   # In .env
   OLLAMA_MODEL=qwen3:1.7b
   ```

3. **Offload to GPU** — If you have a capable GPU, ensure Ollama uses it fully so CPU is freed:
   ```bash
   # Verify GPU is being used
   ollama ps
   # Should show GPU percentage > 0%
   ```

### If CPU Check Warns (4–7 cores)

The system runs but may be slow under load. Options:

1. **Prioritize Ollama CPU affinity** — Pin Ollama to specific cores to avoid contention:
   ```bash
   # /etc/systemd/system/ollama.service.d/override.conf
   [Service]
   CPUAffinity=0-5
   ```
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart ollama
   ```

2. **Limit concurrent services** — Stop services you're not actively using:
   ```bash
   sudo docker stop n8n        # stop workflow engine when not needed
   sudo docker stop openwebui  # stop UI when using API only
   ```

3. **Reduce Ollama parallelism** — Limit concurrent requests:
   ```bash
   # /etc/systemd/system/ollama.service
   [Service]
   Environment="OLLAMA_NUM_PARALLEL=1"
   Environment="OLLAMA_MAX_LOADED_MODELS=1"
   ```
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart ollama
   ```

### Checking CPU Details

```bash
# Core count
nproc

# Full CPU info (model, speed, cache)
lscpu

# Real-time CPU usage per core
htop

# Check which process is consuming CPU
top -o %CPU

# Check Ollama CPU usage specifically
pidof ollama | xargs -I{} ps -p {} -o %cpu,%mem,cmd
```

### CPU vs GPU Inference

| Scenario | Tokens/sec (approx) | Notes |
|----------|---------------------|-------|
| 14B model, CPU only (8 cores) | 3–8 t/s | Usable but slow |
| 14B model, GPU full offload (8GB VRAM) | 20–40 t/s | Recommended |
| 14B model, partial GPU + CPU | 10–20 t/s | Ollama splits layers automatically |
| 8B model, CPU only (4 cores) | 5–12 t/s | Acceptable for minimum spec |

If inference is too slow, the bottleneck is almost always CPU when GPU VRAM is insufficient. Check with:

```bash
# During active inference, watch CPU saturation
watch -n1 'grep "cpu " /proc/stat | awk "{usage=(\$2+\$4)*100/(\$2+\$4+\$5)} END {print usage\"%\"}"'

# Check if Ollama is using GPU at all
nvidia-smi -l 1
```

---

## Quick Reference — All Checks

| Check | Minimum | Recommended | Failure Action |
|-------|---------|-------------|----------------|
| RAM | 16GB | 32GB | Upgrade or use smaller models |
| CPU | 4 cores | 8 cores | See CPU section above |
| Disk | 50GB | 100GB | Free space or expand volume |
| Docker | ≥ 20.10 | Latest | `sudo apt install docker.io` |
| Python | 3.x | 3.10+ | `sudo apt install python3` |
| GPU | Optional | 8GB+ VRAM | See GPU tips in script output |

---

## Manually Testing Whether a GPU Is Running a Model

### Quick Check — Is a model loaded?

```bash
ollama ps
```

Output when model is loaded on GPU:
```
NAME              ID              SIZE      PROCESSOR    CONTEXT    UNTIL
qwen3:14b         bdbd181c33f2    10 GB     30%/70% CPU/GPU    4096    4 minutes from now
```

Output when idle (no model loaded):
```
NAME    ID    SIZE    PROCESSOR    CONTEXT    UNTIL
```

### Confirm Which GPU Has the Model Process

```bash
nvidia-smi --query-compute-apps=gpu_uuid,pid,process_name,used_memory --format=csv
```

Output when Ollama is using a GPU:
```
gpu_uuid, pid, process_name, used_gpu_memory [MiB]
GPU-6ef1a4a6-8765-e0ba-add8-57c7d161abb5, 834418, /usr/local/bin/ollama, 7386 MiB
```

Output when no model on GPU:
```
gpu_uuid, pid, process_name, used_gpu_memory [MiB]
```

### Map GPU UUID to Name/Index

```bash
nvidia-smi --query-gpu=index,gpu_uuid,name --format=csv
```

### Check Per-GPU Memory Usage

```bash
nvidia-smi --query-gpu=index,name,memory.used,memory.total,utilization.gpu --format=csv
```

A GPU running a model will show high `memory.used` relative to `memory.total`:
```
index, name, memory.used [MiB], memory.total [MiB], utilization.gpu [%]
0, NVIDIA GeForce GTX 970, 1575, 4096, 6       # display only
1, NVIDIA GeForce RTX 2060 SUPER, 7396, 8192, 14  # running model
```

### One-Liner: Is Ollama Using Any GPU Right Now?

```bash
nvidia-smi --query-compute-apps=process_name,used_memory --format=csv,noheader | grep -i ollama && echo "YES: Model on GPU" || echo "NO: GPU idle"
```

### Watch GPU During Active Inference

```bash
# Live refresh every 1 second
nvidia-smi -l 1

# Or watch just utilization + memory
watch -n1 'nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total --format=csv'
```

### Interpret the PROCESSOR Column in `ollama ps`

| PROCESSOR Value | Meaning |
|-----------------|--------|
| `100% GPU` | Entire model fits in VRAM — fastest |
| `30%/70% CPU/GPU` | Model split — 70% of layers on GPU, 30% on CPU (RAM) |
| `100% CPU` | No GPU used — slowest, VRAM insufficient or GPU not configured |

### If GPU Shows Idle When It Shouldn't

1. Check Ollama can see the GPU:
   ```bash
   ollama ps   # PROCESSOR column should mention GPU
   ```

2. Check CUDA_VISIBLE_DEVICES isn't hiding the GPU:
   ```bash
   grep CUDA /etc/systemd/system/ollama.service
   ```

3. Verify the correct GPU index is exposed:
   ```bash
   nvidia-smi --query-gpu=index,name,display_active --format=csv
   ```
   The compute GPU should show `display_active = Disabled`.

4. Restart Ollama and reload a model:
   ```bash
   sudo systemctl restart ollama
   ollama run qwen3:14b "test"
   nvidia-smi --query-compute-apps=process_name,used_memory --format=csv
   ```

---

## Running the Check

```bash
./admin/system_minreq_check.sh
```

Exit codes:
- `0` — All checks pass (or warnings only)
- `1` — One or more failures detected
