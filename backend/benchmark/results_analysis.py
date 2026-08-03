"""Consistent 4-model results analysis for the CP2 report (§4.3).

Evaluates all four candidate models on the SAME local test set through ONE
harness, so the comparison is apples-to-apples:

  * Keras models (MobileNetV2 / MobileNetV3Large / EfficientNetV2-S) are loaded
    via the deployment weight-transplant path (benchmark_model_loader), i.e. the
    exact code the running Flask app uses.
  * YOLO11n-cls is evaluated per-image and mapped into the same class ordering,
    so it finally gets full per-class precision/recall/F1 and a confusion matrix
    instead of only top-1/top-5 scalars.

Outputs (written to backend/benchmark/results/):
  <arch>_classification_report.txt   per-model P/R/F1 (matches AI mdel/ format)
  <arch>_confusion_matrix.png        30x30 count-annotated matrix, titled v6
  per_class_f1_comparison.png        grouped bars, 4 models, sorted by MNv3 F1
  top_confusions.csv                 top-10 confused pairs per model
  results_summary.json               machine-readable everything
  results_table.md                   paste-ready headline table

NOTE ON NUMBERS: the Keras path here is the DEPLOYMENT loader (PIL resize), so
MobileNetV3Large scores ~0.9191 vs 0.9198 in the HPC training environment — a
1-image difference from resize interpolation, not weight loss (see report
�4.3.5). The YOLO checkpoint in `models/yolo11n_cls_final.pt` is the weighted-sampler retrain; this harness provides the internally consistent 4-model comparison and YOLO per-class metrics.

Run from backend/benchmark/:
    ../.venv/Scripts/python.exe results_analysis.py
"""

import csv
import json
import os

os.environ.setdefault("TF_USE_LEGACY_KERAS", "1")
os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "3")

import numpy as np
from PIL import Image

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

from sklearn.metrics import classification_report, confusion_matrix

from benchmark_model_loader import load_trained_model

# --- paths -----------------------------------------------------------------
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
TEST_DIR = os.path.join(REPO, "dataset", "test")   # dataset/ holds the v6 images
MODELS_DIR = os.path.join(HERE, "models")
OUT_DIR = os.path.join(HERE, "results")
DATASET_TAG = "dataset_v6"
BATCH = 32

KERAS_MODELS = [
    ("MobileNetV2", "mobilenetv2", "mobilenetv2_final.keras"),
    ("MobileNetV3Large", "mobilenetv3", "mobilenetv3_final.keras"),
    ("EfficientNetV2-S", "efficientnetv2s", "efficientnetv2s_final.keras"),
]
YOLO_MODEL = ("YOLO11n-cls", "yolo11n_cls", "yolo11n_cls_final.pt")


# --- test set --------------------------------------------------------------
def load_test_set():
    class_names = sorted(os.listdir(TEST_DIR))
    paths, labels = [], []
    for idx, cls in enumerate(class_names):
        cls_dir = os.path.join(TEST_DIR, cls)
        for fname in sorted(os.listdir(cls_dir)):
            paths.append(os.path.join(cls_dir, fname))
            labels.append(idx)
    return class_names, paths, np.array(labels)


# --- prediction ------------------------------------------------------------
def predict_keras(arch, fname, class_names, paths):
    model = load_trained_model(os.path.join(MODELS_DIR, fname), arch,
                               num_classes=len(class_names))
    preds = np.empty(len(paths), dtype=np.int64)
    for start in range(0, len(paths), BATCH):
        batch = paths[start:start + BATCH]
        imgs = np.stack([
            np.array(Image.open(p).convert("RGB").resize((224, 224)),
                     dtype=np.float32)
            for p in batch
        ])
        probs = model.predict(imgs, verbose=0)
        preds[start:start + len(batch)] = probs.argmax(axis=1)
    return preds


def predict_yolo(fname, class_names, paths):
    from ultralytics import YOLO
    model = YOLO(os.path.join(MODELS_DIR, fname))
    # Map YOLO's own class index -> our sorted-class index (guard against any
    # ordering mismatch between ultralytics and sorted(os.listdir)).
    yolo_idx_to_ours = {}
    for yi, yname in model.names.items():
        if yname in class_names:
            yolo_idx_to_ours[yi] = class_names.index(yname)
    preds = np.empty(len(paths), dtype=np.int64)
    for start in range(0, len(paths), BATCH):
        batch = paths[start:start + BATCH]
        results = model.predict(batch, imgsz=224, verbose=False)
        for i, r in enumerate(results):
            preds[start + i] = yolo_idx_to_ours[int(r.probs.top1)]
    return preds


# --- artefacts -------------------------------------------------------------
def write_report(name, arch, labels, preds, class_names):
    top1 = (preds == labels).mean()
    txt = classification_report(labels, preds, target_names=class_names,
                                digits=3, zero_division=0)
    path = os.path.join(OUT_DIR, f"{arch}_classification_report.txt")
    with open(path, "w", encoding="utf-8") as f:
        f.write(f"Test accuracy: {top1:.4f}\n\n{txt}")
    rep = classification_report(labels, preds, target_names=class_names,
                                output_dict=True, zero_division=0)
    return top1, rep


