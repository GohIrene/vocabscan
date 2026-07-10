"""
VocabScan CP2 - Data Cleaning & Verification (Step 2 of pipeline)
==================================================================
Run this AFTER download_dataset_v3_crops.py and BEFORE training.

Pipeline position:
  1. download_dataset_v3_crops.py   (collection + initial filtering)
  2. clean_dataset_v3.py            <-- THIS SCRIPT
  3. train_mobilenetv2_v3data.py    (training)

What it does:
  - Checks for corrupted / unreadable images
  - Removes completely black or white images (camera errors)
  - Removes extreme aspect ratios (useless slivers)
  - Detects and removes duplicate images (MD5 hash comparison)
  - Detects near-duplicate images across classes (wrong label)
  - Resizes all images to a consistent size (224x224) for uniformity
  - Verifies class balance and flags imbalanced classes
  - Generates a cleaning report (cleaning_report.json + terminal summary)

Usage:
    python clean_dataset_v3.py --data dataset_v3
    python clean_dataset_v3.py --data dataset_v3 --dry-run   # preview only, no deletions
"""

import argparse
import hashlib
import json
import os
import sys
from collections import defaultdict
from pathlib import Path

from PIL import Image

# ----------------------------------------------------------------------
# Config
# ----------------------------------------------------------------------
TARGET_SIZE = (224, 224)          # resize all images to this
MIN_ASPECT = 0.3                 # width/height ratio; below this = too narrow
MAX_ASPECT = 3.3                 # above this = too wide
BLACK_WHITE_THRESHOLD = 10       # mean pixel value below this = black, above 245 = white
MIN_STD_THRESHOLD = 5            # std dev below this = nearly uniform color (useless)
MIN_IMAGES_PER_CLASS = 80        # flag classes below this count
EXPECTED_CLASSES = 30


def md5_hash(filepath: str) -> str:
    """Compute MD5 hash of a file."""
    h = hashlib.md5()
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


def check_image(filepath: str) -> dict:
    """
    Validate a single image. Returns a dict with:
      - valid: bool
      - issue: str or None
      - width, height, aspect_ratio, mean_pixel, std_pixel
    """
    result = {"filepath": filepath, "valid": True, "issue": None}

    try:
        img = Image.open(filepath)
        img.verify()  # checks for corruption without loading full pixels
    except Exception as e:
        result["valid"] = False
        result["issue"] = f"corrupted: {str(e)[:80]}"
        return result

    # re-open after verify (verify closes the file)
    try:
        img = Image.open(filepath).convert("RGB")
    except Exception as e:
        result["valid"] = False
        result["issue"] = f"cannot convert to RGB: {str(e)[:80]}"
        return result

    w, h = img.size
    result["width"] = w
    result["height"] = h

    # --- aspect ratio check ---
    aspect = w / h if h > 0 else 0
    result["aspect_ratio"] = round(aspect, 2)
    if aspect < MIN_ASPECT or aspect > MAX_ASPECT:
        result["valid"] = False
        result["issue"] = f"extreme aspect ratio: {aspect:.2f} (allowed {MIN_ASPECT}-{MAX_ASPECT})"
        return result

    # --- black / white / uniform color check ---
    import numpy as np
    pixels = np.array(img, dtype=np.float32)
    mean_val = pixels.mean()
    std_val = pixels.std()
    result["mean_pixel"] = round(float(mean_val), 1)
    result["std_pixel"] = round(float(std_val), 1)

    if mean_val < BLACK_WHITE_THRESHOLD:
        result["valid"] = False
        result["issue"] = f"nearly black image (mean={mean_val:.1f})"
        return result
    if mean_val > 245:
        result["valid"] = False
        result["issue"] = f"nearly white image (mean={mean_val:.1f})"
        return result
    if std_val < MIN_STD_THRESHOLD:
        result["valid"] = False
        result["issue"] = f"uniform color image (std={std_val:.1f})"
        return result

    return result


def find_duplicates(hash_map: dict) -> list:
    """
    Given {hash: [filepath, ...]} find groups with >1 file.
    Returns list of (hash, [filepaths]) tuples.
    """
    return [(h, paths) for h, paths in hash_map.items() if len(paths) > 1]


def find_cross_class_duplicates(hash_map: dict) -> list:
    """
    Find images that appear in MORE THAN ONE class (same hash, different class folder).
    This catches the exact bug from dataset_v2.
    """
    cross = []
    for h, paths in hash_map.items():
        if len(paths) < 2:
            continue
        classes = set()
        for p in paths:
            parts = Path(p).parts
            # structure: dataset_v3/<split>/<class>/image.jpg
            # class is the second-to-last directory
            cls = parts[-2]
            classes.add(cls)
        if len(classes) > 1:
            cross.append((h, paths, classes))
    return cross


