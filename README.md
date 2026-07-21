# VocabScan

AI-based object recognition and vocabulary learning app for kids, built for a final year capstone project.

A child points a camera at a real object (a cup, a chair, a banana...), the app recognizes it and shows the word in English, Malay, and Chinese with audio pronunciation, then follows up with a quiz and a speech practice activity. Parents can track their child's progress over time, and teachers can run a live multiplayer quiz with a whole class using a join code.

## Features

- Object recognition from a live camera feed or an uploaded photo (30 everyday objects)
- Trilingual vocabulary cards (English / Malay / Chinese) with audio playback
- Multiple-choice quiz practice built from real vocabulary, not hardcoded questions
- Speech practice using the browser's speech recognition to check pronunciation
- Parent dashboard: per-child progress report, day-by-day activity chart, word mastery, common mistakes
- Revision mode: re-practise words a child has already scanned, without needing the object again
- Teacher Class Code mode: create a session, students join from their own devices with a 6-character code, teacher scans an object and pushes a live quiz to everyone, with a real-time leaderboard
- Teacher Class Reports: view past sessions and their leaderboards

## Tech stack

| Layer | Technology |
|---|---|
| Frontend | Flutter Web (Dart) |
| Backend | Flask + Flask-SocketIO (Python) |
| Real-time | Socket.IO (for the live Class Code quiz mode) |
| Database | MongoDB |
| ML model | MobileNetV3Large (TensorFlow/Keras), trained on a custom 30-class dataset |
| Audio | Pre-generated gTTS audio, with browser speech synthesis as a fallback |

## Project structure

```
vocabscan/
├── backend/            Flask API + Socket.IO server, model loading, MongoDB access
├── frontend/           Flutter Web app (screens, services, widgets)
├── dataset*/           Dataset-building and cleaning artifacts (not used at runtime)
├── training_script/    Scripts used to train and compare candidate models
└── runs/                Training run outputs
```

The `dataset*/`, `training_script/`, and `runs/` folders are all part of the model-development side of the project, not the running app itself.

## Running it locally

You need Python 3.12, Flutter, and a local MongoDB instance running on the default port.

**Backend**

```
cd backend
pip install -r requirements.txt
python app.py
```

The server starts on `http://0.0.0.0:5000`. If MongoDB isn't running, the app still starts — object recognition keeps working off an in-memory word list, but accounts, logging, and class sessions will return a 503 until MongoDB is reachable.

**Frontend**

```
cd frontend
flutter pub get
flutter run -d chrome
```

If you're testing from a phone or another device on the same network, update `baseUrl` in `frontend/lib/config.dart` — it's hardcoded to `127.0.0.1` by default.

## Current status

This is an active capstone project. Recognition, quiz practice, speech practice, the parent dashboard, revision, and the live Class Code mode are all working end to end. There's no Docker setup and no CI yet, and both the backend's Mongo URI and the frontend's API URL are hardcoded rather than read from environment variables — fine for local development, but something to fix before any real deployment.

## More documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) — full technical reference: every API route, every Socket.IO event, database schema, and how each screen works
- [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md) — what's implemented vs. what's still planned
- [CP1_REPORT_SUMMARY.md](CP1_REPORT_SUMMARY.md) — the academic report this project is based on
