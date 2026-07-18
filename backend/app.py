from flask import Flask, jsonify, request
from flask_cors import CORS
from pymongo import MongoClient
from pymongo.errors import PyMongoError
from werkzeug.security import generate_password_hash, check_password_hash
import uuid
import os
import io
import json
import time
from datetime import datetime

# The model was trained/saved with Keras 2. TensorFlow 2.16+ bundles Keras 3,
# which cannot deserialize the Keras 2 format, so route tf.keras through the
# legacy tf-keras package. Must be set before importing tensorflow/keras.
os.environ.setdefault("TF_USE_LEGACY_KERAS", "1")

import numpy as np
from PIL import Image
from model_loader import load_trained_model

app = Flask(__name__)
app.json.ensure_ascii = False
CORS(app)

# ---------------------------------------------------------------------------
# Model loading (once at startup)
# ---------------------------------------------------------------------------

_BASE_DIR = os.path.dirname(os.path.abspath(__file__))
_MODEL_PATH = os.path.join(_BASE_DIR, "mobilenetv3_final.keras")
_CLASSES_PATH = os.path.join(_BASE_DIR, "mobilenetv3_classes.json")

CONFIDENCE_THRESHOLD = 0.6

model = None
class_names = []
try:
    with open(_CLASSES_PATH, "r", encoding="utf-8") as f:
        class_names = json.load(f)
    model = load_trained_model(_MODEL_PATH, len(class_names))
    print(f"Loaded model with {len(class_names)} classes.")
except Exception as e:
    print(f"WARNING: Could not load model: {e}")

VOCABULARY = {
    "apple": {"english_word": "Apple", "malay_word": "Epal", "chinese_word": "苹果"},
    "backpack": {"english_word": "Backpack", "malay_word": "Beg Galas", "chinese_word": "书包"},
    "ball": {"english_word": "Ball", "malay_word": "Bola", "chinese_word": "球"},
    "banana": {"english_word": "Banana", "malay_word": "Pisang", "chinese_word": "香蕉"},
    "book": {"english_word": "Book", "malay_word": "Buku", "chinese_word": "书"},
    "bottle": {"english_word": "Bottle", "malay_word": "Botol", "chinese_word": "瓶子"},
    "bowl": {"english_word": "Bowl", "malay_word": "Mangkuk", "chinese_word": "碗"},
    "bread": {"english_word": "Bread", "malay_word": "Roti", "chinese_word": "面包"},
    "chair": {"english_word": "Chair", "malay_word": "Kerusi", "chinese_word": "椅子"},
    "clock": {"english_word": "Clock", "malay_word": "Jam", "chinese_word": "时钟"},
    "cup": {"english_word": "Cup", "malay_word": "Cawan", "chinese_word": "杯子"},
    "fork": {"english_word": "Fork", "malay_word": "Garpu", "chinese_word": "叉子"},
    "glasses": {"english_word": "Glasses", "malay_word": "Cermin Mata", "chinese_word": "眼镜"},
    "keyboard": {"english_word": "Keyboard", "malay_word": "Papan Kekunci", "chinese_word": "键盘"},
    "knife": {"english_word": "Knife", "malay_word": "Pisau", "chinese_word": "刀"},
    "lamp": {"english_word": "Lamp", "malay_word": "Lampu", "chinese_word": "灯"},
    "laptop": {"english_word": "Laptop", "malay_word": "Komputer Riba", "chinese_word": "笔记本电脑"},
    "mobile_phone": {"english_word": "Mobile Phone", "malay_word": "Telefon Bimbit", "chinese_word": "手机"},
    "orange": {"english_word": "Orange", "malay_word": "Oren", "chinese_word": "橙"},
    "pen": {"english_word": "Pen", "malay_word": "Pen", "chinese_word": "钢笔"},
    "plate": {"english_word": "Plate", "malay_word": "Pinggan", "chinese_word": "盘子"},
    "remote_control": {"english_word": "Remote Control", "malay_word": "Alat Kawalan Jauh", "chinese_word": "遥控器"},
    "ruler": {"english_word": "Ruler", "malay_word": "Pembaris", "chinese_word": "尺子"},
    "scissors": {"english_word": "Scissors", "malay_word": "Gunting", "chinese_word": "剪刀"},
    "shoe": {"english_word": "Shoe", "malay_word": "Kasut", "chinese_word": "鞋子"},
    "spoon": {"english_word": "Spoon", "malay_word": "Sudu", "chinese_word": "勺子"},
    "table": {"english_word": "Table", "malay_word": "Meja", "chinese_word": "桌子"},
    "teddy_bear": {"english_word": "Teddy Bear", "malay_word": "Teddy Bear", "chinese_word": "泰迪熊"},
    "toothbrush": {"english_word": "Toothbrush", "malay_word": "Berus Gigi", "chinese_word": "牙刷"},
    "umbrella": {"english_word": "Umbrella", "malay_word": "Payung", "chinese_word": "雨伞"},
}

