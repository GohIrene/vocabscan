import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'config.dart';

/// Thin wrapper around the Flask backend API.
class ApiService {
  static final Uri _predictMockUrl = Uri.parse(
    '${AppConfig.baseUrl}/predict-mock',
  );

  /// Calls POST /predict-mock and returns the decoded JSON map.
  /// Uses utf8 decoding so Chinese characters display correctly.
  static Future<Map<String, dynamic>> predictMock() async {
    final response = await http.post(_predictMockUrl);
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode == 200) {
      return jsonDecode(body) as Map<String, dynamic>;
    } else {
      throw Exception('predict-mock failed (${response.statusCode}): $body');
    }
  }

  /// Sends image bytes to POST /predict-mock as multipart form-data.
  /// Returns the full decoded JSON map including vocab and audio fields.
  static Future<Map<String, dynamic>> predictObject(
      Uint8List imageBytes) async {
    final request = http.MultipartRequest('POST', _predictMockUrl);
    request.files.add(http.MultipartFile.fromBytes(
      'image',
      imageBytes,
      filename: 'capture.jpg',
    ));
    final streamed = await request.send();
    final rawBytes = await streamed.stream.toBytes();
    final body = utf8.decode(rawBytes);
    if (streamed.statusCode == 200) {
      return jsonDecode(body) as Map<String, dynamic>;
    } else {
      throw Exception('predict-mock failed (${streamed.statusCode}): $body');
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

  /// Fetches the learning report for a child. GET /report/<childId>
  static Future<Map<String, dynamic>> getReport(String childId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/report/$childId'),
    );
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
}
