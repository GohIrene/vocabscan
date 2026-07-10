from gtts import gTTS
import os

os.makedirs("static/audio", exist_ok=True)

words = {
    "bottle":         {"en": "Bottle",              "ms": "Botol",              "zh": "瓶子"},
    "cup":            {"en": "Cup",                 "ms": "Cawan",              "zh": "杯子"},
    "spoon":          {"en": "Spoon",               "ms": "Sudu",               "zh": "勺子"},
    "plate":          {"en": "Plate",               "ms": "Pinggan",            "zh": "盘子"},
    "remote_control": {"en": "Remote Control",      "ms": "Alat Kawalan Jauh",  "zh": "遥控器"},
    "book":           {"en": "Book",                "ms": "Buku",               "zh": "书"},
    "scissors":       {"en": "Scissors",            "ms": "Gunting",            "zh": "剪刀"},
    "pen":            {"en": "Pen",                 "ms": "Pen",                "zh": "钢笔"},
    "ruler":          {"en": "Ruler",               "ms": "Pembaris",           "zh": "尺子"},
    "backpack":       {"en": "Backpack",            "ms": "Beg Galas",          "zh": "书包"},
    "chair":          {"en": "Chair",                "ms": "Kerusi",             "zh": "椅子"},
    "table":          {"en": "Table",                "ms": "Meja",               "zh": "桌子"},
    "clock":          {"en": "Clock",                "ms": "Jam",                "zh": "时钟"},
    "lamp":           {"en": "Lamp",                 "ms": "Lampu",              "zh": "灯"},
    "bowl":           {"en": "Bowl",                 "ms": "Mangkuk",            "zh": "碗"},
    "fork":           {"en": "Fork",                 "ms": "Garpu",              "zh": "叉子"},
    "knife":          {"en": "Knife",                "ms": "Pisau",              "zh": "刀"},
    "apple":          {"en": "Apple",                "ms": "Epal",               "zh": "苹果"},
    "banana":         {"en": "Banana",               "ms": "Pisang",             "zh": "香蕉"},
    "orange":         {"en": "Orange",                "ms": "Oren",               "zh": "橙"},
    "bread":          {"en": "Bread",                "ms": "Roti",               "zh": "面包"},
    "toothbrush":     {"en": "Toothbrush",           "ms": "Berus Gigi",         "zh": "牙刷"},
    "umbrella":       {"en": "Umbrella",             "ms": "Payung",             "zh": "雨伞"},
    "shoe":           {"en": "Shoe",                 "ms": "Kasut",              "zh": "鞋子"},
    "laptop":         {"en": "Laptop",               "ms": "Komputer Riba",      "zh": "笔记本电脑"},
    "mobile_phone":   {"en": "Mobile Phone",         "ms": "Telefon Bimbit",     "zh": "手机"},
    "keyboard":       {"en": "Keyboard",             "ms": "Papan Kekunci",      "zh": "键盘"},
    "ball":           {"en": "Ball",                 "ms": "Bola",               "zh": "球"},
    "teddy_bear":     {"en": "Teddy Bear",           "ms": "Teddy Bear",         "zh": "泰迪熊"},
    "glasses":        {"en": "Glasses",              "ms": "Cermin Mata",        "zh": "眼镜"},
}

generated = 0
skipped = 0

for key, translations in words.items():
    for lang_code, word in translations.items():
        gtts_lang = {"en": "en", "ms": "ms", "zh": "zh-CN"}[lang_code]
        filename = f"static/audio/{key}_{lang_code}.mp3"
        if os.path.exists(filename):
            print(f"Skipped (already exists): {filename}")
            skipped += 1
            continue
        tts = gTTS(text=word, lang=gtts_lang)
        tts.save(filename)
        print(f"Created: {filename}")
        generated += 1

print(f"Done! {generated} audio files generated, {skipped} skipped.")
