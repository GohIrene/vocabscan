"""
VocabScan CP2 - Model Latency Benchmark
========================================
Measures inference latency, model load time, warmup time, and model size
for all 4 models on CPU — matching the Flask deployment environment.

CP1 Section 3.7.1 requires:
  1. Inference latency (ms) — model prediction time after preprocessing
  2. Model size (MB) — deployment practicality and loading overhead

Usage:
    python benchmark_latency.py --models-dir models --images-dir test_images

Output:
    benchmark_results.txt  — summary table for CP2 report
    benchmark_detailed.csv — per-image latencies for analysis
"""

import argparse
import csv
import os
import time
import statistics

# The models were saved with Keras 2.15, which Keras 3 cannot deserialize, so
# route tf.keras through the legacy tf-keras package — same as backend/app.py.
# Must be set before tensorflow/keras is imported anywhere.
os.environ.setdefault("TF_USE_LEGACY_KERAS", "1")

import numpy as np
from PIL import Image

from benchmark_model_loader import load_trained_model

NUM_CLASSES = 30


# ── Keras model helpers ──────────────────────────────────────────────

def load_keras_model(model_path, arch):
    """Rebuild the architecture and copy in the trained weights.

    A plain keras.models.load_model() cannot read these Keras 2.15 archives —
    see benchmark_model_loader for why.
    """
    return load_trained_model(model_path, arch, num_classes=NUM_CLASSES)


def keras_predict(model, img_array):
    """Run a single Keras inference and return time in ms.

    All three models take raw 0-255 pixels (preprocessing is baked into the
    model), so no preprocess_input call belongs here.
    """
    x = np.expand_dims(img_array, axis=0)

    # Inference only (timed)
    start = time.perf_counter()
    model.predict(x, verbose=0)
    elapsed = (time.perf_counter() - start) * 1000
    return elapsed


# ── YOLO model helpers ───────────────────────────────────────────────

def load_yolo_model(model_path):
    """Load a YOLO .pt model using ultralytics."""
    from ultralytics import YOLO
    model = YOLO(model_path)
    return model


def yolo_predict(model, img_path):
    """Run a single YOLO inference and return time in ms."""
    start = time.perf_counter()
    model.predict(img_path, imgsz=224, verbose=False)
    elapsed = (time.perf_counter() - start) * 1000
    return elapsed


# ── Image loading ────────────────────────────────────────────────────

def load_test_images(images_dir, target_size=(224, 224)):
    """Load test images as numpy arrays and keep file paths."""
    img_paths = []
    img_arrays = []

    for fname in sorted(os.listdir(images_dir)):
        if fname.lower().endswith((".jpg", ".jpeg", ".png", ".webp")):
            fpath = os.path.join(images_dir, fname)
            img = Image.open(fpath).convert("RGB").resize(target_size)
            img_arrays.append(np.array(img, dtype=np.float32))
            img_paths.append(fpath)

    print(f"Loaded {len(img_paths)} test images from {images_dir}")
    return img_paths, img_arrays


# ── Benchmark runner ─────────────────────────────────────────────────

def benchmark_model(model_name, arch, model_path, img_paths, img_arrays,
                    n_warmup=5, n_runs=50):
    """Benchmark a single model and return results dict."""
    print(f"\n{'='*60}")
    print(f"Benchmarking: {model_name}")
    print(f"  Model file: {model_path}")
    file_size_mb = os.path.getsize(model_path) / (1024 * 1024)
    print(f"  Model size: {file_size_mb:.1f} MB")

    is_yolo = model_path.endswith(".pt")

    # ── Model load time ──
    load_start = time.perf_counter()
    if is_yolo:
        model = load_yolo_model(model_path)
    else:
        model = load_keras_model(model_path, arch)
    load_time = (time.perf_counter() - load_start) * 1000
    print(f"  Load time:  {load_time:.0f} ms")

    # ── Warmup (not counted) ──
    print(f"  Warmup ({n_warmup} runs)...")
    for i in range(min(n_warmup, len(img_arrays))):
        if is_yolo:
            yolo_predict(model, img_paths[i])
        else:
            keras_predict(model, img_arrays[i])

    # ── Timed inference runs ──
    n_images = min(n_runs, len(img_arrays))
    latencies = []
    print(f"  Running {n_images} inference measurements...")

    if is_yolo:
        for i in range(n_images):
            lat = yolo_predict(model, img_paths[i])
            latencies.append(lat)
    else:
        for i in range(n_images):
            lat = keras_predict(model, img_arrays[i])
            latencies.append(lat)

    # ── Stats ──
    mean_lat = statistics.mean(latencies)
    median_lat = statistics.median(latencies)
    std_lat = statistics.stdev(latencies) if len(latencies) > 1 else 0
    min_lat = min(latencies)
    max_lat = max(latencies)

    print(f"  Mean latency:   {mean_lat:.1f} ms")
    print(f"  Median latency: {median_lat:.1f} ms")
    print(f"  Std dev:        {std_lat:.1f} ms")
    print(f"  Min / Max:      {min_lat:.1f} / {max_lat:.1f} ms")

    return {
        "model_name": model_name,
        "file_size_mb": file_size_mb,
        "load_time_ms": load_time,
        "mean_latency_ms": mean_lat,
        "median_latency_ms": median_lat,
        "std_latency_ms": std_lat,
        "min_latency_ms": min_lat,
        "max_latency_ms": max_lat,
        "n_runs": n_images,
        "per_image_latencies": latencies,
    }


