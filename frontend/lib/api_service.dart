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
  static Future<Map<String, dynamic>> createClassSession(
      String teacherId) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/class/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'teacher_id': teacherId}),
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
