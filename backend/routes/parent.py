"""Parent Mode dashboard data.

Two aggregate reads, both scoped to one parent's children:

  * `GET /parent/summary/<parent_id>`  — everything the dashboard draws
  * `GET /parent/activity/<parent_id>` — the combined activity log

The summary exists so the dashboard is one request rather than one per child
plus one for the family code. A parent with four children would otherwise fire
nine requests to paint a single screen.

Read-only. Nothing here writes, and none of it touches the teacher or Class
Code collections.
"""

from datetime import datetime, timedelta

from flask import Blueprint, jsonify, request
from pymongo.errors import PyMongoError

import adventure
import child_progress as cp
import family
import state
import treasures
import vocab
from child_profile import apply_child_defaults
from time_utils import (_clean, _local_day, _local_time, local_day_start_utc,
                        local_today)

bp = Blueprint("parent", __name__)

# How many days the dashboard's trend chart covers.
_WEEK_DAYS = 7

# Cap on the combined activity feed, so a long-running family can't return an
# unbounded response.
_MAX_ACTIVITY = 60


def _children_of(parent_id):
    docs = list(state.db.children.find({"parent_id": parent_id}))
    return [apply_child_defaults(_clean(d)) for d in docs], docs


def _child_card(child, raw):
    """One child as the dashboard's card shows them."""
    child_id = child["child_id"]
    total_xp = int(child.get("total_xp") or 0)
    area_id = adventure.current_area_id(raw)
    area = adventure.area_summary(raw, area_id)
    progress = adventure.all_area_progress(raw)
    streak = child.get("streak") or {}

    return {
        "child_id": child_id,
        "nickname": child.get("nickname", ""),
        "age": child.get("age"),
        "avatar_id": child.get("avatar_id"),
        "avatar_stage": cp.stage_for_xp(total_xp),
        "total_xp": total_xp,
        "next_stage_xp": cp.next_stage_xp(total_xp),
        "is_active": child.get("is_active", True),
        "has_pin": child.get("has_pin", False),
        # Legacy face, still honoured by the UI when a child predates avatars.
        "icon": child.get("icon", ""),
        "adventure": {
            "current_area_id": area["area_id"],
            "current_area_name": area["area_name"],
            "emoji": area["emoji"],
            "progress_percentage": area["progress_percentage"],
            "keys": area["keys"],
            "completed_areas": sum(
                1 for a in adventure.AREA_IDS
                if progress.get(a, 0) >= adventure.MAX_PROGRESS),
            "area_count": len(adventure.AREA_IDS),
        },
        "treasure_count": treasures.count(state.db, child_id),
        "streak_days": int(streak.get("current_days") or 0),
        # Distinct words actually scanned — the parent-facing "words learned",
        # which stays on the scan logs so it matches the existing report.
        "words_learned": len(
            [k for k in state.db.scan_logs.distinct(
                "english_key", {"child_id": child_id}) if k]),
    }


@bp.get("/parent/summary/<parent_id>")
def parent_summary(parent_id):
    err = state._db_required()
    if err:
        return err

    try:
        user = state.db.users.find_one({"user_id": parent_id, "role": "parent"})
        if user is None:
            return jsonify({"status": "error",
                            "message": "Parent account not found"}), 404

        children, raws = _children_of(parent_id)
        by_id = {r["child_id"]: r for r in raws}
        cards = [_child_card(c, by_id[c["child_id"]]) for c in children]
        active = [c for c in cards if c["is_active"]]
        inactive = [c for c in cards if not c["is_active"]]

        # Today's totals across every active child, so the parent sees the
        # household at a glance rather than per child.
        active_ids = [c["child_id"] for c in active]
        today_start = local_day_start_utc()
        today_filter = {"child_id": {"$in": active_ids},
                        "created_at": {"$gte": today_start}}
        today = {
            "scans": state.db.scan_logs.count_documents(today_filter),
            "quiz_attempts": state.db.quiz_logs.count_documents(today_filter),
            "speech_attempts": state.db.speech_logs.count_documents(today_filter),
            "new_words": state.db.child_treasures.count_documents({
                "child_id": {"$in": active_ids},
                "discovered_at": {"$gte": today_start}}),
        } if active_ids else {"scans": 0, "quiz_attempts": 0,
                              "speech_attempts": 0, "new_words": 0}

        return jsonify({
            "status": "ok",
            "parent": {
                "user_id": parent_id,
                "username": user.get("username", ""),
            },
            # Assigned on first read, exactly as the family-code screen does.
            "family_code": family.ensure_family_code(user),
            "children": active,
            "inactive_children": inactive,
            "child_count": len(active),
            "inactive_count": len(inactive),
            "today": today,
            "week": _week_series(active),
        })
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


