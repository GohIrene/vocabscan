from flask import Blueprint, jsonify, request

import vocab

bp = Blueprint("quiz", __name__)


@bp.get("/quiz/distractors")
def quiz_distractors():
    """Real vocab-based wrong answers for a quiz question — shared by Home
    mode (quiz_practice_screen.dart) and Class Code (quiz_logic._build_quiz), so
    neither has to hardcode a fixed wrong-answer list."""
    english_key = request.args.get("english_key", "")
    field = request.args.get("field", "")
    answer = request.args.get("answer", "")
    n = request.args.get("n", "3")

    if field not in ("malay_word", "chinese_word", "english_word"):
        return jsonify({"status": "error", "message": "Invalid field"}), 400
    if not english_key or not answer:
        return jsonify({"status": "error", "message": "english_key and answer are required"}), 400
    try:
        n = max(1, min(int(n), 10))
    except ValueError:
        n = 3

    options = vocab._random_distractors(field, answer, english_key, n)
    return jsonify({"distractors": options})


@bp.get("/quiz/questions")
def quiz_questions():
    """All three MCQ distractor sets for one scanned word in a single request,
    so the Home-mode quiz screen makes one round trip instead of three. Built
    from the in-memory vocab cache (no per-request DB scans). The per-field
    `/quiz/distractors` endpoint above is kept for backward compatibility."""
    english_key = request.args.get("english_key", "")
    n = request.args.get("n", "3")
    if not english_key:
        return jsonify({"status": "error", "message": "english_key is required"}), 400
    try:
        n = max(1, min(int(n), 10))
    except ValueError:
        n = 3

    item = vocab._resolve_vocab(english_key)
    mal = item.get("malay_word", "")
    chi = item.get("chinese_word", "")
    eng = item.get("english_word", "")
    return jsonify({
        "english_key": english_key,
        "english_word": eng,
        "malay_word": mal,
        "chinese_word": chi,
        "distractors": {
            "malay_word": vocab._random_distractors("malay_word", mal, english_key, n),
            "chinese_word": vocab._random_distractors("chinese_word", chi, english_key, n),
            "english_word": vocab._random_distractors("english_word", eng, english_key, n),
        },
    })
