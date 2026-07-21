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

    if not parent_id:
        return jsonify({"status": "error", "message": "parent_id is required"}), 400
    if not nickname:
        return jsonify({"status": "error", "message": "nickname is required"}), 400

    try:
        child_id = str(uuid.uuid4())
        state.db.children.insert_one({
            "child_id": child_id,
            "parent_id": parent_id,
            "nickname": nickname,
            "age": age,
            "created_at": datetime.utcnow(),
        })
        return jsonify({"status": "ok", "child_id": child_id, "nickname": nickname, "age": age}), 201
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
