"""
VocabScan CP2 - Full Dataset Supplement (All 30 Classes -> ~500 each)
====================================================================
Brings every class up to ~500 total images by downloading the gap
from Open Images V7 validation + test splits (new images not in v3).

Why 500 per class:
  - Current v3: ~150 per class (105 train / 22 val / 23 test)
  - Target v4:  ~600 per class (420 train / 90 val / 90 test)
  - More data -> less overfitting -> better generalization
  - EfficientNetV2-S currently: train 99%+ vs val 93% (6% gap)
  - Expected after 500/class: gap reduces to ~2-3%, accuracy ~ 95-97%

Strategy:
  - Count existing images per class in dataset_v3/
  - Calculate how many MORE are needed to reach TARGET_TOTAL
  - Download only the gap (don't re-download what already exists)
  - Pull from OIv7 validation then test splits (new images)
  - Merge into dataset_v4/ (dataset_v3/ untouched as backup)

Pipeline position:
  1. download_dataset_v3_crops.py    (done - dataset_v3/ exists)
  2. supplement_all_classes.py       <-- THIS SCRIPT
  3. clean_dataset_v3.py --data dataset_v4
  4. zip and upload to HPC
  5. retrain all 5 models --data dataset_v4

Usage:
    python supplement_all_classes.py
    python supplement_all_classes.py --dry-run    # preview counts only
    python supplement_all_classes.py --target 300  # custom target (default 600)
"""

import argparse
import json
import os
import random
import shutil

import fiftyone as fo
import fiftyone.zoo as foz
from PIL import Image

# -----------------------------------------------------------------------
# Config
# -----------------------------------------------------------------------
SOURCE_DIR   = "dataset_v4_old"
OUTPUT_DIR   = "dataset_v4"
TARGET_TOTAL = 300           # target total images per class (buffer for cleaning losses)
SEED         = 99            # different from v3 seed (42) - different images

# OIv7 splits to pull from (v3 used "train" only)
OIV7_SPLITS  = ["validation", "test"]

MAX_SAMPLES_PER_SPLIT = 1000   # raw images to search per split per class
MAX_CROPS_PER_IMAGE   = 3      # allow 3 crops per image for diversity
PAD_FRAC     = 0.10
MIN_CROP_PX  = 48
MIN_REL_AREA = 0.010

SPLIT_RATIOS = {"train": 0.70, "val": 0.15, "test": 0.15}
SPLITS       = ["train", "val", "test"]

# Full class map (same as original download script)
CLASS_MAP = {
    "apple":          ["Apple"],
    "backpack":       ["Backpack"],
    "ball":           ["Ball"],
    "banana":         ["Banana"],
    "book":           ["Book"],
    "bottle":         ["Bottle"],
    "bowl":           ["Bowl"],
    "bread":          ["Bread"],
    "chair":          ["Chair"],
    "clock":          ["Clock", "Alarm clock", "Wall clock"],
    "cup":            ["Coffee cup", "Mug"],
    "fork":           ["Fork"],
    "glasses":        ["Glasses"],
    "keyboard":       ["Computer keyboard"],
    "knife":          ["Knife", "Kitchen knife"],
    "lamp":           ["Lamp"],
    "laptop":         ["Laptop"],
    "mobile_phone":   ["Mobile phone"],
    "orange":         ["Orange"],
    "pen":            ["Pen"],
    "plate":          ["Plate"],
    "remote_control": ["Remote control"],
    "ruler":          ["Ruler"],
    "scissors":       ["Scissors"],
    "shoe":           ["Footwear"],
    "spoon":          ["Spoon"],
    "table":          ["Table"],
    "teddy_bear":     ["Teddy bear"],
    "toothbrush":     ["Toothbrush"],
    "umbrella":       ["Umbrella"],
}


def crop_detection(img: Image.Image, det) -> Image.Image | None:
    """Crop bounding box with padding and quality filters."""
    w, h = img.size
    x, y, bw, bh = det.bounding_box

    if bw * bh < MIN_REL_AREA:
        return None
    if getattr(det, "IsGroupOf", False) or getattr(det, "iscrowd", False):
        return None
    if getattr(det, "IsDepiction", False):
        return None

    px, py = bw * PAD_FRAC, bh * PAD_FRAC
    x0 = max(0.0, x - px) * w
    y0 = max(0.0, y - py) * h
    x1 = min(1.0, x + bw + px) * w
    y1 = min(1.0, y + bh + py) * h

    if (x1 - x0) < MIN_CROP_PX or (y1 - y0) < MIN_CROP_PX:
        return None

    return img.crop((int(x0), int(y0), int(x1), int(y1)))


