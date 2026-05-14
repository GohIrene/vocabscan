import 'package:flutter/material.dart';
import 'mode_selection_screen.dart';

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
      backgroundColor: const Color(0xFFF1ECFF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 8),
                  const Text(
                    'Quiz Complete!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF17234D),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Score badge ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: correct == total
                          ? const Color(0xFFE6FFED)
                          : const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$correct / $total correct ($pct%)',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: correct == total
                            ? const Color(0xFF2E9E5E)
                            : const Color(0xFFD4A017),
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
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ok
                            ? const Color(0xFFE6FFED)
                            : const Color(0xFFFFEBEB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: ok
                              ? const Color(0xFFACE8C5)
                              : const Color(0xFFF5BBB9),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            ok ? '✅' : '❌',
                            style: const TextStyle(fontSize: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Q${i + 1}: ${r['question']}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF17234D),
                                  ),
                                ),
                                if (!ok) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Your answer: ${r['chosen']}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF8B6E6E),
                                    ),
                                  ),
                                  Text(
                                    'Correct: ${r['correct_answer']}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2E9E5E),
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
                      // Pop back to the Mode Selection Screen
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const ModeSelectionScreen(),
                        ),
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.home_rounded, size: 18),
                    label: const Text('Back to Home'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF9B8CF2),
                      foregroundColor: Colors.white,
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
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
