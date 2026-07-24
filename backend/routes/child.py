"""Child-facing Home Adventure routes.

`GET /child/home/<child_id>` is deliberately one call: the home screen needs
the buddy, the adventure, today's mission, the streak, the treasure count and
the achievement count all at once, and a young child on a slow connection
should not watch six spinners resolve one at a time.
"""

from flask import Blueprint, jsonify
from pymongo.errors import PyMongoError

import adventure
import child_progress as cp
import state
from child_profile import apply_child_defaults
from time_utils import _clean

bp = Blueprint("child", __name__)


def _load_active_child(child_id):
    """(raw_doc, serialised, error_response). Deactivated reads as not found,
    so a child whose profile a parent switched off can't slip back in."""
    raw = state.db.children.find_one({"child_id": child_id})
    if raw is None:
        return None, None, (jsonify({"status": "error",
                                     "message": "Child not found"}), 404)
    child = apply_child_defaults(_clean(raw))
    if not child.get("is_active"):
        return None, None, (jsonify({"status": "error",
                                     "message": "Child not found"}), 404)
    return raw, child, None


@bp.get("/child/home/<child_id>")
def child_home(child_id):
    err = state._db_required()
    if err:
        return err

    try:
        raw, child, missing = _load_active_child(child_id)
        if missing:
            return missing

        total_xp = int(child.get("total_xp") or 0)
        # Recomputed from XP rather than trusting the stored stage, so a
        # missed write during a reward can't leave a buddy visually stuck.
        stage = cp.stage_for_xp(total_xp)

        # Derived from progress, not the stored pointer — see
        # adventure.current_area_id.
        area = adventure.area_summary(raw, adventure.current_area_id(raw))

        streak = child.get("streak") or {}

        return jsonify({
            "status": "ok",
            "child": {
                "child_id": child_id,
                "nickname": child.get("nickname", ""),
                "age": child.get("age"),
            },
            "avatar": {
                "avatar_id": child.get("avatar_id"),
                "stage": stage,
                "total_xp": total_xp,
                # None once the buddy is fully grown — the client shows a
                # "max" state rather than an unreachable target.
                "next_stage_xp": cp.next_stage_xp(total_xp),
            },
            "adventure": {
                "current_area_id": area["area_id"],
                "current_area_name": area["area_name"],
                "emoji": area["emoji"],
                "progress_percentage": area["progress_percentage"],
                "visual_stage": area["visual_stage"],
                # Derived from progress, never stored separately.
                "keys": area["keys"],
                "max_keys": adventure.MAX_STAGE,
            },
            "daily_mission": cp.daily_mission(state.db, child_id),
            "streak_days": int(streak.get("current_days") or 0),
            "treasure_count": cp.treasure_count(state.db, child_id),
            "achievement_count": cp.achievement_count(state.db, raw, child_id),
            "achievement_total": len(cp.ACHIEVEMENTS),
        })
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


@bp.get("/child/adventure/<child_id>")
def child_adventure(child_id):
    """The whole adventure route for the map screen.

    Every area is returned, including locked ones — a child can look ahead at
    where they're going, they just can't grow anything but the current area
    (`can_grow`). Status, progress, decoration stage and keys are all derived
    from one stored number per area, so nothing here can contradict the home
    screen.
    """
    err = state._db_required()
    if err:
        return err

    try:
        raw, child, missing = _load_active_child(child_id)
        if missing:
            return missing

        summary = adventure.adventure_summary(raw)
        return jsonify({
            "status": "ok",
            "child": {
                "child_id": child_id,
                "nickname": child.get("nickname", ""),
            },
            "avatar": {
                "avatar_id": child.get("avatar_id"),
                "stage": cp.stage_for_xp(child.get("total_xp", 0)),
            },
            **summary,
        })
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500
