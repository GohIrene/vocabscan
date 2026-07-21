from flask import Flask, jsonify, request
from flask_cors import CORS
from flask_socketio import SocketIO, join_room, emit
from pymongo import MongoClient
from pymongo.errors import PyMongoError
from werkzeug.security import generate_password_hash, check_password_hash
import uuid
import os
import io
import json
import time
import random
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
socketio = SocketIO(app, cors_allowed_origins='*', async_mode='threading')

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


# ---------------------------------------------------------------------------
# Startup: indexes + static vocab cache
# ---------------------------------------------------------------------------

def _ensure_indexes():
    """Create an index on every field the app filters/sorts by. Each index is
    created independently so one failure (e.g. a pre-existing duplicate) never
    blocks the rest. Idempotent — safe to run on every boot."""
    if db is None:
        return
    specs = [
        (db.users, "username", {"unique": True}),
        (db.children, "parent_id", {}),
        (db.scan_logs, "child_id", {}),
        (db.quiz_logs, [("child_id", 1), ("english_key", 1)], {}),
        (db.speech_logs, [("child_id", 1), ("english_key", 1)], {}),
        (db.vocab, "english_key", {"unique": True}),
        (db.class_sessions, "code", {}),
        (db.class_sessions, "teacher_id", {}),
        (db.class_sessions, "students.sid", {}),
    ]
    created = 0
    for coll, keys, opts in specs:
        try:
            coll.create_index(keys, **opts)
            created += 1
        except PyMongoError as e:
            print(f"Index on {keys} skipped: {e}")
    print(f"MongoDB indexes ensured ({created}/{len(specs)}).")


# The vocab collection is 30 rows that never change at runtime, yet it was
# re-read from Mongo on every scan and three times per quiz. Load it once at
# startup into a dict keyed by english_key; fall back to the bundled VOCABULARY
# map when the DB is empty/unavailable. _resolve_vocab and _random_distractors
# read from this cache instead of hitting Mongo per request.
_VOCAB_CACHE = {}


def _load_vocab_cache():
    """Populate _VOCAB_CACHE from Mongo (DB-first), then fill any gaps from the
    in-memory VOCABULARY so recognition/quizzes still work without Mongo."""
    global _VOCAB_CACHE
    cache = {}
    if db is not None:
        try:
            for doc in db.vocab.find():
                key = doc.get("english_key")
                if key:
                    cache[key] = {
                        "english_word": doc.get("english_word", key),
                        "malay_word": doc.get("malay_word", ""),
                        "chinese_word": doc.get("chinese_word", ""),
                    }
        except PyMongoError as e:
            print(f"Vocab cache load failed, using in-memory fallback: {e}")
    for key, item in VOCABULARY.items():
        cache.setdefault(key, item)
    _VOCAB_CACHE = cache
    print(f"Vocab cache ready: {len(_VOCAB_CACHE)} words.")


_ensure_indexes()
_load_vocab_cache()


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
    """Look up a word's translations from the in-memory vocab cache (loaded once
    at startup, DB-first; see _load_vocab_cache)."""
    item = _VOCAB_CACHE.get(english_key)
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


@app.post("/auth/verify-pin")
def verify_pin():
    """Re-checks a PIN for an already-logged-in session, without issuing a
    fresh login. Used to gate sensitive parent actions (e.g. Add Child) mid-
    session, since a child may be holding the device after the parent logged in."""
    err = _db_required()
    if err:
        return err

    data = request.get_json() or {}
    username = (data.get("username") or "").strip()
    pin = str(data.get("pin") or "")

    try:
        user = db.users.find_one({"username": username})
        if not user or not check_password_hash(user["pin_hash"], pin):
            return jsonify({"status": "error", "message": "Incorrect PIN"}), 401
        return jsonify({"status": "ok"})
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
# Class Code Mode (WebSocket / real-time)
# REST bootstrap + Socket.IO events. Added ALONGSIDE the REST API; MongoDB
# `class_sessions` is the source of truth so sessions survive a restart.
# ---------------------------------------------------------------------------

# 6-char code alphabet, excluding ambiguous 0/O/1/I.
_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

# The three CP1 question patterns, mirroring quiz_practice_screen.dart.
_QUESTION_PATTERNS = ("en_ms", "en_zh", "zh_en")


def _generate_code():
    """Return a 6-char code not currently used by any non-ended session."""
    while True:
        code = "".join(random.choice(_CODE_ALPHABET) for _ in range(6))
        if db is None:
            return code
        existing = db.class_sessions.find_one({"code": code, "status": {"$ne": "ended"}})
        if existing is None:
            return code


