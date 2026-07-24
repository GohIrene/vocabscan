import re
import uuid
from datetime import datetime

from flask import Blueprint, jsonify, request
from pymongo.errors import PyMongoError

import state
from time_utils import _clean

bp = Blueprint("children", __name__)


@bp.post("/children")
def add_child():
    err = state._db_required()
    if err:
        return err

    data = request.get_json() or {}
    parent_id = (data.get("parent_id") or "").strip()
    nickname = (data.get("nickname") or "").strip()
    age = data.get("age")
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
        state.db.children.insert_one({
            "child_id": child_id,
            "parent_id": parent_id,
            "nickname": nickname,
            "age": age,
            "gender": gender,
            "icon": icon,
            "created_at": datetime.utcnow(),
        })
        return jsonify({"status": "ok", "child_id": child_id, "nickname": nickname, "age": age}), 201
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
        return jsonify({"children": [_clean(d) for d in docs]})
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


@bp.get("/children/<parent_id>")
def get_children(parent_id):
    err = state._db_required()
    if err:
        return err

    try:
        docs = list(state.db.children.find({"parent_id": parent_id}))
        return jsonify({"children": [_clean(d) for d in docs]})
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500
