#!/bin/bash
# ==========================================
# system_minreq_check.sh
# Checks current system resources against
# Business Assistant Box minimum requirements.
# ==========================================

# Minimum requirements
MIN_RAM_GB=16
MIN_DISK_GB=50
MIN_CORES=4
MIN_DOCKER_VERSION="20.10"

# Recommended (for Ollama 14B model + all services)
REC_RAM_GB=32
REC_DISK_GB=100
REC_CORES=8

PASS=0
WARN=0
FAIL=0

pass()  { echo "  ✅ PASS: $1"; ((PASS++)); }
warn()  { echo "  ⚠️  WARN: $1"; ((WARN++)); }
fail()  { echo "  ❌ FAIL: $1"; ((FAIL++)); }

echo "========================================"
echo "  SYSTEM MINIMUM REQUIREMENTS CHECK"
echo "========================================"
echo ""

# --- RAM ---
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))

echo "RAM: ${TOTAL_RAM_GB}GB detected (min: ${MIN_RAM_GB}GB, recommended: ${REC_RAM_GB}GB)"
if [ "$TOTAL_RAM_GB" -ge "$REC_RAM_GB" ]; then
  pass "RAM meets recommended"
elif [ "$TOTAL_RAM_GB" -ge "$MIN_RAM_GB" ]; then
  warn "RAM meets minimum but below recommended — large models may be slow"
else
  fail "RAM below minimum ${MIN_RAM_GB}GB — Ollama 14B models will not load"
fi

# --- CPU Cores ---
CPU_CORES=$(nproc)

echo "CPU: ${CPU_CORES} cores detected (min: ${MIN_CORES}, recommended: ${REC_CORES})"
if [ "$CPU_CORES" -ge "$REC_CORES" ]; then
  pass "CPU meets recommended"
elif [ "$CPU_CORES" -ge "$MIN_CORES" ]; then
  warn "CPU meets minimum but below recommended"
else
  fail "CPU below minimum ${MIN_CORES} cores"
fi

# --- Disk Space ---
AVAIL_DISK_GB=$(df -BG --output=avail / | tail -1 | tr -d ' G')

echo "Disk: ${AVAIL_DISK_GB}GB available (min: ${MIN_DISK_GB}GB, recommended: ${REC_DISK_GB}GB)"
if [ "$AVAIL_DISK_GB" -ge "$REC_DISK_GB" ]; then
  pass "Disk meets recommended"
elif [ "$AVAIL_DISK_GB" -ge "$MIN_DISK_GB" ]; then
  warn "Disk meets minimum — models + containers may fill up"
else
  fail "Disk below minimum ${MIN_DISK_GB}GB"
fi

# --- Docker ---
echo ""
echo "--- Software Dependencies ---"
if command -v docker &>/dev/null; then
  DOCKER_VER=$(docker --version 2>/dev/null | grep -oP '\d+\.\d+' | head -1)
  if [ "$(printf '%s\n' "$MIN_DOCKER_VERSION" "$DOCKER_VER" | sort -V | head -1)" = "$MIN_DOCKER_VERSION" ]; then
    pass "Docker $DOCKER_VER installed"
  else
    fail "Docker $DOCKER_VER too old (need >= $MIN_DOCKER_VERSION)"
  fi
else
  fail "Docker not installed"
fi

# --- Python 3 ---
if command -v python3 &>/dev/null; then
  PY_VER=$(python3 --version 2>&1 | awk '{print $2}')
  pass "Python $PY_VER installed"
else
  fail "Python 3 not installed"
fi

# --- curl / jq / git ---
for tool in curl jq git; do
  if command -v "$tool" &>/dev/null; then
    pass "$tool installed"
  else
    fail "$tool not installed"
  fi
done

