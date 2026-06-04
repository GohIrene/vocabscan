import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'scan_object_screen.dart';
import '../theme/app_theme.dart';

/// Screen 9 – Join Class
/// Lets a student enter a 6-character class code to join a teacher session.
class JoinClassScreen extends StatefulWidget {
  const JoinClassScreen({super.key});

  @override
  State<JoinClassScreen> createState() => _JoinClassScreenState();
}

class _JoinClassScreenState extends State<JoinClassScreen> {
  final _controller = TextEditingController();

  static const _quickCodes = ['ABC123', 'XYZ789', 'DEF456'];

  void _joinClass(String code) {
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a class code')),
      );
      return;
    }
    // For prototype, just take them to Scan Object screen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScanObjectScreen()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
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
                            "Enter your teacher's code",
                            style: AppTheme.body.copyWith(
                              fontSize: 14,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: AppTheme.xl),

                          // ── Label ──
                          Text(
                            'Class Code',
                            style: AppTheme.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // ── Text field ──
                          TextField(
                            controller: _controller,
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
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 20),

                          // ── Join button ──
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () =>
                                  _joinClass(_controller.text.trim()),
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
                              child: const Text('Join Class 🎉'),
                            ),
                          ),
                          const SizedBox(height: AppTheme.xl),

                          // ── Divider ──
                          Divider(
                            color: AppTheme.primary.withValues(alpha: 0.15),
                          ),
                          const SizedBox(height: AppTheme.md),
                          Text(
                            'Quick Access (Demo)',
                            style: AppTheme.caption,
                          ),
                          const SizedBox(height: AppTheme.md),

                          // ── Quick code chips ──
                          Wrap(
                            spacing: 10,
                            children: _quickCodes
                                .map(
                                  (code) => FilledButton(
                                    onPressed: () {
                                      _controller.text = code;
                                      setState(() {});
                                    },
                                    style: AppTheme.smallButton.copyWith(
                                      backgroundColor:
                                          const WidgetStatePropertyAll(
                                        AppTheme.secondary,
                                      ),
                                    ),
                                    child: Text(code),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 20),

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
