import uuid
from datetime import datetime

from flask import request
from flask_socketio import emit, join_room
from pymongo.errors import PyMongoError

import class_sessions as cs
import quiz_logic
import state
import vocab

socketio = state.socketio


@socketio.on("connect_session")
def on_connect_session(data):
    if state.db is None:
        return
    data = data or {}
    code = (data.get("code") or "").strip().upper()
    role = data.get("role")
    nickname = (data.get("nickname") or "").strip()

    try:
        session = state.db.class_sessions.find_one({"code": code, "status": {"$ne": "ended"}})
        if session is None:
            emit("session_error", {"message": "Class not found or ended"})
            return

        join_room(code)

        if role == "student" and nickname:
            state.db.class_sessions.update_one(
                {"session_id": session["session_id"], "students.nickname": nickname},
                {"$set": {"students.$.connected": True, "students.$.sid": request.sid}},
            )
            session = state.db.class_sessions.find_one({"session_id": session["session_id"]})

            # Reconnection contract: re-deliver a live quiz to this socket only if
            # this student hasn't answered it yet.
            me = next(
                (s for s in session.get("students", []) if s.get("nickname") == nickname),
                None,
            )
            quiz = session.get("current_quiz")
            if session.get("status") == "quiz" and quiz:
                if me and not me.get("answered_current"):
                    emit("new_quiz", {
                        "quiz_id": quiz["quiz_id"],
                        "prompt": quiz["prompt"],
                        "options": quiz["options"],
                    })

            # Same contract for a live summary quiz: resend it with the questions
            # this student already answered marked, so they resume where they
            # left off with their score intact.
            summary = session.get("summary_quiz")
            if session.get("status") == "summary" and summary:
                done = (me.get("summary_answered") or []) if me else []
                right = (me.get("summary_correct") or []) if me else []
                questions = summary.get("questions", [])
                if len(done) < len(questions):
                    emit("summary_quiz", {
                        "summary_id": summary["summary_id"],
                        "total": len(questions),
                        "answered": done,
                        # Score so far, so the end-of-recap card is right for a
                        # student who reconnected partway through rather than
                        # counting only what they answered after reconnecting.
                        "correct_count": len(right),
                        "questions": [
                            {"quiz_id": q["quiz_id"], "prompt": q["prompt"],
                             "options": q["options"]}
                            for q in questions
                        ],
                    })

            emit(
                "student_joined",
                {
                    "nickname": nickname,
                    "student_count": cs._count_connected(session),
                    "word_count": cs._count_words(session),
                },
                to=code,
            )
        else:
            # Teacher: sync current connected count to this socket only (no phantom join).
            # word_count comes from the session doc rather than the teacher
            # counting their own pushes, so the summary-quiz button is correct
            # immediately on (re)connect instead of resetting to disabled.
            emit("student_joined", {
                "nickname": None,
                "student_count": cs._count_connected(session),
                "word_count": cs._count_words(session),
            })
    except PyMongoError:
        emit("session_error", {"message": "Could not connect to the class. Please try again."})


@socketio.on("push_quiz")
def on_push_quiz(data):
    if state.db is None:
        return
    data = data or {}
    session_id = data.get("session_id")
    english_key = (data.get("english_key") or "").strip()

    # A failed/low-confidence scan used to arrive here as an empty key, which
    # got recorded in word_keys and produced a quiz with a blank prompt and a
    # blank option — and later a summary quiz made of those blanks. Reject it
    # at the door so nothing unquizzable ever enters the session.
    if not vocab._is_known(english_key):
        emit("session_error", {
            "message": "That word isn't in the vocabulary list — try scanning again."
        })
        return

    try:
        session = state.db.class_sessions.find_one({"session_id": session_id, "status": {"$ne": "ended"}})
        if session is None:
            emit("session_error", {"message": "Session not active"})
            return

        quiz = quiz_logic._build_quiz(english_key)
        # Archive the previously-live quiz so session reports can count every quiz
        # that was pushed, not just the final one (end_session archives the last).
        # A live summary quiz is superseded by a normal quiz, so archive it too.
        push_ops = {}
        if session.get("current_quiz"):
            push_ops["quiz_history"] = session["current_quiz"]
        if session.get("summary_quiz"):
            push_ops["summary_history"] = session["summary_quiz"]

        update = {
            "$set": {
                "current_quiz": quiz,
                "summary_quiz": None,
                "status": "quiz",
                "students.$[].answered_current": False,
            },
            "$addToSet": {"word_keys": english_key},
        }
        if push_ops:
            update["$push"] = push_ops
        state.db.class_sessions.update_one({"session_id": session_id}, update)
        # Post-push distinct word count, so the teacher's summary-quiz gate is
        # server-derived rather than a local tally of their own pushes.
        word_count = len({k for k in (session.get("word_keys") or []) if vocab._is_known(k)}
                         | {english_key})
        emit(
            "new_quiz",
            {
                "quiz_id": quiz["quiz_id"],
                "prompt": quiz["prompt"],
                "options": quiz["options"],
                "word_count": word_count,
            },
            to=session["code"],
        )
    except PyMongoError:
        # Teacher only — students never learned a quiz was coming.
        emit("session_error", {"message": "Could not send the quiz. Please try again."})


