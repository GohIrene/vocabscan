import random
from datetime import datetime

from flask import Blueprint, jsonify, request
from pymongo.errors import PyMongoError

import quiz_logic
import state
import vocab
from time_utils import _local_day

bp = Blueprint("revision", __name__)


def _child_word_keys(child_id, date=None):
    """Distinct words a child has scanned, optionally limited to one local day.

    The date filter is applied BEFORE the de-duplication check: a word scanned
    on several days must still be found when filtering to a later one.
    """
    keys = []
    seen = set()
    for log in state.db.scan_logs.find({"child_id": child_id}):
        key = log.get("english_key")
        if not key:
            continue
        if date:
            day, _ = _local_day(log.get("created_at"))
            if day != date:
                continue
        if key in seen:
            continue
        seen.add(key)
        keys.append(key)
    return keys


@bp.get("/revision/quiz/<child_id>")
def revision_quiz(child_id):
    """A quiz built from words this child has already learned, so a parent can
    revisit earlier vocabulary without needing the physical object to scan.
    Pass `date=YYYY-MM-DD` (local/GMT+8) to revise one specific day."""
    err = state._db_required()
    if err:
        return err

    date = request.args.get("date") or None
    n = request.args.get("n", "5")
    try:
        n = max(1, min(int(n), 20))
    except ValueError:
        n = 5

    try:
        keys = _child_word_keys(child_id, date)
        if not keys:
            return jsonify({
                "child_id": child_id, "date": date,
                "word_count": 0, "questions": [],
            })

        # Random subset so repeat revisions aren't identical, and each question
        # is freshly built (rotating pattern + real distractors).
        chosen = random.sample(keys, min(n, len(keys)))
        questions = []
        for key in chosen:
            q = quiz_logic._build_quiz(key)
            questions.append({
                "english_key": key,
                "prompt": q["prompt"],
                "options": q["options"],
                "correct_answer": q["correct_answer"],
            })
        return jsonify({
            "child_id": child_id,
            "date": date,
            "word_count": len(keys),
            "questions": questions,
        })
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


@bp.get("/revision/words/teacher/<teacher_id>")
def revision_words_teacher(teacher_id):
    """Words this teacher has already covered in past class sessions, newest
    first, so a revision quiz can be pushed without re-scanning the object."""
    err = state._db_required()
    if err:
        return err

    try:
        docs = list(state.db.class_sessions.find({"teacher_id": teacher_id}))
        docs.sort(key=lambda d: d.get("created_at") or datetime.min, reverse=True)

        words = []
        seen = set()
        for d in docs:
            day, weekday = _local_day(d.get("created_at"))
            for key in d.get("word_keys", []) or []:
                if not key or key in seen:
                    continue
                seen.add(key)
                item = vocab._resolve_vocab(key)
                words.append({
                    "english_key": key,
                    "english_word": item.get("english_word", key),
                    "malay_word": item.get("malay_word", ""),
                    "chinese_word": item.get("chinese_word", ""),
                    "last_used_date": day or "",
                    "last_used_weekday": weekday or "",
                })
        return jsonify({
            "teacher_id": teacher_id,
            "word_count": len(words),
            "words": words,
        })
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500
