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
