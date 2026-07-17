"""Full test-set accuracy for all 4 models, to pair with benchmark_latency.py's
speed numbers when picking a model for deployment.

Keras models: batched model.predict() over every image in dataset_v6/test.
YOLO: ultralytics' own .val(split="test"), so its accuracy is computed the
same way the training script measured it.
"""

import json
import os
import time

os.environ.setdefault("TF_USE_LEGACY_KERAS", "1")
os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "3")

import numpy as np
from PIL import Image

from benchmark_model_loader import load_trained_model

MODELS_DIR = "models"
TEST_DIR = r"C:\Users\Irenehaha\capstoneProject\vocabscan\dataset_v6\test"
BATCH = 32

KERAS_MODELS = [
    ("MobileNetV2", "mobilenetv2", "mobilenetv2_final.keras"),
    ("MobileNetV3Large", "mobilenetv3", "mobilenetv3_final.keras"),
    ("EfficientNetV2-S", "efficientnetv2s", "efficientnetv2s_final.keras"),
]


def load_test_set():
    class_names = sorted(os.listdir(TEST_DIR))
    paths, labels = [], []
    for idx, cls in enumerate(class_names):
        cls_dir = os.path.join(TEST_DIR, cls)
        for fname in sorted(os.listdir(cls_dir)):
            paths.append(os.path.join(cls_dir, fname))
            labels.append(idx)
    return class_names, paths, np.array(labels)


def eval_keras(name, arch, fname, class_names, paths, labels):
    print(f"\n{'='*60}\nEvaluating: {name}")
    model = load_trained_model(os.path.join(MODELS_DIR, fname), arch,
                                num_classes=len(class_names))
    preds = np.empty(len(paths), dtype=np.int64)
    top5_hit = np.zeros(len(paths), dtype=bool)

    t0 = time.perf_counter()
    for start in range(0, len(paths), BATCH):
        batch_paths = paths[start:start + BATCH]
        imgs = np.stack([
            np.array(Image.open(p).convert("RGB").resize((224, 224)), dtype=np.float32)
            for p in batch_paths
        ])
        probs = model.predict(imgs, verbose=0)
        preds[start:start + len(batch_paths)] = probs.argmax(axis=1)
        top5 = np.argsort(-probs, axis=1)[:, :5]
        batch_labels = labels[start:start + len(batch_paths)]
        top5_hit[start:start + len(batch_paths)] = (top5 == batch_labels[:, None]).any(axis=1)
    elapsed = time.perf_counter() - t0

    top1 = (preds == labels).mean()
    top5 = top5_hit.mean()
    print(f"  {len(paths)} images in {elapsed:.1f}s")
    print(f"  Top-1: {top1:.4f}   Top-5: {top5:.4f}")

    # Worst 5 classes by recall, useful to know before picking a model.
    per_class = {}
    for idx, cls in enumerate(class_names):
        mask = labels == idx
        per_class[cls] = (preds[mask] == labels[mask]).mean()
    worst = sorted(per_class.items(), key=lambda kv: kv[1])[:5]
    print("  Worst classes:", ", ".join(f"{c}={a:.0%}" for c, a in worst))

    return {"model": name, "top1": float(top1), "top5": float(top5),
            "per_class": per_class}


def eval_yolo():
    print(f"\n{'='*60}\nEvaluating: YOLO11n-cls (ultralytics .val)")
    from ultralytics import YOLO
    model = YOLO(os.path.join(MODELS_DIR, "yolo11n_cls_final.pt"))
    data_root = r"C:\Users\Irenehaha\capstoneProject\vocabscan\dataset_v6"
    metrics = model.val(data=data_root, split="test", imgsz=224, verbose=False)
    print(f"  Top-1: {metrics.top1:.4f}   Top-5: {metrics.top5:.4f}")
    return {"model": "YOLO11n-cls", "top1": float(metrics.top1),
            "top5": float(metrics.top5), "per_class": None}


def main():
    class_names, paths, labels = load_test_set()
    print(f"Test set: {len(paths)} images across {len(class_names)} classes")

    results = []
    for name, arch, fname in KERAS_MODELS:
        results.append(eval_keras(name, arch, fname, class_names, paths, labels))
    results.append(eval_yolo())

    print(f"\n{'='*60}\nSUMMARY — Top-1 / Top-5 accuracy (dataset_v6/test, {len(paths)} images)")
    print(f"{'='*60}")
    header = f"{'Model':<20} {'Top-1':>8} {'Top-5':>8}"
    print(header)
    print("-" * len(header))
    for r in results:
        print(f"{r['model']:<20} {r['top1']:>8.2%} {r['top5']:>8.2%}")

    with open("accuracy_results.json", "w") as f:
        json.dump(results, f, indent=2)
    print("\nSaved: accuracy_results.json")


if __name__ == "__main__":
    main()