# --- GPU (optional, for Ollama performance) ---
echo ""
echo "--- GPU (optional, improves Ollama) ---"
GPU_TIPS=""
if command -v nvidia-smi &>/dev/null; then
  GPU_COUNT=0
  COMPUTE_VRAM=0
  COMPUTE_GPU=""
  COMPUTE_IDX=""
  ALL_DISPLAY=true
  while IFS=, read -r idx name mem display; do
    idx=$(echo "$idx" | xargs)
    name=$(echo "$name" | xargs)
    mem=$(echo "$mem" | xargs)
    display=$(echo "$display" | xargs)
    ((GPU_COUNT++))
    if [ "$display" = "Enabled" ]; then
      ROLE="display"
    else
      ROLE="compute"
      ALL_DISPLAY=false
      if [ "${mem:-0}" -gt "$COMPUTE_VRAM" ]; then
        COMPUTE_VRAM="$mem"
        COMPUTE_GPU="$name"
        COMPUTE_IDX="$idx"
      fi
    fi
    pass "NVIDIA GPU $idx: $name (${mem}MB VRAM) [$ROLE]"
  done < <(nvidia-smi --query-gpu=index,name,memory.total,display_active --format=csv,noheader,nounits 2>/dev/null)

  if [ "$GPU_COUNT" -eq 0 ]; then
    warn "No NVIDIA GPU detected — Ollama will use CPU only (slower)"
    GPU_TIPS="no_gpu"
  elif [ "$ALL_DISPLAY" = true ] && [ "$GPU_COUNT" -gt 1 ]; then
    warn "All GPUs have display attached — Ollama competes with desktop rendering"
    GPU_TIPS="all_display_multi"
  elif [ "$ALL_DISPLAY" = true ] && [ "$GPU_COUNT" -eq 1 ]; then
    warn "Single GPU handles both display and compute — model inference may stutter"
    GPU_TIPS="all_display_single"
  elif [ "$COMPUTE_VRAM" -lt 8000 ]; then
    warn "Compute GPU ($COMPUTE_GPU) VRAM < 8GB — 14B models may not fit"
    GPU_TIPS="low_vram"
  fi
else
  warn "No NVIDIA GPU detected — Ollama will use CPU only (slower)"
  GPU_TIPS="no_gpu"
fi

if [ -n "$GPU_TIPS" ]; then
  echo ""
  echo "  --- GPU Configuration Tips ---"
  case "$GPU_TIPS" in
    no_gpu)
      echo "  Install NVIDIA drivers: sudo apt install nvidia-driver-560"
      echo "  Verify: nvidia-smi"
      ;;
    all_display_multi)
      echo "  Dedicate a GPU to compute (model-only) by offloading display to one GPU:"
      echo ""
      echo "  1. Identify GPU bus IDs:"
      echo "     nvidia-smi --query-gpu=index,pci.bus_id,name --format=csv"
      echo ""
      echo "  2. Set display GPU in /etc/X11/xorg.conf:"
      echo '     Section "Device"'
      echo '       Identifier "DisplayGPU"'
      echo '       Driver "nvidia"'
      echo '       BusID "PCI:<bus>:<device>:<function>"  # display GPU bus ID'
      echo '     EndSection'
      echo ""
      echo "  3. Assign compute GPU to Ollama in /etc/systemd/system/ollama.service:"
      echo '     [Service]'
      echo '     Environment="CUDA_VISIBLE_DEVICES=<compute-gpu-index>"'
      echo ""
      echo "  4. Reload and restart:"
      echo "     sudo systemctl daemon-reload"
      echo "     sudo systemctl restart ollama"
      ;;
    all_display_single)
      echo "  Single GPU must share display + compute. To reduce contention:"
      echo ""
      echo "  Option A — Add a second GPU dedicated to compute."
      echo ""
      echo "  Option B — Use headless mode (SSH only, no desktop):"
      echo "     sudo systemctl set-default multi-user.target"
      echo "     sudo reboot"
      echo "     (GPU becomes fully available for Ollama)"
      echo ""
      echo "  Option C — Use integrated graphics (iGPU) for display:"
      echo "     Enable iGPU in BIOS, set as primary display."
      echo "     Then in /etc/systemd/system/ollama.service:"
      echo '     Environment="CUDA_VISIBLE_DEVICES=0"'
      ;;
    low_vram)
      echo "  Compute GPU VRAM is limited. Options:"
      echo ""
      echo "  1. Use a smaller model in .env:"
      echo "     OLLAMA_MODEL=qwen3:8b   # fits in <8GB VRAM"
      echo ""
      echo "  2. Enable partial GPU offload (Ollama does this automatically):"
      echo "     Layers that don't fit VRAM spill to RAM — slower but functional."
      echo ""
      echo "  3. Upgrade to a GPU with >=12GB VRAM for full 14B model offload."
      ;;
  esac
  echo ""