def resize_image(filepath: str, target_size: tuple) -> bool:
    """Resize an image to target_size and overwrite. Returns True if resized."""
    try:
        img = Image.open(filepath).convert("RGB")
        if img.size == target_size:
            return False
        img = img.resize(target_size, Image.LANCZOS)
        img.save(filepath, "JPEG", quality=92)
        return True
    except Exception:
        return False


def main():
    ap = argparse.ArgumentParser(description="VocabScan dataset cleaning & verification")
    ap.add_argument("--data", default="dataset_v3", help="Path to dataset folder")
    ap.add_argument("--dry-run", action="store_true", help="Preview issues without deleting/modifying")
    args = ap.parse_args()

    data_dir = Path(args.data)
    if not data_dir.exists():
        print(f"ERROR: {data_dir} does not exist.")
        sys.exit(1)

    print(f"{'='*60}")
    print(f"  VocabScan Data Cleaning - {'DRY RUN' if args.dry_run else 'LIVE RUN'}")
    print(f"  Dataset: {data_dir.resolve()}")
    print(f"{'='*60}\n")

    # ---- Collect all image paths ----
    splits = ["train", "val", "test"]
    all_images = []
    class_counts = defaultdict(lambda: defaultdict(int))   # class -> split -> count
    all_classes = set()

    for split in splits:
        split_dir = data_dir / split
        if not split_dir.exists():
            print(f"WARNING: {split_dir} does not exist!")
            continue
        for cls_dir in sorted(split_dir.iterdir()):
            if not cls_dir.is_dir():
                continue
            cls = cls_dir.name
            all_classes.add(cls)
            for img_path in cls_dir.iterdir():
                if img_path.suffix.lower() in (".jpg", ".jpeg", ".png", ".bmp", ".webp"):
                    all_images.append(str(img_path))
                    class_counts[cls][split] += 1

    print(f"Found {len(all_images)} images across {len(all_classes)} classes\n")

    # ---- Phase 1: Validate each image ----
    print("Phase 1: Validating images...")
    issues = []
    valid_images = []

    for i, filepath in enumerate(all_images):
        result = check_image(filepath)
        if not result["valid"]:
            issues.append(result)
        else:
            valid_images.append(filepath)

        if (i + 1) % 500 == 0:
            print(f"  checked {i+1}/{len(all_images)}...")

    print(f"  {len(issues)} problematic images found\n")

    # ---- Phase 2: Duplicate detection (MD5 hash) ----
    print("Phase 2: Checking for duplicates...")
    hash_map = defaultdict(list)
    for filepath in valid_images:
        h = md5_hash(filepath)
        hash_map[h].append(filepath)

    within_class_dupes = find_duplicates(hash_map)
    cross_class_dupes = find_cross_class_duplicates(hash_map)

    # count files to remove (keep 1 from each duplicate group)
    dupe_removals = []
    for h, paths in within_class_dupes:
        # keep the first, mark rest for removal
        for p in paths[1:]:
            dupe_removals.append({"filepath": p, "issue": f"duplicate of {paths[0]}"})

    print(f"  {len(within_class_dupes)} duplicate groups found ({len(dupe_removals)} files to remove)")
    if cross_class_dupes:
        print(f"  *** {len(cross_class_dupes)} CROSS-CLASS duplicate groups! ***")
        for h, paths, classes in cross_class_dupes:
            print(f"      same image in classes: {classes}")
    else:
        print(f"  No cross-class duplicates (the dataset_v2 bug is NOT present)")
    print()

    # ---- Phase 3: Remove bad images ----
    all_removals = issues + dupe_removals
    removed_count = 0

    if all_removals:
        print(f"Phase 3: {'Would remove' if args.dry_run else 'Removing'} {len(all_removals)} images...")
        for item in all_removals:
            fp = item["filepath"]
            reason = item["issue"]
            if args.dry_run:
                print(f"  [DRY RUN] {fp}  -- {reason}")
            else:
                try:
                    os.remove(fp)
                    removed_count += 1
                except OSError as e:
                    print(f"  ERROR removing {fp}: {e}")
        if not args.dry_run:
            print(f"  Removed {removed_count} images")
    else:
        print("Phase 3: No images to remove - dataset is clean!")
    print()

    # ---- Phase 4: Resize all remaining images to 224x224 ----
    print(f"Phase 4: {'Would resize' if args.dry_run else 'Resizing'} images to {TARGET_SIZE}...")
    resized_count = 0

    if not args.dry_run:
        remaining = []
        for split in splits:
            split_dir = data_dir / split
            if not split_dir.exists():
                continue
            for cls_dir in split_dir.iterdir():
                if not cls_dir.is_dir():
                    continue
                for img_path in cls_dir.iterdir():
                    if img_path.suffix.lower() in (".jpg", ".jpeg", ".png", ".bmp", ".webp"):
                        remaining.append(str(img_path))

        for i, filepath in enumerate(remaining):
            if resize_image(filepath, TARGET_SIZE):
                resized_count += 1
            if (i + 1) % 500 == 0:
                print(f"  resized {i+1}/{len(remaining)}...")

        print(f"  Resized {resized_count} images (others were already {TARGET_SIZE})")
    else:
        print(f"  [DRY RUN] Would check and resize all remaining images")
    print()

    # ---- Phase 5: Class balance verification ----
    print("Phase 5: Verifying class balance...")

    # recount after cleaning
    final_counts = defaultdict(lambda: defaultdict(int))
    for split in splits:
        split_dir = data_dir / split
        if not split_dir.exists():
            continue
        for cls_dir in sorted(split_dir.iterdir()):
            if not cls_dir.is_dir():
                continue
            count = len([f for f in cls_dir.iterdir()
                         if f.suffix.lower() in (".jpg", ".jpeg", ".png", ".bmp", ".webp")])
            final_counts[cls_dir.name][split] = count

    print(f"\n{'Class':<20} {'Train':>6} {'Val':>6} {'Test':>6} {'Total':>7}  Status")
    print("-" * 65)

    low_classes = []
    for cls in sorted(final_counts):
        t = final_counts[cls].get("train", 0)
        v = final_counts[cls].get("val", 0)
        te = final_counts[cls].get("test", 0)
        total = t + v + te
        status = "OK" if total >= MIN_IMAGES_PER_CLASS else "LOW"
        if status == "LOW":
            low_classes.append((cls, total))
        print(f"{cls:<20} {t:>6} {v:>6} {te:>6} {total:>7}  {status}")

    num_classes = len(final_counts)
    print(f"\nTotal classes: {num_classes}/{EXPECTED_CLASSES}")
    if num_classes < EXPECTED_CLASSES:
        print(f"  WARNING: Missing {EXPECTED_CLASSES - num_classes} classes!")

    if low_classes:
        print(f"\n  WARNING: {len(low_classes)} classes below {MIN_IMAGES_PER_CLASS} images:")
        for cls, count in low_classes:
            print(f"    {cls}: {count} images - needs supplementing")
    else:
        print(f"\n  All classes have >= {MIN_IMAGES_PER_CLASS} images")

    # ---- Generate cleaning report ----
    report = {
        "dataset_path": str(data_dir.resolve()),
        "dry_run": args.dry_run,
        "total_images_scanned": len(all_images),
        "corrupted_removed": len([i for i in issues if "corrupt" in (i.get("issue") or "")]),
        "black_white_removed": len([i for i in issues if "black" in (i.get("issue") or "") or "white" in (i.get("issue") or "")]),
        "uniform_color_removed": len([i for i in issues if "uniform" in (i.get("issue") or "")]),
        "extreme_aspect_removed": len([i for i in issues if "aspect" in (i.get("issue") or "")]),
        "duplicates_removed": len(dupe_removals),
        "cross_class_duplicates_found": len(cross_class_dupes),
        "total_removed": len(all_removals),
        "images_resized": resized_count,
        "final_class_counts": {cls: dict(splits) for cls, splits in final_counts.items()},
        "low_classes": [{"class": cls, "count": count} for cls, count in low_classes],
        "issues_detail": [{"file": i["filepath"], "reason": i["issue"]} for i in all_removals],
    }

    report_path = data_dir / "cleaning_report.json"
    with open(report_path, "w") as f:
        json.dump(report, f, indent=2)

    # ---- Summary ----
    print(f"\n{'='*60}")
    print("  CLEANING SUMMARY")
    print(f"{'='*60}")
    print(f"  Images scanned:          {len(all_images)}")
    print(f"  Corrupted:               {report['corrupted_removed']}")
    print(f"  Black/white:             {report['black_white_removed']}")
    print(f"  Uniform color:           {report['uniform_color_removed']}")
    print(f"  Extreme aspect ratio:    {report['extreme_aspect_removed']}")
    print(f"  Duplicates:              {report['duplicates_removed']}")
    print(f"  Cross-class duplicates:  {report['cross_class_duplicates_found']}")
    print(f"  Total removed:           {report['total_removed']}")
    print(f"  Images resized:          {report['images_resized']}")
    print(f"  Low classes:             {len(low_classes)}")
    print(f"  Report saved to:         {report_path}")
    print(f"{'='*60}")

    if args.dry_run:
        print("\nThis was a DRY RUN. No files were modified.")
        print("Run again without --dry-run to apply changes.")

    if cross_class_dupes:
        print("\n*** CRITICAL: Cross-class duplicates detected! ***")
        print("This is the same bug that broke dataset_v2.")
        print("Investigate before training.")
        sys.exit(1)

    if low_classes:
        print(f"\nACTION NEEDED: {len(low_classes)} classes need more images.")
        print("Options: relax download filters, take photos, or supplement from another source.")

    print("\nNext step: run training scripts on the cleaned dataset.")


if __name__ == "__main__":
    main()
