"""
VocabScan CP2 - Merge External Supplement (5 weak classes -> dataset_v6)
=========================================================================
dataset_v4 supplemented 25/30 classes to ~300 via OIv7 validation+test,
but 5 classes hit the OIv7 scarcity ceiling:
    toothbrush 110, ruler 138, scissors 152, remote_control 175, banana 208

This script tops those 5 up to ~300 using external Roboflow Universe
datasets (single-class YOLOv8 exports) placed in external_supplement/,
while copying the other 25 classes unchanged from dataset_v4.

Crops are read directly out of each zip (no full extraction - Scissors
alone is 1.8GB) using the same quality filters as supplement_all_classes.py
(min crop size, min relative area, 10% padding), adapted for YOLO-format
normalized xywh labels instead of OIv7 FiftyOne detections.

Pipeline position:
    1. supplement_all_classes.py           (done - dataset_v4/ exists)
    2. merge_external_supplement.py        <-- THIS SCRIPT
    3. clean_dataset_v3.py --data dataset_v6 --dry-run
    4. clean_dataset_v3.py --data dataset_v6
    5. zip and upload to HPC
    6. retrain all 4 models --data dataset_v6

Usage:
    python merge_external_supplement.py --dry-run
    python merge_external_supplement.py
"""

import argparse
import io
import json
import os
import random
import shutil
import zipfile

from PIL import Image

# -----------------------------------------------------------------------
# Config
# -----------------------------------------------------------------------
SOURCE_DIR = "dataset_v4"
OUTPUT_DIR = "dataset_v6"
TARGET_TOTAL = 300
SEED = 123  # different from v3 (42) and v4 (99) seeds

SUPPLEMENT_DIR = "external_supplement"
ZIP_MAP = {
    "toothbrush": "toothbrush.yolov8.zip",
    "ruler": "Ruler.yolov8.zip",
    "scissors": "Scissors.yolov8.zip",
    "remote_control": "Remote Control.yolov8.zip",
    "banana": "Banana Detection.yolov8.zip",
}

MAX_CROPS_PER_IMAGE = 3
PAD_FRAC = 0.10
MIN_CROP_PX = 48
MIN_REL_AREA = 0.010

SPLIT_RATIOS = {"train": 0.70, "val": 0.15, "test": 0.15}
SPLITS = ["train", "val", "test"]

IMG_EXTS = (".jpg", ".jpeg", ".png")


def count_existing(data_dir: str, cls: str) -> int:
    total = 0
    for split in SPLITS:
        p = os.path.join(data_dir, split, cls)
        if os.path.exists(p):
            total += len([f for f in os.listdir(p) if f.lower().endswith(IMG_EXTS)])
    return total


def copy_existing_dataset(src_dir: str, dst_dir: str):
    """Copy all of dataset_v4 into dataset_v6 as the base (all 30 classes)."""
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
                if f.lower().endswith(IMG_EXTS):
                    shutil.copy2(os.path.join(src, f), os.path.join(dst, f))
    print("Copy complete.\n")


def crop_yolo_box(img: Image.Image, xc: float, yc: float, bw: float, bh: float):
    """Crop a normalized YOLO xywh box with padding + quality filters."""
    w, h = img.size

    if bw * bh < MIN_REL_AREA:
        return None

    x = xc - bw / 2.0
    y = yc - bh / 2.0
    px, py = bw * PAD_FRAC, bh * PAD_FRAC
    x0 = max(0.0, x - px) * w
    y0 = max(0.0, y - py) * h
    x1 = min(1.0, x + bw + px) * w
    y1 = min(1.0, y + bh + py) * h

    if (x1 - x0) < MIN_CROP_PX or (y1 - y0) < MIN_CROP_PX:
        return None

    return img.crop((int(x0), int(y0), int(x1), int(y1)))


