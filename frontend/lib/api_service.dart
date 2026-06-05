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
}
