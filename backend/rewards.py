"""Reward rules for one completed Child Adventure learning cycle.

Option A, as specified: `/log/scan`, `/log/quiz` and `/log/speech` remain the
authoritative record of what a child actually did. This module never writes to
those collections — it reads the outcome of a cycle and applies *rewards*
only. Nothing here duplicates a log.

What a cycle changes:
  * a Treasure, the first time a word is discovered
  * avatar XP, and the stage that follows from it
  * progress in whichever area is currently growing
  * the daily streak

Everything a client needs to animate the reward screen is returned, including
the before/after values, so the screen never has to guess what changed.
"""

from datetime import datetime, timedelta

import adventure
import child_progress as cp
import treasures
from time_utils import local_today

# ── Reward table ─────────────────────────────────────────────────────────────
# A first discovery is worth substantially more than a repeat: the point of
# the adventure is to meet new words, while repeats should still feel worth
# doing without becoming the efficient way to farm progress.
NEW_WORD_XP = 20
NEW_WORD_QUIZ_BONUS = 5
NEW_WORD_AREA_POINTS = 10

REPEAT_WORD_XP = 5
REPEAT_WORD_QUIZ_BONUS = 3
REPEAT_WORD_AREA_POINTS = 5

# Speech XP by how many of the three languages the child said successfully,
# indexed 0-3. Trilingual learning is the point of the app, so saying a word
# in more than one language is rewarded — but with a flattening curve, since
# one language is the requirement and the others are optional bonus practice.
# Language count affects XP ONLY: it never multiplies area progress and never
# yields a second Treasure.
NEW_WORD_SPEECH_BONUS_BY_LANGUAGES = (0, 5, 7, 10)
REPEAT_WORD_SPEECH_BONUS_BY_LANGUAGES = (0, 2, 3, 5)

# How many languages exist to practise; caps the bonus lookup.
MAX_SPEECH_LANGUAGES = 3

# Repeats can push an area forward only this far per day. Without it a child
# could finish the whole route by re-scanning one object, which would make the
# map meaningless. New words are deliberately NOT capped.
REPEAT_AREA_POINTS_DAILY_CAP = 10

# Where the per-day repeat allowance is tracked on the child document.
_REPEAT_BUDGET_FIELD = "daily_repeat_area_points"


def _perfect_quiz(quiz):
    """True only for a full-marks quiz that actually had questions."""
    total = int(quiz.get("total") or 0)
    score = int(quiz.get("score") or 0)
    return total > 0 and score >= total


def _repeat_budget(child):
    """(points_used_today, is_stale) for the repeat allowance."""
    budget = (child or {}).get(_REPEAT_BUDGET_FIELD)
    if not isinstance(budget, dict):
        return 0, True
    if budget.get("date") != local_today():
        return 0, True  # yesterday's allowance, start fresh
    try:
        return max(0, int(budget.get("points") or 0)), False
    except (TypeError, ValueError):
        return 0, True


def speech_bonus(is_new_word, languages_succeeded):
    """Speech XP for however many languages the child got right.

    A flat lookup rather than a formula, so the numbers a child experiences
    are exactly the ones written in the table above.
    """
    table = (NEW_WORD_SPEECH_BONUS_BY_LANGUAGES if is_new_word
             else REPEAT_WORD_SPEECH_BONUS_BY_LANGUAGES)
    try:
        count = max(0, int(languages_succeeded or 0))
    except (TypeError, ValueError):
        count = 0
    return table[min(count, MAX_SPEECH_LANGUAGES)]


def compute_xp(is_new_word, speech, quiz):
    """XP for this cycle, broken down so the reward screen can explain it."""
    base = NEW_WORD_XP if is_new_word else REPEAT_WORD_XP
    quiz_bonus = NEW_WORD_QUIZ_BONUS if is_new_word else REPEAT_WORD_QUIZ_BONUS

    succeeded = speech.get("languages_succeeded") or 0
    earned_speech = speech_bonus(is_new_word, succeeded)
    earned_quiz = quiz_bonus if _perfect_quiz(quiz) else 0
    return {
        "base": base,
        "speech_bonus": earned_speech,
        "languages_succeeded": succeeded,
        "quiz_bonus": earned_quiz,
        "total": base + earned_speech + earned_quiz,
    }


def _next_streak(child):
    """(days, last_active_date) after counting today.

    Same day → unchanged, so finishing several words in an afternoon doesn't
    inflate a streak. Yesterday → +1. Any older gap (or none) → back to 1.
    """
    streak = (child or {}).get("streak")
    if not isinstance(streak, dict):
        streak = {}
    today = local_today()
    last = streak.get("last_active_date")
    try:
        current = max(0, int(streak.get("current_days") or 0))
    except (TypeError, ValueError):
        current = 0

    if last == today:
        return max(current, 1), today

    yesterday = (datetime.strptime(today, "%Y-%m-%d") - timedelta(days=1)) \
        .strftime("%Y-%m-%d")
    if last == yesterday:
        return current + 1, today
    return 1, today


