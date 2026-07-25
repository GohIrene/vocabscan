# Class Code & Teacher Mode: Complete Flow Architecture

## 📊 System Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           VOCABSCAN SYSTEM                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  FRONTEND (Flutter)              API (Flask)              DATABASE (MongoDB) │
│  ─────────────────────           ───────────              ──────────────────│
│                                                                              │
│  Teachers:                       Routes:                                    │
│  • TeacherHomeScreen      →  • /class/create          → class_sessions     │
│  • ClassroomManageScreen  →  • /class/join            → classrooms         │
│  • Teacher Projection     →  • /class/sessions/<id>   → (session docs)     │
│                           →  • /classroom/*                                │
│                           →  Socket.IO (WebSocket)    → (real-time)        │
│                                                                              │
│  Students:                                                                  │
│  • JoinClassScreen        →  • /classroom/roster/<code>                    │
│  • StudentSessionScreen   →  → Socket.IO Events       → (live quiz state) │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 🎯 Teacher Mode: Create & Run Session

### **Phase 1: Teacher Starts Session**

```
TeacherHomeScreen
    ↓
    ├─→ [Create Class Session Button]
    │
    ├─→ Show Classroom Dialog:
    │    • List all saved classrooms
    │    • Option: "Quick session" (no saved class)
    │
    └─→ Teacher selects classroom OR quick session
         ↓
         TeacherClassSessionScreen
         ↓
         ApiService.createClassSession(teacherId, classroomId?)
         │
         ├─ HTTP POST to /class/create
         │  ├─ Request: { teacher_id, classroom_id (optional) }
         │  │
         │  └─ Backend (class_code.py):
         │     ├─ Generate 6-char code (A1B2C3)
         │     ├─ Create session_id (UUID)
         │     └─ MongoDB insert:
         │        {
         │          session_id, code, teacher_id,
         │          classroom_id (null if quick),
         │          status: "waiting",
         │          students: [],
         │          current_quiz: null,
         │          word_keys: [prepared words from classroom],
         │          ...
         │        }
         │
         └─ Response: { session_id, code }
            ↓
            Display code to students
            + Teacher can scan objects to generate quizzes
```

### **Key Data: class_sessions collection**
```javascript
{
  _id: ObjectId,
  session_id: "uuid",
  code: "A1B2C3",               // What students enter
  teacher_id: "teacher-001",
  classroom_id: "class-uuid" or null,  // null = quick session
  status: "waiting" | "quiz" | "summary" | "ended",
  students: [
    {
      nickname: "Ali",
      score: 45,
      answered_current: false,
      connected: true,
      sid: "socket.io-sid",     // For targeting messages
      avatar: 0,                // From classrooms.students
      xp: 100,
      level: 2,
      ...
    }
  ],
  current_quiz: {              // Current live question
    quiz_id: "uuid",
    english_key: "cat",
    prompt: "中文/Malay prompt",
    options: ["选项1", "选项2", "选项3"],
    correct_answer: "选项2",
    ...
  },
  quiz_history: [...],         // Archived quizzes for reports
  word_keys: ["cat", "dog"],   // All words this session
  summary_quiz: { questions: [...] } or null,
  summary_history: [...],
  created_at, ended_at
}
```

---

## 👨‍🎓 Student Mode: Join Class

### **Phase 2: Student Joins (2-Step Flow)**

```
JoinClassScreen - Step 1: Enter Class Code
    ↓
    Student enters code (e.g., "A1B2C3")
    ↓
    _lookUpCode()
    │
    └─ ApiService.getRosterByCode(code)
       │
       ├─ HTTP GET to /classroom/roster/<code>
       │
       └─ Backend (classroom.py):
          ├─ Find session by code
          │
          ├─ If classroom_id exists:
          │  ├─ Fetch saved class roster from classrooms collection
          │  ├─ Mark students already connected as "taken"
          │  └─ Response:
          │     {
          │       has_roster: true,
          │       classroom_name: "Year 2 Melur",
          │       students: [
          │         {
          │           student_id: "uuid",
          │           name: "Ali",
          │           avatar: 2,
          │           level: 3,
          │           taken: false,  // Is this name already joined?
          │           ...
          │         }
          │       ]
          │     }
          │
          └─ If NO classroom_id (quick session):
             └─ Response: { has_roster: false, students: [] }
                ↓
                Fall back to typed name input

JoinClassScreen - Step 2: Tap Name or Type
    ├─ IF has_roster=true:
    │  └─ Show grid of student avatars + names
    │     Student taps their name
    │
    └─ IF has_roster=false OR "My name isn't here":
       └─ Text input field
          Student types nickname

    ↓
    Student submits (taps grid or "Join Class" button)
    ↓
    _join(name)
    │
    └─ ApiService.joinClassSession(code, nickname)
       │
       ├─ HTTP POST to /class/join
       │  ├─ Request: { code, nickname }
       │  │
       │  └─ Backend (class_code.py):
       │     ├─ Find session by code
       │     ├─ Check for duplicate nickname (if connected)
       │     ├─ MongoDB update:
       │     │  db.class_sessions.update_one(
       │     │    { session_id },
       │     │    { $push: { students: { nickname, score: 0, ... } } }
       │     │  )
       │     │
       │     └─ Response: { session_id, joined: true }
       │
       └─ StudentSessionScreen(sessionId, code, nickname)

StudentSessionScreen - Connect via Socket.IO
    ↓
    SocketService._connect()
    │
    └─ Socket.IO connect to /
       ├─ Emit: "connect_session"
       │  ├─ Data: { code, role: "student", nickname }
       │  │
       │  └─ Backend (sockets.py):
       │     ├─ Validate session exists
       │     ├─ Join Socket.IO room = code (broadcast room)
       │     ├─ MongoDB update:
       │     │  db.class_sessions.update_one(
       │     │    { session_id, "students.nickname": nickname },
       │     │    { $set: { "students.$.connected": true, "students.$.sid": socket_id } }
       │     │  )
       │     │
       │     └─ Emit to code room:
       │        "student_joined": { nickname, student_count, word_count }
       │
       └─ Listen for events:
          ├─ "new_quiz" → display question
          ├─ "answer_result" → show if correct/incorrect
          ├─ "summary_quiz" → show recap
          └─ "session_ended" → show final leaderboard
```

---

## 🎬 Live Session: Teacher Pushes Quiz

### **Phase 3: Teacher Scans Object → Students Answer**

```
TeacherClassSessionScreen
    ↓
    Teacher taps camera/scans object
    ↓
    ScanObjectScreen (flowMode: teacherProjection)
    ├─ Capture image
    ├─ Send to /predict
    └─ Returns: { vocab, confidence, ... }

        ↓
        Teacher confirms word (e.g., "cat")
        ↓
        TeacherProjectionScreen
        │
        └─ Socket.IO emit: "push_quiz"
           ├─ Data: { session_id, english_key: "cat" }
           │
           └─ Backend (sockets.py):
              ├─ Validate word is in vocab
              ├─ Build quiz using quiz_logic._build_quiz("cat")
              │  └─ Creates question with 3 options (correct + 2 distractors)
              │
              ├─ MongoDB update session:
              │  ├─ Archive previous quiz to quiz_history
              │  ├─ Set current_quiz = new quiz
              │  ├─ Reset all students.answered_current = false
              │  ├─ Set status = "quiz"
              │  └─ $addToSet word_keys: "cat"
              │
              └─ Socket.IO emit to code room:
                 "new_quiz": {
                   quiz_id, prompt, options,
                   english_key: "cat",
                   pattern: "CONSONANT-VOWEL-CONSONANT",
                   word_count (for summary button)
                 }

StudentSessionScreen (receives "new_quiz")
    ↓
    Update UI with new question
    ├─ Show prompt (Malay/Chinese)
    ├─ Show 3 options as buttons
    └─ Display answer_result from PREVIOUS quiz

    ↓
    Student selects an option
    ↓
    Socket.IO emit: "submit_answer"
    ├─ Data: { session_id, nickname, quiz_id, chosen: "选项1" }
    │
    └─ Backend (sockets.py):
       ├─ Find session + student + quiz
       ├─ Validate quiz_id matches current_quiz
       ├─ Check student hasn't already answered
       ├─ Compare: chosen == correct_answer
       ├─ Update XP if in saved classroom:
       │  ├─ If correct: +10 XP
       │  └─ If incorrect: +0 XP
       │
       ├─ MongoDB update:
       │  db.class_sessions.update_one(
       │    { session_id, "students.nickname": nickname },
       │    {
       │      $set: {
       │        "students.$.answered_current": true,
       │        "students.$.score": score + 10,  // or not
       │        "students.$.xp": xp + 10
       │      }
       │    }
       │  )
       │
       └─ Socket.IO emit to student's socket only:
          "answer_result": {
            correct: true/false,
            correct_answer: "选项2",
            points: 10
          }

StudentSessionScreen (receives "answer_result")
    ↓
    Show feedback animation
    ├─ ✓ Green animation if correct
    └─ ✗ Red animation if incorrect
```

### **Summary of Quiz Flow**
```
┌─────────────────────────────────────────┐
│ Teacher Project Mode Flow               │
├─────────────────────────────────────────┤
│                                         │
│ Scan → Confirm → push_quiz socket.io   │
│         ↓                                │
│         ├─→ All students get new_quiz   │
│         │    (via Socket.IO broadcast)  │
│         │                                │
│         ├─→ Student selects option      │
│         │                                │
│         ├─→ submit_answer socket.io     │
│         │                                │
│         └─→ Backend updates score + XP  │
│              (if saved classroom)       │
│                                         │
│            answer_result back to        │
│            (correct/incorrect feedback) │
│                                         │
└─────────────────────────────────────────┘
```

---

## 📋 Summary Quiz: Class Recap

### **Phase 4: Teacher Creates Summary Quiz**

```
TeacherProjectionScreen (quiz complete, showing stats)
    ↓
    Teacher has scanned N words
    ├─ Scanned words in session.word_keys
    └─ Click: "Summary Quiz"

        ↓
        TeacherProjectionScreen
        │
        └─ Socket.IO emit: "make_summary_quiz"
           ├─ Data: { session_id }
           │
           └─ Backend (sockets.py):
              ├─ Get word_keys from current session
              ├─ Filter to valid words
              ├─ Build quiz_logic.make_summary(words)
              │  └─ Creates list of questions:
              │     [
              │       { quiz_id, english_key: "cat", prompt, options, ... },
              │       { quiz_id, english_key: "dog", prompt, options, ... },
              │       ...
              │     ]
              │
              ├─ MongoDB update:
              │  ├─ summary_quiz = quiz doc with all questions
              │  ├─ status = "summary"
              │  ├─ Reset all students.summary_answered = []
              │  └─ Reset all students.summary_correct = []
              │
              └─ Socket.IO emit to code room:
                 "summary_quiz": {
                   summary_id, total, answered: [],
                   correct_count: 0,
                   questions: [{ quiz_id, prompt, options, ... }, ...]
                 }

StudentSessionScreen (receives "summary_quiz")
    ↓
    Show recap quiz
    ├─ Progress bar: "1 of 5"
    ├─ Question 1 of recap
    └─ Student works through at their own pace

    ↓
    For each question:
        ├─ Select option
        ├─ Socket.IO emit: "submit_summary_answer"
        │  ├─ Data: { session_id, nickname, quiz_id, chosen, summary_id }
        │  │
        │  └─ Backend:
        │     ├─ Find question in summary_quiz
        │     ├─ Check answer
        │     ├─ Update XP (+10 if correct)
        │     ├─ Mark quiz_id as answered for this student
        │     └─ Emit: "summary_result": { correct, points }
        │
        └─ Move to next question

    ↓ (After all questions)
    Show summary: "You got 4 out of 5!"
    ├─ Display badge if earned
    └─ Wait for teacher to end session
```

---

## 🎓 Class Reports: Teacher Reviews Session

### **Phase 5: Teacher Views Session History**

```
TeacherHomeScreen
    ↓
    [Class Reports Button]
    ↓
    TeacherProjectionScreen (showing reports)
    │
    └─ ApiService.getClassSessions(teacherId)
       │
       ├─ HTTP GET to /class/sessions/<teacher_id>
       │
       └─ Backend (class_code.py):
          ├─ Find all sessions for teacher
          ├─ For each session:
          │  ├─ Build leaderboard from students
          │  ├─ Count quizzes (includes summary questions)
          │  ├─ Compute local date/time (GMT+8)
          │  └─ Return:
          │     {
          │       session_id, code, status,
          │       created_at, local_date, local_time,
          │       student_count, quiz_count,
          │       leaderboard: [
          │         { nickname: "Ali", score: 50 },
          │         { nickname: "Budi", score: 40 }
          │       ]
          │     }
          │
          └─ Response:
             {
               teacher_id,
               session_count: 15,
               total_students: 127,
               live_count: 2,
               sessions: [...]
             }

Display:
    ├─ List of past sessions (newest first)
    ├─ For each session:
    │  ├─ Date/time
    │  ├─ Student count
    │  ├─ Quiz count
    │  └─ Leaderboard
    └─ Allows grouping by date
```

---

## 🏫 Classroom Management: Save Classes & Track Progress

### **Phase 6: Teacher Manages Saved Classes**

```
TeacherHomeScreen
    ↓
    [My Classes Button]
    ↓
    ClassroomManageScreen
    │
    ├─→ ApiService.getClassrooms(teacherId)
    │   └─ GET /classroom/list/<teacher_id>
    │      ├─ MongoDB: find classrooms by teacher_id
    │      └─ Response: [ { classroom_id, name, students, prepared_words }, ... ]
    │
    ├─→ [New Class] → _createClassroom()
    │   └─ POST /classroom/create
    │      ├─ Request: { teacher_id, name }
    │      └─ Creates classroom doc:
    │         {
    │           classroom_id: UUID,
    │           teacher_id,
    │           name: "Year 2 Melur",
    │           students: [],
    │           prepared_words: [],
    │           created_at
    │         }
    │
    ├─→ [Add Student] → _addStudent()
    │   └─ POST /classroom/<id>/students
    │      ├─ Request: { name, avatar }
    │      └─ Creates student doc:
    │         {
    │           student_id: UUID,
    │           name: "Ali",
    │           avatar: 2,
    │           xp: 0,
    │           level: 1,
    │           badges: [],
    │           sessions_played: 0,
    │           wins: 0
    │         }
    │
    ├─→ [Import CSV] → _importCsv()
    │   └─ POST /classroom/<id>/students/import
    │      ├─ Parse CSV: one name per row
    │      └─ Bulk insert students
    │
    ├─→ [Prep Photos] → _prepPhotos()
    │   └─ BatchUploadScreen
    │      ├─ Upload photos
    │      ├─ Send to /predict for each
    │      ├─ Collect recognized words
    │      └─ POST /classroom/<id>/prepare-words
    │         └─ These words pre-loaded in all sessions for this class
    │
    ├─→ [Add/Deduct XP] → _adjustPoints()
    │   └─ POST /classroom/<id>/students/<studentId>/points
    │      ├─ Request: { delta: 10 or -5 }
    │      └─ Manually update student XP (for behavior/participation)
    │
    └─→ [Delete Student/Class]
        └─ DELETE endpoints

Classroom Data Model:
    {
      classroom_id: UUID,
      teacher_id: "teacher-001",
      name: "Year 2 Melur",
      students: [
        {
          student_id: UUID,
          name: "Ali",
          avatar: 2,
          xp: 150,
          level: 2,
          xp_into_level: 50,
          badges: ["speed_reader", "perfect_score"],
          sessions_played: 5,
          wins: 3
        },
        ...
      ],
      prepared_words: ["cat", "dog", "bird"],
      created_at
    }
```

---

## 🔗 API Endpoint Summary

### **Class Sessions (REST)**
```
POST   /class/create              → Start a session (teacher)
POST   /class/join                → Join a session (student)
GET    /class/sessions/<teacher>  → All sessions + leaderboard (teacher)
```

### **Classrooms (REST)**
```
POST   /classroom/create                        → Create class
GET    /classroom/list/<teacher_id>             → All classes (teacher)
GET    /classroom/<classroom_id>                → Class details
GET    /classroom/roster/<code>                 → Roster for join screen (unauthenticated!)

POST   /classroom/<id>/students                 → Add student
POST   /classroom/<id>/students/import          → Bulk import CSV
DELETE /classroom/<id>/students/<student_id>   → Remove student
DELETE /classroom/<id>                          → Delete class

POST   /classroom/<id>/students/<sid>/points    → Adjust XP
POST   /classroom/<id>/prepare-words            → Stage words for class
POST   /classroom/<id>/prepare-words/remove     → Remove staged word
```

### **Socket.IO Events (Real-Time)**
```
STUDENT                             TEACHER
───────────────────────────────     ─────────────────────────────
connect_session                     connect_session
  ├─ code, nickname, role="student"   ├─ code, role="teacher"
  └─ Reconnect logic                  └─ Sync current state

                ↓ BROADCAST ↓
          "student_joined"
           (via room=code)

push_quiz (TEACHER ONLY)
  └─ Session updates, broadcasts "new_quiz"

                ↓ BROADCAST ↓
          "new_quiz"
          (students display question)

submit_answer (STUDENT → TEACHER)
  ├─ Session validates & updates
  └─ "answer_result" back to student

make_summary_quiz (TEACHER ONLY)
  └─ Session creates recap

                ↓ BROADCAST ↓
          "summary_quiz"
          (multi-question recap)

submit_summary_answer (STUDENT → TEACHER)
  ├─ Validates each question
  └─ "summary_result" back

end_session (TEACHER ONLY)
  └─ Archives state, broadcasts "session_ended"

                ↓ BROADCAST ↓
          "session_ended"
          (final leaderboard, rewards)
```

---

## 📊 Data Flow Diagram: Session Lifecycle

```
                    TEACHER                          STUDENTS
                    ────────                          ────────

                   1. CREATE SESSION
                        ↓
                   /class/create
                        ↓
                   Display code: "A1B2C3"
                        ↓
    ┌───────────────────┼────────────────────┐
    │                   │                    │
    │            2. SCAN → QUIZ              │  3. JOIN CLASS
    │                   │                    │       ↓
    │              push_quiz              getRosterByCode
    │            (Socket.IO)                  │       ↓
    │                   │                    │    /class/join
    │                   │                    │       ↓
    │                   ├──→ broadcast ──────→ new_quiz event
    │                   │                    │       ↓
    │                   │              4. ANSWER
    │                   │                    │       ↓
    │                   │                  submit_answer
    │                   │                (Socket.IO)
    │                   │                    │       ↓
    │                   ├←── validate ←──────┤
    │                   │   + update scores
    │                   │                    │
    │                   ├──→ broadcast ──────→ answer_result
    │                   │                    │       ↓
    │                   │              [Show feedback]
    │                   │
    │            5. SUMMARY QUIZ
    │                   │
    │              make_summary_quiz
    │            (Socket.IO)
    │                   │
    │                   ├──→ broadcast ──────→ summary_quiz event
    │                   │                    │       ↓
    │                   │              [Multi-question recap]
    │                   │                    │       ↓
    │                   │              submit_summary_answer
    │                   │                (Socket.IO × N)
    │                   │                    │       ↓
    │                   │              [Final scores]
    │                   │
    │            6. END SESSION
    │                   │
    │              end_session
    │            (Socket.IO)
    │                   │
    │                   ├──→ broadcast ──────→ session_ended
    │                   │                    │       ↓
    │                   │              [Rewards, badges]
    │
    └───────────────────┼────────────────────┘
                        │
                7. REPORTS (REST)
                        │
                GET /class/sessions/<teacher>
                        │
                        └─→ Leaderboard, quiz counts, etc.
```

---

## ⚙️ Technology Stack

| Layer | Technology | Notes |
|-------|-----------|-------|
| **Frontend** | Flutter (Dart) | Cross-platform (web + mobile) |
| **Backend** | Flask (Python) | REST + Socket.IO |
| **Real-Time** | Socket.IO (Eventlet) | Lightweight concurrency, supports ~25-30 students per class |
| **Database** | MongoDB | Collections: `class_sessions`, `classrooms` |
| **Auth** | JWT (for teachers) | Students are unauthenticated (use class code) |
| **Concurrency** | Eventlet green threads | One OS thread, many lightweight threads |

---

## ✅ Current Status

### **What Works**
- ✅ Class code generation & joining (2-step flow)
- ✅ Saved classrooms with student rosters
- ✅ Teacher scans → quiz push (Socket.IO broadcast)
- ✅ Student real-time answers + scoring
- ✅ Summary quiz (recap) flow
- ✅ Leaderboard + session reports
- ✅ XP/level/badge tracking (in saved classes)
- ✅ Roster grid in JoinClassScreen (if classroom exists)

### **Known Issues / Adjustments Needed**
- ⚠️ Eventlet server (Socket.IO): Pending switch for 25-30 student classes (Phase 8 work)
- ⚠️ Reconnection logic: May need refinement for poor network
- ⚠️ Summary quiz: Check if timeout handling is robust when teacher doesn't end session

---

## 🎯 Key Design Decisions

1. **Unauthenticated Roster Lookup** (`/classroom/roster/<code>`)
   - Students have no accounts, only the code
   - Exposes only first names + levels (privacy OK)
   - Allows "tap your name" UX on young children

2. **Socket.IO Broadcast via Code-Room**
   - Teacher + students join room = code
   - New questions broadcast to entire room
   - Efficient: one emit, many receives

3. **Dual Session Types**
   - Saved class → XP/levels/badges persist
   - Quick session → anonymous, no progress saved
   - Same socket flow for both

4. **Summary Quiz Timing**
   - Self-paced (not timed like live quizzes)
   - Student can leave mid-recap and rejoin
   - XP awarded per question, not per recap

5. **Prepared Words**
   - Teachers upload photos before class
   - Recognized words pre-loaded into every session for that class
   - Saves time during lesson (no need to scan prep objects)

