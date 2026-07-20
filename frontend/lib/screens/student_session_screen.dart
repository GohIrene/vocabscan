import 'package:flutter/material.dart';

import '../socket_service.dart';
import '../theme/app_theme.dart';
import '../widgets/class_leaderboard.dart';

/// Live Class Code session (student side).
///
/// No polling and no Timer — the UI is driven entirely by socket events:
/// waiting → new_quiz → answer → answer_result → waiting → session_ended.
class StudentSessionScreen extends StatefulWidget {
  final String sessionId;
  final String code;
  final String nickname;

  const StudentSessionScreen({
    super.key,
    required this.sessionId,
    required this.code,
    required this.nickname,
  });

  @override
  State<StudentSessionScreen> createState() => _StudentSessionScreenState();
}

class _StudentSessionScreenState extends State<StudentSessionScreen> {
  final SocketService _socket = SocketService();

  bool _connected = false;
  int _studentCount = 0;

  // Current quiz
  String? _quizId;
  String? _prompt;
  List<String> _options = [];

  String? _selectedOption;
  bool _awaitingResult = false;

  // Result of the last answer
  bool? _lastCorrect;
  String? _lastCorrectAnswer;

  bool _ended = false;
  List<Map<String, dynamic>> _leaderboard = [];

  @override
  void initState() {
    super.initState();
    _socket
      ..onConnectionChange = (c) {
        if (mounted) setState(() => _connected = c);
      }
      ..onStudentJoined = (d) {
        if (mounted) {
          setState(() => _studentCount = (d['student_count'] ?? 0) as int);
        }
      }
      ..onStudentLeft = (d) {
        if (mounted) {
          setState(() => _studentCount = (d['student_count'] ?? 0) as int);
        }
      }
      ..onNewQuiz = (d) {
        if (mounted) {
          setState(() {
            _quizId = d['quiz_id'] as String?;
            _prompt = d['prompt'] as String?;
            _options = ((d['options'] ?? []) as List).cast<String>();
            _selectedOption = null;
            _awaitingResult = false;
            _lastCorrect = null;
            _lastCorrectAnswer = null;
          });
        }
      }
      ..onAnswerResult = (d) {
        if (mounted) {
          setState(() {
            _lastCorrect = d['correct'] as bool?;
            _lastCorrectAnswer = d['correct_answer'] as String?;
            _awaitingResult = false;
          });
        }
      }
      ..onAnswerRejected = (d) {
        if (mounted) {
          setState(() => _awaitingResult = false);
          final String message;
          switch (d['reason']) {
            case 'already_answered':
              message = 'You already answered this one!';
              break;
            case 'server_error':
              message = 'Could not submit your answer. Please try again.';
              break;
            default:
              message = 'That question has moved on.';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      }
      ..onSessionEnded = (d) {
        if (mounted) {
          setState(() {
            _ended = true;
            _leaderboard =
                ((d['leaderboard'] ?? []) as List).cast<Map<String, dynamic>>();
          });
        }
      }
      ..onSessionError = (d) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text((d['message'] ?? 'Session error').toString())),
          );
        }
      }
      ..connect(
        code: widget.code,
        role: 'student',
        nickname: widget.nickname,
      );
  }

  void _answer(String chosen) {
    if (_awaitingResult || _lastCorrect != null || _quizId == null) return;
    setState(() {
      _selectedOption = chosen;
      _awaitingResult = true;
    });
    _socket.submitAnswer(widget.sessionId, widget.nickname, _quizId!, chosen);
  }

  @override
  void dispose() {
    _socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: _buildBody(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.md),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Leave'),
            style: AppTheme.backButtonStyle,
          ),
          const Spacer(),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _connected ? AppTheme.success : AppTheme.warning,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _connected ? 'Connected' : 'Reconnecting…',
            style: AppTheme.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_ended) {
      return Column(
        children: [
          const SizedBox(height: AppTheme.md),
          const Text('🎉', style: TextStyle(fontSize: 52)),
          const SizedBox(height: AppTheme.sm),
          Text(
            'Session Complete!',
            style: AppTheme.heading
                .copyWith(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          ClassLeaderboard(
            leaderboard: _leaderboard,
            highlightNickname: widget.nickname,
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.home_outlined, size: 18),
            label: const Text('Done'),
            style: AppTheme.secondaryButton,
          ),
          const SizedBox(height: AppTheme.xxl),
        ],
      );
    }

    // Just answered → show feedback until the next quiz arrives.
    if (_lastCorrect != null) {
      final correct = _lastCorrect!;
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Text(correct ? '✅' : '❌', style: const TextStyle(fontSize: 72)),
            const SizedBox(height: AppTheme.md),
            Text(
              correct ? 'Correct!' : 'Not quite!',
              style: AppTheme.heading.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: correct ? AppTheme.success : AppTheme.error,
              ),
            ),
            if (!correct && _lastCorrectAnswer != null) ...[
              const SizedBox(height: 8),
              Text(
                'Answer: $_lastCorrectAnswer',
                style: AppTheme.body.copyWith(color: AppTheme.textLight),
              ),
            ],
            const SizedBox(height: 28),
            _waitingChip('Waiting for the next question… 🧑‍🏫'),
          ],
        ),
      );
    }

    // A live quiz we haven't answered yet.
    if (_quizId != null && _prompt != null) {
      return Column(
        children: [
          const SizedBox(height: AppTheme.md),
          const Text('🧠', style: TextStyle(fontSize: 48)),
          const SizedBox(height: AppTheme.sm),
          Text(
            'Quiz Time!',
            style: AppTheme.heading
                .copyWith(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.xl),
            decoration: AppTheme.cardDecoration,
            child: Column(
              children: [
                Text(
                  _prompt!,
                  textAlign: TextAlign.center,
                  style: AppTheme.subheading
                      .copyWith(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppTheme.xl),
                ..._options.map(
                  (opt) => Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.md),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _awaitingResult ? null : () => _answer(opt),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textDark,
                          backgroundColor: _selectedOption == opt
                              ? AppTheme.primaryLight
                              : null,
                          side: BorderSide(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: AppTheme.lg,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
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
                if (_awaitingResult) ...[
                  const SizedBox(height: 8),
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppTheme.xxl),
        ],
      );
    }

    // Default: waiting for the teacher to send a quiz.
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          const Text('🧑‍🏫', style: TextStyle(fontSize: 64)),
          const SizedBox(height: AppTheme.lg),
          Text(
            'Waiting for teacher…',
            style: AppTheme.heading
                .copyWith(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re in! Class code: ${widget.code}',
            style: AppTheme.caption,
          ),
          const SizedBox(height: 4),
          Text(
            '$_studentCount student${_studentCount == 1 ? '' : 's'} in the class',
            style: AppTheme.caption,
          ),
          const SizedBox(height: 28),
          _waitingChip('The teacher will send a quiz soon! 🎯'),
        ],
      ),
    );
  }

  Widget _waitingChip(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTheme.body.copyWith(
          color: AppTheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
