"""Generates the three remaining Chapter 4 figures (4.1, 4.3, 4.6).

Reads only existing artefacts (dataset_v6 JSON, AI mdel reports, benchmark
tables) — no model runs needed. Writes PNGs to backend/benchmark/results/.

Run from backend/benchmark/:
    ../.venv/Scripts/python.exe make_report_figures.py
"""

import json
import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(HERE, "results")
os.makedirs(OUT, exist_ok=True)

# Training-environment headline numbers (AI mdel/), used as the report primary.
MODELS = ["MobileNetV2", "MobileNetV3Large", "EfficientNetV2-S", "YOLO11n-cls"]
TOP1 = [0.8909, 0.9198, 0.9376, 0.8760]
MACRO_F1 = [0.891, 0.919, 0.937, 0.876]
SIZE_MB = [23.8, 33.4, 189.5, 3.1]
LATENCY_MS = [299.2, 275.7, 602.6, 21.1]
COLORS = ["#4C72B0", "#DD8452", "#55A868", "#C44E52"]
CHOSEN = "MobileNetV3Large"


def fig_4_1_class_counts():
    rep = json.load(open(os.path.join(REPO, "dataset_v6", "cleaning_report.json")))
    fc = rep["final_class_counts"]
    classes = sorted(fc, key=lambda c: fc[c]["train"])
    train = [fc[c]["train"] for c in classes]
    val = [fc[c]["val"] for c in classes]
    test = [fc[c]["test"] for c in classes]
    x = np.arange(len(classes))
    fig, ax = plt.subplots(figsize=(15, 6))
    ax.bar(x, train, label="Train", color="#4C72B0")
    ax.bar(x, val, bottom=train, label="Validation", color="#DD8452")
    ax.bar(x, test, bottom=np.array(train) + np.array(val), label="Test",
           color="#55A868")
    ax.set_xticks(x)
    ax.set_xticklabels(classes, rotation=90, fontsize=9)
    ax.set_ylabel("Images")
    ax.set_title("Figure 4.1 — Per-class image counts by split (dataset_v6, "
                 "sorted by train size)")
    ax.legend()
    ax.grid(axis="y", alpha=0.3)
    fig.tight_layout()
    p = os.path.join(OUT, "fig_4_1_class_counts.png")
    fig.savefig(p, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print("saved", p)


def fig_4_3_model_bars():
    x = np.arange(len(MODELS))
    w = 0.38
    fig, ax = plt.subplots(figsize=(9, 5.5))
    b1 = ax.bar(x - w / 2, [t * 100 for t in TOP1], w, label="Top-1 accuracy",
                color="#4C72B0")
    b2 = ax.bar(x + w / 2, [f * 100 for f in MACRO_F1], w, label="Macro F1",
                color="#55A868")
    ax.set_xticks(x)
    ax.set_xticklabels(MODELS, fontsize=10)
    ax.set_ylabel("Percent")
    ax.set_ylim(80, 100)
    ax.set_title("Figure 4.3 — Top-1 accuracy and macro F1 by model "
                 "(dataset_v6 test set)")
    ax.legend(loc="lower right")
    ax.grid(axis="y", alpha=0.3)
    for bars in (b1, b2):
        for b in bars:
            ax.text(b.get_x() + b.get_width() / 2, b.get_height() + 0.3,
                    f"{b.get_height():.1f}", ha="center", va="bottom", fontsize=8)
    # highlight chosen model
    idx = MODELS.index(CHOSEN)
    ax.axvspan(idx - 0.5, idx + 0.5, color="gold", alpha=0.12)
    fig.tight_layout()
    p = os.path.join(OUT, "fig_4_3_model_bars.png")
    fig.savefig(p, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print("saved", p)


def fig_4_6_accuracy_latency():
    fig, ax = plt.subplots(figsize=(9, 6))
    # bubble area scaled from model size
    sizes = [s * 6 for s in SIZE_MB]
    # per-model label offsets to avoid collisions with the title / bubbles
    offsets = {"EfficientNetV2-S": (-40, -55), "MobileNetV3Large": (12, 12),
               "MobileNetV2": (12, 12), "YOLO11n-cls": (-15, 12)}
    for i, m in enumerate(MODELS):
        ax.scatter(LATENCY_MS[i], TOP1[i] * 100, s=sizes[i], color=COLORS[i],
                   alpha=0.6, edgecolors="black", linewidths=1, zorder=3)
        ax.annotate(f"{m}\n{SIZE_MB[i]} MB",
                    (LATENCY_MS[i], TOP1[i] * 100),
                    textcoords="offset points", xytext=offsets[m], fontsize=9)
    ax.set_ylim(87.5, 95.0)
    ax.set_xlabel("Inference latency (ms, CPU) — lower is better →")
    ax.set_ylabel("Top-1 accuracy (%) — higher is better ↑")
    ax.set_title("Figure 4.6 — Accuracy vs latency (bubble area ∝ model size)",
                 pad=14)
    ax.invert_xaxis()  # so 'better' (faster + more accurate) is top-right
    ax.grid(alpha=0.3, zorder=0)
    # annotate the chosen model as the efficient knee
    idx = MODELS.index(CHOSEN)
    ax.annotate("Selected — best joint trade-off",
                (LATENCY_MS[idx], TOP1[idx] * 100),
                textcoords="offset points", xytext=(15, -30), fontsize=9,
                color="#8B6914",
                arrowprops=dict(arrowstyle="->", color="#8B6914"))
    fig.tight_layout()
    p = os.path.join(OUT, "fig_4_6_accuracy_latency.png")
    fig.savefig(p, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print("saved", p)


if __name__ == "__main__":
    fig_4_1_class_counts()
    fig_4_3_model_bars()
    fig_4_6_accuracy_latency()
    print("\nAll three figures written to", OUT)

