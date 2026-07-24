"""XP, levels and badges for classroom students.

Progress lives on the classroom roster entry (classrooms.students[]) rather
than on the session, so it survives across lessons. Sessions themselves stay
keyed by nickname exactly as before — the roster simply guarantees that
nickname is a real, correctly-spelled student instead of whatever a child
managed to type.
"""

# One correct answer is worth this much XP. A session score is a small integer
# (one point per correct answer), so scaling up keeps the number a child sees
# feeling like a real reward rather than a rounding error.
XP_PER_CORRECT = 10

# Flat rather than escalating: young children should keep levelling at a
# steady, predictable pace instead of stalling once the curve steepens.
XP_PER_LEVEL = 100

# Ordered so the UI can show a sensible progression. Each badge unlocks off a
# single stat, which keeps "why did I get this?" obvious to a child.
BADGES = [
    {"id": "first_steps", "label": "First Steps", "emoji": "🌱",
     "stat": "sessions_played", "threshold": 1},
    {"id": "word_hunter", "label": "Word Hunter", "emoji": "🔎",
     "stat": "xp", "threshold": 100},
    {"id": "champion", "label": "Champion", "emoji": "🏆",
     "stat": "wins", "threshold": 1},
    {"id": "explorer", "label": "Explorer", "emoji": "🧭",
     "stat": "sessions_played", "threshold": 5},
    {"id": "word_wizard", "label": "Word Wizard", "emoji": "🪄",
     "stat": "xp", "threshold": 500},
    {"id": "unstoppable", "label": "Unstoppable", "emoji": "🚀",
     "stat": "wins", "threshold": 5},
]


def level_for_xp(xp):
    """Level 1 is the starting level — a child is never shown 'level 0'."""
    return 1 + int(xp) // XP_PER_LEVEL


def xp_into_level(xp):
    """XP earned toward the next level, for the progress bar."""
    return int(xp) % XP_PER_LEVEL


def new_student(student_id, name, avatar=0):
    """A fresh roster entry, starting at level 1 with nothing earned yet."""
    return {
        "student_id": student_id,
        "name": name,
        "avatar": int(avatar),
        "xp": 0,
        "level": 1,
        "sessions_played": 0,
        "wins": 0,
        "badges": [],
    }


def earned_badges(stats):
    """Every badge id the given stats qualify for.

    Recomputed from totals rather than appended incrementally, so a badge can
    never be missed because of one dropped update.
    """
    return [b["id"] for b in BADGES if stats.get(b["stat"], 0) >= b["threshold"]]


def apply_session_result(student, score, is_winner):
    """Fold one finished session into a roster student's progress.

    Returns the updated student alongside what actually changed, so the child
    can be told "you levelled up" or "you earned a badge" instead of watching a
    number silently tick.
    """
    before_level = student.get("level") or level_for_xp(student.get("xp", 0))
    before_badges = set(student.get("badges") or [])

    gained = max(0, int(score or 0)) * XP_PER_CORRECT
    stats = {
        "xp": int(student.get("xp", 0)) + gained,
        "sessions_played": int(student.get("sessions_played", 0)) + 1,
        "wins": int(student.get("wins", 0)) + (1 if is_winner else 0),
    }
    badges = earned_badges(stats)
    level = level_for_xp(stats["xp"])

    return {
        "student": {**student, **stats, "level": level, "badges": badges},
        "xp_gained": gained,
        "levelled_up": level > before_level,
        "new_badges": [b for b in badges if b not in before_badges],
    }
