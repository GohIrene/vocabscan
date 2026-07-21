import random

import state

# 6-char code alphabet, excluding ambiguous 0/O/1/I.
_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

# A recap covering more than this many words is too long for young children;
# the most recently covered words win.
_MAX_SUMMARY_QUESTIONS = 10


def _generate_code():
    """Return a 6-char code not currently used by any non-ended session."""
    while True:
        code = "".join(random.choice(_CODE_ALPHABET) for _ in range(6))
        if state.db is None:
            return code
        existing = state.db.class_sessions.find_one({"code": code, "status": {"$ne": "ended"}})
        if existing is None:
            return code


def _count_connected(session):
    return sum(1 for s in session.get("students", []) if s.get("connected"))


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
