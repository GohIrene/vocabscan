"""End-to-end /predict latency, measured from an HTTP client (report §4.6).

benchmark_latency.py times model.predict() in isolation. This script instead
measures the REAL request a scan makes: multipart image upload -> Flask ->
PIL decode + resize + single-image inference -> vocab lookup -> JSON response,
including network/serialisation overhead. It decomposes each request into:

    total round-trip   (wall clock, client side)
  = server inference   (decode + resize + model.predict, reported by /predict)
  + network + overhead (upload/download, Flask handling, vocab lookup, JSON)

It does NOT cover the browser-side capture and render stages of the full
"camera -> UI" chain; those need the real Flutter client and are noted as a
separate, out-of-harness measurement in the report.

Requires the Flask server to be RUNNING (start it yourself: `python app.py`
from backend/). Requests are sent sequentially, matching one child scanning
one object at a time.

Run from backend/benchmark/:
    ../.venv/Scripts/python.exe benchmark_e2e.py
    ../.venv/Scripts/python.exe benchmark_e2e.py --url http://127.0.0.1:5000 --n 60 --warmup 5
"""

import argparse
import csv
import os
import statistics
import sys
import time

import requests

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
TEST_DIR = os.path.join(REPO, "dataset", "test")


def sample_images(n):
    """Round-robin across classes so the sample isn't dominated by one object."""
    per_class = {}
    for cls in sorted(os.listdir(TEST_DIR)):
        cdir = os.path.join(TEST_DIR, cls)
        per_class[cls] = [os.path.join(cdir, f) for f in sorted(os.listdir(cdir))]
    picks, i = [], 0
    classes = list(per_class)
    while len(picks) < n:
        cls = classes[i % len(classes)]
        depth = i // len(classes)
        if depth < len(per_class[cls]):
            picks.append((cls, per_class[cls][depth]))
        i += 1
        if i > n * len(classes):  # safety
            break
    return picks[:n]


def one_request(url, path):
    with open(path, "rb") as fh:
        files = {"image": (os.path.basename(path), fh, "image/jpeg")}
        t0 = time.perf_counter()
        r = requests.post(f"{url}/predict", files=files, timeout=30)
        total_ms = (time.perf_counter() - t0) * 1000
    r.raise_for_status()
    data = r.json()
    return total_ms, data


def pctl(values, p):
    """Nearest-rank percentile."""
    s = sorted(values)
    k = max(0, min(len(s) - 1, int(round(p / 100 * (len(s) - 1)))))
    return s[k]


def summarise(label, values):
    return (f"{label:<22} n={len(values):<4} "
            f"mean={statistics.mean(values):7.1f}  "
            f"median={statistics.median(values):7.1f}  "
            f"p95={pctl(values, 95):7.1f}  "
            f"min={min(values):7.1f}  max={max(values):7.1f}  "
            f"std={statistics.pstdev(values):6.1f}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", default="http://127.0.0.1:5000")
    ap.add_argument("--n", type=int, default=60, help="measured requests")
    ap.add_argument("--warmup", type=int, default=5, help="discarded requests")
    args = ap.parse_args()

    try:
        h = requests.get(f"{args.url}/health", timeout=3)
        h.raise_for_status()
    except Exception as e:
        sys.exit(f"Server not reachable at {args.url} ({e}). "
                 f"Start it with `python app.py` from backend/ first.")

    imgs = sample_images(args.n + args.warmup)
    if len(imgs) < args.n + args.warmup:
        print(f"WARNING: only {len(imgs)} images available")

    print(f"Warming up ({args.warmup}) ...")
    for _, p in imgs[:args.warmup]:
        one_request(args.url, p)

    print(f"Measuring {args.n} sequential /predict round-trips against {args.url}\n")
    rows, total_l, infer_l, overhead_l = [], [], [], []
    correct = considered = 0
    for cls, p in imgs[args.warmup:args.warmup + args.n]:
        total_ms, data = one_request(args.url, p)
        infer_ms = data.get("inference_time_ms")
        if infer_ms is None:
            # low_confidence or error responses still carry timing when inference ran
            infer_ms = data.get("inference_time_ms", float("nan"))
        overhead = total_ms - infer_ms if infer_ms == infer_ms else float("nan")
        total_l.append(total_ms)
        if infer_ms == infer_ms:
            infer_l.append(infer_ms)
            overhead_l.append(overhead)
        if data.get("success"):
            considered += 1
            if data.get("english_key") == cls:
                correct += 1
        rows.append([cls, os.path.basename(p), round(total_ms, 1),
                     infer_ms, round(overhead, 1) if overhead == overhead else "",
                     data.get("success"), data.get("predicted_class", ""),
                     data.get("confidence", "")])

    print(summarise("total round-trip", total_l))
    print(summarise("server inference", infer_l))
    print(summarise("network+overhead", overhead_l))
    if considered:
        print(f"\nSanity: {correct}/{considered} confident predictions matched the "
              f"source class ({correct / considered:.1%}).")

    out_txt = os.path.join(HERE, "benchmark_e2e_results.txt")
    with open(out_txt, "w", encoding="utf-8") as f:
        f.write(f"VocabScan CP2 - End-to-End /predict Latency\n")
        f.write(f"Server: {args.url} | Measured: {args.n} | Warmup: {args.warmup} "
                f"| Sequential\n")
        f.write("=" * 70 + "\n")
        f.write("All values in milliseconds.\n\n")
        f.write(summarise("total round-trip", total_l) + "\n")
        f.write(summarise("server inference", infer_l) + "\n")
        f.write(summarise("network+overhead", overhead_l) + "\n")
        if considered:
            f.write(f"\nSanity: {correct}/{considered} confident predictions "
                    f"matched source class ({correct / considered:.1%}).\n")

    out_csv = os.path.join(HERE, "benchmark_e2e_detailed.csv")
    with open(out_csv, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["true_class", "image", "total_ms", "inference_ms",
                    "overhead_ms", "success", "predicted", "confidence"])
        w.writerows(rows)

    print(f"\nSaved: {out_txt}\n       {out_csv}")


if __name__ == "__main__":
    main()
