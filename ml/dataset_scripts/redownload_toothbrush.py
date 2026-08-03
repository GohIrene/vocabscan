"""
VocabScan CP2 - Targeted re-download for a single LOW class (toothbrush)
=======================================================================
The 30-class download left `toothbrush` at only 91 crops, and the cleaning
step's aspect-ratio filter would cut that to ~65 (below the 80 minimum).
This script re-fetches ONLY toothbrush with relaxed crop filters + more raw
samples, then REPLACES the toothbrush images in dataset_v3/.

It reuses the exact crop geometry of download_dataset_v3_crops.py; only the
quality thresholds and sample budget are relaxed (see RELAXED CONFIG).

Usage:
    python redownload_toothbrush.py
Then re-run cleaning:
    python clean_dataset_v3.py --data dataset_v3 --dry-run
"""

import os
import json
import random
import shutil

import fiftyone as fo
import fiftyone.zoo as foz
from PIL import Image

# ---------------------------------------------------------------- config
OUTPUT_DIR = "dataset_v3"
APP_CLASS = "toothbrush"
OIV7_LABELS = ["Toothbrush"]
SEED = 42

# ---- RELAXED CONFIG (only difference vs. the main downloader) ----
TARGET_PER_CLASS = 250          # was 150 - take as many valid crops as we can
MAX_SAMPLES_PER_CLASS = 2000    # was 600 - fetch far more raw images
MAX_CROPS_PER_IMAGE = 3         # was 2
PAD_FRAC = 0.10                 # unchanged (proportional padding)
MIN_CROP_PX = 40                # was 64
MIN_REL_AREA = 0.006            # was 0.015


def crop_detection(img: Image.Image, det):
    """Same geometry as the main downloader, relaxed thresholds."""
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


def collect_crops(tmp_dir: str):
    print(f"\n=== {APP_CLASS}  (OIv7: {OIV7_LABELS}) [RELAXED] ===")
    ds_name = f"oiv7_{APP_CLASS}_relaxed"
    if fo.dataset_exists(ds_name):
        fo.delete_dataset(ds_name)

    dataset = foz.load_zoo_dataset(
        "open-images-v7",
        split="train",
        label_types=["detections"],
        classes=OIV7_LABELS,
        max_samples=MAX_SAMPLES_PER_CLASS,
        dataset_name=ds_name,
        shuffle=True,
        seed=SEED,
    )

    os.makedirs(tmp_dir, exist_ok=True)
    crop_paths = []
    n = 0
    for sample in dataset:
        if len(crop_paths) >= TARGET_PER_CLASS:
            break
        if sample.ground_truth is None:
            continue
        try:
            img = Image.open(sample.filepath).convert("RGB")
        except Exception:
            continue
        taken = 0
        for det in sample.ground_truth.detections:
            if det.label not in OIV7_LABELS:
                continue
            crop = crop_detection(img, det)
            if crop is None:
                continue
            out = os.path.join(tmp_dir, f"{APP_CLASS}_{n:05d}.jpg")
            crop.save(out, "JPEG", quality=92)
            crop_paths.append(out)
            n += 1
            taken += 1
            if taken >= MAX_CROPS_PER_IMAGE or len(crop_paths) >= TARGET_PER_CLASS:
                break

    fo.delete_dataset(ds_name)
    print(f"    collected {len(crop_paths)} crops (raw, pre-clean)")
    return crop_paths


def main():
    random.seed(SEED)
    if not os.path.isdir(OUTPUT_DIR):
        raise SystemExit(f"{OUTPUT_DIR}/ not found - run the main downloader first.")

    tmp_dir = os.path.join("_tmp_crops", APP_CLASS)
    if os.path.isdir(tmp_dir):
        shutil.rmtree(tmp_dir)
    crops = collect_crops(tmp_dir)

    if not crops:
        raise SystemExit("No crops collected - aborting, existing data left untouched.")

    # ---- clear existing toothbrush images in all splits ----
    for split in ("train", "val", "test"):
        d = os.path.join(OUTPUT_DIR, split, APP_CLASS)
        if os.path.isdir(d):
            for f in os.listdir(d):
                os.remove(os.path.join(d, f))
        else:
            os.makedirs(d, exist_ok=True)

    # ---- 70/15/15 split ----
    random.shuffle(crops)
    n = len(crops)
    n_train = round(n * 0.70)
    n_val = round(n * 0.15)
    chunks = {
        "train": crops[:n_train],
        "val": crops[n_train:n_train + n_val],
        "test": crops[n_train + n_val:],
    }
    for split, paths in chunks.items():
        for p in paths:
            shutil.move(p, os.path.join(OUTPUT_DIR, split, APP_CLASS, os.path.basename(p)))

    shutil.rmtree(os.path.join("_tmp_crops", APP_CLASS), ignore_errors=True)

    counts = {s: len(chunks[s]) for s in chunks}
    print("\n================ RESULT ================")
    print(f"{APP_CLASS}: train={counts['train']} val={counts['val']} "
          f"test={counts['test']} total={sum(counts.values())} (raw, before cleaning)")

    # ---- update dataset_report.json ----
    rep_path = os.path.join(OUTPUT_DIR, "dataset_report.json")
    if os.path.isfile(rep_path):
        with open(rep_path) as f:
            report = json.load(f)
        report[APP_CLASS] = counts
        with open(rep_path, "w") as f:
            json.dump(report, f, indent=2)
        print(f"Updated {rep_path}")

    print("\nNext: python clean_dataset_v3.py --data dataset_v3 --dry-run")


if __name__ == "__main__":
    main()
