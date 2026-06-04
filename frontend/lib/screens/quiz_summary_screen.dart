import 'package:flutter/material.dart';
import 'welcome_screen.dart';
import '../theme/app_theme.dart';

/// Screen 6 – Quiz Summary
/// Shows overall score and per-question results after completing the quiz.
class QuizSummaryScreen extends StatelessWidget {
  final List<Map<String, dynamic>> results;
  final Map<String, dynamic> vocab;

  const QuizSummaryScreen({
    super.key,
    required this.results,
    required this.vocab,
  });

  @override
  Widget build(BuildContext context) {
    final total = results.length;
    final correct = results.where((r) => r['is_correct'] == true).length;
    final pct = total > 0 ? (correct / total * 100).toStringAsFixed(0) : '0';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: AppTheme.xl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: AppTheme.sm),
                  Text(
                    'Quiz Complete!',
                    style: AppTheme.heading.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppTheme.sm),

                  // ── Score badge ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: AppTheme.lg,
                    ),
                    decoration: BoxDecoration(
                      color: correct == total
                          ? AppTheme.successLight
                          : AppTheme.warningLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$correct / $total correct ($pct%)',
                      style: AppTheme.subheading.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: correct == total
                            ? AppTheme.success
                            : AppTheme.warning,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Per-question breakdown ──
                  ...results.asMap().entries.map((entry) {
                    final i = entry.key;
                    final r = entry.value;
                    final ok = r['is_correct'] == true;
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: AppTheme.md),
                      padding: const EdgeInsets.all(AppTheme.lg),
                      decoration: BoxDecoration(
                        color: ok ? AppTheme.successLight : AppTheme.errorLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: ok
                              ? AppTheme.success.withValues(alpha: 0.4)
                              : AppTheme.error.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            ok ? '✅' : '❌',
                            style: const TextStyle(fontSize: 22),
                          ),
                          const SizedBox(width: AppTheme.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Q${i + 1}: ${r['question']}',
                                  style: AppTheme.body.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (!ok) ...[
                                  const SizedBox(height: AppTheme.xs),
                                  Text(
                                    'Your answer: ${r['chosen']}',
                                    style: AppTheme.caption.copyWith(
                                      color: AppTheme.textLight,
                                    ),
                                  ),
                                  Text(
                                    'Correct: ${r['correct_answer']}',
                                    style: AppTheme.caption.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.success,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 20),

                  // ── Actions ──
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const WelcomeScreen(),
                        ),
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.home_rounded, size: 18),
                    label: const Text('Back to Home'),
                    style: AppTheme.primaryButton,
                  ),
                  const SizedBox(height: AppTheme.xxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
