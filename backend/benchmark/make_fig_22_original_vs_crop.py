"""Generates Figure 22 - Original Scene and Object-Centred Crop.

Uses one real Open Images V7 detection sample (cached locally under
~/fiftyone/open-images-v7/train/) to show:
  (a) the original, uncropped photograph — a cluttered, multi-object scene;
  (b) the same photograph with its actual OIv7 detection bounding box drawn
      on it;
  (c) the crop produced from that box using the pipeline's 10% contextual
      padding rule (identical math to crop_detection() in
      download_dataset_v3_crops.py).

Sample: f177b5f4c0d6d5fa.jpg, OIv7 label "Coffee cup", ground-truth
bounding_box [0.334, 0.218, 0.394, 0.540] (relative x, y, w, h) — a table
with a coffee cup, a glass of water, and a glass of beer, illustrating why
classification labels (§3.2.2) were too cluttered and detection crops were
needed.

Run from backend/benchmark/:
    ../.venv/Scripts/python.exe make_fig_22_original_vs_crop.py
"""

import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as patches
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results")
os.makedirs(OUT, exist_ok=True)

IMG_PATH = os.path.expanduser(
    r"~/fiftyone/open-images-v7/train/data/f177b5f4c0d6d5fa.jpg")
LABEL = "Coffee cup"
BBOX = (0.334, 0.218, 0.394, 0.540)  # relative x, y, w, h (OIv7 ground truth)
PAD_FRAC = 0.10                       # same as download_dataset_v3_crops.py


def crop_with_padding(img: Image.Image, bbox) -> Image.Image:
    """Identical crop geometry to crop_detection() in
    download_dataset_v3_crops.py."""
    w, h = img.size
    x, y, bw, bh = bbox
    px, py = bw * PAD_FRAC, bh * PAD_FRAC
    x0 = max(0.0, x - px) * w
    y0 = max(0.0, y - py) * h
    x1 = min(1.0, x + bw + px) * w
    y1 = min(1.0, y + bh + py) * h
    return img.crop((int(x0), int(y0), int(x1), int(y1)))


def main():
    img = Image.open(IMG_PATH).convert("RGB")
    w, h = img.size
    x, y, bw, bh = BBOX

    crop = crop_with_padding(img, BBOX)

    fig, axes = plt.subplots(1, 2, figsize=(11, 5.5))

    axes[0].imshow(img)
    rect = patches.Rectangle(
        (x * w, y * h), bw * w, bh * h,
        linewidth=2.5, edgecolor="#DD2C2C", facecolor="none")
    axes[0].add_patch(rect)
    axes[0].text(
        x * w, y * h - 8, LABEL, color="white", fontsize=10, weight="bold",
        bbox=dict(facecolor="#DD2C2C", edgecolor="none", pad=2))
    axes[0].set_title("(a) Original OIv7 photograph\nwith detection bounding box")
    axes[0].axis("off")

    axes[1].imshow(crop)
    axes[1].set_title("(b) Object-centred crop\n(10% contextual padding)")
    axes[1].axis("off")

    fig.suptitle(
        "Figure 22 — Original Scene and Object-Centred Crop", fontsize=13)
    fig.tight_layout(rect=[0, 0, 1, 0.94])

    p = os.path.join(OUT, "fig_22_original_vs_crop.png")
    fig.savefig(p, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print("saved", p)


if __name__ == "__main__":
    main()
