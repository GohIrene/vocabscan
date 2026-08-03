import uuid
from datetime import datetime

from flask import Blueprint, jsonify, request
from pymongo.errors import PyMongoError

import class_sessions as cs

import progress
import state
import vocab

bp = Blueprint("classroom", __name__)

# A class is a small group of young children; this keeps a runaway roster from
# making the tap-your-name grid unusable.
_MAX_ROSTER = 40


def _public_student(s):
    """Roster entry as the apps consume it, with the level bar pre-derived."""
    xp = int(s.get("xp", 0))
    return {
        "student_id": s.get("student_id"),
        "name": s.get("name"),
        "avatar": int(s.get("avatar", 0)),
        "xp": xp,
        "level": progress.level_for_xp(xp),
        "xp_into_level": progress.xp_into_level(xp),
        "xp_per_level": progress.XP_PER_LEVEL,
        "sessions_played": int(s.get("sessions_played", 0)),
        "wins": int(s.get("wins", 0)),
        "badges": s.get("badges") or [],
    }


def _public_classroom(c):
    return {
        "classroom_id": c.get("classroom_id"),
        "name": c.get("name"),
        "teacher_id": c.get("teacher_id"),
        "student_count": len(c.get("students") or []),
        "students": [_public_student(s) for s in (c.get("students") or [])],
        # Words the teacher staged from photos before class; seeded into every
        # session run against this class.
        "prepared_words": c.get("prepared_words") or [],
    }


@bp.post("/classroom/create")
def classroom_create():
    err = state._db_required()
    if err:
        return err

    data = request.get_json() or {}
    teacher_id = (data.get("teacher_id") or "").strip()
    name = (data.get("name") or "").strip()
    if not teacher_id:
        return jsonify({"status": "error", "message": "teacher_id is required"}), 400
    if not name:
        return jsonify({"status": "error", "message": "Class name is required"}), 400

    try:
        classroom_id = str(uuid.uuid4())
        state.db.classrooms.insert_one({
            "classroom_id": classroom_id,
            "teacher_id": teacher_id,
            "name": name,
            "students": [],
            "created_at": datetime.utcnow(),
        })
        return jsonify({"classroom_id": classroom_id, "name": name}), 201
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


@bp.get("/classroom/list/<teacher_id>")
def classroom_list(teacher_id):
    err = state._db_required()
    if err:
        return err

    try:
        docs = list(state.db.classrooms.find({"teacher_id": teacher_id}))
        docs.sort(key=lambda d: d.get("created_at") or datetime.min, reverse=True)
        return jsonify({"classrooms": [_public_classroom(d) for d in docs]})
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


@bp.get("/classroom/<classroom_id>")
def classroom_get(classroom_id):
    err = state._db_required()
    if err:
        return err

    try:
        doc = state.db.classrooms.find_one({"classroom_id": classroom_id})
        if doc is None:
            return jsonify({"status": "error", "message": "Class not found"}), 404
        return jsonify(_public_classroom(doc))
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


@bp.post("/classroom/<classroom_id>/students")
def classroom_add_student(classroom_id):
    err = state._db_required()
    if err:
        return err

    data = request.get_json() or {}
    name = (data.get("name") or "").strip()
    avatar = data.get("avatar", 0)
    if not name:
        return jsonify({"status": "error", "message": "Student name is required"}), 400

    try:
        doc = state.db.classrooms.find_one({"classroom_id": classroom_id})
        if doc is None:
            return jsonify({"status": "error", "message": "Class not found"}), 404

        students = doc.get("students") or []
        if len(students) >= _MAX_ROSTER:
            return jsonify({
                "status": "error",
                "message": f"A class can hold up to {_MAX_ROSTER} students",
            }), 400
        # Names are the join key children tap, so duplicates inside one class
        # would make two children indistinguishable at sign-in.
        if any((s.get("name") or "").lower() == name.lower() for s in students):
            return jsonify({
                "status": "error",
                "message": "Another student in this class already has that name",
            }), 409

        student = progress.new_student(str(uuid.uuid4()), name, avatar)
        state.db.classrooms.update_one(
            {"classroom_id": classroom_id},
            {"$push": {"students": student}},
        )
        return jsonify(_public_student(student)), 201
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


