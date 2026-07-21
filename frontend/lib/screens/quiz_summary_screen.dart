import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Pops exactly [count] routes off the navigator, or fewer if the stack runs
/// out first. Deliberately unnamed/count-based rather than matching a
/// RouteSettings name: naming a route makes Flutter Web reflect it in the
/// browser's address bar, and an unrelated page reload while sitting on that
/// URL has nowhere to restore to in this app (no route table), which dumps
/// the whole session back to the welcome screen.
void _popRoutes(BuildContext context, int count) {
  var remaining = count;
  Navigator.of(context).popUntil((route) {
    if (route.isFirst || remaining <= 0) return true;
    remaining--;
    return false;
  });
}

/// Screen 6 – Quiz Summary
/// Shows overall score and per-question results after completing the quiz.
class QuizSummaryScreen extends StatelessWidget {
  final List<Map<String, dynamic>> results;
  final Map<String, dynamic> vocab;
  final String? childId;

  const QuizSummaryScreen({
    super.key,
    required this.results,
    required this.vocab,
    this.childId,
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
                  Image.asset(
                    'assets/icons/trophy.png',
                    width: 56,
                    height: 56,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.emoji_events, size: 56);
                    },
                  ),
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
                          Image.asset(
                            ok
                                ? 'assets/icons/checkmark.png'
                                : 'assets/icons/cross.png',
                            width: 24,
                            height: 24,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                ok ? Icons.check_circle : Icons.cancel,
                                size: 24,
                                color: ok ? AppTheme.success : AppTheme.error,
                              );
                            },
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
                      // Unwind the quiz sub-flow (Result, Practice, this Summary
                      // screen -- 3 routes) back onto the scan screen that started
                      // it. Reusing that instance (rather than pushing a fresh
                      // one) keeps its camera live and, in Class Code mode, keeps
                      // the teacher's live session context intact.
                      //
                      // Counts routes rather than matching a name/predicate: a
                      // named route makes Flutter Web reflect it in the browser
                      // URL bar, and a stray reload while sitting on that URL has
                      // nowhere to restore to (this app has no route table),
                      // dumping the whole session back to the welcome screen.
                      _popRoutes(context, 3);
                    },
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: const Text('Scan Another Object'),
                    style: AppTheme.primaryButton,
                  ),
                  const SizedBox(height: AppTheme.md),
                  OutlinedButton(
                    onPressed: () {
                      // One route further than "Scan Another Object" -- past the
                      // scan screen too -- landing on whichever screen opened it
                      // (parent home, teacher home, or a live class session).
                      _popRoutes(context, 4);
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(200, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Done'),
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
