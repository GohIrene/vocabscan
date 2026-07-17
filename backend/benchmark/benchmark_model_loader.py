"""Loads the three Keras 2.15 VocabScan models for benchmarking.

Generalises the workaround in ``backend/model_loader.py`` to all three
architectures. See that module for the full explanation; in short, the saved
``.keras`` archives cannot be read by ``keras.models.load_model`` under either
Keras 3 or the tf-keras 2.21 shim, because ``config.json`` keys layers by
semantic name ("Conv1", "stem_conv", ...) while ``model.weights.h5`` keys them
generically ("conv2d", "batch_normalization_N", ...). Name-based mapping finds
nothing for the nested base and fails with "expected 1 variables, but received
0 variables during loading".

So: rebuild the architecture from the training script, then copy weights across
positionally. Same architecture => same layer order, and ``set_weights``
validates every shape.

All three models take RAW 0-255 pixels: MobileNetV2 has an explicit Rescaling
layer, MobileNetV3Large and EfficientNetV2S use include_preprocessing=True.
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


def _augmentation():
    return keras.Sequential([
        layers.RandomFlip("horizontal"),
        layers.RandomRotation(0.15),
        layers.RandomZoom(0.20),
        layers.RandomTranslation(0.10, 0.10),
        layers.RandomContrast(0.20),
        layers.RandomBrightness(0.15),
    ], name="augmentation")


def _head(inputs, x, num_classes):
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(DROPOUT)(x)
    outputs = layers.Dense(num_classes, activation="softmax")(x)
    return keras.Model(inputs, outputs)


def _build_mobilenetv2(num_classes):
    """Mirrors training_script/train_mobilenetv2_v6data.py build_model."""
    base = keras.applications.MobileNetV2(
        input_shape=IMG_SIZE + (3,), include_top=False, weights=None)
    inputs = keras.Input(shape=IMG_SIZE + (3,))
    x = _augmentation()(inputs)
    x = layers.Rescaling(1.0 / 127.5, offset=-1.0)(x)   # [0,255] -> [-1,1]
    x = base(x, training=False)
    return _head(inputs, x, num_classes), base


def _build_mobilenetv3(num_classes):
    """Mirrors training_script/train_mobilenetv3_v6data.py build_model."""
    base = keras.applications.MobileNetV3Large(
        input_shape=IMG_SIZE + (3,), include_top=False, weights=None,
        include_preprocessing=True)
    inputs = keras.Input(shape=IMG_SIZE + (3,))
    x = _augmentation()(inputs)
    x = base(x, training=False)
    return _head(inputs, x, num_classes), base


def _build_efficientnetv2s(num_classes):
    """Mirrors training_script/train_efficientnetv2s_v6data.py build_model."""
    base = keras.applications.EfficientNetV2S(
        input_shape=IMG_SIZE + (3,), include_top=False, weights=None,
        include_preprocessing=True)
    inputs = keras.Input(shape=IMG_SIZE + (3,))
    x = _augmentation()(inputs)
    x = base(x, training=False)
    return _head(inputs, x, num_classes), base


BUILDERS = {
    "mobilenetv2": _build_mobilenetv2,
    "mobilenetv3": _build_mobilenetv3,
    "efficientnetv2s": _build_efficientnetv2s,
}


def load_trained_model(model_path, arch, num_classes=30):
    """Rebuild `arch` and load the trained weights out of the .keras archive."""
    if arch not in BUILDERS:
        raise ValueError(f"Unknown arch {arch!r}; expected one of {list(BUILDERS)}")

    model, base = BUILDERS[arch](num_classes)

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

    if len(generic_names) != len(base.layers):
        raise ValueError(
            f"{arch}: archive lists {len(generic_names)} base layers but the "
            f"rebuilt model has {len(base.layers)} — architectures diverged."
        )

    with h5py.File(io.BytesIO(weights_bytes), "r") as f:
        base_groups = f["layers"]["functional"]["layers"]
        for gname, layer in zip(generic_names, base.layers):
            if not layer.get_weights():
                continue
            vars_grp = base_groups[gname]["vars"]
            arrays = [vars_grp[str(i)][()] for i in range(len(vars_grp.keys()))]
            layer.set_weights(arrays)  # raises on any shape/count mismatch

        dense_vars = f["layers"]["dense"]["vars"]
        model.layers[-1].set_weights([dense_vars["0"][()], dense_vars["1"][()]])

    return model