def _random_distractors(field, answer, english_key, n):
    """Pick up to n distinct `field` values from the in-memory vocab cache,
    excluding the answer and the word itself. Never hardcoded word lists."""
    values = []
    seen = set()
    for key, item in _VOCAB_CACHE.items():
        if key == english_key:
            continue
        v = item.get(field)
        if v and v != answer and v not in seen:
            seen.add(v)
            values.append(v)
    random.shuffle(values)
    return values[:n]


def _build_quiz(english_key):
    """Build one MCQ server-side. Returns the full quiz dict (incl. answer)."""
    vocab = _resolve_vocab(english_key)
    eng = vocab.get("english_word") or english_key
    mal = vocab.get("malay_word") or ""
    chi = vocab.get("chinese_word") or ""

    pattern = random.choice(_QUESTION_PATTERNS)
    if pattern == "en_ms":
        prompt = f'What is "{eng}" in Malay?'
        answer = mal
        field = "malay_word"
    elif pattern == "en_zh":
        prompt = f'What is "{eng}" in Chinese?'
        answer = chi
        field = "chinese_word"
    else:  # zh_en
        prompt = f'Which English word matches "{chi}"?'
        answer = eng
        field = "english_word"

    options = _random_distractors(field, answer, english_key, 3) + [answer]
    random.shuffle(options)

    return {
        "quiz_id": str(uuid.uuid4()),
        "english_key": english_key,
        "prompt": prompt,
        "options": options,
        "correct_answer": answer,
        "pushed_at": datetime.utcnow(),
    }


@app.get("/quiz/distractors")
def quiz_distractors():
    """Real vocab-based wrong answers for a quiz question — shared by Home
    mode (quiz_practice_screen.dart) and Class Code (_build_quiz above), so
    neither has to hardcode a fixed wrong-answer list."""
    english_key = request.args.get("english_key", "")
    field = request.args.get("field", "")
    answer = request.args.get("answer", "")
    n = request.args.get("n", "3")

    if field not in ("malay_word", "chinese_word", "english_word"):
        return jsonify({"status": "error", "message": "Invalid field"}), 400
    if not english_key or not answer:
        return jsonify({"status": "error", "message": "english_key and answer are required"}), 400
    try:
        n = max(1, min(int(n), 10))
    except ValueError:
        n = 3

    options = _random_distractors(field, answer, english_key, n)
    return jsonify({"distractors": options})


@app.get("/quiz/questions")
def quiz_questions():
    """All three MCQ distractor sets for one scanned word in a single request,
    so the Home-mode quiz screen makes one round trip instead of three. Built
    from the in-memory vocab cache (no per-request DB scans). The per-field
    `/quiz/distractors` endpoint above is kept for backward compatibility."""
    english_key = request.args.get("english_key", "")
    n = request.args.get("n", "3")
    if not english_key:
        return jsonify({"status": "error", "message": "english_key is required"}), 400
    try:
        n = max(1, min(int(n), 10))
    except ValueError:
        n = 3

    vocab = _resolve_vocab(english_key)
    mal = vocab.get("malay_word", "")
    chi = vocab.get("chinese_word", "")
    eng = vocab.get("english_word", "")
    return jsonify({
        "english_key": english_key,
        "english_word": eng,
        "malay_word": mal,
        "chinese_word": chi,
        "distractors": {
            "malay_word": _random_distractors("malay_word", mal, english_key, n),
            "chinese_word": _random_distractors("chinese_word", chi, english_key, n),
            "english_word": _random_distractors("english_word", eng, english_key, n),
        },
    })


def _count_connected(session):
    return sum(1 for s in session.get("students", []) if s.get("connected"))


def _count_answered(session):
    return sum(
        1 for s in session.get("students", [])
        if s.get("connected") and s.get("answered_current")
    )


@app.post("/class/create")
def class_create():
    err = _db_required()
    if err:
        return err

    data = request.get_json() or {}
    teacher_id = (data.get("teacher_id") or "").strip()
    if not teacher_id:
        return jsonify({"status": "error", "message": "teacher_id is required"}), 400

    try:
        code = _generate_code()
        session_id = str(uuid.uuid4())
        db.class_sessions.insert_one({
            "session_id": session_id,
            "code": code,
            "teacher_id": teacher_id,
            "status": "waiting",
            "students": [],
            "current_quiz": None,
            "quiz_history": [],
            "created_at": datetime.utcnow(),
            "ended_at": None,
        })
        return jsonify({"session_id": session_id, "code": code}), 201
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


