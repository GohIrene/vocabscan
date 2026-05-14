import 'package:flutter/material.dart';
import 'quiz_summary_screen.dart';

/// Screen 5 – Quiz Feedback
/// Shows whether the answer was correct and the right answer if wrong.
class QuizFeedbackScreen extends StatelessWidget {
  final bool isCorrect;
  final String correctAnswer;
  final String chosenAnswer;
  final int questionIndex;
  final int totalQuestions;
  final List<Map<String, dynamic>> results;
  final Map<String, dynamic> vocab;
  final VoidCallback onNext;

  const QuizFeedbackScreen({
    super.key,
    required this.isCorrect,
    required this.correctAnswer,
    required this.chosenAnswer,
    required this.questionIndex,
    required this.totalQuestions,
    required this.results,
    required this.vocab,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = questionIndex >= totalQuestions - 1;
    final bgColor = isCorrect
        ? const Color(0xFFE6FFED)
        : const Color(0xFFFFEBEB);
    final accentColor = isCorrect
        ? const Color(0xFF2E9E5E)
        : const Color(0xFFD9534F);

    return Scaffold(
      backgroundColor: const Color(0xFFF1ECFF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: bgColor,
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
                    Text(
                      isCorrect ? '🎉' : '😢',
                      style: const TextStyle(fontSize: 56),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isCorrect ? 'Correct!' : 'Not quite…',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (!isCorrect) ...[
                      Text(
                        'Your answer: $chosenAnswer',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF65708C),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Correct answer: $correctAnswer',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    if (isCorrect)
                      const Text(
                        'Great job! Keep going! 🌟',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF2E9E5E),
                        ),
                      ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: isLast
                          ? () {
                              // Pop feedback, then push summary
                              Navigator.pop(context);
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => QuizSummaryScreen(
                                    results: results,
                                    vocab: vocab,
                                  ),
                                ),
                              );
                            }
                          : onNext,
                      icon: Icon(
                        isLast ? Icons.flag_rounded : Icons.arrow_forward,
                        size: 18,
                      ),
                      label: Text(isLast ? 'See Results' : 'Next Question'),
                      style: FilledButton.styleFrom(
                        backgroundColor: accentColor,
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
