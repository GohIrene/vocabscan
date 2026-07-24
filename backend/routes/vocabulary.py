import io
import time

import numpy as np
from flask import Blueprint, jsonify, request
from PIL import Image
from pymongo.errors import PyMongoError

import state
import vocab
from time_utils import _clean

bp = Blueprint("vocabulary", __name__)

# Mirrors the frontend's own allow-list (image_upload_utils.dart). HEIC/HEIF —
# the default photo format on iPhone — can't be decoded by a browser <img>
# element either, so the frontend already rejects it before upload; this is
# the backstop for a direct API call or a spoofed content-type that skips
# that check.
_ALLOWED_IMAGE_FORMATS = {"JPEG", "PNG", "WEBP"}

# Mirrors the frontend's kMaxImageBytes.
_MAX_UPLOAD_BYTES = 8 * 1024 * 1024


@bp.get("/vocabulary/<english_key>")
def get_vocabulary(english_key):
    if state.db is not None:
        try:
            doc = state.db.vocab.find_one({"english_key": english_key})
            if doc:
                cleaned = _clean(doc)
                cleaned["audio"] = vocab._audio_urls(english_key)
                return jsonify(cleaned)
        except PyMongoError as e:
            print(f"MongoDB query failed, falling back to in-memory: {e}")

    item = vocab.VOCABULARY.get(english_key)
    if item is None:
        return jsonify({"error": "Vocabulary item not found", "english_key": english_key}), 404
    return jsonify({"english_key": english_key, **item, "audio": vocab._audio_urls(english_key)})


@bp.post("/predict-mock")
def predict_mock():
    english_key = "book"
    return jsonify({
        "english_key": english_key,
        "confidence": 0.95,
        "english_word": "Book",
        "malay_word": "Buku",
        "chinese_word": "书",
        "audio": vocab._audio_urls(english_key),
    })


@bp.post("/predict")
def predict():
    if state.model is None:
        return jsonify({
            "success": False,
            "reason": "error",
            "message": "Model not loaded",
        })

    # Flutter posts the image under "image"; the curl test uses "file".
    file = request.files.get("image") or request.files.get("file")
    if file is None:
        return jsonify({
            "success": False,
            "reason": "error",
            "message": "No image file provided",
        })

    try:
        raw = file.read()
        if len(raw) > _MAX_UPLOAD_BYTES:
            return jsonify({
                "success": False,
                "reason": "file_too_large",
                "message": "That photo is too large — please choose one under 8MB.",
            })

        start = time.perf_counter()

        try:
            opened = Image.open(io.BytesIO(raw))
            image_format = opened.format
        except Exception:
            image_format = None

        if image_format not in _ALLOWED_IMAGE_FORMATS:
            return jsonify({
                "success": False,
                "reason": "unsupported_format",
                "message": "Please upload a JPEG, PNG, or WEBP photo.",
            })

        img = opened.convert("RGB").resize((224, 224))
        # Raw 0-255 pixels; MobileNetV3 has include_preprocessing=True built in.
        arr = np.expand_dims(np.array(img, dtype=np.float32), axis=0)  # (1, 224, 224, 3)

        preds = state.model.predict(arr, verbose=0)[0]
        idx = int(np.argmax(preds))
        confidence = float(preds[idx])
        inference_time_ms = round((time.perf_counter() - start) * 1000, 1)

        if confidence < state.CONFIDENCE_THRESHOLD:
            return jsonify({
                "success": False,
                "reason": "low_confidence",
                "confidence": confidence,
                "inference_time_ms": inference_time_ms,
            })

        english_key = state.class_names[idx]
        vocab_item = vocab._resolve_vocab(english_key)
        return jsonify({
            "success": True,
            "predicted_class": english_key,
            "english_key": english_key,
            "confidence": confidence,
            "inference_time_ms": inference_time_ms,
            "audio": vocab._audio_urls(english_key),
            **vocab_item,
        })
    except Exception as e:
        return jsonify({
            "success": False,
            "reason": "error",
            "message": str(e),
        })
