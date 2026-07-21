import json
import os

from flask import Flask, jsonify
from flask_cors import CORS
from flask_socketio import SocketIO
from pymongo import MongoClient
from pymongo.errors import PyMongoError

# The model was trained/saved with Keras 2. TensorFlow 2.16+ bundles Keras 3,
# which cannot deserialize the Keras 2 format, so route tf.keras through the
# legacy tf-keras package. Must be set before importing tensorflow/keras.
os.environ.setdefault("TF_USE_LEGACY_KERAS", "1")

from model_loader import load_trained_model

app = Flask(__name__)
app.json.ensure_ascii = False
CORS(app)
socketio = SocketIO(app, cors_allowed_origins='*', async_mode='eventlet')

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

db = None
try:
    _client = MongoClient("mongodb://127.0.0.1:27017", serverSelectionTimeoutMS=3000)
    _client.admin.command("ping")
    db = _client["vocabscan"]
    print("Connected to MongoDB successfully.")
except Exception as e:
    print(f"MongoDB connection failed: {e}")


# ---------------------------------------------------------------------------
# Startup: indexes
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


_ensure_indexes()


def _db_required():
    """Return a 503 response tuple when db is unavailable, or None if it is."""
    if db is None:
        return jsonify({"status": "error", "message": "Database unavailable"}), 503
    return None
