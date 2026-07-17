"""Loads the trained MobileNetV3Large VocabScan model.

Why this exists (instead of a plain ``tf.keras.models.load_model``):

The model was trained and saved with Keras 2.15 (see ``train_mobilenetv3_v3data.py``).
On this machine (Python 3.12) only TensorFlow 2.16+ / Keras 3 is installable, and
even the ``tf-keras`` 2.21 legacy shim cannot deserialize the Keras 2.15 ``.keras``
archive: its ``config.json`` uses semantic layer names ("Conv",
"expanded_conv/depthwise", ...) while ``model.weights.h5`` keys the arrays by
generic names ("conv2d", "batch_normalization_N", ...). The normal loader maps by
name, finds nothing for the nested base model, and fails with
"Layer 'Conv' expected 1 variables, but received 0 variables during loading".

Workaround: rebuild the exact architecture from the training script, then copy the
trained weights across. The two naming schemes are bridged by walking the archive's
``config.json`` in topological order and regenerating Keras' generic layer names
with the same per-class counters Keras uses. Weights are assigned positionally
(same architecture => same layer order) and validated by shape via ``set_weights``.
"""

import io
import json
import re
import zipfile

import h5py
from tensorflow import keras
from tensorflow.keras import layers

IMG_SIZE = (224, 224)
DROPOUT = 0.4


def _to_snake(name):
    """Reproduce Keras' default class-name -> layer-name conversion."""
    s = re.sub(r"(.)([A-Z][a-z0-9]+)", r"\1_\2", name)
    return re.sub(r"([a-z])([A-Z])", r"\1_\2", s).lower()


def build_model(num_classes):
    """Recreate the architecture from train_mobilenetv3_v3data.py (build_model)."""
    augmentation = keras.Sequential([
        layers.RandomFlip("horizontal"),
        layers.RandomRotation(0.15),
        layers.RandomZoom(0.20),
        layers.RandomTranslation(0.10, 0.10),
        layers.RandomContrast(0.20),
        layers.RandomBrightness(0.15),
    ], name="augmentation")

    base = keras.applications.MobileNetV3Large(
        input_shape=IMG_SIZE + (3,),
        include_top=False,
        weights=None,
        include_preprocessing=True,
    )

    inputs = keras.Input(shape=IMG_SIZE + (3,))
    x = augmentation(inputs)
    x = base(x, training=False)
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(DROPOUT)(x)
    outputs = layers.Dense(num_classes, activation="softmax")(x)
    return keras.Model(inputs, outputs), base


def load_trained_model(model_path, num_classes):
    """Build the architecture and load trained weights from the .keras archive."""
    model, base = build_model(num_classes)

    with zipfile.ZipFile(model_path) as z:
        weights_bytes = z.read("model.weights.h5")
        config = json.loads(z.read("config.json"))

    # Regenerate the generic layer names Keras assigned to the nested base model,
    # in the same topological order as config.json lists them.
    base_cfg = next(
        l for l in config["config"]["layers"]
        if l["class_name"] in ("Functional", "Model")
    )
    counters = {}
    generic_names = []
    for layer_cfg in base_cfg["config"]["layers"]:
        stem = _to_snake(layer_cfg["class_name"])
        idx = counters.get(stem, 0)
        counters[stem] = idx + 1
        generic_names.append(stem if idx == 0 else f"{stem}_{idx}")

    with h5py.File(io.BytesIO(weights_bytes), "r") as f:
        base_groups = f["layers"]["functional"]["layers"]
        for gname, layer in zip(generic_names, base.layers):
            if not layer.get_weights():
                continue
            vars = base_groups[gname]["vars"]
            arrays = [vars[str(i)][()] for i in range(len(vars.keys()))]
            layer.set_weights(arrays)  # raises on any shape/count mismatch

        dense_vars = f["layers"]["dense"]["vars"]
        model.layers[-1].set_weights(
            [dense_vars["0"][()], dense_vars["1"][()]]
        )

    return model
