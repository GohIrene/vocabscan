import uuid
from datetime import datetime

from flask import Blueprint, jsonify, request
from pymongo.errors import PyMongoError
from werkzeug.security import check_password_hash, generate_password_hash

import state

bp = Blueprint("auth", __name__)


@bp.post("/auth/register")
def register():
    err = state._db_required()
    if err:
        return err

    data = request.get_json() or {}
    username = (data.get("username") or "").strip()
    pin = str(data.get("pin") or "")
    role = data.get("role") or ""

    if not username:
        return jsonify({"status": "error", "message": "Username is required"}), 400
    if not pin.isdigit() or not (4 <= len(pin) <= 6):
        return jsonify({"status": "error", "message": "PIN must be 4-6 digits"}), 400
    if role not in ("parent", "teacher"):
        return jsonify({"status": "error", "message": "Role must be 'parent' or 'teacher'"}), 400

    try:
        if state.db.users.find_one({"username": username}):
            return jsonify({"status": "error", "message": "Username already taken"}), 409

        user_id = str(uuid.uuid4())
        state.db.users.insert_one({
            "user_id": user_id,
            "username": username,
            "pin_hash": generate_password_hash(pin),
            "role": role,
            "created_at": datetime.utcnow(),
        })
        return jsonify({"status": "ok", "user_id": user_id, "username": username, "role": role}), 201
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


@bp.post("/auth/login")
def login():
    err = state._db_required()
    if err:
        return err

    data = request.get_json() or {}
    username = (data.get("username") or "").strip()
    pin = str(data.get("pin") or "")

    try:
        user = state.db.users.find_one({"username": username})
        if not user or not check_password_hash(user["pin_hash"], pin):
            return jsonify({"status": "error", "message": "Invalid username or PIN"}), 401
        return jsonify({"status": "ok", "user_id": user["user_id"], "username": user["username"], "role": user["role"]})
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


@bp.post("/auth/verify-pin")
def verify_pin():
    """Re-checks a PIN for an already-logged-in session, without issuing a
    fresh login. Used to gate sensitive parent actions (e.g. Add Child) mid-
    session, since a child may be holding the device after the parent logged in."""
    err = state._db_required()
    if err:
        return err

    data = request.get_json() or {}
    username = (data.get("username") or "").strip()
    pin = str(data.get("pin") or "")

    try:
        user = state.db.users.find_one({"username": username})
        if not user or not check_password_hash(user["pin_hash"], pin):
            return jsonify({"status": "error", "message": "Incorrect PIN"}), 401
        return jsonify({"status": "ok"})
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500
