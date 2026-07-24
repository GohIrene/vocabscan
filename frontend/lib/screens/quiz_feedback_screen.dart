import 'package:flutter/material.dart';
import 'quiz_summary_screen.dart';
import '../socket_service.dart';
import '../theme/app_theme.dart';

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
  final String? childId;

  /// Non-null only in Class Code mode; threaded through to QuizSummaryScreen.
  final ClassSessionContext? classSession;

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
    this.childId,
    this.classSession,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = questionIndex >= totalQuestions - 1;
    final bgColor = isCorrect ? AppTheme.successLight : AppTheme.errorLight;
    final accentColor = isCorrect ? AppTheme.success : AppTheme.error;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.all(AppTheme.xxl),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: AppTheme.shadowColor,
                      blurRadius: AppTheme.lg,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      isCorrect ? 'assets/icons/confetti.png' : 'assets/icons/sad.png',
                      width: 56,
                      height: 56,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          isCorrect ? Icons.celebration : Icons.sentiment_dissatisfied,
                          size: 56,
                          color: accentColor,
                        );
                      },
                    ),
                    const SizedBox(height: AppTheme.md),
                    Text(
                      isCorrect ? 'Correct!' : 'Not quite…',
                      style: AppTheme.heading.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (!isCorrect) ...[
                      Text(
                        'Your answer: $chosenAnswer',
                        style: AppTheme.body.copyWith(color: AppTheme.textLight),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Correct answer: $correctAnswer',
                        style: AppTheme.body.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    if (isCorrect)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Great job! Keep going!',
                            style: AppTheme.body.copyWith(color: AppTheme.success),
                          ),
                          const SizedBox(width: 6),
                          Image.asset(
                            'assets/icons/star.png',
                            width: 18,
                            height: 18,
                            errorBuilder: (context, error, stackTrace) {
                              return const SizedBox(width: 18, height: 18);
                            },
                          ),
                        ],
                      ),
                    const SizedBox(height: AppTheme.xl),
                    FilledButton.icon(
                      onPressed: isLast
                          ? () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => QuizSummaryScreen(
                                    results: results,
                                    vocab: vocab,
                                    childId: childId,
                                    classSession: classSession,
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
                        foregroundColor: AppTheme.surface,
                        minimumSize: const Size(200, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: AppTheme.buttonText,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.xxl,
                          vertical: AppTheme.lg,
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
