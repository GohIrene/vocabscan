from gtts import gTTS
import os

os.makedirs("static/audio", exist_ok=True)

words = {
    "bottle":         {"en": "Bottle",              "ms": "Botol",              "zh": "瓶子"},
    "cup":            {"en": "Cup",                 "ms": "Cawan",              "zh": "杯子"},
    "spoon":          {"en": "Spoon",               "ms": "Sudu",              "zh": "勺子"},
    "plate":          {"en": "Plate",               "ms": "Pinggan",            "zh": "盘子"},
    "remote_control": {"en": "Remote Control",      "ms": "Alat Kawalan Jauh",  "zh": "遥控器"},
    "book":           {"en": "Book",                "ms": "Buku",               "zh": "书"},
    "pencil":         {"en": "Pencil",              "ms": "Pensel",             "zh": "铅笔"},
    "pen":            {"en": "Pen",                 "ms": "Pen",                "zh": "钢笔"},
    "ruler":          {"en": "Ruler",               "ms": "Pembaris",           "zh": "尺子"},
    "backpack":       {"en": "Backpack",            "ms": "Beg Galas",          "zh": "书包"},
}

for key, translations in words.items():
    for lang_code, word in translations.items():
        gtts_lang = {"en": "en", "ms": "ms", "zh": "zh-CN"}[lang_code]
        filename = f"static/audio/{key}_{lang_code}.mp3"
        tts = gTTS(text=word, lang=gtts_lang)
        tts.save(filename)
        print(f"Created: {filename}")

print("Done! 30 audio files generated.")