def apply_cycle(db, child, english_key, speech, quiz):
    """Work out and apply every reward for one cycle.

    Returns (response_payload, mongo_update). The caller performs the update,
    so the completion record and the reward can be written under one decision.
    """
    child_id = child["child_id"]

    # The Treasure insert decides new-vs-repeat, so two rapid submissions
    # can't both be treated as a first discovery.
    area_id = adventure.current_area_id(child)
    all_done = adventure.adventure_summary(child)["all_completed"]
    is_new_word = treasures.discover(db, child_id, english_key, area_id)

    # ── XP and avatar stage ──
    xp = compute_xp(is_new_word, speech, quiz)
    previous_xp = int(child.get("total_xp") or 0)
    total_xp = previous_xp + xp["total"]
    previous_stage = cp.stage_for_xp(previous_xp)
    current_stage = cp.stage_for_xp(total_xp)

    # ── Area progress ──
    used_today, stale_budget = _repeat_budget(child)
    previous_progress = adventure.get_area_progress(child, area_id)
    area_points = 0
    capped = False

    if all_done:
        # Every area is finished. Learning continues — XP, treasures, streak
        # and missions all still count — there is simply nowhere left to grow.
        pass
    elif is_new_word:
        area_points = NEW_WORD_AREA_POINTS
    else:
        remaining = max(0, REPEAT_AREA_POINTS_DAILY_CAP - used_today)
        area_points = min(REPEAT_WORD_AREA_POINTS, remaining)
        capped = area_points < REPEAT_WORD_AREA_POINTS

    # Overflow is discarded rather than carried into the next area: an area
    # tops out at 100 and the next one starts where it stands.
    current_progress = min(adventure.MAX_PROGRESS, previous_progress + area_points)
    granted = current_progress - previous_progress

    area_completed = (current_progress >= adventure.MAX_PROGRESS
                      and previous_progress < adventure.MAX_PROGRESS)
    next_area_unlocked = adventure.next_area_id(area_id) if area_completed else None

    # ── Streak ──
    streak_days, streak_date = _next_streak(child)

    # ── Build the update ──
    update = {
        "total_xp": total_xp,
        "avatar_stage": current_stage,
        "streak": {"current_days": streak_days, "last_active_date": streak_date},
    }
    if granted:
        update[f"{adventure.PROGRESS_FIELD}.{area_id}"] = current_progress
    if area_completed:
        # Kept in step for cheap reads; the authority stays the derivation in
        # adventure.current_area_id.
        update["current_area_id"] = next_area_unlocked or area_id
    if not is_new_word and granted and not all_done:
        used = (0 if stale_budget else used_today) + granted
        update[_REPEAT_BUDGET_FIELD] = {"date": local_today(), "points": used}

    payload = {
        "status": "ok",
        "is_new_word": is_new_word,
        "english_key": english_key,
        "rewards": {
            "xp_earned": xp["total"],
            "xp_breakdown": xp,
            "area_points_earned": granted,
            "area_points_capped": capped,
            "new_treasure": is_new_word,
        },
        # Echoed back so the reward screen can show which languages the child
        # managed. Area progress and the Treasure above are deliberately
        # independent of these counts.
        "speech": {
            "languages_attempted": speech.get("languages_attempted", 0),
            "languages_succeeded": speech.get("languages_succeeded", 0),
            "languages": speech.get("languages", []),
            "skipped": bool(speech.get("skipped")),
        },
        "avatar": {
            "previous_stage": previous_stage,
            "current_stage": current_stage,
            "previous_xp": previous_xp,
            "total_xp": total_xp,
            "next_stage_xp": cp.next_stage_xp(total_xp),
            "evolved": current_stage > previous_stage,
        },
        "adventure": {
            "area_id": area_id,
            "area_name": (adventure.area_by_id(area_id) or {}).get("name", area_id),
            "previous_progress": previous_progress,
            "current_progress": current_progress,
            "previous_visual_stage": adventure.visual_stage(previous_progress),
            "visual_stage": adventure.visual_stage(current_progress),
            # A crossed stage boundary means a new decoration appeared in the
            # area — the most tangible "my place grew" moment, so the reward
            # screen is told about it explicitly rather than having to compare.
            "decoration_unlocked": (adventure.visual_stage(current_progress)
                                    > adventure.visual_stage(previous_progress)),
            "previous_keys": adventure.keys_for_progress(previous_progress),
            "keys": adventure.keys_for_progress(current_progress),
            "area_completed": area_completed,
            "next_area_unlocked": next_area_unlocked,
            "all_areas_completed": all_done,
        },
        "streak_days": streak_days,
    }
    return payload, update
