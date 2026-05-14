import 'package:flutter/material.dart';
import 'quiz_practice_screen.dart';

/// Screen 3 – Recognition Result
/// Displays the object the AI recognised together with its trilingual vocabulary.
class RecognitionResultScreen extends StatelessWidget {
  final Map<String, dynamic> predictionData;

  const RecognitionResultScreen({super.key, required this.predictionData});

  @override
  Widget build(BuildContext context) {
    final english = predictionData['english_word'] ?? '';
    final malay = predictionData['malay_word'] ?? '';
    final chinese = predictionData['chinese_word'] ?? '';
    final confidence = predictionData['confidence'] ?? 0.0;
    final pct = ((confidence as num) * 100).toStringAsFixed(0);

    return Scaffold(
      backgroundColor: const Color(0xFFF1ECFF),
      body: SafeArea(
        child: Column(
          children: [
            _backButton(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        const Text('🎉', style: TextStyle(fontSize: 52)),
                        const SizedBox(height: 8),
                        const Text(
                          'Object Recognised!',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF17234D),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Confidence: $pct%',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF65708C),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── Vocabulary card ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x18000000),
                                blurRadius: 16,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Big object emoji
                              const Text('📦', style: TextStyle(fontSize: 56)),
                              const SizedBox(height: 16),
                              _VocabRow(
                                flag: '🇬🇧',
                                label: 'English',
                                value: english,
                              ),
                              const SizedBox(height: 12),
                              _VocabRow(
                                flag: '🇲🇾',
                                label: 'Malay',
                                value: malay,
                              ),
                              const SizedBox(height: 12),
                              _VocabRow(
                                flag: '🇨🇳',
                                label: 'Chinese',
                                value: chinese,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── Practice quiz ──
                        FilledButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  QuizPracticeScreen(vocab: predictionData),
                            ),
                          ),
                          icon: const Text(
                            '🎯',
                            style: TextStyle(fontSize: 18),
                          ),
                          label: const Text('Practice Quiz'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF80DFA7),
                            foregroundColor: const Color(0xFF17234D),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ── Scan another ──
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.camera_alt, size: 18),
                          label: const Text('Scan Another Object'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF7C6CF2),
                            side: const BorderSide(
                              color: Color(0xFF7C6CF2),
                              width: 2,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
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

  static Widget _backButton(BuildContext context) {
    return Align(
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
    );
  }
}

/// One row inside the vocabulary card.
class _VocabRow extends StatelessWidget {
  final String flag;
  final String label;
  final String value;

  const _VocabRow({
    required this.flag,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1ECFF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF65708C)),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF17234D),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
