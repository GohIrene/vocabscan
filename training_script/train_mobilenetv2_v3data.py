"""
VocabScan CP2 - MobileNetV2 training (dataset_v3, tuned hyperparameters)
=========================================================================
Option D tuning:
  Stage 1 (frozen base):  epochs=30, lr=1e-3, EarlyStopping patience=8
  Stage 2 (fine-tune):    epochs=20, lr=5e-5, EarlyStopping patience=8
  Dropout=0.4, Batch=16, stronger augmentation

NOTE: MobileNetV2 expects inputs in [-1, 1]. We handle this with an
explicit Rescaling layer INSIDE the model, so at inference time the
Flask backend can just feed raw 0-255 pixels.

Run on HPC:
    python train_mobilenetv2_v3data.py --data dataset_v3
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
MODEL_NAME = "mobilenetv2"


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


def build_model(num_classes):
    augmentation = keras.Sequential([
        layers.RandomFlip("horizontal"),
        layers.RandomRotation(0.15),
        layers.RandomZoom(0.20),
        layers.RandomTranslation(0.10, 0.10),
        layers.RandomContrast(0.20),
        layers.RandomBrightness(0.15),
    ], name="augmentation")

    base = keras.applications.MobileNetV2(
        input_shape=IMG_SIZE + (3,), include_top=False, weights="imagenet")
    base.trainable = False

    inputs = keras.Input(shape=IMG_SIZE + (3,))
    x = augmentation(inputs)
    x = layers.Rescaling(1.0 / 127.5, offset=-1.0)(x)   # [0,255] -> [-1,1]
    x = base(x, training=False)                          # BN stays in inference mode
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(DROPOUT)(x)
    outputs = layers.Dense(num_classes, activation="softmax")(x)
    return keras.Model(inputs, outputs), base


def compile_and_fit(model, train, val, lr, epochs, tag):
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
    return model.fit(train, validation_data=val, epochs=epochs, callbacks=callbacks)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="dataset_v3")
    args = ap.parse_args()

    train, val, test, class_names = load_datasets(args.data)
    print(f"Classes ({len(class_names)}):", class_names)

    with open(f"{MODEL_NAME}_classes.json", "w") as f:
        json.dump(class_names, f, indent=2)

    model, base = build_model(len(class_names))
    model.summary()

    # ---- Stage 1: frozen base ----
    print("\n########## STAGE 1: frozen base ##########")
    compile_and_fit(model, train, val, STAGE1_LR, STAGE1_EPOCHS, "stage1")

    # ---- Stage 2: fine-tune top of the base ----
    print("\n########## STAGE 2: fine-tuning ##########")
    base.trainable = True
    for layer in base.layers[:100]:      # keep early layers frozen
        layer.trainable = False
    compile_and_fit(model, train, val, STAGE2_LR, STAGE2_EPOCHS, "stage2")

    # ---- Evaluate ----
    print("\n########## TEST EVALUATION ##########")
    loss, acc = model.evaluate(test)
    print(f"Test accuracy: {acc:.4f}")

    # per-class report + confusion matrix
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
        ax.set_title("MobileNetV2 Confusion Matrix (test set, dataset_v3)")
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
