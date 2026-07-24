import re
import uuid
from datetime import datetime

from flask import Blueprint, jsonify, request
from pymongo.errors import PyMongoError

import state
from child_profile import (apply_child_defaults, new_child_fields,
                           validate_avatar_id, validate_child_pin)
from time_utils import _clean

bp = Blueprint("children", __name__)


def _serialise(doc):
    """A child document as the API returns it.

    `_clean` handles _id/datetime; `apply_child_defaults` fills in the Home
    Adventure fields a pre-adventure profile is missing and strips the PIN
    hash. Purely a read path — nothing here writes back to MongoDB, so
    listing children never mutates them (migrate_children.py owns persistence).
    """
    return apply_child_defaults(_clean(doc))


@bp.post("/children")
def add_child():
    err = state._db_required()
    if err:
        return err

    data = request.get_json() or {}
    parent_id = (data.get("parent_id") or "").strip()
    nickname = (data.get("nickname") or "").strip()
    age = data.get("age")
    # gender/icon predate the animal avatars and are no longer sent by the
    # add-child wizard, but they stay accepted (and stored when present) so
    # profiles created under the old screen keep rendering their chosen face.
    gender = (data.get("gender") or "").strip()
    # Asset name of the icon the parent picked (e.g. "boy1"), so the child's
    # card shows their chosen face rather than an auto-assigned one.
    icon = (data.get("icon") or "").strip()

    if not parent_id:
        return jsonify({"status": "error", "message": "parent_id is required"}), 400
    if not nickname:
        return jsonify({"status": "error", "message": "nickname is required"}), 400
    # The app is designed for early learners; the picker offers only this range.
    if not isinstance(age, int) or not (3 <= age <= 10):
        return jsonify({"status": "error", "message": "Age must be between 3 and 10"}), 400

    avatar_id, avatar_error = validate_avatar_id(data.get("avatar_id"))
    if avatar_error:
        return jsonify({"status": "error", "message": avatar_error}), 400

    # Optional: a child with no PIN is picked by tapping their face.
    child_pin_hash, pin_error = validate_child_pin(data.get("child_pin"))
    if pin_error:
        return jsonify({"status": "error", "message": pin_error}), 400

    try:
        # Unique per parent, case-insensitively: the nickname is how a parent
        # tells their children apart when picking one, so two "Ali"s under the
        # same parent would be indistinguishable. Different parents may of
        # course both have an Ali.
        existing = state.db.children.find_one({
            "parent_id": parent_id,
            "nickname": {"$regex": f"^{re.escape(nickname)}$", "$options": "i"},
        })
        if existing:
            return jsonify({
                "status": "error",
                "message": "You already have a child with that name",
            }), 409

        child_id = str(uuid.uuid4())
        doc = {
            "child_id": child_id,
            "parent_id": parent_id,
            "nickname": nickname,
            "age": age,
            "gender": gender,
            "icon": icon,
            "created_at": datetime.utcnow(),
            # avatar_stage / total_xp / current_area_id / streak / is_active /
            # first_login_completed — see child_profile.py.
            **new_child_fields(avatar_id),
        }
        # Absent rather than null when unset, so "has a PIN" is a simple
        # existence check and migrations can tell the two apart.
        if child_pin_hash:
            doc["child_pin_hash"] = child_pin_hash
        state.db.children.insert_one(doc)

        return jsonify({
            "status": "ok",
            "child_id": child_id,
            "nickname": nickname,
            "age": age,
            "avatar_id": avatar_id,
            "has_pin": bool(child_pin_hash),
        }), 201
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