@app.post("/class/join")
def class_join():
    err = _db_required()
    if err:
        return err

    data = request.get_json() or {}
    code = (data.get("code") or "").strip().upper()
    nickname = (data.get("nickname") or "").strip()
    if not code:
        return jsonify({"status": "error", "message": "Class code is required"}), 400
    if not nickname:
        return jsonify({"status": "error", "message": "Nickname is required"}), 400

    try:
        session = db.class_sessions.find_one({"code": code, "status": {"$ne": "ended"}})
        if session is None:
            return jsonify({"status": "error", "message": "Class not found or already ended"}), 404

        for s in session.get("students", []):
            if s.get("nickname") == nickname:
                if s.get("connected"):
                    return jsonify({"status": "error", "message": "That name is already taken in this class"}), 409
                # Exists but disconnected → this is a rejoin, allow it.
                return jsonify({"session_id": session["session_id"], "joined": True})

        db.class_sessions.update_one(
            {"session_id": session["session_id"]},
            {"$push": {"students": {
                "nickname": nickname,
                "score": 0,
                "answered_current": False,
                "connected": False,
            }}},
        )
        return jsonify({"session_id": session["session_id"], "joined": True})
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


@app.get("/class/sessions/<teacher_id>")
def class_sessions(teacher_id):
    """All Class Code sessions a teacher has run, newest first, each with its
    leaderboard and quiz count — real data for the teacher Class Reports screen."""
    err = _db_required()
    if err:
        return err

    def _iso(v):
        return v.isoformat() if isinstance(v, datetime) else v

    try:
        docs = list(db.class_sessions.find({"teacher_id": teacher_id}))
        docs.sort(key=lambda d: d.get("created_at") or datetime.min, reverse=True)

        sessions = []
        total_students = 0
        live_count = 0
        for d in docs:
            students = d.get("students", [])
            leaderboard = sorted(
                [{"nickname": s.get("nickname"), "score": s.get("score", 0)}
                 for s in students],
                key=lambda x: x["score"],
                reverse=True,
            )
            quiz_count = len(d.get("quiz_history", []))
            if d.get("current_quiz"):
                quiz_count += 1
            total_students += len(students)
            if d.get("status") != "ended":
                live_count += 1
            sessions.append({
                "session_id": d.get("session_id"),
                "code": d.get("code"),
                "status": d.get("status"),
                "created_at": _iso(d.get("created_at")),
                "ended_at": _iso(d.get("ended_at")),
                "student_count": len(students),
                "quiz_count": quiz_count,
                "leaderboard": leaderboard,
            })

        return jsonify({
            "teacher_id": teacher_id,
            "session_count": len(sessions),
            "total_students": total_students,
            "live_count": live_count,
            "sessions": sessions,
        })
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


# ── Socket.IO events ────────────────────────────────────────────────────────

@socketio.on("connect_session")
def on_connect_session(data):
    if db is None:
        return
    data = data or {}
    code = (data.get("code") or "").strip().upper()
    role = data.get("role")
    nickname = (data.get("nickname") or "").strip()

    try:
        session = db.class_sessions.find_one({"code": code, "status": {"$ne": "ended"}})
        if session is None:
            emit("session_error", {"message": "Class not found or ended"})
            return

        join_room(code)

        if role == "student" and nickname:
            db.class_sessions.update_one(
                {"session_id": session["session_id"], "students.nickname": nickname},
                {"$set": {"students.$.connected": True, "students.$.sid": request.sid}},
            )
            session = db.class_sessions.find_one({"session_id": session["session_id"]})

            # Reconnection contract: re-deliver a live quiz to this socket only if
            # this student hasn't answered it yet.
            quiz = session.get("current_quiz")
            if session.get("status") == "quiz" and quiz:
                me = next((s for s in session.get("students", []) if s.get("nickname") == nickname), None)
                if me and not me.get("answered_current"):
                    emit("new_quiz", {
                        "quiz_id": quiz["quiz_id"],
                        "prompt": quiz["prompt"],
                        "options": quiz["options"],
                    })

            emit(
                "student_joined",
                {"nickname": nickname, "student_count": _count_connected(session)},
                to=code,
            )
        else:
            # Teacher: sync current connected count to this socket only (no phantom join).
            emit("student_joined", {"nickname": None, "student_count": _count_connected(session)})
    except PyMongoError:
        emit("session_error", {"message": "Could not connect to the class. Please try again."})


