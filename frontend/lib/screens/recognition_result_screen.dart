import 'package:flutter/material.dart';
import 'quiz_practice_screen.dart';
import '../theme/app_theme.dart';

/// Screen 3 – Recognition Result
/// Displays the object the AI recognised together with its trilingual vocabulary.
class RecognitionResultScreen extends StatelessWidget {
  final Map<String, dynamic> predictionData;
  final String? childId;

  const RecognitionResultScreen({
    super.key,
    required this.predictionData,
    this.childId,
  });

  @override
  Widget build(BuildContext context) {
    final english = predictionData['english_word'] ?? '';
    final malay = predictionData['malay_word'] ?? '';
    final chinese = predictionData['chinese_word'] ?? '';
    final confidence = predictionData['confidence'] ?? 0.0;
    final pct = ((confidence as num) * 100).toStringAsFixed(0);

    return Scaffold(
      backgroundColor: AppTheme.background,
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
                        const SizedBox(height: AppTheme.sm),
                        const Text('🎉', style: TextStyle(fontSize: 52)),
                        const SizedBox(height: AppTheme.sm),
                        Text(
                          'Object Recognised!',
                          style: AppTheme.heading.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Confidence: $pct%',
                          style: AppTheme.body.copyWith(
                            fontSize: 15,
                            color: AppTheme.textLight,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── Vocabulary card ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppTheme.xl),
                          decoration: AppTheme.cardDecoration,
                          child: Column(
                            children: [
                              const Text('📦', style: TextStyle(fontSize: 56)),
                              const SizedBox(height: AppTheme.lg),
                              _VocabRow(
                                flag: '🇬🇧',
                                label: 'English',
                                value: english,
                              ),
                              const SizedBox(height: AppTheme.md),
                              _VocabRow(
                                flag: '🇲🇾',
                                label: 'Malay',
                                value: malay,
                              ),
                              const SizedBox(height: AppTheme.md),
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
                              builder: (_) => QuizPracticeScreen(
                                  vocab: predictionData,
                                  childId: childId,
                                ),
                            ),
                          ),
                          icon: const Text('🎯', style: TextStyle(fontSize: 18)),
                          label: const Text('Practice Quiz'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            foregroundColor: AppTheme.textDark,
                            minimumSize: const Size(200, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: AppTheme.buttonText.copyWith(
                              color: AppTheme.textDark,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.xxl,
                              vertical: AppTheme.lg,
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ── Scan another ──
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.camera_alt, size: 18),
                          label: const Text('Scan Another Object'),
                          style: AppTheme.secondaryButton,
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

  static Widget _backButton(BuildContext context) {
    return Align(
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
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.lg, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: AppTheme.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTheme.caption.copyWith(fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTheme.subheading.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