def count_existing(data_dir: str, cls: str) -> int:
    """Count total images for a class across all splits."""
    total = 0
    for split in SPLITS:
        p = os.path.join(data_dir, split, cls)
        if os.path.exists(p):
            total += len([f for f in os.listdir(p)
                          if f.lower().endswith((".jpg", ".jpeg", ".png"))])
    return total


def collect_extra_crops(app_class: str, labels: list,
                        needed: int, tmp_dir: str) -> list:
    """Download extra crops from OIv7 validation + test splits."""
    os.makedirs(tmp_dir, exist_ok=True)
    all_crops = []
    n = 0

    for oiv7_split in OIV7_SPLITS:
        if len(all_crops) >= needed:
            break

        still_need = needed - len(all_crops)
        print(f"    [{oiv7_split}] need {still_need} more crops...")

        ds_name = f"oiv7_supp_{app_class}_{oiv7_split}"
        if fo.dataset_exists(ds_name):
            fo.delete_dataset(ds_name)

        try:
            dataset = foz.load_zoo_dataset(
                "open-images-v7",
                split=oiv7_split,
                label_types=["detections"],
                classes=labels,
                max_samples=MAX_SAMPLES_PER_SPLIT,
                dataset_name=ds_name,
                shuffle=True,
                seed=SEED,
            )
        except Exception as e:
            print(f"    WARNING: {oiv7_split} split failed: {e}")
            if fo.dataset_exists(ds_name):
                fo.delete_dataset(ds_name)
            continue

        for sample in dataset:
            if len(all_crops) >= needed:
                break
            if sample.ground_truth is None:
                continue
            try:
                img = Image.open(sample.filepath).convert("RGB")
            except Exception:
                continue

            taken = 0
            for det in sample.ground_truth.detections:
                if det.label not in labels:
                    continue
                crop = crop_detection(img, det)
                if crop is None:
                    continue
                out = os.path.join(tmp_dir, f"{app_class}_supp_{n:05d}.jpg")
                crop.save(out, "JPEG", quality=92)
                all_crops.append(out)
                n += 1
                taken += 1
                if taken >= MAX_CROPS_PER_IMAGE or len(all_crops) >= needed:
                    break

        fo.delete_dataset(ds_name)
        print(f"    [{oiv7_split}] done - total collected so far: {len(all_crops)}")

    return all_crops


