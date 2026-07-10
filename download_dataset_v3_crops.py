"""
VocabScan CP2 - Dataset v3 downloader (BOUNDING BOX CROPS)
===========================================================
Downloads Open Images V7 DETECTION data via fiftyone, then crops each
bounding box into a single-object image. This fixes the core problem
with dataset_v2: OIv7 photos are cluttered multi-object scenes, but
VocabScan's focus-box design assumes ONE dominant object per image.

Run this LOCALLY (needs internet), then zip dataset_v3/ and upload to HPC,
same workflow as before.

Output structure (works for both Keras and YOLOv8-cls):
    dataset_v3/
        train/<class>/*.jpg   (105 per class)
        val/<class>/*.jpg     (22 per class)
        test/<class>/*.jpg    (23 per class)

Usage:
    pip install fiftyone pillow
    python download_dataset_v3_crops.py
"""

import os
import json
import random
import shutil

import fiftyone as fo
import fiftyone.zoo as foz
from PIL import Image

# ----------------------------------------------------------------------
# Config
# ----------------------------------------------------------------------
OUTPUT_DIR = "dataset_v3"
TARGET_PER_CLASS = 150          # total crops per class
SPLITS = {"train": 105, "val": 22, "test": 23}   # 70 / 15 / 15
SEED = 42

MAX_SAMPLES_PER_CLASS = 600     # raw OIv7 images to fetch per class
MAX_CROPS_PER_IMAGE = 2         # diversity: don't take 10 crops of one photo
PAD_FRAC = 0.10                 # 10% context padding around each box
MIN_CROP_PX = 64                # discard tiny crops (both dims must be >= this)
MIN_REL_AREA = 0.015            # discard boxes covering <1.5% of the image

# App class name -> Open Images V7 label(s)
CLASS_MAP = {
    "bottle":         ["Bottle"],
    "cup":            ["Coffee cup", "Mug"],
    "spoon":          ["Spoon"],
    "plate":          ["Plate"],
    "remote_control": ["Remote control"],
    "book":           ["Book"],
    "scissors":       ["Scissors"],
    "pen":            ["Pen"],
    "ruler":          ["Ruler"],
    "backpack":       ["Backpack"],
    "chair":          ["Chair"],
    "table":          ["Table"],
    "clock":          ["Clock", "Alarm clock", "Wall clock"],
    "lamp":           ["Lamp"],
    "bowl":           ["Bowl"],
    "fork":           ["Fork"],
    "knife":          ["Knife", "Kitchen knife"],
    "apple":          ["Apple"],
    "banana":         ["Banana"],
    "orange":         ["Orange"],
    "bread":          ["Bread"],
    "toothbrush":     ["Toothbrush"],
    "umbrella":       ["Umbrella"],
    "shoe":           ["Footwear"],
    "laptop":         ["Laptop"],
    "mobile_phone":   ["Mobile phone"],
    "keyboard":       ["Computer keyboard"],
    "ball":           ["Ball"],
    "teddy_bear":     ["Teddy bear"],
    "glasses":        ["Glasses"],
}


def crop_detection(img: Image.Image, det) -> Image.Image | None:
    """Crop one fiftyone Detection from a PIL image, with padding + quality filters."""
    w, h = img.size
    x, y, bw, bh = det.bounding_box  # relative [x, y, w, h]

    # quality filters
    if bw * bh < MIN_REL_AREA:
        return None
    if getattr(det, "IsGroupOf", False) or getattr(det, "iscrowd", False):
        return None
    if getattr(det, "IsDepiction", False):   # drawings/cartoons of the object
        return None

    # padding (10% of box size on each side)
    px, py = bw * PAD_FRAC, bh * PAD_FRAC
    x0 = max(0.0, x - px) * w
    y0 = max(0.0, y - py) * h
    x1 = min(1.0, x + bw + px) * w
    y1 = min(1.0, y + bh + py) * h

    if (x1 - x0) < MIN_CROP_PX or (y1 - y0) < MIN_CROP_PX:
        return None

    return img.crop((int(x0), int(y0), int(x1), int(y1)))


def collect_crops_for_class(app_class: str, oiv7_labels: list[str], tmp_dir: str) -> list[str]:
    """Download OIv7 detections for one class and save crops. Returns crop paths."""
    print(f"\n=== {app_class}  (OIv7: {oiv7_labels}) ===")
    ds_name = f"oiv7_{app_class}"
    if fo.dataset_exists(ds_name):
        fo.delete_dataset(ds_name)

    dataset = foz.load_zoo_dataset(
        "open-images-v7",
        split="train",
        label_types=["detections"],
        classes=oiv7_labels,
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
            if det.label not in oiv7_labels:
                continue
            crop = crop_detection(img, det)
            if crop is None:
                continue
            out = os.path.join(tmp_dir, f"{app_class}_{n:05d}.jpg")
            crop.save(out, "JPEG", quality=92)
            crop_paths.append(out)
            n += 1
            taken += 1
            if taken >= MAX_CROPS_PER_IMAGE or len(crop_paths) >= TARGET_PER_CLASS:
                break

    fo.delete_dataset(ds_name)
    print(f"    collected {len(crop_paths)} crops")
    return crop_paths


def main():
    random.seed(SEED)

    if os.path.exists(OUTPUT_DIR):
        raise SystemExit(f"{OUTPUT_DIR}/ already exists - delete or rename it first.")

    for split in SPLITS:
        for cls in CLASS_MAP:
            os.makedirs(os.path.join(OUTPUT_DIR, split, cls), exist_ok=True)

    report = {}
    tmp_root = "_tmp_crops"

    for app_class, labels in CLASS_MAP.items():
        tmp_dir = os.path.join(tmp_root, app_class)
        crops = collect_crops_for_class(app_class, labels, tmp_dir)

        if len(crops) < TARGET_PER_CLASS:
            print(f"    WARNING: only {len(crops)}/{TARGET_PER_CLASS} for {app_class}")

        random.shuffle(crops)
        # proportional split even if we got fewer than 150
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
                shutil.move(p, os.path.join(OUTPUT_DIR, split, app_class, os.path.basename(p)))

        report[app_class] = {s: len(chunks[s]) for s in chunks}

    shutil.rmtree(tmp_root, ignore_errors=True)

    with open(os.path.join(OUTPUT_DIR, "dataset_report.json"), "w") as f:
        json.dump(report, f, indent=2)

    print("\n================ SUMMARY ================")
    for cls, counts in report.items():
        total = sum(counts.values())
        flag = "" if total >= TARGET_PER_CLASS else "  <-- LOW"
        print(f"{cls:16s} train={counts['train']:3d} val={counts['val']:3d} test={counts['test']:3d}{flag}")
    print(f"\nDone. Dataset written to {OUTPUT_DIR}/")
    print("Next: zip it and upload to HPC:  zip -r dataset_v3.zip dataset_v3/")


if __name__ == "__main__":
    main()
