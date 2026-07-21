from datetime import datetime

from flask import Blueprint, jsonify, request
from pymongo.errors import PyMongoError

import state

bp = Blueprint("logs", __name__)


@bp.post("/log/scan")
def log_scan():
    err = state._db_required()
    if err:
        return err

    data = request.get_json() or {}
    try:
        state.db.scan_logs.insert_one({
            "child_id": data.get("child_id"),
            "english_key": data.get("english_key"),
            "confidence": data.get("confidence"),
            "mode": data.get("mode"),
            "created_at": datetime.utcnow(),
        })
        return jsonify({"status": "ok"})
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


@bp.post("/log/quiz")
def log_quiz():
    err = state._db_required()
    if err:
        return err

    data = request.get_json() or {}
    try:
        state.db.quiz_logs.insert_one({
            "child_id": data.get("child_id"),
            "english_key": data.get("english_key"),
            "correct": data.get("correct"),
            "created_at": datetime.utcnow(),
        })
        return jsonify({"status": "ok"})
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


@bp.post("/log/speech")
def log_speech():
    err = state._db_required()
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
        state.db.speech_logs.insert_one({
            "child_id": child_id,
            "english_key": english_key,
            "language": language,
            "correct": correct,
            "activity_type": "speech_practice",
            "created_at": datetime.utcnow(),
        })

        # Combined mastery: quiz + speech attempts
        quiz_total = state.db.quiz_logs.count_documents({
            "child_id": child_id,
            "english_key": english_key,
        })
        speech_total = state.db.speech_logs.count_documents({
            "child_id": child_id,
            "english_key": english_key,
        })
        quiz_correct = state.db.quiz_logs.count_documents({
            "child_id": child_id,
            "english_key": english_key,
            "correct": True,
        })
        speech_correct = state.db.speech_logs.count_documents({
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

        state.db.children.update_one(
            {"child_id": child_id},
            {"$set": {f"mastery.{english_key}": mastered}},
        )
        return jsonify({"logged": True, "mastered": mastered})
    except PyMongoError as e:
        return jsonify({"status": "error", "message": str(e)}), 500
