import 'package:flutter/material.dart';
import '../auth_service.dart';
import 'register_screen.dart';
import 'parent_home_screen.dart';
import 'teacher_home_screen.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  final String role; // 'parent' or 'teacher'
  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  String? _error;
  bool _loading = false;

  bool get _isParent => widget.role == 'parent';

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    final result = await AuthService.instance.login(
      _usernameCtrl.text,
      _pinCtrl.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (result['status'] == 'error') {
      setState(() => _error = result['message'] as String? ?? 'Login failed');
      return;
    }
    final role = result['role'] as String? ?? widget.role;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            role == 'parent' ? const ParentHomeScreen() : const TeacherHomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.md),
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back'),
                  style: AppTheme.backButtonStyle,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.xl),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _isParent
                                  ? 'Welcome, Parent!'
                                  : 'Welcome, Teacher!',
                              style: AppTheme.heading.copyWith(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(width: 8),
                            Image.asset(
                              _isParent
                                  ? 'assets/icons/family.png'
                                  : 'assets/icons/teacher.png',
                              width: 28,
                              height: 28,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.person, size: 28);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.xxl),

                        _buildField(
                          controller: _usernameCtrl,
                          label: 'Username',
                          hint: 'Enter your username',
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: AppTheme.lg),
                        _buildField(
                          controller: _pinCtrl,
                          label: 'PIN (4–6 digits)',
                          hint: '● ● ● ●',
                          icon: Icons.lock_outline,
                          obscure: true,
                          numeric: true,
                        ),

                        if (_error != null) ...[
                          const SizedBox(height: AppTheme.md),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.lg,
                              vertical: AppTheme.md,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.errorLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _error!,
                              style: AppTheme.caption.copyWith(
                                color: AppTheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: AppTheme.xl),
                        FilledButton(
                          onPressed: _loading ? null : _login,
                          style: AppTheme.primaryButton,
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Log In'),
                        ),
                        const SizedBox(height: AppTheme.lg),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: AppTheme.caption,
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      RegisterScreen(role: widget.role),
                                ),
                              ),
                              child: Text(
                                'Register here',
                                style: AppTheme.caption.copyWith(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.xxl),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    bool numeric = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppTheme.xs),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: numeric ? TextInputType.number : TextInputType.text,
          maxLength: numeric ? 6 : null,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppTheme.textLight, size: 20),
            counterText: '',
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: AppTheme.primary.withValues(alpha: 0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: AppTheme.primary.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppTheme.lg,
              vertical: AppTheme.lg,
            ),
          ),
        ),
      ],
    );
  }
}
