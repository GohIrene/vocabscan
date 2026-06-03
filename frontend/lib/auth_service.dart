class Child {
  final String nickname;
  final int age;
  Child({required this.nickname, required this.age});
}

class AppUser {
  final String username;
  final String pin;
  final String role; // 'parent' or 'teacher'
  final List<Child> children;

  AppUser({
    required this.username,
    required this.pin,
    required this.role,
  }) : children = [];
}

class AuthService {
  static final AuthService _instance = AuthService._();
  AuthService._();
  static AuthService get instance => _instance;

  final Map<String, AppUser> _users = {};
  AppUser? _currentUser;

  AppUser? get currentUser => _currentUser;

  /// Returns null on success, an error message on failure.
  String? register(String username, String pin, String role) {
    final u = username.trim();
    if (u.isEmpty) return 'Username cannot be empty';
    if (pin.length < 4) return 'PIN must be at least 4 digits';
    if (_users.containsKey(u)) return 'Username already taken';
    final user = AppUser(username: u, pin: pin, role: role);
    _users[u] = user;
    _currentUser = user;
    return null;
  }

  /// Returns null on success, an error message on failure.
  String? login(String username, String pin) {
    final user = _users[username.trim()];
    if (user == null) return 'Username not found';
    if (user.pin != pin) return 'Incorrect PIN';
    _currentUser = user;
    return null;
  }

  void logout() => _currentUser = null;

  void addChild(String nickname, int age) {
    _currentUser?.children.add(Child(nickname: nickname, age: age));
  }
}
