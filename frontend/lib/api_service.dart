import 'dart:convert';
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
}