db = None
try:
    _client = MongoClient("mongodb://127.0.0.1:27017", serverSelectionTimeoutMS=3000)
    _client.admin.command("ping")
    db = _client["vocabscan"]
    print("Connected to MongoDB successfully.")
except Exception as e:
    print(f"MongoDB connection failed: {e}")


def _db_required():
    """Return a 503 response tuple when db is unavailable, or None if it is."""
    if db is None:
        return jsonify({"status": "error", "message": "Database unavailable"}), 503
    return None


def _clean(doc):
    """Strip _id and convert datetime values to ISO strings."""
    if doc is None:
        return None
    result = {}
    for k, v in doc.items():
        if k == "_id":
            continue
        result[k] = v.isoformat() if isinstance(v, datetime) else v
    return result


# ---------------------------------------------------------------------------
# Existing endpoints
# ---------------------------------------------------------------------------

@app.get("/health")
def health_check():
    return jsonify({"status": "ok", "service": "VocabScan Flask API"})


def _audio_urls(english_key):
    return {
        "en": f"/static/audio/{english_key}_en.mp3",
        "ms": f"/static/audio/{english_key}_ms.mp3",
        "zh": f"/static/audio/{english_key}_zh.mp3",
    }


@app.get("/vocabulary/<english_key>")
def get_vocabulary(english_key):
    if db is not None:
        try:
            doc = db.vocab.find_one({"english_key": english_key})
            if doc:
                cleaned = _clean(doc)
                cleaned["audio"] = _audio_urls(english_key)
                return jsonify(cleaned)
        except PyMongoError as e:
            print(f"MongoDB query failed, falling back to in-memory: {e}")

    item = VOCABULARY.get(english_key)
    if item is None:
        return jsonify({"error": "Vocabulary item not found", "english_key": english_key}), 404
    return jsonify({"english_key": english_key, **item, "audio": _audio_urls(english_key)})


@app.post("/predict-mock")
def predict_mock():
    english_key = "book"
    return jsonify({
        "english_key": english_key,
        "confidence": 0.95,
        "english_word": "Book",
        "malay_word": "Buku",
        "chinese_word": "书",
        "audio": _audio_urls(english_key),
    })


def _resolve_vocab(english_key):
    """Look up a word's translations, DB-first with the in-memory fallback."""
    if db is not None:
        try:
            doc = db.vocab.find_one({"english_key": english_key})
            if doc:
                return {
                    "english_word": doc.get("english_word", english_key),
                    "malay_word": doc.get("malay_word", ""),
                    "chinese_word": doc.get("chinese_word", ""),
                }
        except PyMongoError as e:
            print(f"MongoDB vocab lookup failed, falling back to in-memory: {e}")

    item = VOCABULARY.get(english_key)
    if item is None:
        return {"english_word": english_key, "malay_word": "", "chinese_word": ""}
    return item


@app.post("/predict")
def predict():
    if model is None:
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
        start = time.perf_counter()

        img = Image.open(io.BytesIO(file.read())).convert("RGB").resize((224, 224))
        # Raw 0-255 pixels; MobileNetV3 has include_preprocessing=True built in.
        arr = np.expand_dims(np.array(img, dtype=np.float32), axis=0)  # (1, 224, 224, 3)

        preds = model.predict(arr, verbose=0)[0]
        idx = int(np.argmax(preds))
        confidence = float(preds[idx])
        inference_time_ms = round((time.perf_counter() - start) * 1000, 1)

        if confidence < CONFIDENCE_THRESHOLD:
            return jsonify({
                "success": False,
                "reason": "low_confidence",
                "confidence": confidence,
                "inference_time_ms": inference_time_ms,
            })

        english_key = class_names[idx]
        vocab = _resolve_vocab(english_key)
        return jsonify({
            "success": True,
            "predicted_class": english_key,
            "english_key": english_key,
            "confidence": confidence,
            "inference_time_ms": inference_time_ms,
            "audio": _audio_urls(english_key),
            **vocab,
        })
    except Exception as e:
        return jsonify({
            "success": False,
            "reason": "error",
            "message": str(e),
        })


# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------

@app.post("/auth/register")
def register():
    err = _db_required()
    if err:
        return err

    data = request.get_json() or {}
    username = (data.get("username") or "").strip()
    pin = str(data.get("pin") or "")
    role = data.get("role") or ""

    if not username:
        return jsonify({"status": "error", "message": "Username is required"}), 400
    if not pin.isdigit() or not (4 <= len(pin) <= 6):
        return jsonify({"status": "error", "message": "PIN must be 4-6 digits"}), 400
    if role not in ("parent", "teacher"):
        return jsonify({"status": "error", "message": "Role must be 'parent' or 'teacher'"}), 400

    try:
        if db.users.find_one({"username": username}):
            return jsonify({"status": "error", "message": "Username already taken"}), 409

        user_id = str(uuid.uuid4())
        db.users.insert_one({
            "user_id": user_id,
            "username": username,
            "pin_hash": generate_password_hash(pin),
            "role": role,
            "created_at": datetime.utcnow(),
        })
        return jsonify({"status": "ok", "user_id": user_id, "username": username, "role": role}), 201
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


@app.post("/auth/login")
def login():
    err = _db_required()
    if err:
        return err

    data = request.get_json() or {}
    username = (data.get("username") or "").strip()
    pin = str(data.get("pin") or "")

    try:
        user = db.users.find_one({"username": username})
        if not user or not check_password_hash(user["pin_hash"], pin):
            return jsonify({"status": "error", "message": "Invalid username or PIN"}), 401
        return jsonify({"status": "ok", "user_id": user["user_id"], "username": user["username"], "role": user["role"]})
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


# ---------------------------------------------------------------------------
# Children
# ---------------------------------------------------------------------------

@app.post("/children")
def add_child():
    err = _db_required()
    if err:
        return err

    data = request.get_json() or {}
    parent_id = (data.get("parent_id") or "").strip()
    nickname = (data.get("nickname") or "").strip()
    age = data.get("age")

    if not parent_id:
        return jsonify({"status": "error", "message": "parent_id is required"}), 400
    if not nickname:
        return jsonify({"status": "error", "message": "nickname is required"}), 400

    try:
        child_id = str(uuid.uuid4())
        db.children.insert_one({
            "child_id": child_id,
            "parent_id": parent_id,
            "nickname": nickname,
            "age": age,
            "created_at": datetime.utcnow(),
        })
        return jsonify({"status": "ok", "child_id": child_id, "nickname": nickname, "age": age}), 201
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


@app.get("/children/<parent_id>")
def get_children(parent_id):
    err = _db_required()
    if err:
        return err

    try:
        docs = list(db.children.find({"parent_id": parent_id}))
        return jsonify({"children": [_clean(d) for d in docs]})
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

@app.post("/log/scan")
def log_scan():
    err = _db_required()
    if err:
        return err

    data = request.get_json() or {}
    try:
        db.scan_logs.insert_one({
            "child_id": data.get("child_id"),
            "english_key": data.get("english_key"),
            "confidence": data.get("confidence"),
            "mode": data.get("mode"),
            "created_at": datetime.utcnow(),
        })
        return jsonify({"status": "ok"})
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


@app.post("/log/quiz")
def log_quiz():
    err = _db_required()
    if err:
        return err

    data = request.get_json() or {}
    try:
        db.quiz_logs.insert_one({
            "child_id": data.get("child_id"),
            "english_key": data.get("english_key"),
            "correct": data.get("correct"),
            "created_at": datetime.utcnow(),
        })
        return jsonify({"status": "ok"})
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


@app.post("/log/speech")
def log_speech():
    err = _db_required()
    if err:
        return err

    data = request.get_json() or {}
    child_id = data.get("child_id")
    english_key = data.get("english_key", "")
    language = data.get("language", "en")
    correct = bool(data.get("correct", False))

    if not child_id:
        return jsonify({"status": "error", "message": "child_id required"}), 400

    try:
        db.speech_logs.insert_one({
            "child_id": child_id,
            "english_key": english_key,
            "language": language,
            "correct": correct,
            "activity_type": "speech_practice",
            "created_at": datetime.utcnow(),
        })

        # Combined mastery: quiz + speech attempts
        quiz_total = db.quiz_logs.count_documents({
            "child_id": child_id,
            "english_key": english_key,
        })
        speech_total = db.speech_logs.count_documents({
            "child_id": child_id,
            "english_key": english_key,
        })
        quiz_correct = db.quiz_logs.count_documents({
            "child_id": child_id,
            "english_key": english_key,
            "correct": True,
        })
        speech_correct = db.speech_logs.count_documents({
            "child_id": child_id,
            "english_key": english_key,
            "correct": True,
        })

        combined_total = quiz_total + speech_total
        combined_correct = quiz_correct + speech_correct
        mastered = (
            combined_total >= 3 and
            (combined_correct / combined_total) >= 0.8
        )

        db.children.update_one(
            {"child_id": child_id},
            {"$set": {f"mastery.{english_key}": mastered}},
        )
        return jsonify({"logged": True, "mastered": mastered})
    except PyMongoError as e:
        return jsonify({"status": "error", "message": str(e)}), 500


# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

@app.get("/report/<child_id>")
def get_report(child_id):
    err = _db_required()
    if err:
        return err

    try:
        scan_logs = list(db.scan_logs.find({"child_id": child_id}))
        quiz_logs = list(db.quiz_logs.find({"child_id": child_id}))
        speech_logs = list(db.speech_logs.find({"child_id": child_id}))

        # Per-word scan counts
        scan_counts = {}
        for log in scan_logs:
            key = log["english_key"]
            scan_counts[key] = scan_counts.get(key, 0) + 1

        # Per-word quiz stats
        quiz_stats = {}
        for log in quiz_logs:
            key = log["english_key"]
            if key not in quiz_stats:
                quiz_stats[key] = {"attempts": 0, "correct": 0}
            quiz_stats[key]["attempts"] += 1
            if log.get("correct"):
                quiz_stats[key]["correct"] += 1

        # Per-word speech stats
        speech_stats = {}
        for log in speech_logs:
            key = log["english_key"]
            if key not in speech_stats:
                speech_stats[key] = {"attempts": 0, "correct": 0}
            speech_stats[key]["attempts"] += 1
            if log.get("correct"):
                speech_stats[key]["correct"] += 1

        # Build per-word breakdown
        all_keys = set(scan_counts.keys()) | set(quiz_stats.keys()) | set(speech_stats.keys())
        words = []
        for key in all_keys:
            attempts = quiz_stats.get(key, {}).get("attempts", 0)
            correct = quiz_stats.get(key, {}).get("correct", 0)
            accuracy = round(correct / attempts * 100, 1) if attempts > 0 else 0.0

            sp_attempts = speech_stats.get(key, {}).get("attempts", 0)
            sp_correct = speech_stats.get(key, {}).get("correct", 0)

            # Combined mastery: quiz + speech attempts (same logic as /log/speech)
            combined_total = attempts + sp_attempts
            combined_correct = correct + sp_correct
            mastered = combined_total >= 3 and (combined_correct / combined_total) >= 0.8

            words.append({
                "english_key": key,
                "scan_count": scan_counts.get(key, 0),
                "quiz_attempts": attempts,
                "quiz_correct": correct,
                "accuracy": accuracy,
                "speech_attempts": sp_attempts,
                "speech_correct": sp_correct,
                "mastery": "mastered" if mastered else "learning",
            })

        # Overall quiz accuracy
        total_attempts = sum(s["attempts"] for s in quiz_stats.values())
        total_correct = sum(s["correct"] for s in quiz_stats.values())
        quiz_accuracy = round(total_correct / total_attempts * 100, 1) if total_attempts > 0 else 0.0

        # Overall speech accuracy
        speech_attempts = sum(s["attempts"] for s in speech_stats.values())
        speech_correct = sum(s["correct"] for s in speech_stats.values())
        speech_accuracy = round(speech_correct / speech_attempts * 100, 1) if speech_attempts > 0 else 0.0

        # Bottom 3 words by accuracy (words with at least 1 quiz attempt)
        words_with_attempts = [w for w in words if w["quiz_attempts"] >= 1]
        common_mistakes = sorted(words_with_attempts, key=lambda w: w["accuracy"])[:3]

        # Last 10 scan logs sorted by created_at descending
        recent_docs = sorted(scan_logs, key=lambda d: d.get("created_at", datetime.min), reverse=True)[:10]

        return jsonify({
            "child_id": child_id,
            "total_words": len(scan_counts),
            "total_scans": len(scan_logs),
            "quiz_accuracy": quiz_accuracy,
            "speech_attempts": speech_attempts,
            "speech_correct": speech_correct,
            "speech_accuracy": speech_accuracy,
            "words": words,
            "common_mistakes": common_mistakes,
            "recent_activity": [_clean(d) for d in recent_docs],
        })
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


if __name__ == "__main__":
    app.run(debug=True)
