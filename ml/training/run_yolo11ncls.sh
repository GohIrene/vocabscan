#!/bin/bash
#SBATCH --job-name=yolo11ncls
#SBATCH --partition=gpu-24c-l40s-4g
#SBATCH --account=fet_student
#SBATCH --gres=gpu:1
#SBATCH --time=03:00:00
#SBATCH --output=yolo11ncls_%j.log

set -o pipefail

# ---- Activate conda (robust in non-interactive SLURM; fixes "Run conda init") ----
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate vocabscan

PYTHON=/home/user/22044614/.conda/envs/vocabscan/bin/python

# ---- Ensure a CUDA-capable torch matching the HPC driver (12.8) ----
# The env ships torch built for cu130, which needs a 13.0 driver and silently
# falls back to CPU on this node. Reinstall a cu121 build (works on any 12.x
# driver) -- but ONLY if CUDA isn't already usable, so repeat jobs don't repay
# the download cost.
CUDA_OK=$($PYTHON -c "import torch; print('yes' if torch.cuda.is_available() else 'no')" 2>/dev/null || echo "no")
if [ "$CUDA_OK" != "yes" ]; then
    echo "=== CUDA not usable with current torch -> reinstalling cu121 build ==="
    pip uninstall -y torch torchvision triton 2>/dev/null
    pip install torch torchvision --index-url https://download.pytorch.org/whl/cu121 --quiet
fi

# ---- Pin ultralytics to the known-good version ----
pip install "ultralytics==8.4.90" --quiet

# ---- Environment check ----
echo "=== Environment check ==="
$PYTHON -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA available: {torch.cuda.is_available()}'); print(f'GPU: {torch.cuda.get_device_name(0)}' if torch.cuda.is_available() else 'GPU: NONE')"
echo "========================="

# ---- Hard GPU guard: abort instead of silently training on CPU ----
$PYTHON -c "import torch, sys; sys.exit(0 if torch.cuda.is_available() else 1)"
if [ $? -ne 0 ]; then
    echo "ERROR: No GPU available after setup. Aborting so we don't train on CPU."
    exit 1
fi

# ---- Train with weighted sampler, matching the Keras class-imbalance treatment ----
$PYTHON train_yolo11ncls_v6data.py --data dataset_v6

