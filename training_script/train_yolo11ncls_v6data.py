"""
VocabScan CP2 - YOLO11n-cls training (dataset_v4)
===================================================
New script (no v3-data predecessor exists in this repo - only a stale
__pycache__ for an older train_yolov8_v3data.py was found, source lost).

Uses the ultralytics classification API. dataset_v4's existing
train/val/test + per-class-subfolder layout is already the format
ultralytics classification expects - no reshaping needed.

Class imbalance handling - IMPORTANT CAVEAT:
  Unlike the three Keras scripts (train_mobilenetv2_v4data.py,
  train_mobilenetv3_v4data.py, train_efficientnetv2s_v4data.py), ultralytics
  has NO built-in `class_weight` argument for classification training
  (confirmed via ultralytics community/GitHub threads, July 2026). The
  documented workaround is a weighted dataloader: subclass
  ClassificationTrainer to sample minority-class images more often via
  torch's WeightedRandomSampler. That's what WeightedClassificationTrainer
  below does.

  This relies on ClassificationDataset internals (`dataset.samples`, a list
  of (path, class_index) tuples) that are NOT part of ultralytics' public
  API and can change between versions. Before a long HPC run, sanity check
  with a short (1-2 epoch) run first. If it errors, rerun with
  --no-weighted to fall back to plain (unweighted) training rather than
  losing the whole job.

Run on HPC:
    pip install ultralytics
    python train_yolo11ncls_v4data.py --data dataset_v4
    python train_yolo11ncls_v4data.py --data dataset_v4 --no-weighted   # fallback
"""

import argparse
import json
import os
import shutil

import numpy as np

IMGSZ = 224
BATCH = 16
EPOCHS = 50
SEED = 42
BASE_WEIGHTS = "yolo11n-cls.pt"
MODEL_NAME = "yolo11n_cls"


def build_class_weights(data_dir, class_names):
    counts = np.array([
        len(os.listdir(os.path.join(data_dir, "train", c))) for c in class_names
    ], dtype=np.float64)
    return counts.sum() / (len(class_names) * counts)


def make_weighted_trainer():
    """Constructs WeightedClassificationTrainer lazily so --no-weighted runs
    don't need a working ultralytics internals import at all."""
    import torch
    from torch.utils.data import DataLoader, WeightedRandomSampler
    from ultralytics.models.yolo.classify import ClassificationTrainer

    class WeightedClassificationTrainer(ClassificationTrainer):
        def get_dataloader(self, dataset_path, batch_size=16, rank=0, mode="train"):
            dataset = self.build_dataset(dataset_path, mode)
            if mode != "train":
                return super().get_dataloader(dataset_path, batch_size, rank, mode)

            targets = [s[1] for s in dataset.samples]
            class_counts = np.bincount(targets)
            inv_freq = 1.0 / class_counts
            sample_weights = [inv_freq[t] for t in targets]
            sampler = WeightedRandomSampler(
                sample_weights, num_samples=len(sample_weights), replacement=True)

            return DataLoader(
                dataset,
                batch_size=batch_size,
                sampler=sampler,
                num_workers=getattr(self.args, "workers", 8),
                pin_memory=True,
                collate_fn=getattr(dataset, "collate_fn", None),
            )

    return WeightedClassificationTrainer


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="dataset_v6")
    ap.add_argument("--epochs", type=int, default=EPOCHS)
    ap.add_argument("--weighted", dest="weighted", action="store_true", default=True)
    ap.add_argument("--no-weighted", dest="weighted", action="store_false")
    args = ap.parse_args()

    from ultralytics import YOLO

    class_names = sorted(os.listdir(os.path.join(args.data, "train")))
    print(f"Classes ({len(class_names)}):", class_names)

    class_weight = build_class_weights(args.data, class_names)
    print("Class weights (inverse frequency, used for sampling):")
    for name, w in zip(class_names, class_weight):
        print(f"    {name:<16} {w:.3f}")

    with open("yolo11_classes.json", "w") as f:
        json.dump(class_names, f, indent=2)

    model = YOLO(BASE_WEIGHTS)

    train_kwargs = dict(
        data=os.path.abspath(args.data),
        epochs=args.epochs,
        imgsz=IMGSZ,
        batch=BATCH,
        seed=SEED,
        project="runs_yolo11ncls",
        name="v4data",
    )

    if args.weighted:
        print("\n########## Training with weighted sampler (class imbalance) ##########")
        train_kwargs["trainer"] = make_weighted_trainer()
    else:
        print("\n########## Training WITHOUT class weighting (--no-weighted) ##########")

    results = model.train(**train_kwargs)

    best_pt = os.path.join(results.save_dir, "weights", "best.pt")
    shutil.copyfile(best_pt, f"{MODEL_NAME}_final.pt")
    print(f"\nSaved {MODEL_NAME}_final.pt (copied from {best_pt})")

    print("\n########## TEST EVALUATION ##########")
    metrics = YOLO(f"{MODEL_NAME}_final.pt").val(
        data=os.path.abspath(args.data), split="test", imgsz=IMGSZ)
    print(f"Top-1 accuracy: {metrics.top1:.4f}")
    print(f"Top-5 accuracy: {metrics.top5:.4f}")

    with open(f"{MODEL_NAME}_classification_report.txt", "w") as f:
        f.write(f"Top-1 accuracy: {metrics.top1:.4f}\n")
        f.write(f"Top-5 accuracy: {metrics.top5:.4f}\n")


if __name__ == "__main__":
    main()