@bp.post("/classroom/<classroom_id>/students/import")
def classroom_import_students(classroom_id):
    """Bulk-add students from a spreadsheet export (one name per row).

    The frontend parses the CSV and sends just the names; this applies the
    same rules as single add — per-class duplicate names rejected, roster
    capped — and reports per-name what happened, so a half-good file still
    imports the good half instead of failing outright.
    """
    err = state._db_required()
    if err:
        return err

    data = request.get_json() or {}
    names = data.get("names") or []
    if not isinstance(names, list) or not names:
        return jsonify({"status": "error", "message": "No names to import"}), 400

    try:
        doc = state.db.classrooms.find_one({"classroom_id": classroom_id})
        if doc is None:
            return jsonify({"status": "error", "message": "Class not found"}), 404

        students = list(doc.get("students") or [])
        existing = {(s.get("name") or "").lower() for s in students}
        added, skipped = [], []

        for raw in names:
            name = str(raw or "").strip()[:20]
            if not name:
                continue
            if name.lower() in existing:
                skipped.append({"name": name, "reason": "duplicate"})
                continue
            if len(students) + len(added) >= _MAX_ROSTER:
                skipped.append({"name": name, "reason": "class_full"})
                continue
            # Cycle avatars so an imported class isn't a wall of identical
            # faces; parents/teachers can't pick per-row in a spreadsheet.
            avatar = (len(students) + len(added)) % 8
            added.append(progress.new_student(str(uuid.uuid4()), name, avatar))
            existing.add(name.lower())

        if added:
            state.db.classrooms.update_one(
                {"classroom_id": classroom_id},
                {"$push": {"students": {"$each": added}}},
            )
        return jsonify({
            "added": len(added),
            "skipped": skipped,
            "student_count": len(students) + len(added),
        })
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


@bp.post("/classroom/<classroom_id>/students/<student_id>/points")
def classroom_adjust_points(classroom_id, student_id):
    """Teacher awards or deducts XP by hand (participation, helping a friend…).

    Deduction floors at 0 rather than going negative, and badges are kept as a
    union with what the new stats earn — once a child has been shown a badge,
    a deduction never takes it back off their screen.
    """
    err = state._db_required()
    if err:
        return err

    data = request.get_json() or {}
    try:
        delta = int(data.get("delta"))
    except (TypeError, ValueError):
        return jsonify({"status": "error", "message": "delta must be a number"}), 400
    if delta == 0:
        return jsonify({"status": "error", "message": "delta must not be zero"}), 400

    try:
        doc = state.db.classrooms.find_one({"classroom_id": classroom_id})
        if doc is None:
            return jsonify({"status": "error", "message": "Class not found"}), 404
        student = next(
            (s for s in (doc.get("students") or [])
             if s.get("student_id") == student_id),
            None,
        )
        if student is None:
            return jsonify({"status": "error", "message": "Student not found"}), 404

        xp = max(0, int(student.get("xp", 0)) + delta)
        stats = {
            "xp": xp,
            "sessions_played": int(student.get("sessions_played", 0)),
            "wins": int(student.get("wins", 0)),
        }
        badges = sorted(set(student.get("badges") or [])
                        | set(progress.earned_badges(stats)))
        level = progress.level_for_xp(xp)

        state.db.classrooms.update_one(
            {"classroom_id": classroom_id, "students.student_id": student_id},
            {"$set": {
                "students.$.xp": xp,
                "students.$.level": level,
                "students.$.badges": badges,
            }},
        )
        return jsonify(_public_student({**student, "xp": xp, "level": level,
                                        "badges": badges}))
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