@socketio.on("submit_answer")
def on_submit_answer(data):
    if state.db is None:
        return
    data = data or {}
    session_id = data.get("session_id")
    nickname = data.get("nickname")
    quiz_id = data.get("quiz_id")
    chosen = data.get("chosen")

    try:
        session = state.db.class_sessions.find_one({"session_id": session_id})
        if session is None:
            return

        quiz = session.get("current_quiz")
        if not quiz or quiz.get("quiz_id") != quiz_id:
            emit("answer_rejected", {"reason": "stale"})
            return

        me = next((s for s in session.get("students", []) if s.get("nickname") == nickname), None)
        if me is None:
            return
        if me.get("answered_current"):
            emit("answer_rejected", {"reason": "already_answered"})
            return

        correct = chosen == quiz.get("correct_answer")
        update = {"$set": {"students.$.answered_current": True}}
        if correct:
            update["$inc"] = {"students.$.score": 1}
        state.db.class_sessions.update_one(
            {"session_id": session_id, "students.nickname": nickname},
            update,
        )
        session = state.db.class_sessions.find_one({"session_id": session_id})

        emit("answer_result", {"correct": correct, "correct_answer": quiz.get("correct_answer")})
        emit(
            "answer_received",
            {
                "nickname": nickname,
                "answered_count": cs._count_answered(session),
                "student_count": cs._count_connected(session),
            },
            to=session["code"],
        )
    except PyMongoError:
        emit("answer_rejected", {"reason": "server_error"})


@socketio.on("push_summary_quiz")
def on_push_summary_quiz(data):
    """Send a multi-question recap covering every word the class has seen.

    Available at ANY point once at least one word has been pushed — not only at
    the end — so a teacher can run a consolidation round mid-lesson. Students
    work through it at their own pace; scores roll into the same leaderboard.
    """
    if state.db is None:
        return
    data = data or {}
    session_id = data.get("session_id")

    try:
        session = state.db.class_sessions.find_one(
            {"session_id": session_id, "status": {"$ne": "ended"}}
        )
        if session is None:
            emit("session_error", {"message": "Session not active"})
            return

        # Only keys the vocab cache can build a real question from. Older
        # sessions can hold a blank key from a failed scan; recapping it would
        # show the class an empty question.
        word_keys = [k for k in (session.get("word_keys") or []) if vocab._is_known(k)]
        if not word_keys:
            emit("session_error", {
                "message": "Send at least one word to the class before the summary quiz."
            })
            return

        # One fresh question per word covered (patterns/distractors are re-rolled,
        # so the recap isn't a replay of the identical questions). Capped so a
        # long lesson can't produce an exhausting quiz for young children.
        keys = word_keys[-cs._MAX_SUMMARY_QUESTIONS:]
        questions = [quiz_logic._build_quiz(k) for k in keys]
        summary = {
            "summary_id": str(uuid.uuid4()),
            "questions": questions,
            "pushed_at": datetime.utcnow(),
        }

        push_ops = {}
        if session.get("current_quiz"):
            push_ops["quiz_history"] = session["current_quiz"]
        if session.get("summary_quiz"):
            push_ops["summary_history"] = session["summary_quiz"]

        update = {
            "$set": {
                "summary_quiz": summary,
                "current_quiz": None,
                "status": "summary",
                "students.$[].summary_answered": [],
                "students.$[].summary_correct": [],
            },
        }
        if push_ops:
            update["$push"] = push_ops
        state.db.class_sessions.update_one({"session_id": session_id}, update)

        emit(
            "summary_quiz",
            {
                "summary_id": summary["summary_id"],
                "total": len(questions),
                # correct_answer is deliberately omitted — scoring is server-side.
                "questions": [
                    {"quiz_id": q["quiz_id"], "prompt": q["prompt"], "options": q["options"]}
                    for q in questions
                ],
            },
            to=session["code"],
        )
    except PyMongoError:
        emit("session_error", {"message": "Could not send the summary quiz. Please try again."})
    except Exception as e:
        # Building N questions at once has more ways to fail than a single
        # push. Without this the handler died inside Socket.IO and the teacher
        # saw a button that simply did nothing.
        print(f"push_summary_quiz failed: {e}")
        emit("session_error", {"message": "Could not build the summary quiz. Please try again."})


