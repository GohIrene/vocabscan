import uuid
from datetime import datetime

from flask import Blueprint, jsonify, request
from pymongo.errors import PyMongoError

import class_sessions as cs
import state
from time_utils import _local_day, _local_time

bp = Blueprint("class_code", __name__)


@bp.post("/class/create")
def class_create():
    err = state._db_required()
    if err:
        return err

    data = request.get_json() or {}
    teacher_id = (data.get("teacher_id") or "").strip()
    if not teacher_id:
        return jsonify({"status": "error", "message": "teacher_id is required"}), 400

    try:
        code = cs._generate_code()
        session_id = str(uuid.uuid4())
        state.db.class_sessions.insert_one({
            "session_id": session_id,
            "code": code,
            "teacher_id": teacher_id,
            "status": "waiting",
            "students": [],
            "current_quiz": None,
            "quiz_history": [],
            # Every distinct word pushed this session, so a summary quiz can be
            # built from exactly what the class actually covered.
            "word_keys": [],
            "summary_quiz": None,
            "summary_history": [],
            "created_at": datetime.utcnow(),
            "ended_at": None,
        })
        return jsonify({"session_id": session_id, "code": code}), 201
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


@bp.post("/class/join")
def class_join():
    err = state._db_required()
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
        session = state.db.class_sessions.find_one({"code": code, "status": {"$ne": "ended"}})
        if session is None:
            return jsonify({"status": "error", "message": "Class not found or already ended"}), 404

        for s in session.get("students", []):
            if s.get("nickname") == nickname:
                if s.get("connected"):
                    return jsonify({"status": "error", "message": "That name is already taken in this class"}), 409
                # Exists but disconnected → this is a rejoin, allow it.
                return jsonify({"session_id": session["session_id"], "joined": True})

        state.db.class_sessions.update_one(
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


@bp.get("/class/sessions/<teacher_id>")
def class_sessions(teacher_id):
    """All Class Code sessions a teacher has run, newest first, each with its
    leaderboard and quiz count — real data for the teacher Class Reports screen."""
    err = state._db_required()
    if err:
        return err

    def _iso(v):
        return v.isoformat() if isinstance(v, datetime) else v

    try:
        docs = list(state.db.class_sessions.find({"teacher_id": teacher_id}))
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
            # Summary quizzes carry many questions each; count every question so
            # the report reflects how much the class actually answered.
            summary_rounds = list(d.get("summary_history", []))
            if d.get("summary_quiz"):
                summary_rounds.append(d["summary_quiz"])
            quiz_count += sum(len(s.get("questions", [])) for s in summary_rounds)
            total_students += len(students)
            if d.get("status") != "ended":
                live_count += 1
            # Pre-formatted local (GMT+8) values so Class Reports can group by
            # day without the UI re-deriving the offset from a UTC timestamp.
            local_date, local_weekday = _local_day(d.get("created_at"))
            sessions.append({
                "session_id": d.get("session_id"),
                "code": d.get("code"),
                "status": d.get("status"),
                "created_at": _iso(d.get("created_at")),
                "ended_at": _iso(d.get("ended_at")),
                "local_date": local_date or "",
                "local_weekday": local_weekday or "",
                "local_time": _local_time(d.get("created_at")),
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
