import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'config.dart';

/// Thin wrapper around the Flask backend API.
class ApiService {
  static final Uri _predictMockUrl = Uri.parse(
    '${AppConfig.baseUrl}/predict-mock',
  );

  static final Uri _predictUrl = Uri.parse(
    '${AppConfig.baseUrl}/predict',
  );

  /// Calls POST /predict-mock and returns the decoded JSON map.
  /// Uses utf8 decoding so Chinese characters display correctly.
  static Future<Map<String, dynamic>> predictMock() async {
    final response = await http
        .post(_predictMockUrl)
        .timeout(const Duration(seconds: 10));
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode == 200) {
      return jsonDecode(body) as Map<String, dynamic>;
    } else {
      throw Exception('predict-mock failed (${response.statusCode}): $body');
    }
  }

  /// Sends image bytes to POST /predict as multipart form-data.
  /// Returns the full decoded JSON map including vocab and audio fields.
  static Future<Map<String, dynamic>> predictObject(
      Uint8List imageBytes) async {
    final request = http.MultipartRequest('POST', _predictUrl);
    request.files.add(http.MultipartFile.fromBytes(
      'image',
      imageBytes,
      filename: 'capture.jpg',
    ));
    final streamed =
        await request.send().timeout(const Duration(seconds: 30));
    final rawBytes = await streamed.stream.toBytes();
    final body = utf8.decode(rawBytes);
    if (streamed.statusCode == 200) {
      return jsonDecode(body) as Map<String, dynamic>;
    } else {
      throw Exception('predict failed (${streamed.statusCode}): $body');
    }
  }

  /// Fire-and-forget scan event log. Never throws.
  static Future<void> logScan(
    String childId,
    String englishKey,
    double confidence,
    String mode,
  ) async {
    try {
      await http.post(
        Uri.parse('${AppConfig.baseUrl}/log/scan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'child_id': childId,
          'english_key': englishKey,
          'confidence': confidence,
          'mode': mode,
        }),
      );
    } catch (e) {
      // ignore_for_file: avoid_print
      print('logScan error: $e');
    }
  }

  /// Fetches the learning report for a child. GET /report/`childId`
  static Future<Map<String, dynamic>> getReport(String childId) async {
    final response = await http
        .get(Uri.parse('${AppConfig.baseUrl}/report/$childId'))
        .timeout(const Duration(seconds: 10));
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode == 200) {
      return jsonDecode(body) as Map<String, dynamic>;
    } else {
      throw Exception('getReport failed (${response.statusCode}): $body');
    }
  }

  /// Fire-and-forget quiz answer log. Never throws.
  static Future<void> logQuiz(
    String childId,
    String englishKey,
    bool correct,
  ) async {
    try {
      await http.post(
        Uri.parse('${AppConfig.baseUrl}/log/quiz'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'child_id': childId,
          'english_key': englishKey,
          'correct': correct,
        }),
      );
    } catch (e) {
      print('logQuiz error: $e');
    }
  }

  /// Creates a live Class Code session. POST /class/create
  /// Returns the parsed response map ({session_id, code} on success).
  /// Pass [classroomId] to run the session against a saved class, so students
  /// tap their name and earn XP. Omit it for the original nickname-only
  /// session with no saved progress.
  static Future<Map<String, dynamic>> createClassSession(
      String teacherId, {String? classroomId}) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/class/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'teacher_id': teacherId,
          'classroom_id': ?classroomId,
        }),
      );
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  /// Joins a live Class Code session by code. POST /class/join
  /// Returns the parsed response map ({session_id, joined} on success, or a
  /// {status: error, message} map with the HTTP failure reason).
  static Future<Map<String, dynamic>> joinClassSession(
      String code, String nickname) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/class/join'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': code, 'nickname': nickname}),
      );
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  // ── Classrooms (saved rosters + student progress) ──────────────────────────

  /// Every saved class belonging to a teacher. GET /classroom/list/`teacherId`
  static Future<List<Map<String, dynamic>>> getClassrooms(
      String teacherId) async {
    final response = await http
        .get(Uri.parse('${AppConfig.baseUrl}/classroom/list/$teacherId'))
        .timeout(const Duration(seconds: 10));
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode != 200) {
      throw Exception('getClassrooms failed (${response.statusCode}): $body');
    }
    final data = jsonDecode(body) as Map<String, dynamic>;
    return (data['classrooms'] as List? ?? const [])
        .whereType<Map>()
        .map((c) => Map<String, dynamic>.from(c))
        .toList();
  }

  /// Creates a saved class. POST /classroom/create
  static Future<Map<String, dynamic>> createClassroom(
      String teacherId, String name) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/classroom/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'teacher_id': teacherId, 'name': name}),
      );
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  /// Adds a student to a class roster. POST /classroom/`id`/students
  static Future<Map<String, dynamic>> addClassroomStudent(
      String classroomId, String name, int avatar) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/classroom/$classroomId/students'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'avatar': avatar}),
      );
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  /// Removes a student from a class roster.
  /// DELETE /classroom/`id`/students/`studentId`
  static Future<bool> removeClassroomStudent(
      String classroomId, String studentId) async {
    try {
      final response = await http.delete(Uri.parse(
          '${AppConfig.baseUrl}/classroom/$classroomId/students/$studentId'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Deletes a whole class. DELETE /classroom/`id`
  static Future<bool> deleteClassroom(String classroomId) async {
    try {
      final response = await http
          .delete(Uri.parse('${AppConfig.baseUrl}/classroom/$classroomId'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Bulk-adds students parsed from a spreadsheet (CSV) export.
  /// POST /classroom/`id`/students/import
  static Future<Map<String, dynamic>> importClassroomStudents(
      String classroomId, List<String> names) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/classroom/$classroomId/students/import'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'names': names}),
      );
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  /// Teacher awards (positive) or deducts (negative) XP by hand.
  /// POST /classroom/`id`/students/`studentId`/points
  static Future<Map<String, dynamic>> adjustStudentPoints(
      String classroomId, String studentId, int delta) async {
    try {
      final response = await http.post(
        Uri.parse(
            '${AppConfig.baseUrl}/classroom/$classroomId/students/$studentId/points'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'delta': delta}),
      );
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  /// Stages pre-class words (from photo uploads) onto a classroom, so every
  /// session run against it starts with them. POST /classroom/`id`/prepare-words
  static Future<Map<String, dynamic>> prepareClassroomWords(
      String classroomId, List<String> englishKeys) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/classroom/$classroomId/prepare-words'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'english_keys': englishKeys}),
      );
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  /// Removes one staged word from a classroom's prep list.
  /// POST /classroom/`id`/prepare-words/remove
  static Future<Map<String, dynamic>> removePreparedWord(
      String classroomId, String englishKey) async {
    try {
      final response = await http.post(
        Uri.parse(
            '${AppConfig.baseUrl}/classroom/$classroomId/prepare-words/remove'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'english_key': englishKey}),
      );
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  // ── Child Home Adventure ───────────────────────────────────────────────────

  /// Everything ChildHomeScreen draws, in one round trip: buddy, adventure,
  /// today's mission, streak, treasure count and achievement count.
  /// GET /child/home/`childId`
  static Future<Map<String, dynamic>> getChildHome(String childId) async {
    final response = await http
        .get(Uri.parse('${AppConfig.baseUrl}/child/home/$childId'))
        .timeout(const Duration(seconds: 10));
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode == 200) {
      return jsonDecode(body) as Map<String, dynamic>;
    }
    throw Exception('getChildHome failed (${response.statusCode}): $body');
  }

  /// The Treasure Album: every learnable word with a `discovered` flag.
  ///
  /// The word list and total come from the backend's vocabulary, so the album
  /// grows on its own as vocabulary is added — never hardcode a count here.
  /// GET /child/treasures/`childId`
  static Future<Map<String, dynamic>> getChildTreasures(String childId) async {
    final response = await http
        .get(Uri.parse('${AppConfig.baseUrl}/child/treasures/$childId'))
        .timeout(const Duration(seconds: 10));
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode == 200) {
      return jsonDecode(body) as Map<String, dynamic>;
    }
    throw Exception('getChildTreasures failed (${response.statusCode}): $body');
  }

  /// Applies the rewards for one finished Child Adventure cycle.
  ///
  /// Idempotent on [completionId]: the backend replays the original result if
  /// the same id arrives twice, so retrying after a network blip can never
  /// award XP or a treasure twice. The scan/quiz/speech logs are written by
  /// the existing `/log/*` calls during the flow — this adds no log entries.
  /// POST /learning/complete
  static Future<Map<String, dynamic>> completeLearning({
    required String childId,
    required String completionId,
    required String englishKey,
    required Map<String, dynamic> speech,
    required Map<String, dynamic> quiz,
  }) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/learning/complete'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'child_id': childId,
            'completion_id': completionId,
            'english_key': englishKey,
            'speech': speech,
            'quiz': quiz,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode == 200) {
      return jsonDecode(body) as Map<String, dynamic>;
    }
    throw Exception('completeLearning failed (${response.statusCode}): $body');
  }

  /// The full adventure route for the map screen — every area with its
  /// progress, decoration stage, keys and locked/current/completed status.
  /// GET /child/adventure/`childId`
  static Future<Map<String, dynamic>> getChildAdventure(String childId) async {
    final response = await http
        .get(Uri.parse('${AppConfig.baseUrl}/child/adventure/$childId'))
        .timeout(const Duration(seconds: 10));
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode == 200) {
      return jsonDecode(body) as Map<String, dynamic>;
    }
    throw Exception('getChildAdventure failed (${response.statusCode}): $body');
  }

  // ── Family Code (Home Mode child entry) ────────────────────────────────────

  /// The parent's standing family code, assigned on first view.
  /// GET /family-code/`parentId`
  static Future<Map<String, dynamic>> getFamilyCode(String parentId) async {
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.baseUrl}/family-code/$parentId'))
          .timeout(const Duration(seconds: 10));
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  /// Issues a new family code, invalidating the previous one. Gate this behind
  /// the parent PIN dialog — any child holding the old code loses access.
  /// POST /family-code/regenerate
  static Future<Map<String, dynamic>> regenerateFamilyCode(
      String parentId) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/family-code/regenerate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'parent_id': parentId}),
      );
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  /// Redeems a family code, returning the active child profiles behind it.
  /// POST /child-access/family
  static Future<Map<String, dynamic>> childAccessByFamilyCode(
      String familyCode) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/child-access/family'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'family_code': familyCode}),
      );
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  /// Checks a child's optional 4-digit PIN. A child with no PIN always passes,
  /// so this can be called unconditionally. POST /child-access/verify-pin
  static Future<Map<String, dynamic>> verifyChildPin(
      String childId, String pin) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/child-access/verify-pin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'child_id': childId, 'pin': pin}),
      );
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  /// Children behind a parent's username.
  ///
  /// LEGACY — superseded by [childAccessByFamilyCode]. Kept only so anything
  /// still pointing at it keeps working; no Home Mode screen calls it, and it
  /// can be deleted in a later cleanup phase.
  /// GET /children/by-username/`username`
  static Future<Map<String, dynamic>> getChildrenByUsername(
      String username) async {
    try {
      final response = await http
          .get(Uri.parse(
              '${AppConfig.baseUrl}/children/by-username/${Uri.encodeComponent(username)}'))
          .timeout(const Duration(seconds: 10));
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  /// The roster behind a live class code, for the student join screen.
  /// GET /classroom/roster/`code`
  ///
  /// Answers `has_roster: false` when the teacher started the session without
  /// a saved class — the signal to fall back to a typed name.
  static Future<Map<String, dynamic>> getRosterByCode(String code) async {
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.baseUrl}/classroom/roster/$code'))
          .timeout(const Duration(seconds: 10));
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } catch (e) {
      // A roster we can't reach shouldn't block joining — the caller falls
      // back to the typed-name path.
      return {'has_roster': false, 'students': []};
    }
  }

  /// Fetches [n] real vocab-based wrong answers for a quiz question — the
  /// same pool Class Code draws from, so Home-mode quizzes never show a
  /// hardcoded distractor that happens to equal the correct answer.
  /// GET /quiz/distractors
  static Future<List<String>> getQuizDistractors({
    required String englishKey,
    required String field,
    required String answer,
    int n = 3,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/quiz/distractors').replace(
      queryParameters: {
        'english_key': englishKey,
        'field': field,
        'answer': answer,
        'n': '$n',
      },
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode == 200) {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return (data['distractors'] as List? ?? []).cast<String>();
    } else {
      throw Exception('getQuizDistractors failed (${response.statusCode}): $body');
    }
  }

  /// Fetches all three distractor sets for a scanned word in ONE request
  /// (combined GET /quiz/questions), so the quiz screen makes a single round
  /// trip instead of three. Returns a map of field → distractor list, e.g.
  /// {'malay_word': [...], 'chinese_word': [...], 'english_word': [...]}.
  static Future<Map<String, List<String>>> getQuizQuestions({
    required String englishKey,
    int n = 3,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/quiz/questions').replace(
      queryParameters: {'english_key': englishKey, 'n': '$n'},
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode == 200) {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final d = (data['distractors'] as Map?) ?? const {};
      List<String> pick(String k) => ((d[k] as List?) ?? const []).cast<String>();
      return {
        'malay_word': pick('malay_word'),
        'chinese_word': pick('chinese_word'),
        'english_word': pick('english_word'),
      };
    } else {
      throw Exception('getQuizQuestions failed (${response.statusCode}): $body');
    }
  }

  /// Fetches all Class Code sessions run by a teacher, newest first, each with
  /// its leaderboard and quiz count. GET /class/sessions/`teacherId`
  static Future<Map<String, dynamic>> getClassSessions(String teacherId) async {
    final response = await http
        .get(Uri.parse('${AppConfig.baseUrl}/class/sessions/$teacherId'))
        .timeout(const Duration(seconds: 10));
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode == 200) {
      return jsonDecode(body) as Map<String, dynamic>;
    } else {
      throw Exception('getClassSessions failed (${response.statusCode}): $body');
    }
  }

  /// Builds a revision quiz from words a child has already learned, so past
  /// vocabulary can be re-practised without re-scanning the object.
  /// Pass [date] ("YYYY-MM-DD", local/GMT+8) to revise one specific day.
  /// GET /revision/quiz/`childId`
  static Future<Map<String, dynamic>> getRevisionQuiz(
    String childId, {
    String? date,
    int n = 5,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/revision/quiz/$childId').replace(
      queryParameters: {
        'n': '$n',
        'date': ?date,
      },
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode == 200) {
      return jsonDecode(body) as Map<String, dynamic>;
    } else {
      throw Exception('getRevisionQuiz failed (${response.statusCode}): $body');
    }
  }

  /// Words a teacher has already covered in past class sessions, newest first —
  /// lets them push a revision quiz without re-scanning.
  /// GET /revision/words/teacher/`teacherId`
  static Future<List<Map<String, dynamic>>> getTeacherRevisionWords(
      String teacherId) async {
    final response = await http
        .get(Uri.parse('${AppConfig.baseUrl}/revision/words/teacher/$teacherId'))
        .timeout(const Duration(seconds: 10));
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode == 200) {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return (data['words'] as List? ?? const [])
          .whereType<Map>()
          .map((w) => Map<String, dynamic>.from(w))
          .toList();
    } else {
      throw Exception(
          'getTeacherRevisionWords failed (${response.statusCode}): $body');
    }
  }

  /// Sends a recorded audio clip to the backend for Whisper transcription and
  /// matching against [target]. Returns the decoded map
  /// ({'transcript': String, 'correct': bool}). Used for languages the
  /// browser's Web Speech API can't handle reliably (e.g. Malay).
  static Future<Map<String, dynamic>> transcribeSpeech({
    required Uint8List audioBytes,
    required String lang,
    required String target,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.baseUrl}/speech/transcribe'),
    );
    request.fields['lang'] = lang;
    request.fields['target'] = target;
    request.files.add(http.MultipartFile.fromBytes(
      'audio',
      audioBytes,
      filename: 'speech.webm',
    ));
    final streamed =
        await request.send().timeout(const Duration(seconds: 30));
    final body = utf8.decode(await streamed.stream.toBytes());
    if (streamed.statusCode == 200) {
      return jsonDecode(body) as Map<String, dynamic>;
    }
    throw Exception('transcribe failed (${streamed.statusCode}): $body');
  }

  /// Fire-and-forget speech-practice attempt log. Never throws.
  static Future<void> logSpeech(
    String childId,
    String englishKey,
    String language,
    bool correct,
  ) async {
    try {
      await http.post(
        Uri.parse('${AppConfig.baseUrl}/log/speech'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'child_id': childId,
          'english_key': englishKey,
          'language': language,
          'correct': correct,
        }),
      );
    } catch (_) {}
  }
}