# ── Main ─────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--models-dir", default="models",
                    help="Directory containing model files")
    ap.add_argument("--images-dir", default="test_images",
                    help="Directory containing test images")
    ap.add_argument("--n-warmup", type=int, default=5)
    ap.add_argument("--n-runs", type=int, default=50)
    args = ap.parse_args()

    # ── Define models ──
    models = [
        ("MobileNetV2", "mobilenetv2",
         os.path.join(args.models_dir, "mobilenetv2_final.keras")),
        ("MobileNetV3Large", "mobilenetv3",
         os.path.join(args.models_dir, "mobilenetv3_final.keras")),
        ("EfficientNetV2-S", "efficientnetv2s",
         os.path.join(args.models_dir, "efficientnetv2s_final.keras")),
        ("YOLO11n-cls", None,
         os.path.join(args.models_dir, "yolo11n_cls_final.pt")),
    ]

    # ── Check files exist ──
    for name, arch, path in models:
        if not os.path.exists(path):
            print(f"ERROR: {path} not found")
            return

    # ── Load images ──
    img_paths, img_arrays = load_test_images(args.images_dir)
    if not img_paths:
        print("ERROR: No images found")
        return

    # ── Benchmark each model ──
    results = []
    for name, arch, path in models:
        r = benchmark_model(name, arch, path, img_paths, img_arrays,
                            n_warmup=args.n_warmup, n_runs=args.n_runs)
        results.append(r)

    # ── Summary table ──
    print(f"\n{'='*60}")
    print("SUMMARY — Model Comparison (CPU inference)")
    print(f"{'='*60}")
    header = f"{'Model':<20} {'Size(MB)':>8} {'Load(ms)':>9} {'Mean(ms)':>9} {'Median(ms)':>10} {'Std(ms)':>8}"
    print(header)
    print("-" * len(header))
    for r in results:
        print(f"{r['model_name']:<20} {r['file_size_mb']:>8.1f} {r['load_time_ms']:>9.0f} "
              f"{r['mean_latency_ms']:>9.1f} {r['median_latency_ms']:>10.1f} {r['std_latency_ms']:>8.1f}")

    # ── Save summary ──
    with open("benchmark_results.txt", "w") as f:
        f.write("VocabScan CP2 — Model Latency Benchmark Results\n")
        f.write(f"Platform: CPU | Images: {len(img_paths)} | "
                f"Warmup: {args.n_warmup} | Runs: {args.n_runs}\n")
        f.write(f"{'='*70}\n")
        f.write(f"{'Model':<20} {'Size(MB)':>8} {'Load(ms)':>9} {'Mean(ms)':>9} "
                f"{'Median(ms)':>10} {'Std(ms)':>8}\n")
        f.write(f"{'-'*70}\n")
        for r in results:
            f.write(f"{r['model_name']:<20} {r['file_size_mb']:>8.1f} {r['load_time_ms']:>9.0f} "
                    f"{r['mean_latency_ms']:>9.1f} {r['median_latency_ms']:>10.1f} "
                    f"{r['std_latency_ms']:>8.1f}\n")
    print("\nSaved: benchmark_results.txt")

    # ── Save detailed CSV ──
    with open("benchmark_detailed.csv", "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["model", "run", "latency_ms"])
        for r in results:
            for i, lat in enumerate(r["per_image_latencies"]):
                writer.writerow([r["model_name"], i + 1, f"{lat:.2f}"])
    print("Saved: benchmark_detailed.csv")


if __name__ == "__main__":
    main()