@bp.post("/classroom/<classroom_id>/prepare-words")
def classroom_prepare_words(classroom_id):
    """Stage words (from pre-class photo uploads) onto the classroom itself.

    Unlike stage_batch_words on a live session, this needs no session at all —
    it's how a teacher preps at home the night before. Every session created
    against this class starts with these words already in its pool.
    """
    err = state._db_required()
    if err:
        return err

    data = request.get_json() or {}
    raw_keys = data.get("english_keys") or []
    keys = [k for k in raw_keys if vocab._is_known(k)]
    if not keys:
        return jsonify({"status": "error",
                        "message": "No recognisable words to save"}), 400

    try:
        res = state.db.classrooms.update_one(
            {"classroom_id": classroom_id},
            {"$addToSet": {"prepared_words": {"$each": keys}}},
        )
        if res.matched_count == 0:
            return jsonify({"status": "error", "message": "Class not found"}), 404
        doc = state.db.classrooms.find_one({"classroom_id": classroom_id})
        return jsonify({"prepared_words": doc.get("prepared_words") or []})
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


@bp.post("/classroom/<classroom_id>/prepare-words/remove")
def classroom_remove_prepared_word(classroom_id):
    # POST body rather than a path segment because keys can contain spaces
    # ("teddy bear").
    err = state._db_required()
    if err:
        return err

    data = request.get_json() or {}
    key = (data.get("english_key") or "").strip()
    if not key:
        return jsonify({"status": "error", "message": "english_key is required"}), 400

    try:
        res = state.db.classrooms.update_one(
            {"classroom_id": classroom_id},
            {"$pull": {"prepared_words": key}},
        )
        if res.matched_count == 0:
            return jsonify({"status": "error", "message": "Class not found"}), 404
        doc = state.db.classrooms.find_one({"classroom_id": classroom_id})
        return jsonify({"prepared_words": doc.get("prepared_words") or []})
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


@bp.delete("/classroom/<classroom_id>/students/<student_id>")
def classroom_remove_student(classroom_id, student_id):
    err = state._db_required()
    if err:
        return err

    try:
        res = state.db.classrooms.update_one(
            {"classroom_id": classroom_id},
            {"$pull": {"students": {"student_id": student_id}}},
        )
        if res.matched_count == 0:
            return jsonify({"status": "error", "message": "Class not found"}), 404
        return jsonify({"status": "ok", "removed": student_id})
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


@bp.delete("/classroom/<classroom_id>")
def classroom_delete(classroom_id):
    err = state._db_required()
    if err:
        return err

    try:
        res = state.db.classrooms.delete_one({"classroom_id": classroom_id})
        if res.deleted_count == 0:
            return jsonify({"status": "error", "message": "Class not found"}), 404
        return jsonify({"status": "ok", "deleted": classroom_id})
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500


@bp.get("/classroom/roster/<code>")
def classroom_roster_by_code(code):
    """Roster behind a live class code, for the student join screen.

    Deliberately unauthenticated: children have no account, and this is what
    lets them tap their name instead of spelling it. It exposes only first
    names and progress for a class someone already holds the code to.
    Answers has_roster:false when a session was started without a class, which
    is the signal for the join screen to fall back to a typed name.
    """
    err = state._db_required()
    if err:
        return err

    try:
        live_code = (code or "").strip().upper()
        cs.expire_stale_sessions({"code": live_code})
        session = state.db.class_sessions.find_one(
            {"code": live_code, "status": {"$ne": "ended"}}
        )
        if session is None:
            return jsonify({"status": "error", "message": "Class not found or already ended"}), 404

        classroom_id = session.get("classroom_id")
        if not classroom_id:
            return jsonify({"has_roster": False, "students": []})

        doc = state.db.classrooms.find_one({"classroom_id": classroom_id})
        if doc is None:
            return jsonify({"has_roster": False, "students": []})

        # Who is already connected, so the grid can show a child their name is
        # in use rather than failing after they tap it.
        taken = {
            (s.get("nickname") or "").lower()
            for s in (session.get("students") or [])
            if s.get("connected")
        }
        students = []
        for s in (doc.get("students") or []):
            pub = _public_student(s)
            pub["taken"] = (pub["name"] or "").lower() in taken
            students.append(pub)

        return jsonify({
            "has_roster": True,
            "classroom_id": classroom_id,
            "classroom_name": doc.get("name"),
            "students": students,
        })
    except PyMongoError:
        return jsonify({"status": "error", "message": "Database error"}), 500
