"""POST /learning/complete — apply the rewards for one Child Adventure cycle.

Option A: the scan/quiz/speech logs stay authoritative for *what happened*,
written by the existing `/log/*` endpoints as the child moves through the
flow. This endpoint only reads the outcome and applies rewards. It writes to
`children`, `child_treasures` and `learning_completions`, and to no log
collection — nothing here is duplicated.

Idempotent by `completion_id`, which the client generates once per cycle. A
double-tapped Continue, a retried request or a refreshed reward screen all
replay the original result rather than awarding twice; the guarantee comes
from a unique index, not from a check-then-write.
"""

from datetime import datetime

from flask import Blueprint, jsonify, request
from pymongo.errors import DuplicateKeyError, PyMongoError

import child_progress as cp
import rewards
import state
import vocab
from child_profile import apply_child_defaults
from time_utils import _clean

bp = Blueprint("learning", __name__)


def _parse_speech(data):
    """Accept the structured shape, falling back to the flat one.

    The flow sends `speech: {...}`; the flatter `speech_attempted` /
    `speech_success` pair from the original spec still works so an older
    client isn't broken by this endpoint.
    """
    speech = data.get("speech")
    if isinstance(speech, dict):
        attempts = speech.get("attempts")
        return {
            "attempted": bool(speech.get("attempted", False)),
            "success": bool(speech.get("success", False)),
            "attempts": max(0, int(attempts)) if isinstance(attempts, int) else 0,
            "skipped": bool(speech.get("skipped", False)),
            # Per-language outcomes, recorded for the response only — the
            # authoritative record is already in speech_logs.
            "languages": [
                {"language": str(l.get("language") or ""),
                 "correct": bool(l.get("correct"))}
                for l in (speech.get("languages") or [])
                if isinstance(l, dict)
            ],
        }
    return {
        "attempted": bool(data.get("speech_attempted", False)),
        "success": bool(data.get("speech_success", False)),
        "attempts": 0,
        "skipped": False,
        "languages": [],
    }


def _parse_quiz(data):
    quiz = data.get("quiz")
    if isinstance(quiz, dict):
        raw_score, raw_total = quiz.get("score"), quiz.get("total")
        answers = [
            {"english_key": str(a.get("english_key") or ""),
             "correct": bool(a.get("correct"))}
            for a in (quiz.get("answers") or []) if isinstance(a, dict)
        ]
    else:
        raw_score, raw_total, answers = (data.get("quiz_score"),
                                         data.get("quiz_total"), [])
    try:
        total = max(0, int(raw_total or 0))
    except (TypeError, ValueError):
        total = 0
    try:
        # Clamped to the number asked, so a malformed score can't manufacture
        # a "perfect" quiz bonus.
        score = max(0, min(total, int(raw_score or 0)))
    except (TypeError, ValueError):
        score = 0
    return {"score": score, "total": total, "answers": answers}


@bp.post("/learning/complete")
def learning_complete():
    err = state._db_required()
    if err:
        return err

    data = request.get_json() or {}
    child_id = (data.get("child_id") or "").strip()
    english_key = (data.get("english_key") or "").strip()
    completion_id = (data.get("completion_id") or "").strip()

    if not child_id:
        return jsonify({"status": "error", "message": "child_id is required"}), 400
    if not english_key:
        return jsonify({"status": "error", "message": "english_key is required"}), 400
    if not completion_id:
        return jsonify({"status": "error",
                        "message": "completion_id is required"}), 400
    if not vocab._is_known(english_key):
        return jsonify({"status": "error",
                        "message": "Unknown word"}), 400

    try:
        raw = state.db.children.find_one({"child_id": child_id})
        if raw is None:
            return jsonify({"status": "error", "message": "Child not found"}), 404
        child = apply_child_defaults(_clean(raw))
        if not child.get("is_active"):
            return jsonify({"status": "error", "message": "Child not found"}), 404

        # Claim the completion first. If this id has been seen, the original
        # result is replayed and nothing is applied a second time.
        try:
            state.db.learning_completions.insert_one({
                "completion_id": completion_id,
                "child_id": child_id,
                "english_key": english_key,
                "created_at": datetime.utcnow(),
                "applied": False,
                "result": None,
            })
        except DuplicateKeyError:
            existing = state.db.learning_completions.find_one(
                {"completion_id": completion_id}) or {}
            stored = existing.get("result")
            if stored:
                return jsonify({**stored, "replayed": True})
            # Claimed but not yet finished — a genuinely concurrent duplicate.
            # Reporting rather than recomputing keeps the award single.
            return jsonify({
                "status": "error",
                "message": "That reward is still being saved",
                "replayed": True,
            }), 409

        speech = _parse_speech(data)
        quiz = _parse_quiz(data)

        # `raw` (not the serialised copy) so area_progress reads the stored map.
        merged = {**raw, **{k: v for k, v in child.items() if k not in raw}}
        payload, update = rewards.apply_cycle(
            state.db, merged, english_key, speech, quiz)

        state.db.children.update_one({"child_id": child_id}, {"$set": update})

        # Counts that the reward screen shows are read *after* the write, so
        # they include this cycle.
        payload["treasure_count"] = cp.treasure_count(state.db, child_id)
        payload["daily_mission"] = cp.daily_mission(state.db, child_id)
        after = state.db.children.find_one({"child_id": child_id}) or {}
        payload["achievement_count"] = cp.achievement_count(
            state.db, after, child_id)
        payload["achievement_total"] = len(cp.ACHIEVEMENTS)

        state.db.learning_completions.update_one(
            {"completion_id": completion_id},
            {"$set": {"applied": True, "result": payload}},
        )
        return jsonify(payload)
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500
