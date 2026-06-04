import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class AuthService {
  static final AuthService _instance = AuthService._();
  AuthService._();
  static AuthService get instance => _instance;

  Map<String, dynamic>? _currentUser;

  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  Future<Map<String, dynamic>> register(
      String username, String pin, String role) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'pin': pin, 'role': role}),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] == 'ok') _currentUser = data;
      return data;
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> login(String username, String pin) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'pin': pin}),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] == 'ok') _currentUser = data;
      return data;
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  void logout() => _currentUser = null;

  Future<Map<String, dynamic>> addChild(
      String parentId, String nickname, int age) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/children'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(
            {'parent_id': parentId, 'nickname': nickname, 'age': age}),
      );
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  Future<List<Map<String, dynamic>>> getChildren(String parentId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/children/$parentId'),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['children'];
      if (list is List) {
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