fi

# --- Model on GPU Detection ---
echo ""
echo "--- Model Status ---"
if command -v ollama &>/dev/null; then
  OLLAMA_MODELS=$(ollama ps 2>/dev/null | tail -n +2)
  if [ -n "$(echo "$OLLAMA_MODELS" | grep -v '^$')" ]; then
    while read -r line; do
      [ -z "$line" ] && continue
      MODEL_NAME=$(echo "$line" | awk '{print $1}')
      [ -z "$MODEL_NAME" ] && continue
      if echo "$line" | grep -qP '\d+%.*GPU'; then
        PROC_INFO=$(echo "$line" | grep -oP '\d+%(/\d+%)?\s+(CPU/)?GPU')
        GPU_PCT=$(echo "$line" | grep -oP '\d+(?=%\s+GPU|%.*GPU)' | tail -1)
        pass "Model '$MODEL_NAME' loaded — $PROC_INFO"
        if [ "${GPU_PCT:-0}" -lt 50 ]; then
          warn "'$MODEL_NAME' mostly on CPU — GPU VRAM too small for full offload"
        fi
      elif echo "$line" | grep -qP '\d+%.*CPU'; then
        warn "Model '$MODEL_NAME' loaded on CPU only — no GPU acceleration"
      fi
    done <<< "$OLLAMA_MODELS"
  else
    echo "  No model currently loaded (idle). Load one with: ollama run <model>"
  fi
else
  echo "  Ollama not installed — skipping model check"
fi

# Confirm via nvidia-smi which GPU is running the model process
if command -v nvidia-smi &>/dev/null; then
  OLLAMA_ON_GPU=$(nvidia-smi --query-compute-apps=gpu_uuid,pid,process_name,used_memory --format=csv,noheader,nounits 2>/dev/null | grep -i ollama)
  if [ -n "$OLLAMA_ON_GPU" ]; then
    while IFS=, read -r uuid pid pname mem; do
      uuid=$(echo "$uuid" | xargs)
      mem=$(echo "$mem" | xargs)
      GPU_NAME=$(nvidia-smi --query-gpu=gpu_uuid,index,name --format=csv,noheader 2>/dev/null | grep "$uuid" | cut -d, -f3 | xargs)
      GPU_IDX=$(nvidia-smi --query-gpu=gpu_uuid,index --format=csv,noheader 2>/dev/null | grep "$uuid" | cut -d, -f2 | xargs)
      pass "Ollama process on GPU $GPU_IDX ($GPU_NAME) — ${mem}MB VRAM allocated"
    done <<< "$OLLAMA_ON_GPU"
  fi
fi

# --- Summary ---
echo ""
echo "========================================"
echo "  RESULTS: $PASS passed, $WARN warnings, $FAIL failures"
echo "========================================"

if [ "$FAIL" -gt 0 ]; then
  echo "  ❌ System does NOT meet minimum requirements."
  exit 1
elif [ "$WARN" -gt 0 ]; then
  echo "  ⚠️  System meets minimum but not recommended specs."
  exit 0
else
  echo "  ✅ System meets all recommended requirements."
  exit 0
fi