@socketio.on("push_quiz")
def on_push_quiz(data):
    if db is None:
        return
    data = data or {}
    session_id = data.get("session_id")
    english_key = data.get("english_key")

    try:
        session = db.class_sessions.find_one({"session_id": session_id, "status": {"$ne": "ended"}})
        if session is None:
            emit("session_error", {"message": "Session not active"})
            return

        quiz = _build_quiz(english_key)
        update = {"$set": {
            "current_quiz": quiz,
            "status": "quiz",
            "students.$[].answered_current": False,
        }}
        # Archive the previously-live quiz so session reports can count every quiz
        # that was pushed, not just the final one (end_session archives the last).
        if session.get("current_quiz"):
            update["$push"] = {"quiz_history": session["current_quiz"]}
        db.class_sessions.update_one({"session_id": session_id}, update)
        emit(
            "new_quiz",
            {"quiz_id": quiz["quiz_id"], "prompt": quiz["prompt"], "options": quiz["options"]},
            to=session["code"],
        )
    except PyMongoError:
        # Teacher only — students never learned a quiz was coming.
        emit("session_error", {"message": "Could not send the quiz. Please try again."})


@socketio.on("submit_answer")
def on_submit_answer(data):
    if db is None:
        return
    data = data or {}
    session_id = data.get("session_id")
    nickname = data.get("nickname")
    quiz_id = data.get("quiz_id")
    chosen = data.get("chosen")

    try:
        session = db.class_sessions.find_one({"session_id": session_id})
        if session is None:
            return

        quiz = session.get("current_quiz")
        if not quiz or quiz.get("quiz_id") != quiz_id:
            emit("answer_rejected", {"reason": "stale"})
            return

        me = next((s for s in session.get("students", []) if s.get("nickname") == nickname), None)
        if me is None:
            return
        if me.get("answered_current"):
            emit("answer_rejected", {"reason": "already_answered"})
            return

        correct = chosen == quiz.get("correct_answer")
        update = {"$set": {"students.$.answered_current": True}}
        if correct:
            update["$inc"] = {"students.$.score": 1}
        db.class_sessions.update_one(
            {"session_id": session_id, "students.nickname": nickname},
            update,
        )
        session = db.class_sessions.find_one({"session_id": session_id})

        emit("answer_result", {"correct": correct, "correct_answer": quiz.get("correct_answer")})
        emit(
            "answer_received",
            {
                "nickname": nickname,
                "answered_count": _count_answered(session),
                "student_count": _count_connected(session),
            },
            to=session["code"],
        )
    except PyMongoError:
        emit("answer_rejected", {"reason": "server_error"})


@socketio.on("end_session")
def on_end_session(data):
    if db is None:
        return
    data = data or {}
    session_id = data.get("session_id")

    try:
        session = db.class_sessions.find_one({"session_id": session_id})
        if session is None:
            return

        leaderboard = sorted(
            [{"nickname": s.get("nickname"), "score": s.get("score", 0)}
             for s in session.get("students", [])],
            key=lambda x: x["score"],
            reverse=True,
        )

        update = {"$set": {"status": "ended", "ended_at": datetime.utcnow(), "current_quiz": None}}
        if session.get("current_quiz"):
            update["$push"] = {"quiz_history": session["current_quiz"]}
        db.class_sessions.update_one({"session_id": session_id}, update)

        emit("session_ended", {"leaderboard": leaderboard}, to=session["code"])
    except PyMongoError:
        # Teacher only — nothing was changed in Mongo, safe to just retry.
        emit("session_error", {"message": "Could not end the session. Please try again."})


@socketio.on("disconnect")
def on_disconnect():
    if db is None:
        return
    sid = request.sid
    try:
        session = db.class_sessions.find_one({"students.sid": sid})
        if session is None:
            return

        nickname = next(
            (s.get("nickname") for s in session.get("students", []) if s.get("sid") == sid),
            None,
        )
        db.class_sessions.update_one(
            {"session_id": session["session_id"], "students.sid": sid},
            {"$set": {"students.$.connected": False}},
        )
        session = db.class_sessions.find_one({"session_id": session["session_id"]})
        emit(
            "student_left",
            {"nickname": nickname, "student_count": _count_connected(session)},
            to=session["code"],
        )
    except PyMongoError as e:
        # The disconnecting client is already gone — no one to answer. Just
        # log it; their `connected` flag simply won't flip to False this one
        # time, which self-heals on their next reconnect or action.
        print(f"disconnect handler: Mongo error while marking sid {sid} disconnected: {e}")


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
    socketio.run(app, host='0.0.0.0', port=5000)
