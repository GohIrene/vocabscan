import 'dart:math';
import 'package:flutter/material.dart';
import 'quiz_feedback_screen.dart';

/// Screen 4 – Quiz Practice
/// Presents a multiple-choice question for the scanned vocabulary word.
class QuizPracticeScreen extends StatefulWidget {
  final Map<String, dynamic> vocab;

  const QuizPracticeScreen({super.key, required this.vocab});

  @override
  State<QuizPracticeScreen> createState() => _QuizPracticeScreenState();
}

class _QuizPracticeScreenState extends State<QuizPracticeScreen> {
  int _currentQuestion = 0;
  final List<Map<String, dynamic>> _results = [];

  // We create 3 mini-questions from the vocab data.
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

    // Navigate to feedback screen
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
            Navigator.pop(context); // pop feedback
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
      // safety – should not reach here
      return const SizedBox.shrink();
    }
    final q = _questions[_currentQuestion];

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
                        const SizedBox(height: 12),
                        const Text('🧠', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 8),
                        const Text(
                          'Quiz Time!',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF17234D),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Question ${_currentQuestion + 1} of ${_questions.length}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF65708C),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // ── Progress bar ──
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: (_currentQuestion + 1) / _questions.length,
                            minHeight: 8,
                            backgroundColor: const Color(0xFFE0DCF0),
                            color: const Color(0xFF80DFA7),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── Question card ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 14,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                q.prompt,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF17234D),
                                ),
                              ),
                              const SizedBox(height: 24),
                              ...q.options.map(
                                (opt) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: () => _answer(opt),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF17234D,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0xFFD5D0E3),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        textStyle: const TextStyle(
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