@bp.patch("/children/<child_id>")
def update_child(child_id):
    """Edit a child profile: name, age, buddy, PIN, or active state.

    Every field is optional — only what's sent is changed — so the same route
    serves the edit form, the deactivate toggle and a PIN reset without any of
    them clobbering the others.
    """
    err = state._db_required()
    if err:
        return err

    data = request.get_json() or {}
    try:
        existing = state.db.children.find_one({"child_id": child_id})
        if existing is None:
            return jsonify({"status": "error", "message": "Child not found"}), 404

        update = {}

        if "nickname" in data:
            nickname = (data.get("nickname") or "").strip()
            if not nickname:
                return jsonify({"status": "error",
                                "message": "nickname is required"}), 400
            # Same per-parent, case-insensitive rule as creation, but ignoring
            # this child — otherwise saving a profile unchanged would 409.
            clash = state.db.children.find_one({
                "parent_id": existing.get("parent_id"),
                "child_id": {"$ne": child_id},
                "nickname": {"$regex": f"^{re.escape(nickname)}$",
                             "$options": "i"},
            })
            if clash:
                return jsonify({
                    "status": "error",
                    "message": "You already have a child with that name",
                }), 409
            update["nickname"] = nickname

        if "age" in data:
            age = data.get("age")
            if not isinstance(age, int) or not (3 <= age <= 10):
                return jsonify({"status": "error",
                                "message": "Age must be between 3 and 10"}), 400
            update["age"] = age

        if "avatar_id" in data:
            avatar_id, avatar_error = validate_avatar_id(data.get("avatar_id"))
            if avatar_error:
                return jsonify({"status": "error", "message": avatar_error}), 400
            update["avatar_id"] = avatar_id
            # Clear the legacy face: it takes precedence over the buddy when
            # rendering, so leaving it set would silently discard the parent's
            # new choice.
            update["icon"] = ""

        if "is_active" in data:
            update["is_active"] = bool(data.get("is_active"))

        unset = {}
        if "child_pin" in data:
            raw_pin = data.get("child_pin")
            if raw_pin is None or str(raw_pin).strip() == "":
                # Explicitly clearing the PIN. Removed rather than nulled, so
                # "has a PIN" stays a plain existence check.
                unset["child_pin_hash"] = ""
            else:
                pin_hash, pin_error = validate_child_pin(raw_pin)
                if pin_error:
                    return jsonify({"status": "error",
                                    "message": pin_error}), 400
                update["child_pin_hash"] = pin_hash

        if not update and not unset:
            return jsonify({"status": "error",
                            "message": "Nothing to update"}), 400

        change = {}
        if update:
            change["$set"] = update
        if unset:
            change["$unset"] = unset
        state.db.children.update_one({"child_id": child_id}, change)

        updated = state.db.children.find_one({"child_id": child_id})
        return jsonify({"status": "ok", "child": _serialise(updated)})
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


@bp.delete("/children/<child_id>")
def delete_child(child_id):
    """Permanently remove a child and everything recorded about them.

    Their logs, treasures and completion records go too — leaving those behind
    would orphan rows that no screen can reach and that would silently rejoin
    a future profile if an id were ever reused.
    """
    err = state._db_required()
    if err:
        return err

    try:
        existing = state.db.children.find_one({"child_id": child_id})
        if existing is None:
            return jsonify({"status": "error", "message": "Child not found"}), 404

        removed = {
            "scan_logs": state.db.scan_logs.delete_many(
                {"child_id": child_id}).deleted_count,
            "quiz_logs": state.db.quiz_logs.delete_many(
                {"child_id": child_id}).deleted_count,
            "speech_logs": state.db.speech_logs.delete_many(
                {"child_id": child_id}).deleted_count,
            "treasures": state.db.child_treasures.delete_many(
                {"child_id": child_id}).deleted_count,
            "completions": state.db.learning_completions.delete_many(
                {"child_id": child_id}).deleted_count,
        }
        state.db.children.delete_one({"child_id": child_id})
        return jsonify({"status": "ok", "child_id": child_id, "removed": removed})
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


@bp.get("/children/by-username/<username>")
def get_children_by_username(username):
    """Children behind a parent's username, for the welcome-page Child entry.

    Deliberately PIN-free: this is what lets a young child start learning by
    knowing only their parent's username, no password typing. It exposes only
    nicknames/icons — every parent-only action (adding children, dashboards)
    still sits behind the parent login + PIN gate.
    """
    err = state._db_required()
    if err:
        return err

    try:
        user = state.db.users.find_one({
            "username": (username or "").strip(),
            "role": "parent",
        })
        if user is None:
            return jsonify({"status": "error",
                            "message": "No parent account found with that username"}), 404

        docs = list(state.db.children.find({"parent_id": user["user_id"]}))
        return jsonify({"children": [_serialise(d) for d in docs]})
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


@bp.get("/children/<parent_id>")
def get_children(parent_id):
    err = state._db_required()
    if err:
        return err

    try:
        docs = list(state.db.children.find({"parent_id": parent_id}))
        return jsonify({"children": [_serialise(d) for d in docs]})
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500
