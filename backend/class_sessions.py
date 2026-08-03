import random
from datetime import datetime, timedelta

import progress
import state
import vocab

# 6-char code alphabet, excluding ambiguous 0/O/1/I.
_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

# A recap covering more than this many words is too long for young children;
# the most recently covered words win.
_MAX_SUMMARY_QUESTIONS = 10

# A class session left idle longer than this is treated as abandoned and closed
# the next time class-session APIs are touched.
STALE_SESSION_HOURS = 2


def _generate_code():
    """Return a 6-char code not currently used by any non-ended session."""
    expire_stale_sessions()
    while True:
        code = "".join(random.choice(_CODE_ALPHABET) for _ in range(6))
        if state.db is None:
            return code
        existing = state.db.class_sessions.find_one({"code": code, "status": {"$ne": "ended"}})
        if existing is None:
            return code


def _count_connected(session):
    return sum(1 for s in session.get("students", []) if s.get("connected"))


def roster_state(session):
    """Who is in this session, with their live connection flag.

    The teacher panel draws a named chip per student, which a bare count can't
    rebuild — so this travels alongside `student_count` on every join/leave and
    on the teacher's own (re)connect sync. Nicknames only; no sids leave the
    server.
    """
    return [
        {"nickname": s.get("nickname", ""),
         "connected": bool(s.get("connected"))}
        for s in session.get("students", [])
        if s.get("nickname")
    ]


def _count_words(session):
    """Distinct quizzable words pushed this session — what a summary quiz would
    actually be built from, so the teacher's button gate matches reality."""
    return len({k for k in (session.get("word_keys") or []) if vocab._is_known(k)})


def _count_answered(session):
    return sum(
        1 for s in session.get("students", [])
        if s.get("connected") and s.get("answered_current")
    )


def _count_summary_finished(session, total):
    """Connected students who have answered every question of the summary quiz."""
    if total <= 0:
        return 0
    return sum(
        1 for s in session.get("students", [])
        if s.get("connected") and len(s.get("summary_answered") or []) >= total
    )


def touch_session(session_id):
    """Mark a still-live session as recently active."""
    if state.db is None or not session_id:
        return
    state.db.class_sessions.update_one(
        {"session_id": session_id, "status": {"$ne": "ended"}},
        {"$set": {"last_activity_at": datetime.utcnow()}},
    )


def _activity_at(session):
    """Best available activity timestamp for new and legacy session docs."""
    candidates = [
        session.get("last_activity_at"),
        session.get("created_at"),
    ]
    quiz = session.get("current_quiz") or {}
    summary = session.get("summary_quiz") or {}
    candidates.extend([quiz.get("pushed_at"), summary.get("pushed_at")])
    return max((v for v in candidates if isinstance(v, datetime)), default=None)


def _leaderboard(session):
    return sorted(
        [{"nickname": s.get("nickname"), "score": s.get("score", 0)}
         for s in session.get("students", [])],
        key=lambda x: x["score"],
        reverse=True,
    )


def _archive_live_quizzes(session):
    push_ops = {}
    if session.get("current_quiz"):
        push_ops["quiz_history"] = session["current_quiz"]
    if session.get("summary_quiz"):
        push_ops["summary_history"] = session["summary_quiz"]
    return push_ops


def _award_classroom_progress(session, leaderboard):
    """Fold an ended saved-class session into the classroom roster once."""
    classroom_id = session.get("classroom_id")
    if not classroom_id or session.get("progress_applied_at"):
        return

    doc = state.db.classrooms.find_one({"classroom_id": classroom_id})
    if doc is None:
        return

    top = leaderboard[0]["score"] if leaderboard else 0
    winners = {e["nickname"] for e in leaderboard if e["score"] == top and top > 0}
    roster_by_name = {
        (s.get("name") or "").lower(): s for s in (doc.get("students") or [])
    }

    for student in (session.get("students") or []):
        nickname = student.get("nickname") or ""
        roster = roster_by_name.get(nickname.lower())
        if roster is None:
            continue

        result = progress.apply_session_result(
            roster, student.get("score", 0), nickname in winners
        )
        updated = result["student"]
        state.db.classrooms.update_one(
            {"classroom_id": classroom_id,
             "students.student_id": updated["student_id"]},
            {"$set": {
                "students.$.xp": updated["xp"],
                "students.$.level": updated["level"],
                "students.$.sessions_played": updated["sessions_played"],
                "students.$.wins": updated["wins"],
                "students.$.badges": updated["badges"],
            }},
        )

    state.db.class_sessions.update_one(
        {"session_id": session.get("session_id")},
        {"$set": {"progress_applied_at": datetime.utcnow()}},
    )


def close_session(session, *, auto=False):
    """End a session document, archiving any live quiz and applying roster XP."""
    if state.db is None or session is None:
        return False, []

    leaderboard = _leaderboard(session)
    update = {"$set": {
        "status": "ended",
        "ended_at": datetime.utcnow(),
        "current_quiz": None,
        "summary_quiz": None,
    }}
    if auto:
        update["$set"]["auto_ended"] = True

    push_ops = _archive_live_quizzes(session)
    if push_ops:
        update["$push"] = push_ops

    res = state.db.class_sessions.update_one(
        {"session_id": session.get("session_id"), "status": {"$ne": "ended"}},
        update,
    )
    if res.modified_count == 0:
        return False, leaderboard

    _award_classroom_progress(session, leaderboard)
    return True, leaderboard


def expire_stale_sessions(query=None):
    """Auto-close inactive live sessions and return how many were ended."""
    if state.db is None:
        return 0

    cutoff = datetime.utcnow() - timedelta(hours=STALE_SESSION_HOURS)
    criteria = {"status": {"$ne": "ended"}}
    if query:
        criteria.update(query)

    count = 0
    for session in state.db.class_sessions.find(criteria):
        activity_at = _activity_at(session)
        if activity_at is not None and activity_at <= cutoff:
            changed, _ = close_session(session, auto=True)
            if changed:
                count += 1
    return count

