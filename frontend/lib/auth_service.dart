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

  /// Re-checks the logged-in parent's PIN without issuing a fresh login.
  /// Used to gate sensitive actions (e.g. Add Child) mid-session.
  Future<Map<String, dynamic>> verifyPin(String pin) async {
    final username = _currentUser?['username'] as String?;
    if (username == null) {
      return {'status': 'error', 'message': 'Not logged in'};
    }
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/auth/verify-pin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'pin': pin}),
      );
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  /// Creates a child profile. [avatarId] is the animal buddy's id from
  /// avatar_config.dart (never a list index). [childPin] is optional — null or
  /// blank means the child has no PIN and is picked by tapping their face.
  ///
  /// [gender] and [icon] predate the animal avatars and are no longer sent by
  /// the add-child wizard; they remain here so nothing that still passes them
  /// breaks, and the backend still stores them.
  Future<Map<String, dynamic>> addChild(
      String parentId, String nickname, int age,
      {String? gender, String? icon, String? avatarId, String? childPin}) async {
    try {
      final body = {
        'parent_id': parentId,
        'nickname': nickname,
        'age': age,
      };
      if (gender != null) body['gender'] = gender;
      // Asset name of the icon the parent picked, so the child's card shows it.
      if (icon != null) body['icon'] = icon;
      if (avatarId != null) body['avatar_id'] = avatarId;
      if (childPin != null && childPin.isNotEmpty) body['child_pin'] = childPin;
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/children'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
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