def plot_confusion(name, arch, labels, preds, class_names):
    cm = confusion_matrix(labels, preds, labels=range(len(class_names)))
    n = len(class_names)
    fig, ax = plt.subplots(figsize=(0.55 * n + 3, 0.55 * n + 2))
    im = ax.imshow(cm, cmap="Blues")
    fig.colorbar(im, ax=ax, fraction=0.046, pad=0.04)
    ax.set_xticks(range(n)); ax.set_yticks(range(n))
    ax.set_xticklabels(class_names, rotation=90, fontsize=8)
    ax.set_yticklabels(class_names, fontsize=8)
    ax.set_xlabel("Predicted label"); ax.set_ylabel("True label")
    ax.set_title(f"{name} Confusion Matrix (test set, {DATASET_TAG})")
    thresh = cm.max() / 2.0
    for i in range(n):
        for j in range(n):
            v = cm[i, j]
            if v:
                ax.text(j, i, str(v), ha="center", va="center", fontsize=6,
                        color="white" if v > thresh else "black")
    fig.tight_layout()
    out = os.path.join(OUT_DIR, f"{arch}_confusion_matrix.png")
    fig.savefig(out, dpi=150, bbox_inches="tight")
    plt.close(fig)
    return cm


def top_confusions(cm, class_names, k=10):
    pairs = []
    for i in range(len(class_names)):
        for j in range(len(class_names)):
            if i != j and cm[i, j] > 0:
                pairs.append((class_names[i], class_names[j], int(cm[i, j])))
    pairs.sort(key=lambda t: t[2], reverse=True)
    return pairs[:k]


def plot_f1_comparison(reports, class_names, sort_by="MobileNetV3Large"):
    order = sorted(class_names,
                   key=lambda c: reports[sort_by][c]["f1-score"])
    x = np.arange(len(order))
    model_names = list(reports.keys())
    width = 0.8 / len(model_names)
    fig, ax = plt.subplots(figsize=(16, 7))
    for mi, mname in enumerate(model_names):
        f1s = [reports[mname][c]["f1-score"] for c in order]
        ax.bar(x + mi * width, f1s, width, label=mname)
    ax.set_xticks(x + width * (len(model_names) - 1) / 2)
    ax.set_xticklabels(order, rotation=90, fontsize=9)
    ax.set_ylabel("F1-score"); ax.set_ylim(0.6, 1.02)
    ax.set_title(f"Per-class F1 across models (sorted by {sort_by}, "
                 f"test set, {DATASET_TAG})")
    ax.legend(loc="lower right")
    ax.grid(axis="y", alpha=0.3)
    fig.tight_layout()
    fig.savefig(os.path.join(OUT_DIR, "per_class_f1_comparison.png"),
                dpi=150, bbox_inches="tight")
    plt.close(fig)


# --- main ------------------------------------------------------------------
def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    class_names, paths, labels = load_test_set()
    print(f"Test set: {len(paths)} images across {len(class_names)} classes")

    all_models = KERAS_MODELS + [YOLO_MODEL]
    reports, summary, confusions = {}, [], {}

    for name, arch, fname in all_models:
        print(f"\n{'='*60}\n{name}")
        if arch == "yolo11n_cls":
            preds = predict_yolo(fname, class_names, paths)
        else:
            preds = predict_keras(arch, fname, class_names, paths)

        top1, rep = write_report(name, arch, labels, preds, class_names)
        cm = plot_confusion(name, arch, labels, preds, class_names)
        reports[name] = rep
        confusions[name] = top_confusions(cm, class_names)
        macro, weighted = rep["macro avg"], rep["weighted avg"]
        summary.append({
            "model": name,
            "top1": float(top1),
            "macro_precision": macro["precision"],
            "macro_recall": macro["recall"],
            "macro_f1": macro["f1-score"],
            "weighted_f1": weighted["f1-score"],
        })
        print(f"  top1={top1:.4f}  macroF1={macro['f1-score']:.4f}  "
              f"weightedF1={weighted['f1-score']:.4f}")

    plot_f1_comparison(reports, class_names)

    with open(os.path.join(OUT_DIR, "top_confusions.csv"), "w",
              newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["model", "true", "predicted", "count"])
        for mname, pairs in confusions.items():
            for t, p, c in pairs:
                w.writerow([mname, t, p, c])

    with open(os.path.join(OUT_DIR, "results_summary.json"), "w",
              encoding="utf-8") as f:
        json.dump({"class_names": class_names, "summary": summary,
                   "reports": reports}, f, indent=2)

    lines = ["| Model | Top-1 | Macro P | Macro R | Macro F1 | Weighted F1 |",
             "|---|---|---|---|---|---|"]
    for s in summary:
        lines.append(f"| {s['model']} | {s['top1']:.4f} | "
                     f"{s['macro_precision']:.3f} | {s['macro_recall']:.3f} | "
                     f"{s['macro_f1']:.3f} | {s['weighted_f1']:.3f} |")
    table = "\n".join(lines)
    with open(os.path.join(OUT_DIR, "results_table.md"), "w",
              encoding="utf-8") as f:
        f.write(table + "\n")

    print(f"\n{'='*60}\n{table}\n\nAll artefacts written to {OUT_DIR}")


if __name__ == "__main__":
    main()

