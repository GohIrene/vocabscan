from datetime import datetime

from flask import Blueprint, jsonify
from pymongo.errors import PyMongoError

import adventure
import child_progress as cp
import state
import treasures
from child_profile import apply_child_defaults
from time_utils import _clean, _local_day, _local_time

bp = Blueprint("report", __name__)


def _adventure_block(child_id):
    """Home Adventure standing, appended to the existing report.

    Added alongside the original fields rather than replacing any of them, so
    the parent dashboard's stat cards, day-by-day chart, mastery lists and
    revision buttons keep working untouched.
    """
    raw = state.db.children.find_one({"child_id": child_id})
    if raw is None:
        return None

    child = apply_child_defaults(_clean(raw))
    total_xp = int(child.get("total_xp") or 0)
    area_id = adventure.current_area_id(raw)
    area = adventure.area_summary(raw, area_id)
    progress = adventure.all_area_progress(raw)
    streak = child.get("streak") or {}

    return {
        "nickname": child.get("nickname", ""),
        "age": child.get("age"),
        "avatar": {
            "avatar_id": child.get("avatar_id"),
            "stage": cp.stage_for_xp(total_xp),
            "total_xp": total_xp,
            "next_stage_xp": cp.next_stage_xp(total_xp),
        },
        "adventure": {
            "current_area_id": area["area_id"],
            "current_area_name": area["area_name"],
            "emoji": area["emoji"],
            "progress_percentage": area["progress_percentage"],
            "visual_stage": area["visual_stage"],
            "keys": area["keys"],
            "completed_areas": sum(
                1 for a in adventure.AREA_IDS
                if progress.get(a, 0) >= adventure.MAX_PROGRESS),
            "area_count": len(adventure.AREA_IDS),
            "areas": [adventure.area_summary(raw, a)
                      for a in adventure.AREA_IDS],
        },
        "treasure_count": treasures.count(state.db, child_id),
        "streak_days": int(streak.get("current_days") or 0),
        "achievement_count": cp.achievement_count(state.db, raw, child_id),
        "achievement_total": len(cp.ACHIEVEMENTS),
        "is_active": child.get("is_active", True),
    }


@bp.get("/report/<child_id>")
def get_report(child_id):
    err = state._db_required()
    if err:
        return err

    try:
        scan_logs = list(state.db.scan_logs.find({"child_id": child_id}))
        quiz_logs = list(state.db.quiz_logs.find({"child_id": child_id}))
        speech_logs = list(state.db.speech_logs.find({"child_id": child_id}))

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

        # ── Per-day breakdown, bucketed by LOCAL (GMT+8) calendar day ──
        daily = {}

        def _bucket(created_at):
            """Return the day bucket a log belongs to, or None if undated."""
            day, weekday = _local_day(created_at)
            if day is None:
                return None
            if day not in daily:
                daily[day] = {
                    "date": day,
                    "weekday": weekday,
                    "scans": 0,
                    "quiz_attempts": 0,
                    "quiz_correct": 0,
                    "speech_attempts": 0,
                    "speech_correct": 0,
                    "words": set(),
                }
            return daily[day]

        for log in scan_logs:
            b = _bucket(log.get("created_at"))
            if b is None:
                continue
            b["scans"] += 1
            if log.get("english_key"):
                b["words"].add(log["english_key"])

        for log in quiz_logs:
            b = _bucket(log.get("created_at"))
            if b is None:
                continue
            b["quiz_attempts"] += 1
            if log.get("correct"):
                b["quiz_correct"] += 1

        for log in speech_logs:
            b = _bucket(log.get("created_at"))
            if b is None:
                continue
            b["speech_attempts"] += 1
            if log.get("correct"):
                b["speech_correct"] += 1

        # Newest day first, capped so a long-running profile can't bloat the
        # response; accuracy combines quiz + speech, matching the mastery rule.
        daily_list = []
        for day in sorted(daily.keys(), reverse=True)[:30]:
            b = daily[day]
            day_attempts = b["quiz_attempts"] + b["speech_attempts"]
            day_correct = b["quiz_correct"] + b["speech_correct"]
            daily_list.append({
                "date": b["date"],
                "weekday": b["weekday"],
                "scans": b["scans"],
                "words_practised": len(b["words"]),
                # The actual words, so "revise this day" can quiz exactly these.
                "word_keys": sorted(b["words"]),
                "quiz_attempts": b["quiz_attempts"],
                "quiz_correct": b["quiz_correct"],
                "speech_attempts": b["speech_attempts"],
                "speech_correct": b["speech_correct"],
                "accuracy": round(day_correct / day_attempts * 100, 1) if day_attempts else 0.0,
            })

        # Last 10 scan logs sorted by created_at descending
        recent_docs = sorted(scan_logs, key=lambda d: d.get("created_at", datetime.min), reverse=True)[:10]
        recent_activity = []
        for d in recent_docs:
            entry = _clean(d)
            day, weekday = _local_day(d.get("created_at"))
            # Pre-formatted local values so the UI never has to re-derive GMT+8.
            entry["local_date"] = day or ""
            entry["local_weekday"] = weekday or ""
            entry["local_time"] = _local_time(d.get("created_at"))
            recent_activity.append(entry)

        return jsonify({
            "child_id": child_id,
            # Home Adventure standing, added without touching the fields the
            # existing dashboard already reads.
            "profile": _adventure_block(child_id),
            "total_words": len(scan_counts),
            "total_scans": len(scan_logs),
            "quiz_accuracy": quiz_accuracy,
            "speech_attempts": speech_attempts,
            "speech_correct": speech_correct,
            "speech_accuracy": speech_accuracy,
            "active_days": len(daily),
            "words": words,
            "common_mistakes": common_mistakes,
            "daily": daily_list,
            "recent_activity": recent_activity,
        })
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500
