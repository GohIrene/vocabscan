import random
import uuid
from datetime import datetime

import vocab

# The three CP1 question patterns, mirroring quiz_practice_screen.dart.
_QUESTION_PATTERNS = ("en_ms", "en_zh", "zh_en")


def _build_quiz(english_key):
    """Build one MCQ server-side. Returns the full quiz dict (incl. answer)."""
    item = vocab._resolve_vocab(english_key)
    eng = item.get("english_word") or english_key
    mal = item.get("malay_word") or ""
    chi = item.get("chinese_word") or ""

    pattern = random.choice(_QUESTION_PATTERNS)
    if pattern == "en_ms":
        prompt = f'What is "{eng}" in Malay?'
        answer = mal
        field = "malay_word"
    elif pattern == "en_zh":
        prompt = f'What is "{eng}" in Chinese?'
        answer = chi
        field = "chinese_word"
    else:  # zh_en
        prompt = f'Which English word matches "{chi}"?'
        answer = eng
        field = "english_word"

    options = vocab._random_distractors(field, answer, english_key, 3) + [answer]
    random.shuffle(options)

    return {
        "quiz_id": str(uuid.uuid4()),
        "english_key": english_key,
        "prompt": prompt,
        "options": options,
        "correct_answer": answer,
        "pushed_at": datetime.utcnow(),
    }
