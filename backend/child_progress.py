"""Avatar XP, daily missions, treasures and achievements for Home Adventure.

Everything here is *derived* from data that already exists — the child
document plus the scan/quiz/speech logs — rather than kept in a parallel
counter that could drift. Phase 5 adds the write side (`/learning/complete`);
this module stays the single place those numbers are defined, so the reward
screen and the home summary can never disagree about what a child has.

Distinct from `progress.py`, which is XP and badges for *classroom* students
on a teacher's roster. Different audience, different rules, deliberately not
shared.
"""

import treasures
from adventure import AREA_IDS, MAX_PROGRESS, all_area_progress
from avatars import clamp_stage
from time_utils import local_day_start_utc, local_today

# XP at which each avatar stage begins. Three stages, because that is how
# much artwork each buddy has.
AVATAR_STAGE_THRESHOLDS = (0, 300, 800)

# What "done for today" means. Small and reachable — a young child should be
# able to finish the set in one sitting without it feeling like homework.
DAILY_NEW_WORDS_TARGET = 3
DAILY_SPEECH_TARGET = 3
DAILY_QUIZ_TARGET = 2

# Unlocked by crossing a single threshold, so "why did I get this?" stays
# obvious to a child. Recomputed from totals every time rather than appended,
# so one dropped update can't cost a badge permanently.
ACHIEVEMENTS = (
    {"id": "first_word", "label": "First Word", "emoji": "🌱",
     "stat": "words_discovered", "threshold": 1},
    {"id": "word_collector", "label": "Word Collector", "emoji": "📚",
     "stat": "words_discovered", "threshold": 10},
    {"id": "word_master", "label": "Word Master", "emoji": "🎓",
     "stat": "words_discovered", "threshold": 25},
    {"id": "brave_voice", "label": "Brave Voice", "emoji": "🎤",
     "stat": "speech_correct", "threshold": 5},
    {"id": "clear_speaker", "label": "Clear Speaker", "emoji": "🗣️",
     "stat": "speech_correct", "threshold": 20},
    {"id": "quiz_star", "label": "Quiz Star", "emoji": "⭐",
     "stat": "quiz_correct", "threshold": 10},
    {"id": "quiz_champion", "label": "Quiz Champion", "emoji": "🏆",
     "stat": "quiz_correct", "threshold": 30},
    {"id": "on_a_roll", "label": "On a Roll", "emoji": "🔥",
     "stat": "streak_days", "threshold": 3},
    {"id": "unstoppable", "label": "Unstoppable", "emoji": "🚀",
     "stat": "streak_days", "threshold": 7},
    {"id": "explorer", "label": "Explorer", "emoji": "🧭",
     "stat": "areas_completed", "threshold": 1},
    {"id": "buddy_grew", "label": "Buddy Grew!", "emoji": "✨",
     "stat": "avatar_stage", "threshold": 2},
    {"id": "best_friends", "label": "Best Friends", "emoji": "💛",
     "stat": "avatar_stage", "threshold": 3},
)


# ── Avatar XP ────────────────────────────────────────────────────────────────

def stage_for_xp(total_xp):
    """Which avatar stage [total_xp] has earned (1-3)."""
    try:
        xp = max(0, int(total_xp or 0))
    except (TypeError, ValueError):
        xp = 0
    stage = 1
    for index, threshold in enumerate(AVATAR_STAGE_THRESHOLDS):
        if xp >= threshold:
            stage = index + 1
    return clamp_stage(stage)


def next_stage_xp(total_xp):
    """XP at which the buddy next grows, or None once fully grown."""
    try:
        xp = max(0, int(total_xp or 0))
    except (TypeError, ValueError):
        xp = 0
    for threshold in AVATAR_STAGE_THRESHOLDS:
        if xp < threshold:
            return threshold
    return None


# ── Derived counts ───────────────────────────────────────────────────────────

def discovered_words(db, child_id):
    """Words this child has discovered in Home Adventure — their album.

    Read from the Adventure Treasure records, NOT from scan_logs. A scan log
    means recognition happened in some mode; a treasure means this child was
    actually rewarded for discovering the word inside their adventure. Using
    scan logs here would let teacher-projection scans and old test data award
    treasures a child never earned.
    """
    return treasures.discovered_keys(db, child_id)


def treasure_count(db, child_id):
    return treasures.count(db, child_id)


def daily_mission(db, child_id):
    """Today's three goals and how far along the child is.

    "New words" means words scanned today that they had never scanned before,
    so re-scanning the same object all afternoon doesn't complete the mission.
    """
    empty = {
        "date": local_today(),
        "new_words_target": DAILY_NEW_WORDS_TARGET,
        "new_words_completed": 0,
        "speech_target": DAILY_SPEECH_TARGET,
        "speech_completed": 0,
        "quiz_target": DAILY_QUIZ_TARGET,
        "quiz_completed": 0,
    }
    if db is None:
        return empty

    today = {"child_id": child_id, "created_at": {"$gte": local_day_start_utc()}}

    # New words come from Treasure records, so the goal tracks genuine first
    # discoveries in the adventure — re-scanning the same chair all afternoon
    # never completes it, and unrelated scan history can never pre-complete it.
    new_today = treasures.discovered_today(db, child_id)

    # Practice goals stay on the logs, counted as distinct words rather than
    # raw attempts: three tries at one word is practice, not three missions.
    spoken_today = {k for k in db.speech_logs.distinct("english_key", today) if k}
    quizzed_today = {k for k in db.quiz_logs.distinct("english_key", today) if k}

    return {
        **empty,
        "new_words_completed": min(new_today, DAILY_NEW_WORDS_TARGET),
        "speech_completed": min(len(spoken_today), DAILY_SPEECH_TARGET),
        "quiz_completed": min(len(quizzed_today), DAILY_QUIZ_TARGET),
    }


def achievement_stats(db, child, child_id):
    """The totals every achievement threshold is measured against."""
    streak = (child or {}).get("streak") or {}
    progress = all_area_progress(child)
    stats = {
        "words_discovered": treasure_count(db, child_id),
        "speech_correct": 0,
        "quiz_correct": 0,
        "streak_days": int(streak.get("current_days") or 0),
        "areas_completed": sum(
            1 for area_id in AREA_IDS if progress.get(area_id, 0) >= MAX_PROGRESS
        ),
        "avatar_stage": stage_for_xp((child or {}).get("total_xp", 0)),
    }
    if db is not None:
        stats["speech_correct"] = db.speech_logs.count_documents(
            {"child_id": child_id, "correct": True})
        stats["quiz_correct"] = db.quiz_logs.count_documents(
            {"child_id": child_id, "correct": True})
    return stats


def unlocked_achievements(db, child, child_id):
    """Every achievement the child's totals currently qualify for."""
    stats = achievement_stats(db, child, child_id)
    return [a for a in ACHIEVEMENTS if stats.get(a["stat"], 0) >= a["threshold"]]


def achievement_count(db, child, child_id):
    return len(unlocked_achievements(db, child, child_id))
