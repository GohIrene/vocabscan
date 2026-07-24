"""Family Code routes: the parent's side (view/regenerate) and the child's
side (redeem a code, then optionally clear a child PIN).

The child-side routes are deliberately unauthenticated — that is the whole
point of a family code, since a five-year-old cannot log in. They are kept
narrow to compensate: a code returns nothing but the nicknames, ages and
avatars needed to draw the picker, never the parent's account details, never
a PIN hash, and never a deactivated child.
"""

from flask import Blueprint, jsonify, request
from pymongo.errors import PyMongoError

import family
import state
from child_profile import apply_child_defaults, check_child_pin
from time_utils import _clean

bp = Blueprint("family", __name__)


def _active_children(parent_id):
    """This parent's active children, serialised for the profile picker.

    `is_active` is filtered after defaults are applied rather than in the
    Mongo query, because a profile created before Home Adventure has no
    is_active field at all — a query for `is_active: True` would silently
    hide every legacy child.
    """
    docs = list(state.db.children.find({"parent_id": parent_id}))
    children = [apply_child_defaults(_clean(d)) for d in docs]
    return [c for c in children if c.get("is_active")]


@bp.get("/family-code/<parent_id>")
def get_family_code(parent_id):
    """The parent's family code, assigning one on first view if needed."""
    err = state._db_required()
    if err:
        return err

    try:
        user = state.db.users.find_one({"user_id": parent_id, "role": "parent"})
        if user is None:
            return jsonify({"status": "error",
                            "message": "Parent account not found"}), 404

        code = family.ensure_family_code(user)
        if not code:
            return jsonify({"status": "error",
                            "message": "Could not assign a family code"}), 500

        return jsonify({
            "status": "ok",
            "parent_id": parent_id,
            "family_code": code,
        })
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


@bp.post("/family-code/regenerate")
def regenerate_family_code():
    """Issue a new code, immediately invalidating the old one.

    Sensitive — any child still holding the previous code loses access — so
    the UI gates this behind the parent PIN dialog before calling it. The
    endpoint itself trusts the caller-supplied parent_id, consistent with the
    rest of this API's ID-passing scheme.
    """
    err = state._db_required()
    if err:
        return err

    data = request.get_json() or {}
    parent_id = (data.get("parent_id") or "").strip()
    if not parent_id:
        return jsonify({"status": "error", "message": "parent_id is required"}), 400

    try:
        user = state.db.users.find_one({"user_id": parent_id, "role": "parent"})
        if user is None:
            return jsonify({"status": "error",
                            "message": "Parent account not found"}), 404

        code = family.set_new_family_code(parent_id)
        if not code:
            return jsonify({"status": "error",
                            "message": "Could not assign a family code"}), 500

        return jsonify({"status": "ok", "parent_id": parent_id,
                        "family_code": code})
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


@bp.post("/child-access/family")
def child_access_by_family_code():
    """Redeem a family code: the active children a child may pick from.

    Returns only what the picker draws. `has_pin` tells the client whether to
    prompt for a child PIN; the hash itself never leaves the server (see
    apply_child_defaults).
    """
    err = state._db_required()
    if err:
        return err

    data = request.get_json() or {}
    code = family.normalise_code(data.get("family_code"))
    if not code:
        return jsonify({"status": "error",
                        "message": "Family code is required"}), 400

    try:
        parent = family.find_parent_by_code(code)
        if parent is None:
            # Same message whether the code is malformed or simply unknown —
            # there is nothing useful to tell a child apart from "check it".
            return jsonify({"status": "error",
                            "message": "That family code was not found"}), 404

        children = _active_children(parent["user_id"])
        if not children:
            return jsonify({
                "status": "error",
                "message": "No children on this family code yet — "
                           "ask a grown-up to add you first!",
            }), 404

        return jsonify({
            "status": "ok",
            "parent_id": parent["user_id"],
            "family_code": code,
            "children": children,
        })
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


@bp.post("/child-access/verify-pin")
def verify_child_pin():
    """Check a child's optional 4-digit PIN before entering Home Mode.

    A child with no PIN passes automatically, so the client can call this
    unconditionally rather than branching on has_pin.
    """
    err = state._db_required()
    if err:
        return err

    data = request.get_json() or {}
    child_id = (data.get("child_id") or "").strip()
    pin = data.get("pin")
    if not child_id:
        return jsonify({"status": "error", "message": "child_id is required"}), 400

    try:
        child = state.db.children.find_one({"child_id": child_id})
        if child is None:
            return jsonify({"status": "error", "message": "Child not found"}), 404
        # A deactivated profile must not be reachable even with the right PIN.
        if not apply_child_defaults(_clean(child)).get("is_active"):
            return jsonify({"status": "error", "message": "Child not found"}), 404

        if not check_child_pin(child, pin):
            return jsonify({"status": "error", "message": "That PIN is not right"}), 401

        return jsonify({"status": "ok", "child_id": child_id})
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500
