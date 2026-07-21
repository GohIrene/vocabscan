import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_service.dart';
import '../socket_service.dart';
import '../theme/app_theme.dart';
import '../widgets/class_leaderboard.dart';
import 'scan_object_screen.dart';

/// Live Class Code session (teacher side).
///
/// Creates a session over REST, shows the projector-readable code, tracks the
/// live student count over the socket, lets the teacher scan an object to push
/// a quiz, and ends the session with a leaderboard.
class TeacherClassSessionScreen extends StatefulWidget {
  final String teacherId;

  const TeacherClassSessionScreen({super.key, required this.teacherId});

  @override
  State<TeacherClassSessionScreen> createState() =>
      _TeacherClassSessionScreenState();
}

class _TeacherClassSessionScreenState extends State<TeacherClassSessionScreen> {
  final SocketService _socket = SocketService();

  bool _loading = true;
  String? _error;
  String? _sessionId;
  String? _code;

  int _studentCount = 0;
  bool _connected = false;

  bool _quizLive = false;
  int _answeredCount = 0;
  int _quizStudentCount = 0;

  // Quizzes pushed so far. The server builds the summary from the DISTINCT
  // words behind them, so this is only used to gate the button — it stays
  // disabled until the class has actually been sent something to recap.
  int _quizzesSent = 0;

  bool _summaryLive = false;
  int _summaryFinished = 0;
  int _summaryTotal = 0;

  bool _ended = false;
  List<Map<String, dynamic>> _leaderboard = [];

  @override
  void initState() {
    super.initState();
    _createSession();
  }

