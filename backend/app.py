from flask import Flask, jsonify
from flask_cors import CORS


# Create the Flask application.
app = Flask(__name__)
app.json.ensure_ascii = False

# Allow the frontend to call this backend from a different port/domain during development.
CORS(app)

# Keep Chinese characters readable in JSON responses instead of escaping them.
app.json.ensure_ascii = False


# Temporary vocabulary data for frontend-backend connection testing.
# Later, this can be replaced by database records or AI model prediction results.
VOCABULARY = {
    "bottle": {
        "english_word": "Bottle",
        "malay_word": "Botol",
        "chinese_word": "瓶子",
    },
    "cup": {
        "english_word": "Cup",
        "malay_word": "Cawan",
        "chinese_word": "杯子",
    },
    "spoon": {
        "english_word": "Spoon",
        "malay_word": "Sudu",
        "chinese_word": "勺子",
    },
    "plate": {
        "english_word": "Plate",
        "malay_word": "Pinggan",
        "chinese_word": "盘子",
    },
    "remote_control": {
        "english_word": "Remote Control",
        "malay_word": "Alat Kawalan Jauh",
        "chinese_word": "遥控器",
    },
    "book": {
        "english_word": "Book",
        "malay_word": "Buku",
        "chinese_word": "书",
    },
    "pencil": {
        "english_word": "Pencil",
        "malay_word": "Pensel",
        "chinese_word": "铅笔",
    },
    "pen": {
        "english_word": "Pen",
        "malay_word": "Pen",
        "chinese_word": "笔",
    },
    "ruler": {
        "english_word": "Ruler",
        "malay_word": "Pembaris",
        "chinese_word": "尺子",
    },
    "backpack": {
        "english_word": "Backpack",
        "malay_word": "Beg Galas",
        "chinese_word": "背包",
    },
}


@app.get("/health")
def health_check():
    """Return a simple status response so the frontend can confirm the API is online."""
    return jsonify(
        {
            "status": "ok",
            "service": "VocabScan Flask API",
        }
    )


@app.get("/vocabulary/<english_key>")
def get_vocabulary(english_key):
    """Return vocabulary details for one supported object key."""
    vocabulary_item = VOCABULARY.get(english_key)

    # Return a clear 404 response if the frontend asks for an unsupported object.
    if vocabulary_item is None:
        return (
            jsonify(
                {
                    "error": "Vocabulary item not found",
                    "english_key": english_key,
                }
            ),
            404,
        )

    # Include the key in the response so the frontend can track which object was requested.
    return jsonify(
        {
            "english_key": english_key,
            **vocabulary_item,
        }
    )


@app.post("/predict-mock")
def predict_mock():
    """Return a fake prediction result while the real AI model is not connected yet."""
    return jsonify(
        {
            "english_key": "book",
            "confidence": 0.95,
            "english_word": "Book",
            "malay_word": "Buku",
            "chinese_word": "书",
        }
    )


if __name__ == "__main__":
    # Run the development server when this file is executed directly.
    app.run(debug=True)
