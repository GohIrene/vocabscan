"""
VocabScan CP2 - MobileNetV3Large training (dataset_v4, tuned + BUG FIX)
========================================================================
Same as train_mobilenetv3_v3data.py, retargeted at dataset_v4 and with
class_weight added to counter the class imbalance in dataset_v4 (toothbrush:
102 images vs shoe: 299 images, ~2.9x ratio - see ruler/toothbrush, the two
smallest classes).

BUG FIX vs the original V2 script:
  Keras MobileNetV3 ships with preprocessing BUILT INTO the model
  (include_preprocessing=True). It expects RAW 0-255 pixels.
  If you also apply Rescaling or mobilenet preprocess_input, the inputs
  get scaled twice and the ImageNet weights become useless -> the model
  collapses onto a few classes (which is what we saw: everything
  predicted as bottle/lamp).
  This script feeds raw pixels straight in. NO extra rescaling layer.

Option D tuning (same as V2):
  Stage 1: epochs=30, lr=1e-3, patience=8
  Stage 2: epochs=20, lr=5e-5, patience=8
  Dropout=0.4, Batch=16, stronger augmentation

Run on HPC:
    python train_mobilenetv3_v4data.py --data dataset_v4
"""

import argparse
import json
import os

import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers

IMG_SIZE = (224, 224)
BATCH = 16
DROPOUT = 0.4
SEED = 42
STAGE1_EPOCHS, STAGE1_LR = 30, 1e-3
STAGE2_EPOCHS, STAGE2_LR = 20, 5e-5
PATIENCE = 8
MODEL_NAME = "mobilenetv3"


def load_datasets(data_dir):
    common = dict(image_size=IMG_SIZE, batch_size=BATCH, label_mode="int", seed=SEED)
    train = keras.utils.image_dataset_from_directory(
        os.path.join(data_dir, "train"), shuffle=True, **common)
    val = keras.utils.image_dataset_from_directory(
        os.path.join(data_dir, "val"), shuffle=False, **common)
    test = keras.utils.image_dataset_from_directory(
        os.path.join(data_dir, "test"), shuffle=False, **common)
    class_names = train.class_names

    ac = tf.data.AUTOTUNE
    return (train.prefetch(ac), val.prefetch(ac), test.prefetch(ac), class_names)


def compute_class_weights(data_dir, class_names):
    """Inverse-frequency class weights from the train split (sklearn 'balanced' formula)."""
    counts = np.array([
        len(os.listdir(os.path.join(data_dir, "train", c))) for c in class_names
    ], dtype=np.float64)
    weights = counts.sum() / (len(class_names) * counts)
    return {i: float(w) for i, w in enumerate(weights)}


def build_model(num_classes):
    augmentation = keras.Sequential([
        layers.RandomFlip("horizontal"),
        layers.RandomRotation(0.15),
        layers.RandomZoom(0.20),
        layers.RandomTranslation(0.10, 0.10),
        layers.RandomContrast(0.20),
        layers.RandomBrightness(0.15),
    ], name="augmentation")

    # include_preprocessing=True (default): model expects RAW 0-255 input.
    base = keras.applications.MobileNetV3Large(
        input_shape=IMG_SIZE + (3,),
        include_top=False,
        weights="imagenet",
        include_preprocessing=True,
    )
    base.trainable = False

    inputs = keras.Input(shape=IMG_SIZE + (3,))
    x = augmentation(inputs)
    # !!! NO Rescaling / preprocess_input here - the base model does it !!!
    x = base(x, training=False)
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(DROPOUT)(x)
    outputs = layers.Dense(num_classes, activation="softmax")(x)
    return keras.Model(inputs, outputs), base


def compile_and_fit(model, train, val, lr, epochs, tag, class_weight):
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=lr),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    callbacks = [
        keras.callbacks.EarlyStopping(
            monitor="val_accuracy", patience=PATIENCE, restore_best_weights=True),
        keras.callbacks.ReduceLROnPlateau(
            monitor="val_loss", factor=0.5, patience=3, min_lr=1e-6),
        keras.callbacks.CSVLogger(f"{MODEL_NAME}_{tag}_history.csv"),
    ]
    return model.fit(train, validation_data=val, epochs=epochs, callbacks=callbacks,
                      class_weight=class_weight)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="dataset_v6")
    args = ap.parse_args()

    train, val, test, class_names = load_datasets(args.data)
    print(f"Classes ({len(class_names)}):", class_names)

    class_weight = compute_class_weights(args.data, class_names)
    print("Class weights (inverse frequency):")
    for i, name in enumerate(class_names):
        print(f"    {name:<16} {class_weight[i]:.3f}")

    with open(f"{MODEL_NAME}_classes.json", "w") as f:
        json.dump(class_names, f, indent=2)

    model, base = build_model(len(class_names))
    model.summary()

    print("\n########## STAGE 1: frozen base ##########")
    compile_and_fit(model, train, val, STAGE1_LR, STAGE1_EPOCHS, "stage1", class_weight)

    print("\n########## STAGE 2: fine-tuning ##########")
    base.trainable = True
    for layer in base.layers[:150]:      # V3Large is deeper; freeze more early layers
        layer.trainable = False
    compile_and_fit(model, train, val, STAGE2_LR, STAGE2_EPOCHS, "stage2", class_weight)

    print("\n########## TEST EVALUATION ##########")
    loss, acc = model.evaluate(test)
    print(f"Test accuracy: {acc:.4f}")

    y_true, y_pred = [], []
    for images, labels in test:
        probs = model.predict(images, verbose=0)
        y_true.extend(labels.numpy())
        y_pred.extend(np.argmax(probs, axis=1))

    try:
        from sklearn.metrics import classification_report, confusion_matrix
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        print(classification_report(y_true, y_pred, target_names=class_names, digits=3))
        with open(f"{MODEL_NAME}_classification_report.txt", "w") as f:
            f.write(f"Test accuracy: {acc:.4f}\n\n")
            f.write(classification_report(y_true, y_pred, target_names=class_names, digits=3))

        cm = confusion_matrix(y_true, y_pred)
        fig, ax = plt.subplots(figsize=(18, 15))
        im = ax.imshow(cm, cmap="Blues")
        ax.set_xticks(range(len(class_names)), class_names, rotation=90)
        ax.set_yticks(range(len(class_names)), class_names)
        for i in range(len(class_names)):
            for j in range(len(class_names)):
                ax.text(j, i, cm[i, j], ha="center", va="center", fontsize=7)
        ax.set_title("MobileNetV3Large Confusion Matrix (test set, dataset_v4)")
        ax.set_xlabel("Predicted label"); ax.set_ylabel("True label")
        fig.colorbar(im)
        fig.tight_layout()
        fig.savefig(f"{MODEL_NAME}_confusion_matrix.png", dpi=150)
    except ImportError:
        print("sklearn/matplotlib not installed - skipping report/matrix")

    model.save(f"{MODEL_NAME}_final.keras")
    print(f"\nSaved {MODEL_NAME}_final.keras")


if __name__ == "__main__":
    main()
