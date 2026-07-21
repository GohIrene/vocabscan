import 'dart:math';
import 'package:flutter/material.dart';
import 'quiz_feedback_screen.dart';
import '../api_service.dart';
import '../theme/app_theme.dart';

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

  List<_Question>? _questions;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final eng = (widget.vocab['english_word'] as String?) ?? 'Book';
    final mal = (widget.vocab['malay_word'] as String?) ?? 'Buku';
    final chi = (widget.vocab['chinese_word'] as String?) ?? '书';
    final englishKey = (widget.vocab['english_key'] as String?) ?? '';

    // Real vocab-based wrong answers (same pool Class Code draws from) instead
    // of a fixed hardcoded list, so options vary per scanned object and can
    // never collide with the correct answer. One combined request fetches all
    // three distractor sets at once (was three parallel calls).
    try {
      final distractors =
          await ApiService.getQuizQuestions(englishKey: englishKey);

      final questions = [
        _Question(
          prompt: 'What is "$eng" in Malay?',
          correctAnswer: mal,
          options: _shuffle([mal, ...?distractors['malay_word']]),
        ),
        _Question(
          prompt: 'What is "$eng" in Chinese?',
          correctAnswer: chi,
          options: _shuffle([chi, ...?distractors['chinese_word']]),
        ),
        _Question(
          prompt: 'Which English word matches "$chi"?',
          correctAnswer: eng,
          options: _shuffle([eng, ...?distractors['english_word']]),
        ),
      ];

      if (mounted) {
        setState(() {
          _questions = questions;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<String> _shuffle(List<String> list) {
    final copy = List<String>.from(list);
    copy.shuffle(Random());
    return copy;
  }

  void _answer(String chosen) {
    final questions = _questions!;
    final q = questions[_currentQuestion];
    final correct = chosen == q.correctAnswer;

    _results.add({
      'question': q.prompt,
      'chosen': chosen,
      'correct_answer': q.correctAnswer,
      'is_correct': correct,
    });

    // Fire and forget — don't block UI
    final cid = widget.childId;
    final englishKey = widget.vocab['english_key'] as String? ?? '';
    // ignore: avoid_print
    print('LOG QUIZ: childId=$cid, key=$englishKey, correct=$correct');
    if (cid != null) {
      ApiService.logQuiz(cid, englishKey, correct);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizFeedbackScreen(
          isCorrect: correct,
          correctAnswer: q.correctAnswer,
          chosenAnswer: chosen,
          questionIndex: _currentQuestion,
          totalQuestions: questions.length,
          results: _results,
          vocab: widget.vocab,
          childId: widget.childId,
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
    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Column(
            children: [
              _backButton(context),
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Column(
            children: [
              _backButton(context),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('⚠️', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 16),
                        Text('Failed to load quiz', style: AppTheme.subheading),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: AppTheme.caption,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _loadQuestions,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Retry'),
                          style: AppTheme.primaryButton,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final questions = _questions!;
    if (_currentQuestion >= questions.length) {
      return const SizedBox.shrink();
    }
    final q = questions[_currentQuestion];

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
                          'Question ${_currentQuestion + 1} of ${questions.length}',
                          style: AppTheme.caption,
                        ),
                        const SizedBox(height: AppTheme.sm),

                        // ── Progress bar ──
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppTheme.sm),
                          child: LinearProgressIndicator(
                            value: (_currentQuestion + 1) / questions.length,
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
