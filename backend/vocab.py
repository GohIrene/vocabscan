import random

from pymongo.errors import PyMongoError

import state

VOCABULARY = {
    "apple": {"english_word": "Apple", "malay_word": "Epal", "chinese_word": "苹果"},
    "backpack": {"english_word": "Backpack", "malay_word": "Beg Galas", "chinese_word": "书包"},
    "ball": {"english_word": "Ball", "malay_word": "Bola", "chinese_word": "球"},
    "banana": {"english_word": "Banana", "malay_word": "Pisang", "chinese_word": "香蕉"},
    "book": {"english_word": "Book", "malay_word": "Buku", "chinese_word": "书"},
    "bottle": {"english_word": "Bottle", "malay_word": "Botol", "chinese_word": "瓶子"},
    "bowl": {"english_word": "Bowl", "malay_word": "Mangkuk", "chinese_word": "碗"},
    "bread": {"english_word": "Bread", "malay_word": "Roti", "chinese_word": "面包"},
    "chair": {"english_word": "Chair", "malay_word": "Kerusi", "chinese_word": "椅子"},
    "clock": {"english_word": "Clock", "malay_word": "Jam", "chinese_word": "时钟"},
    "cup": {"english_word": "Cup", "malay_word": "Cawan", "chinese_word": "杯子"},
    "fork": {"english_word": "Fork", "malay_word": "Garpu", "chinese_word": "叉子"},
    "glasses": {"english_word": "Glasses", "malay_word": "Cermin Mata", "chinese_word": "眼镜"},
    "keyboard": {"english_word": "Keyboard", "malay_word": "Papan Kekunci", "chinese_word": "键盘"},
    "knife": {"english_word": "Knife", "malay_word": "Pisau", "chinese_word": "刀"},
    "lamp": {"english_word": "Lamp", "malay_word": "Lampu", "chinese_word": "灯"},
    "laptop": {"english_word": "Laptop", "malay_word": "Komputer Riba", "chinese_word": "笔记本电脑"},
    "mobile_phone": {"english_word": "Mobile Phone", "malay_word": "Telefon Bimbit", "chinese_word": "手机"},
    "orange": {"english_word": "Orange", "malay_word": "Oren", "chinese_word": "橙"},
    "pen": {"english_word": "Pen", "malay_word": "Pen", "chinese_word": "钢笔"},
    "plate": {"english_word": "Plate", "malay_word": "Pinggan", "chinese_word": "盘子"},
    "remote_control": {"english_word": "Remote Control", "malay_word": "Alat Kawalan Jauh", "chinese_word": "遥控器"},
    "ruler": {"english_word": "Ruler", "malay_word": "Pembaris", "chinese_word": "尺子"},
    "scissors": {"english_word": "Scissors", "malay_word": "Gunting", "chinese_word": "剪刀"},
    "shoe": {"english_word": "Shoe", "malay_word": "Kasut", "chinese_word": "鞋子"},
    "spoon": {"english_word": "Spoon", "malay_word": "Sudu", "chinese_word": "勺子"},
    "table": {"english_word": "Table", "malay_word": "Meja", "chinese_word": "桌子"},
    "teddy_bear": {"english_word": "Teddy Bear", "malay_word": "Teddy Bear", "chinese_word": "泰迪熊"},
    "toothbrush": {"english_word": "Toothbrush", "malay_word": "Berus Gigi", "chinese_word": "牙刷"},
    "umbrella": {"english_word": "Umbrella", "malay_word": "Payung", "chinese_word": "雨伞"},
}

# The vocab collection is 30 rows that never change at runtime, yet it was
# re-read from Mongo on every scan and three times per quiz. Load it once at
# startup into a dict keyed by english_key; fall back to the bundled VOCABULARY
# map when the DB is empty/unavailable. _resolve_vocab and _random_distractors
# read from this cache instead of hitting Mongo per request.
_VOCAB_CACHE = {}


def load_vocab_cache():
    """Populate _VOCAB_CACHE from Mongo (DB-first), then fill any gaps from the
    in-memory VOCABULARY so recognition/quizzes still work without Mongo."""
    global _VOCAB_CACHE
    cache = {}
    if state.db is not None:
        try:
            for doc in state.db.vocab.find():
                key = doc.get("english_key")
                if key:
                    cache[key] = {
                        "english_word": doc.get("english_word", key),
                        "malay_word": doc.get("malay_word", ""),
                        "chinese_word": doc.get("chinese_word", ""),
                    }
        except PyMongoError as e:
            print(f"Vocab cache load failed, using in-memory fallback: {e}")
    for key, item in VOCABULARY.items():
        cache.setdefault(key, item)
    _VOCAB_CACHE = cache
    print(f"Vocab cache ready: {len(_VOCAB_CACHE)} words.")


def _resolve_vocab(english_key):
    """Look up a word's translations from the in-memory vocab cache (loaded once
    at startup, DB-first; see load_vocab_cache)."""
    item = _VOCAB_CACHE.get(english_key)
    if item is None:
        return {"english_word": english_key, "malay_word": "", "chinese_word": ""}
    return item


def _is_known(english_key):
    """True only for a key the vocab cache can actually build a quiz from.
    Guards against a blank/unrecognised key reaching push_quiz and producing a
    question with an empty prompt and an empty option."""
    return bool(english_key) and english_key in _VOCAB_CACHE


def _audio_urls(english_key):
    return {
        "en": f"/static/audio/{english_key}_en.mp3",
        "ms": f"/static/audio/{english_key}_ms.mp3",
        "zh": f"/static/audio/{english_key}_zh.mp3",
    }


def _random_distractors(field, answer, english_key, n):
    """Pick up to n distinct `field` values from the in-memory vocab cache,
    excluding the answer and the word itself. Never hardcoded word lists."""
    values = []
    seen = set()
    for key, item in _VOCAB_CACHE.items():
        if key == english_key:
            continue
        v = item.get(field)
        if v and v != answer and v not in seen:
            seen.add(v)
            values.append(v)
    random.shuffle(values)
    return values[:n]