def copy_existing_dataset(src_dir: str, dst_dir: str):
    """Copy all of dataset_v3 into dataset_v4 as the base."""
    print(f"Copying {src_dir}/ -> {dst_dir}/ ...")
    for split in SPLITS:
        split_dir = os.path.join(src_dir, split)
        if not os.path.exists(split_dir):
            continue
        for cls in os.listdir(split_dir):
            src = os.path.join(split_dir, cls)
            dst = os.path.join(dst_dir, split, cls)
            os.makedirs(dst, exist_ok=True)
            for f in os.listdir(src):
                if f.lower().endswith((".jpg", ".jpeg", ".png")):
                    shutil.copy2(os.path.join(src, f),
                                 os.path.join(dst, f))
    print("Copy complete.\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--target", type=int, default=TARGET_TOTAL,
                    help="Target total images per class (default: 500)")
    args = ap.parse_args()

    target = args.target
    random.seed(SEED)

    # ---- Validate ----
    if not os.path.exists(SOURCE_DIR):
        raise SystemExit(f"ERROR: {SOURCE_DIR}/ not found.")
    if os.path.exists(OUTPUT_DIR):
        raise SystemExit(f"ERROR: {OUTPUT_DIR}/ already exists - "
                         f"delete or rename it first.")

    print(f"{'='*65}")
    print(f"  VocabScan Dataset Supplement - All 30 Classes -> {target} each")
    print(f"  Source: {SOURCE_DIR}/   Output: {OUTPUT_DIR}/")
    print(f"  {'DRY RUN' if args.dry_run else 'LIVE RUN'}")
    print(f"{'='*65}\n")

    # ---- Calculate gap per class ----
    print(f"{'Class':<20} {'Current':>8} {'Target':>7} {'Need':>6}")
    print("-" * 45)

    gap_map = {}
    for cls in sorted(CLASS_MAP):
        current = count_existing(SOURCE_DIR, cls)
        need = max(0, target - current)
        gap_map[cls] = need
        flag = "  -> supplement needed" if need > 0 else "  OK already at target"
        print(f"{cls:<20} {current:>8} {target:>7} {need:>6}{flag}")

    total_needed = sum(gap_map.values())
    print(f"\nTotal extra crops needed across all classes: {total_needed}")
    print(f"Estimated download time: ~{max(1, total_needed // 300)}-"
          f"{max(2, total_needed // 150)} hours\n")

    if args.dry_run:
        print("[DRY RUN] No files were created or modified.")
        print("Run without --dry-run to proceed.")
        return

    # ---- Step 1: Copy v3 -> v4 ----
    copy_existing_dataset(SOURCE_DIR, OUTPUT_DIR)

    # ---- Step 2: Download gaps ----
    tmp_root = "_tmp_supp_all"
    supplement_report = {}

    for cls in sorted(CLASS_MAP):
        needed = gap_map[cls]

        if needed == 0:
            print(f"[{cls}] Already at {target}+ images - skipping download.")
            supplement_report[cls] = {"needed": 0, "collected": 0}
            continue

        print(f"\n[{cls}] Need {needed} more images "
              f"(OIv7 labels: {CLASS_MAP[cls]})")
        tmp_dir = os.path.join(tmp_root, cls)
        extra = collect_extra_crops(cls, CLASS_MAP[cls], needed, tmp_dir)

        if not extra:
            print(f"  WARNING: No extra crops collected for {cls}")
            supplement_report[cls] = {"needed": needed, "collected": 0}
            continue

        # Distribute into v4 splits
        random.shuffle(extra)
        n = len(extra)
        n_train = round(n * SPLIT_RATIOS["train"])
        n_val   = round(n * SPLIT_RATIOS["val"])
        chunks  = {
            "train": extra[:n_train],
            "val":   extra[n_train:n_train + n_val],
            "test":  extra[n_train + n_val:],
        }
        for split, paths in chunks.items():
            dst = os.path.join(OUTPUT_DIR, split, cls)
            os.makedirs(dst, exist_ok=True)
            for p in paths:
                shutil.move(p, os.path.join(dst, os.path.basename(p)))

        supplement_report[cls] = {
            "needed":    needed,
            "collected": len(extra),
            "added_train": len(chunks["train"]),
            "added_val":   len(chunks["val"]),
            "added_test":  len(chunks["test"]),
        }
        print(f"  Added: train={len(chunks['train'])} "
              f"val={len(chunks['val'])} test={len(chunks['test'])}")

    shutil.rmtree(tmp_root, ignore_errors=True)

    # ---- Step 3: Final count report ----
    print(f"\n{'='*65}")
    print("  FINAL COUNTS - dataset_v4")
    print(f"{'='*65}")
    print(f"{'Class':<20} {'Train':>6} {'Val':>5} {'Test':>5} {'Total':>7}")
    print("-" * 50)

    final_counts = {}
    for cls in sorted(CLASS_MAP):
        counts = {}
        for split in SPLITS:
            p = os.path.join(OUTPUT_DIR, split, cls)
            counts[split] = len([f for f in os.listdir(p)
                                  if f.lower().endswith((".jpg",".jpeg",".png"))]
                                 ) if os.path.exists(p) else 0
        final_counts[cls] = counts
        total = sum(counts.values())
        flag = "" if total >= target * 0.7 else "  <-- LOW"
        print(f"{cls:<20} {counts['train']:>6} {counts['val']:>5} "
              f"{counts['test']:>5} {total:>7}{flag}")

    # Save report
    report = {
        "source": SOURCE_DIR,
        "output": OUTPUT_DIR,
        "target_per_class": target,
        "supplement_detail": supplement_report,
        "final_counts": final_counts,
    }
    with open(os.path.join(OUTPUT_DIR, "supplement_report.json"), "w") as f:
        json.dump(report, f, indent=2)

    print(f"\n{'='*65}")
    print("  NEXT STEPS")
    print(f"{'='*65}")
    print("1. Run the cleaning script on dataset_v4:")
    print("   python clean_dataset_v3.py --data dataset_v4 --dry-run")
    print("   python clean_dataset_v3.py --data dataset_v4")
    print()
    print("2. Zip for upload:")
    print("   Compress-Archive -Path dataset_v4 -DestinationPath dataset_v4.zip")
    print()
    print("3. Upload dataset_v4.zip to HPC via OpenOnDemand Files UI")
    print()
    print("4. On HPC - unzip, chmod, retrain all 5 models:")
    print("   unzip dataset_v4.zip && chmod -R 755 dataset_v4/")
    print("   python train_mobilenetv2_v3data.py     --data dataset_v4")
    print("   python train_mobilenetv3_v3data.py     --data dataset_v4")
    print("   python train_yolov8_v3data.py          --data dataset_v4")
    print("   python train_efficientnetv2s_v3data.py --data dataset_v4")
    print("   python train_yolo11_v3data.py          --data dataset_v4")


if __name__ == "__main__":
    main()
