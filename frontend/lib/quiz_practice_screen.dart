import 'dart:math';
import 'package:flutter/material.dart';
import 'quiz_feedback_screen.dart';
import 'theme/app_theme.dart';

/// Screen 4 – Quiz Practice
/// Presents a multiple-choice question for the scanned vocabulary word.
class QuizPracticeScreen extends StatefulWidget {
  final Map<String, dynamic> vocab;
  final String? childId;

  const QuizPracticeScreen({super.key, required this.vocab, this.childId});

  @override
  State<QuizPracticeScreen> createState() => _QuizPracticeScreenState();
}

class _QuizPracticeScreenState extends State<QuizPracticeScreen> {
  int _currentQuestion = 0;
  final List<Map<String, dynamic>> _results = [];

  late final List<_Question> _questions;

  @override
  void initState() {
    super.initState();
    final eng = widget.vocab['english_word'] ?? 'Book';
    final mal = widget.vocab['malay_word'] ?? 'Buku';
    final chi = widget.vocab['chinese_word'] ?? '书';

    _questions = [
      _Question(
        prompt: 'What is "$eng" in Malay?',
        correctAnswer: mal,
        options: _shuffle([mal, 'Kerusi', 'Meja', 'Pinggan']),
      ),
      _Question(
        prompt: 'What is "$eng" in Chinese?',
        correctAnswer: chi,
        options: _shuffle([chi, '桌子', '椅子', '电脑']),
      ),
      _Question(
        prompt: 'Which English word matches "$chi"?',
        correctAnswer: eng,
        options: _shuffle([eng, 'Chair', 'Table', 'Phone']),
      ),
    ];
  }

  List<String> _shuffle(List<String> list) {
    final copy = List<String>.from(list);
    copy.shuffle(Random());
    return copy;
  }

  void _answer(String chosen) {
    final q = _questions[_currentQuestion];
    final correct = chosen == q.correctAnswer;

    _results.add({
      'question': q.prompt,
      'chosen': chosen,
      'correct_answer': q.correctAnswer,
      'is_correct': correct,
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizFeedbackScreen(
          isCorrect: correct,
          correctAnswer: q.correctAnswer,
          chosenAnswer: chosen,
          questionIndex: _currentQuestion,
          totalQuestions: _questions.length,
          results: _results,
          vocab: widget.vocab,
          onNext: () {
            Navigator.pop(context);
            setState(() {
              _currentQuestion++;
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentQuestion >= _questions.length) {
      return const SizedBox.shrink();
    }
    final q = _questions[_currentQuestion];

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
                        const SizedBox(height: AppTheme.md),
                        const Text('🧠', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: AppTheme.sm),
                        Text(
                          'Quiz Time!',
                          style: AppTheme.heading.copyWith(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Question ${_currentQuestion + 1} of ${_questions.length}',
                          style: AppTheme.caption,
                        ),
                        const SizedBox(height: AppTheme.sm),

                        // ── Progress bar ──
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppTheme.sm),
                          child: LinearProgressIndicator(
                            value: (_currentQuestion + 1) / _questions.length,
                            minHeight: 8,
                            backgroundColor: AppTheme.primaryLight,
                            color: AppTheme.success,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── Question card ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppTheme.xl),
                          decoration: AppTheme.cardDecoration,
                          child: Column(
                            children: [
                              Text(
                                q.prompt,
                                textAlign: TextAlign.center,
                                style: AppTheme.subheading.copyWith(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AppTheme.xl),
                              ...q.options.map(
                                (opt) => Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppTheme.md,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: () => _answer(opt),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.textDark,
                                        side: BorderSide(
                                          color: AppTheme.primary.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: AppTheme.lg,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        textStyle: AppTheme.body.copyWith(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      child: Text(opt),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
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

class _Question {
  final String prompt;
  final String correctAnswer;
  final List<String> options;

  _Question({
    required this.prompt,
    required this.correctAnswer,
    required this.options,
  });
}