@socketio.on("submit_summary_answer")
def on_submit_summary_answer(data):
    """Score one question of the summary quiz.

    Students move through the recap independently, so answers are keyed by
    quiz_id rather than a single 'current' question. $addToSet on
    summary_answered makes re-scoring the same question impossible even if two
    submissions race.
    """
    if state.db is None:
        return
    data = data or {}
    session_id = data.get("session_id")
    nickname = data.get("nickname")
    summary_id = data.get("summary_id")
    quiz_id = data.get("quiz_id")
    chosen = data.get("chosen")

    try:
        session = state.db.class_sessions.find_one({"session_id": session_id})
        if session is None:
            return

        summary = session.get("summary_quiz")
        if not summary or summary.get("summary_id") != summary_id:
            emit("answer_rejected", {"reason": "stale"})
            return

        question = next(
            (q for q in summary.get("questions", []) if q.get("quiz_id") == quiz_id),
            None,
        )
        if question is None:
            emit("answer_rejected", {"reason": "stale"})
            return

        me = next(
            (s for s in session.get("students", []) if s.get("nickname") == nickname),
            None,
        )
        if me is None:
            return
        if quiz_id in (me.get("summary_answered") or []):
            emit("answer_rejected", {"reason": "already_answered"})
            return

        correct = chosen == question.get("correct_answer")
        update = {"$addToSet": {"students.$.summary_answered": quiz_id}}
        if correct:
            # Tracked as quiz_ids rather than a counter for the same reason as
            # summary_answered: $addToSet makes a duplicate submission a no-op,
            # so a reconnecting student's replayed score can't be inflated.
            update["$addToSet"]["students.$.summary_correct"] = quiz_id
            update["$inc"] = {"students.$.score": 1}
        state.db.class_sessions.update_one(
            {"session_id": session_id, "students.nickname": nickname},
            update,
        )
        session = state.db.class_sessions.find_one({"session_id": session_id})

        total = len(summary.get("questions", []))
        emit("summary_answer_result", {
            "quiz_id": quiz_id,
            "correct": correct,
            "correct_answer": question.get("correct_answer"),
        })
        emit(
            "summary_progress",
            {
                "nickname": nickname,
                "finished_count": cs._count_summary_finished(session, total),
                "student_count": cs._count_connected(session),
                "total": total,
            },
            to=session["code"],
        )
    except PyMongoError:
        emit("answer_rejected", {"reason": "server_error"})


@socketio.on("end_session")
def on_end_session(data):
    if state.db is None:
        return
    data = data or {}
    session_id = data.get("session_id")

    try:
        session = state.db.class_sessions.find_one({"session_id": session_id})
        if session is None:
            return

        leaderboard = sorted(
            [{"nickname": s.get("nickname"), "score": s.get("score", 0)}
             for s in session.get("students", [])],
            key=lambda x: x["score"],
            reverse=True,
        )

        update = {"$set": {
            "status": "ended",
            "ended_at": datetime.utcnow(),
            "current_quiz": None,
            "summary_quiz": None,
        }}
        push_ops = {}
        if session.get("current_quiz"):
            push_ops["quiz_history"] = session["current_quiz"]
        if session.get("summary_quiz"):
            push_ops["summary_history"] = session["summary_quiz"]
        if push_ops:
            update["$push"] = push_ops
        state.db.class_sessions.update_one({"session_id": session_id}, update)

        emit("session_ended", {"leaderboard": leaderboard}, to=session["code"])
    except PyMongoError:
        # Teacher only — nothing was changed in Mongo, safe to just retry.
        emit("session_error", {"message": "Could not end the session. Please try again."})


@socketio.on("disconnect")
def on_disconnect():
    if state.db is None:
        return
    sid = request.sid
    try:
        session = state.db.class_sessions.find_one({"students.sid": sid})
        if session is None:
            return

        nickname = next(
            (s.get("nickname") for s in session.get("students", []) if s.get("sid") == sid),
            None,
        )
        state.db.class_sessions.update_one(
            {"session_id": session["session_id"], "students.sid": sid},
            {"$set": {"students.$.connected": False}},
        )
        session = state.db.class_sessions.find_one({"session_id": session["session_id"]})
        emit(
            "student_left",
            {"nickname": nickname, "student_count": cs._count_connected(session)},
            to=session["code"],
        )
    except PyMongoError as e:
        # The disconnecting client is already gone — no one to answer. Just
        # log it; their `connected` flag simply won't flip to False this one
        # time, which self-heals on their next reconnect or action.
        print(f"disconnect handler: Mongo error while marking sid {sid} disconnected: {e}")
