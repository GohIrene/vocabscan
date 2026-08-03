# VocabScan

AI-based object recognition and trilingual vocabulary learning web app for children aged 3–10.

Point a camera at a real object such as glasses, a pen, a book, whatever's around and the app identifies it, then shows the word in **English, Malay, and Chinese** with audio, a quiz, and a pronunciation-practice activity. Parents get a progress dashboard for their kids. Teachers can run a live quiz for the whole class; students just join with a 6-character code.

Built as a final-year capstone project.

## Table of Contents

- [Features](#features)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Project Structure](#project-structure)
- [API Reference](#api-reference)
- [Socket.IO Events](#socketio-events)
- [Image Classifier](#image-classifier)

## Features

**For children**
- Object recognition from a live camera feed or an uploaded photo (30 everyday object classes)
- Trilingual vocabulary cards (English / Malay / Chinese) with audio playback
- Multiple-choice quizzes generated from real vocabulary data, not a hardcoded question bank
- Pronunciation practice with automatic scoring
- Revision mode — re-practise previously scanned words without needing the physical object
- Adventure Mode: XP, streaks, avatars and collectable treasures
- Children can log in directly with their own username, no parent account required

**For parents**
- Per-child progress summary and day-by-day activity charts
- Word mastery breakdown and most-common-mistake analysis
- Family code system for linking children to a parent account

**For teachers**
- Classroom management with student rosters and CSV import
- Live Class Code sessions — students join from their own devices with a 6-character code
- Push a quiz to every connected student at once, with a real-time leaderboard
- Batch quizzes, summary quizzes, and pre-staged vocabulary for a lesson
- Session history and past leaderboards

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter Web (Dart) - 29 screens |
| Backend | Flask + Flask-SocketIO (Python 3.12) |
| Concurrency | eventlet green threads (one per connected student) |
| Real-time | Socket.IO |
| Database | MongoDB |
| Image classifier | MobileNetV3Large (TensorFlow / Keras), custom 30-class dataset |
| Speech (en/zh) | Browser Web Speech API |
| Speech (ms) | `faster-whisper` server-side transcription |
| Audio playback | Pre-generated gTTS clips, browser speech synthesis as fallback |

## Prerequisites

- **Python** 3.12
- **Flutter** (stable channel) with web support enabled
- **MongoDB** running on the default port (`localhost:27017`)

## Installation

### Backend

```bash
cd backend
pip install -r requirements.txt
python app.py
```

Serves on `http://0.0.0.0:5000`.

MongoDB is optional for a quick look — object recognition works off an in-memory vocabulary cache without it, but every database-backed route returns `503 {"status":"error","message":"Database unavailable"}` until Mongo is reachable. The exceptions are `/health`, `/predict`, `/predict-mock` and `/vocabulary/<key>`, which work regardless.

The Malay speech model (`faster-whisper`, ~500 MB) is lazy-loaded on first use and pre-warmed in the background at startup. Override the size with `WHISPER_MODEL` (defaults to `small`).

### Frontend

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

To test from a phone or another machine on the same network, change `baseUrl` in [frontend/lib/config.dart](frontend/lib/config.dart) — it is hardcoded to `127.0.0.1`.

## Project Structure

```
vocabscan/
├── backend/                  Flask API + Socket.IO server
│   ├── app.py                Entry point — eventlet patch, blueprint registration
│   ├── state.py              Shared app/socketio/db singletons
│   ├── sockets.py            All Socket.IO event handlers (live class mode)
│   ├── model_loader.py       Rebuilds the MobileNetV3 graph and loads weights
│   ├── vocab.py              Trilingual vocabulary cache
│   ├── quiz_logic.py         Distractor selection and question assembly
│   ├── class_sessions.py     Live session state
│   ├── routes/               REST blueprints (auth, child, parent, quiz, …)
│   └── static/               Pre-generated gTTS audio
│
├── frontend/                 Flutter Web app
│   └── lib/
│       ├── main.dart
│       ├── config.dart       API base URL
│       ├── api_service.dart  REST client
│       ├── socket_service.dart
│       ├── screens/          29 screens
│       ├── widgets/          Shared components
│       └── theme/
│
└── dataset/                  train / val / test splits (images are gitignored)
```

`backend/` and `frontend/` are the running application. `dataset/` holds the 30-class image corpus the classifier was trained on and is not read at runtime.

## API Reference

Base URL `http://127.0.0.1:5000`. All routes are registered as Flask blueprints in [backend/app.py](backend/app.py).

### Recognition & vocabulary
| Method | Path | Purpose |
|---|---|---|
| `POST` | `/predict` | Classify an uploaded image |
| `POST` | `/predict-mock` | Stubbed prediction for frontend development |
| `GET` | `/vocabulary/<english_key>` | Trilingual card for one word |
| `GET` | `/health` | Liveness probe |

### Authentication & accounts
| Method | Path | Purpose |
|---|---|---|
| `POST` | `/auth/register` | Create a parent or teacher account |
| `POST` | `/auth/login` | Log in |
| `POST` | `/auth/verify-pin` | Verify a parent PIN |
| `POST` | `/children` | Add a child |
| `GET` | `/children/<parent_id>` | List a parent's children |
| `GET` | `/children/by-username/<username>` | Look up a child for direct login |
| `PATCH` | `/children/<child_id>` | Update a child profile |
| `DELETE` | `/children/<child_id>` | Remove a child |
| `GET` | `/family-code/<parent_id>` | Get the family join code |
| `POST` | `/family-code/regenerate` | Rotate the family code |
| `POST` | `/child-access/family` | Child login via family code |
| `POST` | `/child-access/verify-pin` | Child PIN verification |

### Child experience
| Method | Path | Purpose |
|---|---|---|
| `GET` | `/child/home/<child_id>` | Home screen payload |
| `GET` | `/child/adventure/<child_id>` | Adventure Mode state (XP, streak, stages) |
| `GET` | `/child/treasures/<child_id>` | Collected treasures |
| `POST` | `/learning/complete` | Mark a learning flow finished |

### Quizzes & revision
| Method | Path | Purpose |
|---|---|---|
| `GET` | `/quiz/questions` | Generate quiz questions |
| `GET` | `/quiz/distractors` | Distractor options for one word |
| `GET` | `/revision/quiz/<child_id>` | Quiz built from words the child has already scanned |
| `GET` | `/revision/words/teacher/<teacher_id>` | Teacher's revision word pool |

### Speech
| Method | Path | Purpose |
|---|---|---|
| `POST` | `/speech/transcribe` | Server-side Whisper transcription (Malay) |

### Progress & reporting
| Method | Path | Purpose |
|---|---|---|
| `POST` | `/log/scan` | Record a scan event |
| `POST` | `/log/quiz` | Record a quiz answer |
| `POST` | `/log/speech` | Record a speech attempt |
| `GET` | `/report/<child_id>` | Full progress report for one child |
| `GET` | `/parent/summary/<parent_id>` | Dashboard summary |
| `GET` | `/parent/activity/<parent_id>` | Day-by-day activity |
| `GET` | `/parent/activity/summary/<parent_id>` | Aggregated activity |

### Classrooms & live sessions
| Method | Path | Purpose |
|---|---|---|
| `POST` | `/class/create` | Start a live session, returns a 6-char code |
| `POST` | `/class/join` | Student joins by code |
| `GET` | `/class/sessions/<teacher_id>` | Past session history |
| `POST` | `/classroom/create` | Create a persistent classroom |
| `GET` | `/classroom/list/<teacher_id>` | List classrooms |
| `GET` | `/classroom/<classroom_id>` | Classroom detail |
| `GET` | `/classroom/roster/<code>` | Roster by join code |
| `POST` | `/classroom/<id>/students` | Add a student |
| `POST` | `/classroom/<id>/students/import` | Bulk import students |
| `POST` | `/classroom/<id>/students/<sid>/points` | Award points |
| `DELETE` | `/classroom/<id>/students/<sid>` | Remove a student |
| `DELETE` | `/classroom/<id>` | Delete a classroom |
| `POST` | `/classroom/<id>/prepare-words` | Stage vocabulary for a lesson |
| `POST` | `/classroom/<id>/prepare-words/remove` | Unstage vocabulary |

## Socket.IO Events

Handlers live in [backend/sockets.py](backend/sockets.py); the client is [frontend/lib/socket_service.dart](frontend/lib/socket_service.dart).

| Event | Emitted by | Purpose |
|---|---|---|
| `connect_session` | Student | Join a live class session room |
| `push_quiz` | Teacher | Broadcast a single question to the room |
| `submit_answer` | Student | Answer the current question |
| `push_summary_quiz` | Teacher | Broadcast an end-of-lesson summary quiz |
| `submit_summary_answer` | Student | Answer a summary question |
| `push_batch_quiz` | Teacher | Broadcast a multi-question batch |
| `stage_batch_words` | Teacher | Pre-load vocabulary into the session |
| `end_session` | Teacher | Close the session and finalise the leaderboard |
| `disconnect` | — | Clean up participant state |

## Image Classifier

The shipped classifier is **MobileNetV3Large** fine-tuned on a custom 30-class dataset of everyday objects, served as `backend/mobilenetv3_final.keras` with the class list in `backend/mobilenetv3_classes.json`.

Three other architectures were trained and benchmarked against it during development — MobileNetV2, EfficientNetV2-S, and YOLO11n-cls. MobileNetV3Large was selected on the accuracy-versus-latency trade-off for CPU inference, which is what the Flask server runs on.

`model_loader.py` uses a custom loader instead of a plain `load_model()` call — the model was saved under Keras 2.15, but the server runs Keras 3 on Python 3.12, which can't deserialize the archive directly. It rebuilds the architecture in code and copies weights across by shape. See [backend/model_loader.py](backend/model_loader.py) for the full explanation.