def collect_zip_crops(cls: str, zip_name: str, needed: int, tmp_dir: str) -> list:
    """Read images + YOLO labels directly out of the zip, crop, save to tmp_dir."""
    zip_path = os.path.join(SUPPLEMENT_DIR, zip_name)
    os.makedirs(tmp_dir, exist_ok=True)
    all_crops = []
    n = 0

    with zipfile.ZipFile(zip_path) as zf:
        names = zf.namelist()
        image_entries = [
            nm for nm in names
            if "/images/" in nm and nm.lower().endswith(IMG_EXTS)
        ]
        rng = random.Random(SEED)
        rng.shuffle(image_entries)

        print(f"    {len(image_entries)} images available in {zip_name}, need {needed}")

        for img_entry in image_entries:
            if len(all_crops) >= needed:
                break

            label_entry = img_entry.replace("/images/", "/labels/")
            label_entry = os.path.splitext(label_entry)[0] + ".txt"
            if label_entry not in names:
                continue

            try:
                img_bytes = zf.read(img_entry)
                img = Image.open(io.BytesIO(img_bytes)).convert("RGB")
            except Exception:
                continue

            try:
                label_text = zf.read(label_entry).decode("utf-8")
            except Exception:
                continue

            taken = 0
            for line in label_text.strip().splitlines():
                if len(all_crops) >= needed or taken >= MAX_CROPS_PER_IMAGE:
                    break
                parts = line.strip().split()
                if len(parts) != 5:
                    continue
                try:
                    _cls_id, xc, yc, bw, bh = (float(p) for p in parts)
                except ValueError:
                    continue

                crop = crop_yolo_box(img, xc, yc, bw, bh)
                if crop is None:
                    continue

                out = os.path.join(tmp_dir, f"{cls}_ext_{n:05d}.jpg")
                crop.save(out, "JPEG", quality=92)
                all_crops.append(out)
                n += 1
                taken += 1

    print(f"    Collected {len(all_crops)} crops for {cls}")
    return all_crops


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--target", type=int, default=TARGET_TOTAL)
    args = ap.parse_args()

    target = args.target
    random.seed(SEED)

    if not os.path.exists(SOURCE_DIR):
        raise SystemExit(f"ERROR: {SOURCE_DIR}/ not found.")
    if os.path.exists(OUTPUT_DIR):
        raise SystemExit(f"ERROR: {OUTPUT_DIR}/ already exists - delete or rename it first.")
    for cls, zip_name in ZIP_MAP.items():
        zp = os.path.join(SUPPLEMENT_DIR, zip_name)
        if not os.path.exists(zp):
            raise SystemExit(f"ERROR: {zp} not found.")

    print(f"{'='*65}")
    print(f"  VocabScan Dataset Merge - 5 weak classes -> {target} each")
    print(f"  Source: {SOURCE_DIR}/ (+ {SUPPLEMENT_DIR}/)   Output: {OUTPUT_DIR}/")
    print(f"  {'DRY RUN' if args.dry_run else 'LIVE RUN'}")
    print(f"{'='*65}\n")

    print(f"{'Class':<20} {'Current':>8} {'Target':>7} {'Need':>6}")
    print("-" * 45)
    gap_map = {}
    for cls in ZIP_MAP:
        current = count_existing(SOURCE_DIR, cls)
        need = max(0, target - current)
        gap_map[cls] = need
        print(f"{cls:<20} {current:>8} {target:>7} {need:>6}")

    if args.dry_run:
        print("\n[DRY RUN] No files were created or modified.")
        print("Run without --dry-run to proceed.")
        return

    # ---- Step 1: Copy dataset_v4 -> dataset_v6 (all 30 classes) ----
    copy_existing_dataset(SOURCE_DIR, OUTPUT_DIR)

    # ---- Step 2: Pull crops from external zips for the 5 weak classes ----
    tmp_root = "_tmp_merge_ext"
    merge_report = {}

    for cls, zip_name in ZIP_MAP.items():
        needed = gap_map[cls]
        if needed == 0:
            print(f"[{cls}] Already at target - skipping.")
            merge_report[cls] = {"needed": 0, "collected": 0}
            continue

        print(f"\n[{cls}] Need {needed} more images (source: {zip_name})")
        tmp_dir = os.path.join(tmp_root, cls)
        extra = collect_zip_crops(cls, zip_name, needed, tmp_dir)

        if not extra:
            print(f"  WARNING: No crops collected for {cls}")
            merge_report[cls] = {"needed": needed, "collected": 0}
            continue

        random.shuffle(extra)
        n = len(extra)
        n_train = round(n * SPLIT_RATIOS["train"])
        n_val = round(n * SPLIT_RATIOS["val"])
        chunks = {
            "train": extra[:n_train],
            "val": extra[n_train:n_train + n_val],
            "test": extra[n_train + n_val:],
        }
        for split, paths in chunks.items():
            dst = os.path.join(OUTPUT_DIR, split, cls)
            os.makedirs(dst, exist_ok=True)
            for p in paths:
                shutil.move(p, os.path.join(dst, os.path.basename(p)))

        merge_report[cls] = {
            "needed": needed,
            "collected": len(extra),
            "added_train": len(chunks["train"]),
            "added_val": len(chunks["val"]),
            "added_test": len(chunks["test"]),
        }
        print(f"  Added: train={len(chunks['train'])} val={len(chunks['val'])} "
              f"test={len(chunks['test'])}")

    shutil.rmtree(tmp_root, ignore_errors=True)

    # ---- Step 3: Final count report (all 30 classes) ----
    print(f"\n{'='*65}")
    print("  FINAL COUNTS - dataset_v6")
    print(f"{'='*65}")
    print(f"{'Class':<20} {'Train':>6} {'Val':>5} {'Test':>5} {'Total':>7}")
    print("-" * 50)

    all_classes = sorted(os.listdir(os.path.join(OUTPUT_DIR, "train")))
    final_counts = {}
    for cls in all_classes:
        counts = {}
        for split in SPLITS:
            p = os.path.join(OUTPUT_DIR, split, cls)
            counts[split] = len([f for f in os.listdir(p) if f.lower().endswith(IMG_EXTS)]
                                 ) if os.path.exists(p) else 0
        final_counts[cls] = counts
        total = sum(counts.values())
        flag = "  <-- LOW" if total < target * 0.7 else ""
        print(f"{cls:<20} {counts['train']:>6} {counts['val']:>5} "
              f"{counts['test']:>5} {total:>7}{flag}")

    report = {
        "source": SOURCE_DIR,
        "supplement_dir": SUPPLEMENT_DIR,
        "output": OUTPUT_DIR,
        "target_per_class": target,
        "merge_detail": merge_report,
        "final_counts": final_counts,
    }
    with open(os.path.join(OUTPUT_DIR, "merge_report.json"), "w") as f:
        json.dump(report, f, indent=2)

    print(f"\n{'='*65}")
    print("  NEXT STEPS")
    print(f"{'='*65}")
    print("1. python clean_dataset_v3.py --data dataset_v6 --dry-run")
    print("2. python clean_dataset_v3.py --data dataset_v6")
    print("3. Compress-Archive -Path dataset_v6 -DestinationPath dataset_v6.zip")
    print("4. Upload dataset_v6.zip to HPC, unzip, chmod -R 755 dataset_v6/")
    print("5. Retrain: train_mobilenetv2_v4data.py / train_mobilenetv3_v4data.py /")
    print("   train_efficientnetv2s_v4data.py / train_yolo11ncls_v4data.py --data dataset_v6")


if __name__ == "__main__":
    main()
