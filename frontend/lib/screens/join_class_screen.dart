import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_service.dart';
import 'student_session_screen.dart';
import '../theme/app_theme.dart';

/// Screen 9 – Join Class
/// Lets a student enter their name and a 6-character class code to join a live
/// teacher session.
class JoinClassScreen extends StatefulWidget {
  const JoinClassScreen({super.key});

  @override
  State<JoinClassScreen> createState() => _JoinClassScreenState();
}

class _JoinClassScreenState extends State<JoinClassScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();

  bool _loading = false;
  String? _error;

  Future<void> _joinClass() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim().toUpperCase();

    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }
    if (code.isEmpty) {
      setState(() => _error = 'Please enter a class code');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final res = await ApiService.joinClassSession(code, name);
    if (!mounted) return;
    setState(() => _loading = false);

    final sessionId = res['session_id'] as String?;
    if (res['joined'] == true && sessionId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StudentSessionScreen(
            sessionId: sessionId,
            code: code,
            nickname: name,
          ),
        ),
      );
    } else {
      setState(() =>
          _error = (res['message'] as String?) ?? 'Could not join the class');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Back button ──
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: AppTheme.xxl,
                      ),
                      decoration: AppTheme.cardDecoration.copyWith(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Green circle icon
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: AppTheme.success,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              '👥',
                              style: TextStyle(fontSize: 28),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text('🎓', style: TextStyle(fontSize: 32)),
                          const SizedBox(height: 6),
                          Text(
                            'Join a Class',
                            style: AppTheme.heading.copyWith(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: AppTheme.xs),
                          Text(
                            "Enter your name and teacher's code",
                            textAlign: TextAlign.center,
                            style: AppTheme.body.copyWith(
                              fontSize: 14,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: AppTheme.xl),

                          // ── Name label ──
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Your Name',
                              style: AppTheme.body.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            maxLength: 20,
                            style: AppTheme.subheading.copyWith(fontSize: 18),
                            decoration: InputDecoration(
                              hintText: 'e.g. Ali',
                              filled: true,
                              fillColor: AppTheme.primaryLight,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: AppTheme.primary.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: AppTheme.primary,
                                  width: 2,
                                ),
                              ),
                              counterText: '',
                            ),
                            onChanged: (_) {
                              if (_error != null) setState(() => _error = null);
                            },
                          ),
                          const SizedBox(height: AppTheme.md),

                          // ── Code label ──
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Class Code',
                              style: AppTheme.body.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // ── Code field ──
                          TextField(
                            controller: _codeController,
                            textAlign: TextAlign.center,
                            maxLength: 6,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[A-Za-z0-9]'),
                              ),
                              UpperCaseTextFormatter(),
                            ],
                            style: AppTheme.heading.copyWith(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 8,
                            ),
                            decoration: InputDecoration(
                              hintText: 'ABC123',
                              hintStyle: AppTheme.heading.copyWith(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 8,
                                color: AppTheme.textDark.withValues(alpha: 0.25),
                              ),
                              suffixIcon: Icon(
                                Icons.lock_outline,
                                color: AppTheme.textLight,
                              ),
                              filled: true,
                              fillColor: AppTheme.primaryLight,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: AppTheme.primary.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: AppTheme.primary,
                                  width: 2,
                                ),
                              ),
                              counterStyle: AppTheme.caption,
                            ),
                            onChanged: (_) {
                              if (_error != null) setState(() => _error = null);
                            },
                          ),

                          // ── Error text ──
                          if (_error != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    size: 16, color: AppTheme.error),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: AppTheme.caption.copyWith(
                                      color: AppTheme.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),

                          // ── Join button ──
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _loading ? null : _joinClass,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.success,
                                foregroundColor: AppTheme.textDark,
                                minimumSize: const Size(double.infinity, 52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                textStyle: AppTheme.buttonText.copyWith(
                                  color: AppTheme.textDark,
                                  fontSize: 17,
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.textDark,
                                      ),
                                    )
                                  : const Text('Join Class 🎉'),
                            ),
                          ),
                          const SizedBox(height: AppTheme.xl),

                          // ── Tip ──
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.warningLight,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  '💡',
                                  style: TextStyle(fontSize: 22),
                                ),
                                const SizedBox(height: AppTheme.xs),
                                Text(
                                  'Ask your teacher for the class code!',
                                  textAlign: TextAlign.center,
                                  style: AppTheme.caption.copyWith(
                                    color: AppTheme.textDark,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
}

/// Forces input to uppercase.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
