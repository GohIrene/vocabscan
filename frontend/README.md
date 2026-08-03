# VocabScan — Frontend

Flutter client for VocabScan, a vocabulary-learning app for children with
Teacher and Parent companion tools. It talks to the Flask backend in
`backend/`.

## What it does

- **Child**: scans real-world objects with the camera for object
  recognition, takes vocabulary quizzes, practices pronunciation, and
  progresses through a gamified "Adventure" map (Home Village, Fruit
  Garden, Animal Forest, Cozy Home Corner, Vehicle Valley, Treasure
  Castle) earning rewards along the way.
- **Teacher**: manages classes, runs live quiz sessions with a
  classroom leaderboard/projection view, and prepares vocabulary sets.
- **Parent**: manages their child's account/avatar and views progress
  from a parent dashboard.

## Project structure

- `lib/screens/` — one screen per route, grouped by role (child_*,
  teacher_*, parent_*) plus shared quiz/scan/auth screens
- `lib/widgets/` — reusable UI (adventure art, avatars, shells, nav)
- `lib/api_service.dart`, `lib/auth_service.dart`, `lib/socket_service.dart`
  — backend REST + Socket.IO integration
- `lib/config.dart` — backend base URL (toggle between localhost and
  LAN IP for phone testing)

## Getting started

1. Make sure the backend is running (see `backend/`; the user runs
   `app.py` from `backend/.venv` separately).
2. Update `lib/config.dart` if testing on a physical device over Wi-Fi.
3. Install dependencies:
   ```
   flutter pub get
   ```
4. Run the app:
   ```
   flutter run
   ```

## Learn more

For general Flutter help, see the [official docs](https://docs.flutter.dev/).