  Future<void> _createSession() async {
    final res = await ApiService.createClassSession(widget.teacherId);
    if (!mounted) return;

    final sessionId = res['session_id'] as String?;
    final code = res['code'] as String?;
    if (sessionId == null || code == null) {
      setState(() {
        _loading = false;
        _error = (res['message'] as String?) ?? 'Could not create session';
      });
      return;
    }

    setState(() {
      _sessionId = sessionId;
      _code = code;
      _loading = false;
    });

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
      ..onNewQuiz = (_) {
        if (mounted) {
          setState(() {
            _quizLive = true;
            _answeredCount = 0;
            _quizStudentCount = _studentCount;
            _quizzesSent++;
            // A normal quiz supersedes a live summary (server does the same).
            _summaryLive = false;
          });
        }
      }
      ..onSummaryQuiz = (d) {
        if (mounted) {
          setState(() {
            _summaryLive = true;
            _summaryTotal = (d['total'] ?? 0) as int;
            _summaryFinished = 0;
            _quizLive = false;
          });
        }
      }
      ..onSummaryProgress = (d) {
        if (mounted) {
          setState(() {
            _summaryFinished = (d['finished_count'] ?? 0) as int;
            _quizStudentCount = (d['student_count'] ?? 0) as int;
            _summaryTotal = (d['total'] ?? _summaryTotal) as int;
          });
        }
      }
      ..onAnswerReceived = (d) {
        if (mounted) {
          setState(() {
            _answeredCount = (d['answered_count'] ?? 0) as int;
            _quizStudentCount = (d['student_count'] ?? 0) as int;
          });
        }
      }
      ..onSessionEnded = (d) {
        if (mounted) {
          setState(() {
            _ended = true;
            _quizLive = false;
            _leaderboard = ((d['leaderboard'] ?? []) as List)
                .cast<Map<String, dynamic>>();
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
      ..connect(code: code, role: 'teacher');
  }

  Future<void> _scanForQuiz() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanObjectScreen(
          classSession: ClassSessionContext(
            sessionId: sessionId,
            socket: _socket,
          ),
        ),
      ),
    );
  }

  /// Lets the teacher re-quiz a word from an earlier session without having the
  /// physical object to scan. Reuses the normal push_quiz path, so students see
  /// an ordinary quiz and scoring is unchanged.
  Future<void> _revisePastWord() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;

    List<Map<String, dynamic>> words;
    try {
      words = await ApiService.getTeacherRevisionWords(widget.teacherId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load past words: $e')),
      );
      return;
    }
    if (!mounted) return;

    if (words.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No past words yet — run a session with some scans first.'),
        ),
      );
      return;
    }

    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revise a Past Word'),
        content: SizedBox(
          width: 360,
          height: 380,
          child: ListView.builder(
            itemCount: words.length,
            itemBuilder: (_, i) {
              final w = words[i];
              final key = w['english_key'] as String? ?? '';
              final english = w['english_word'] as String? ?? key;
              final malay = w['malay_word'] as String? ?? '';
              final chinese = w['chinese_word'] as String? ?? '';
              final day = w['last_used_weekday'] as String? ?? '';
              final date = w['last_used_date'] as String? ?? '';
              return ListTile(
                title: Text(english,
                    style: AppTheme.body
                        .copyWith(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  '$malay · $chinese'
                  '${date.isEmpty ? '' : '\nLast used: $day, $date'}',
                  style: AppTheme.caption,
                ),
                isThreeLine: date.isNotEmpty,
                onTap: () => Navigator.pop(ctx, key),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (chosen != null) _socket.pushQuiz(sessionId, chosen);
  }

  void _sendSummaryQuiz() {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    _socket.pushSummaryQuiz(sessionId);
  }

  void _endSession() {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    _socket.endSession(sessionId);
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
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.md),
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Exit'),
                  style: AppTheme.backButtonStyle,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
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

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Column(
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            SizedBox(height: 16),
            Text('Creating class session…'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            const Text('😕', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppTheme.body.copyWith(color: AppTheme.error),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _createSession();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try Again'),
              style: AppTheme.secondaryButton,
            ),
          ],
        ),
      );
    }

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
            'Session Ended',
            style: AppTheme.heading
                .copyWith(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          ClassLeaderboard(leaderboard: _leaderboard),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.home_outlined, size: 18),
            label: const Text('Back to Teacher Panel'),
            style: AppTheme.secondaryButton,
          ),
          const SizedBox(height: AppTheme.xxl),
        ],
      );
    }

    return Column(
      children: [
        const SizedBox(height: AppTheme.sm),
        Text(
          'Class Session',
          style: AppTheme.heading
              .copyWith(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _connected ? AppTheme.success : AppTheme.textLight,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _connected ? 'Live' : 'Connecting…',
              style: AppTheme.caption,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Big projector-readable code ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: AppTheme.cardDecoration,
          child: Column(
            children: [
              Text('Share this code with students',
                  style: AppTheme.caption.copyWith(fontSize: 14)),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: SelectableText(
                  _code ?? '',
                  style: AppTheme.heading.copyWith(
                    fontSize: 96,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary,
                    letterSpacing: 10,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _code ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copied!')),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy code'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ── Live student count ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/icons/Group_Tutoring.png',
                width: 26,
                height: 26,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.people, size: 26);
                },
              ),
              const SizedBox(width: 10),
              Text(
                '$_studentCount student${_studentCount == 1 ? '' : 's'} joined',
                style: AppTheme.subheading.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ── Live quiz status ──
        if (_quizLive)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: AppTheme.successLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Quiz sent!',
                        style: AppTheme.body.copyWith(
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    Image.asset(
                      'assets/icons/target.png',
                      width: 16,
                      height: 16,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox(width: 16, height: 16);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$_answeredCount of $_quizStudentCount answered',
                  style: AppTheme.caption,
                ),
              ],
            ),
          ),

        // ── Live summary-quiz status ──
        if (_summaryLive)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Text('Summary quiz sent! 📝',
                    style: AppTheme.body.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  '$_summaryFinished of $_quizStudentCount finished '
                  'all $_summaryTotal question${_summaryTotal == 1 ? '' : 's'}',
                  style: AppTheme.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

        // ── Scan to push a quiz ──
        FilledButton.icon(
          onPressed: _scanForQuiz,
          icon: const Icon(Icons.center_focus_strong, size: 20),
          label: const Text('Scan Object → Send Quiz'),
          style: AppTheme.primaryButton,
        ),
        const SizedBox(height: 14),

        // ── Revise a word from an earlier session (no object needed) ──
        OutlinedButton.icon(
          onPressed: _revisePastWord,
          icon: const Icon(Icons.history, size: 18),
          label: const Text('Revise a Past Word'),
          style: AppTheme.secondaryButton,
        ),
        const SizedBox(height: 14),

        // ── Summary quiz: available any time once words have been sent ──
        OutlinedButton.icon(
          onPressed: _quizzesSent == 0 ? null : _sendSummaryQuiz,
          icon: const Icon(Icons.checklist_rtl, size: 18),
          label: Text(
            _quizzesSent == 0
                ? 'Summary Quiz (send a word first)'
                : 'Send Summary Quiz 📝',
          ),
          style: AppTheme.secondaryButton,
        ),
        const SizedBox(height: 14),

        // ── End session ──
        OutlinedButton.icon(
          onPressed: _endSession,
          icon: const Icon(Icons.stop_circle_outlined, size: 18),
          label: const Text('End Session'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.error,
            side: const BorderSide(color: AppTheme.error, width: 2),
            minimumSize: const Size(200, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle:
                AppTheme.buttonText.copyWith(color: AppTheme.error),
          ),
        ),
        const SizedBox(height: AppTheme.xxl),
      ],
    );
  }
}