def _week_series(children):
    """Scans per child per local day for the last week, oldest day first.

    One query per child rather than one per child per day: the range is small,
    so bucketing in Python is cheaper than 7x the round trips.
    """
    start = local_day_start_utc(days_ago=_WEEK_DAYS - 1)
    days = []
    for offset in range(_WEEK_DAYS - 1, -1, -1):
        day, weekday = _local_day(
            local_day_start_utc(days_ago=offset) + timedelta(hours=8))
        days.append({"date": day, "weekday": (weekday or "")[:3]})
    index = {d["date"]: i for i, d in enumerate(days)}

    series = []
    for child in children:
        counts = [0] * _WEEK_DAYS
        logs = state.db.scan_logs.find(
            {"child_id": child["child_id"], "created_at": {"$gte": start}},
            {"created_at": 1})
        for log in logs:
            day, _ = _local_day(log.get("created_at"))
            if day in index:
                counts[index[day]] += 1
        series.append({
            "child_id": child["child_id"],
            "nickname": child["nickname"],
            "avatar_id": child["avatar_id"],
            "scans": counts,
        })

    return {"days": days, "series": series, "max": max(
        [max(s["scans"]) for s in series] or [0])}


@bp.get("/parent/activity/<parent_id>")
def parent_activity(parent_id):
    """Recent learning events across all of a parent's children, newest first.

    Merged from the existing logs plus treasure discoveries; nothing new is
    recorded to build this.
    """
    err = state._db_required()
    if err:
        return err

    try:
        limit = min(max(int(request.args.get("n", _MAX_ACTIVITY)), 1),
                    _MAX_ACTIVITY)
    except (TypeError, ValueError):
        limit = _MAX_ACTIVITY

    try:
        children, _ = _children_of(parent_id)
        names = {c["child_id"]: c.get("nickname", "") for c in children}
        avatars = {c["child_id"]: c.get("avatar_id") for c in children}
        if not names:
            return jsonify({"status": "ok", "activity": [], "count": 0})

        child_ids = list(names.keys())
        events = []

        def add(docs, kind, describe):
            for d in docs:
                key = d.get("english_key") or ""
                word = vocab._resolve_vocab(key).get("english_word", key)
                created = d.get("created_at") or d.get("discovered_at")
                day, weekday = _local_day(created)
                events.append({
                    "type": kind,
                    "child_id": d.get("child_id"),
                    "child_nickname": names.get(d.get("child_id"), ""),
                    "avatar_id": avatars.get(d.get("child_id")),
                    "english_key": key,
                    "english_word": word,
                    "description": describe(d, word),
                    "correct": d.get("correct"),
                    "local_date": day or "",
                    "local_weekday": weekday or "",
                    "local_time": _local_time(created),
                    "_sort": created or datetime.min,
                })

        q = {"child_id": {"$in": child_ids}}
        add(state.db.child_treasures.find(q).sort("discovered_at", -1)
            .limit(limit), "treasure",
            lambda d, w: f"Discovered {w}")
        add(state.db.scan_logs.find(q).sort("created_at", -1).limit(limit),
            "scan", lambda d, w: f"Scanned {w}")
        add(state.db.quiz_logs.find(q).sort("created_at", -1).limit(limit),
            "quiz",
            lambda d, w: f"Quiz on {w} — "
                         f"{'correct' if d.get('correct') else 'incorrect'}")
        add(state.db.speech_logs.find(q).sort("created_at", -1).limit(limit),
            "speech",
            lambda d, w: f"Said {w} — "
                         f"{'correct' if d.get('correct') else 'try again'}")

        events.sort(key=lambda e: e["_sort"], reverse=True)
        for e in events:
            e.pop("_sort", None)

        return jsonify({
            "status": "ok",
            "activity": events[:limit],
            "count": len(events[:limit]),
            "today": local_today(),
        })
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500
