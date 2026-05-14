import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'scan_object_screen.dart';

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
      backgroundColor: const Color(0xFFF1ECFF),
      body: SafeArea(
        child: Column(
          children: [
            // ── Back button ──
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back'),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF17234D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
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
                        vertical: 32,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Green circle icon
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: Color(0xFF80DFA7),
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
                          const Text(
                            'Join a Class',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF17234D),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Enter your teacher's code",
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF7C6CF2),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── Label ──
                          const Text(
                            'Class Code',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF17234D),
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
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 8,
                              color: Color(0xFF17234D),
                            ),
                            decoration: InputDecoration(
                              hintText: 'ABC123',
                              hintStyle: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 8,
                                color: const Color(
                                  0xFF17234D,
                                ).withValues(alpha: 0.25),
                              ),
                              suffixIcon: const Icon(
                                Icons.lock_outline,
                                color: Color(0xFFADA6C0),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF1ECFF),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD5D0E3),
                                  width: 2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFF9B8CF2),
                                  width: 2,
                                ),
                              ),
                              counterStyle: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF65708C),
                              ),
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
                                backgroundColor: const Color(0xFF80DFA7),
                                foregroundColor: const Color(0xFF17234D),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: const Text('Join Class 🎉'),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── Divider ──
                          const Divider(color: Color(0xFFE0DCF0)),
                          const SizedBox(height: 12),
                          const Text(
                            'Quick Access (Demo)',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF65708C),
                            ),
                          ),
                          const SizedBox(height: 12),

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
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF7EC8F2),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
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
                              color: const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Column(
                              children: [
                                Text('💡', style: TextStyle(fontSize: 22)),
                                SizedBox(height: 4),
                                Text(
                                  'Ask your teacher for the class code!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF7A6B30),
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
