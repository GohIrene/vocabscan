import 'package:flutter/material.dart';

import '../socket_service.dart';
import '../theme/app_theme.dart';
import '../widgets/class_leaderboard.dart';
import '../widgets/student_progress.dart';
import '../widgets/vocab_icon.dart';

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
  String? _quizEnglishKey;
  String? _quizPattern;

  String? _selectedOption;
  bool _awaitingResult = false;

  // Result of the last answer
  bool? _lastCorrect;
  String? _lastCorrectAnswer;

  // ── Summary quiz: a multi-question recap the student works through at
  // their own pace, so progress is tracked by quiz_id rather than a single
  // "current" question. Scores roll into the same leaderboard.
  String? _summaryId;
  List<Map<String, dynamic>> _summaryQuestions = [];
  final Set<String> _summaryAnswered = {};
  int _summaryIndex = 0;
  int _summaryScore = 0;
  bool _summaryAwaiting = false;
  String? _summarySelected;
  bool? _summaryLastCorrect;
  String? _summaryLastCorrectAnswer;
  bool _summaryDone = false;

  bool _ended = false;
  List<Map<String, dynamic>> _leaderboard = [];

  /// XP/level/badges earned this session. Null when the teacher ran the
  /// session without a saved class, since there's no roster to credit.
  Map<String, dynamic>? _progress;

  /// Index of the first question this student hasn't answered yet, or the
  /// list length when they've finished them all.
  int _firstUnansweredIndex() {
    for (var i = 0; i < _summaryQuestions.length; i++) {
      final qid = _summaryQuestions[i]['quiz_id'] as String?;
      if (qid != null && !_summaryAnswered.contains(qid)) return i;
    }
    return _summaryQuestions.length;
  }

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
            _quizEnglishKey = d['english_key'] as String?;
            _quizPattern = d['pattern'] as String?;
            _selectedOption = null;
            _awaitingResult = false;
            _lastCorrect = null;
            _lastCorrectAnswer = null;
            // A normal quiz supersedes a live recap (the server does the same),
            // so drop the summary and show the new question.
            _summaryQuestions = [];
            _summaryId = null;
            _summaryDone = false;
          });
        }
      }
      ..onSummaryQuiz = (d) {
        if (!mounted) return;
        final questions = ((d['questions'] ?? []) as List)
            .whereType<Map>()
            .map((q) => Map<String, dynamic>.from(q))
            .toList();
        // On reconnect the server replays the recap and tells us which
        // questions we already answered, so we resume instead of re-answering
        // (which the server would reject anyway).
        final answered =
            ((d['answered'] ?? []) as List).map((e) => e.toString()).toSet();
        setState(() {
          _summaryId = d['summary_id'] as String?;
          _summaryQuestions = questions;
          _summaryAnswered
            ..clear()
            ..addAll(answered);
          // Server-supplied, so a student who reconnects partway through the
          // recap keeps the points they'd already earned instead of the final
          // card counting only what they answered after reconnecting.
          _summaryScore = (d['correct_count'] ?? 0) as int;
          _summaryAwaiting = false;
          _summarySelected = null;
          _summaryLastCorrect = null;
          _summaryLastCorrectAnswer = null;
          _summaryIndex = _firstUnansweredIndex();
          _summaryDone = _summaryIndex >= _summaryQuestions.length;
          // Clear single-quiz state so the recap owns the screen.
          _quizId = null;
          _prompt = null;
          _options = [];
          _lastCorrect = null;
          _lastCorrectAnswer = null;
        });
      }
      ..onSummaryAnswerResult = (d) {
        if (!mounted) return;
        setState(() {
          _summaryAwaiting = false;
          _summaryLastCorrect = d['correct'] as bool?;
          _summaryLastCorrectAnswer = d['correct_answer'] as String?;
          final qid = d['quiz_id'] as String?;
          if (qid != null) _summaryAnswered.add(qid);
          if (_summaryLastCorrect == true) _summaryScore++;
        });
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
          setState(() {
            _awaitingResult = false;
            _summaryAwaiting = false;
          });
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
      ..onProgressUpdate = (d) {
        // Only arrives for a session run against a saved class; stays null
        // otherwise, and the end screen simply omits the XP card.
        if (mounted) setState(() => _progress = d);
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

  void _answerSummary(String chosen) {
    if (_summaryAwaiting || _summaryLastCorrect != null) return;
    final summaryId = _summaryId;
    if (summaryId == null || _summaryIndex >= _summaryQuestions.length) return;
    final quizId = _summaryQuestions[_summaryIndex]['quiz_id'] as String?;
    if (quizId == null) return;

    setState(() {
      _summarySelected = chosen;
      _summaryAwaiting = true;
    });
    _socket.submitSummaryAnswer(
      widget.sessionId,
      widget.nickname,
      summaryId,
      quizId,
      chosen,
    );
  }

  /// Clears the feedback and moves to the next unanswered question, or marks
  /// the recap finished when there are none left.
  void _nextSummaryQuestion() {
    setState(() {
      _summaryLastCorrect = null;
      _summaryLastCorrectAnswer = null;
      _summarySelected = null;
      _summaryIndex = _firstUnansweredIndex();
      _summaryDone = _summaryIndex >= _summaryQuestions.length;
    });
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

  /// What this child earned: XP gained, their level bar, and any badge they
  /// just unlocked. Shown only for sessions run against a saved class.
  Widget _buildRewardCard(Map<String, dynamic> p) {
    final gained = (p['xp_gained'] as num? ?? 0).toInt();
    final level = (p['level'] as num? ?? 1).toInt();
    final levelledUp = p['levelled_up'] == true;
    final newBadges = (p['new_badges'] as List? ?? const [])
        .whereType<Map>()
        .map((b) => Map<String, dynamic>.from(b))
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.xl),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          if (levelledUp) ...[
            const Text('🎉', style: TextStyle(fontSize: 36)),
            const SizedBox(height: AppTheme.xs),
            Text(
              'Level Up! You reached Level $level',
              textAlign: TextAlign.center,
              style: AppTheme.subheading.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.adventure,
              ),
            ),
            const SizedBox(height: AppTheme.md),
          ],
          Text(
            '+$gained XP',
            style: AppTheme.heading.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: AppTheme.md),
          LevelBar(
            level: level,
            xpIntoLevel: (p['xp_into_level'] as num? ?? 0).toInt(),
            xpPerLevel: (p['xp_per_level'] as num? ?? 100).toInt(),
          ),
          if (newBadges.isNotEmpty) ...[
            const SizedBox(height: AppTheme.lg),
            Text(
              newBadges.length == 1 ? 'New badge!' : 'New badges!',
              style: AppTheme.body.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppTheme.sm),
            Wrap(
              spacing: AppTheme.sm,
              runSpacing: AppTheme.sm,
              alignment: WrapAlignment.center,
              children: newBadges.map((b) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.md, vertical: AppTheme.sm),
                  decoration: BoxDecoration(
                    color: AppTheme.warningLight,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Text(
                    '${b['emoji'] ?? '🏅'}  ${b['label'] ?? ''}',
                    style: AppTheme.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_ended) {
      return Column(
        children: [
          const SizedBox(height: AppTheme.md),
          Image.asset(
            'assets/icons/confetti.png',
            width: 52,
            height: 52,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.celebration, size: 52);
            },
          ),
          const SizedBox(height: AppTheme.sm),
          Text(
            'Session Complete!',
            style: AppTheme.heading
                .copyWith(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          if (_progress != null) ...[
            _buildRewardCard(_progress!),
            const SizedBox(height: 20),
          ],
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

    // A summary quiz takes over the screen until it's finished.
    if (_summaryQuestions.isNotEmpty) return _buildSummaryBody();

    // Just answered → show feedback until the next quiz arrives.
    if (_lastCorrect != null) {
      final correct = _lastCorrect!;
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Image.asset(
              correct ? 'assets/icons/checkmark.png' : 'assets/icons/cross.png',
              width: 72,
              height: 72,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  correct ? Icons.check_circle : Icons.cancel,
                  size: 72,
                  color: correct ? AppTheme.success : AppTheme.error,
                );
              },
            ),
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
            _waitingChip('Waiting for the next question…'),
          ],
        ),
      );
    }

    // A live quiz we haven't answered yet.
    if (_quizId != null && _prompt != null) {
      return Column(
        children: [
          const SizedBox(height: AppTheme.md),
          Image.asset(
            'assets/icons/brain.png',
            width: 48,
            height: 48,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.psychology, size: 48);
            },
          ),
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
                if (_quizPattern != 'zh_en') ...[
                  VocabIcon(englishKey: _quizEnglishKey),
                  const SizedBox(height: AppTheme.md),
                ],
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
          Image.asset(
            'assets/icons/teacher.png',
            width: 64,
            height: 64,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.person_2_outlined, size: 64);
            },
          ),
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
          _waitingChip('The teacher will send a quiz soon!'),
        ],
      ),
    );
  }

  /// The self-paced recap: one question at a time, feedback after each, then a
  /// score card. Kept separate from the live-quiz UI because the student drives
  /// the pace here rather than the teacher.
  Widget _buildSummaryBody() {
    final total = _summaryQuestions.length;

    if (_summaryDone) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Image.asset(
              'assets/icons/star.png',
              width: 64,
              height: 64,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.star, size: 64);
              },
            ),
            const SizedBox(height: AppTheme.md),
            Text(
              'Summary Complete!',
              style: AppTheme.heading
                  .copyWith(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'You got $_summaryScore out of $total right',
              style: AppTheme.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 28),
            _waitingChip('Great work! Waiting for your teacher…'),
          ],
        ),
      );
    }

    // Feedback for the question just answered.
    if (_summaryLastCorrect != null) {
      final correct = _summaryLastCorrect!;
      final isLast = _firstUnansweredIndex() >= total;
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Image.asset(
              correct ? 'assets/icons/checkmark.png' : 'assets/icons/cross.png',
              width: 72,
              height: 72,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  correct ? Icons.check_circle : Icons.cancel,
                  size: 72,
                  color: correct ? AppTheme.success : AppTheme.error,
                );
              },
            ),
            const SizedBox(height: AppTheme.md),
            Text(
              correct ? 'Correct!' : 'Not quite!',
              style: AppTheme.heading.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: correct ? AppTheme.success : AppTheme.error,
              ),
            ),
            if (!correct && _summaryLastCorrectAnswer != null) ...[
              const SizedBox(height: 8),
              Text(
                'Answer: $_summaryLastCorrectAnswer',
                style: AppTheme.body.copyWith(color: AppTheme.textLight),
              ),
            ],
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _nextSummaryQuestion,
              icon: Icon(isLast ? Icons.flag_outlined : Icons.arrow_forward,
                  size: 18),
              label: Text(isLast ? 'Finish' : 'Next Question'),
              style: AppTheme.primaryButton,
            ),
            const SizedBox(height: AppTheme.xxl),
          ],
        ),
      );
    }

    final question = _summaryQuestions[_summaryIndex];
    final prompt = question['prompt'] as String? ?? '';
    final options = ((question['options'] ?? []) as List).cast<String>();
    final answeredCount = _summaryAnswered.length;
    final iconKey = question['pattern'] == 'zh_en'
        ? null
        : question['english_key'] as String?;

    return Column(
      children: [
        const SizedBox(height: AppTheme.md),
        const Text('📝', style: TextStyle(fontSize: 48)),
        const SizedBox(height: AppTheme.sm),
        Text(
          'Summary Quiz',
          style: AppTheme.heading
              .copyWith(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Question ${answeredCount + 1} of $total',
          style: AppTheme.caption,
        ),
        const SizedBox(height: AppTheme.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.sm),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : answeredCount / total,
            minHeight: 8,
            backgroundColor: AppTheme.primaryLight,
            color: AppTheme.success,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTheme.xl),
          decoration: AppTheme.cardDecoration,
          child: Column(
            children: [
              if (iconKey != null) ...[
                VocabIcon(englishKey: iconKey),
                const SizedBox(height: AppTheme.md),
              ],
              Text(
                prompt,
                textAlign: TextAlign.center,
                style: AppTheme.subheading
                    .copyWith(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppTheme.xl),
              ...options.map(
                (opt) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.md),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed:
                          _summaryAwaiting ? null : () => _answerSummary(opt),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textDark,
                        backgroundColor: _summarySelected == opt
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
              if (_summaryAwaiting) ...[
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
