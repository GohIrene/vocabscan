import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_service.dart';
import '../learning_flow.dart';
import '../socket_service.dart';
import '../theme/app_theme.dart';
import '../widgets/class_leaderboard.dart';
import '../widgets/student_avatar.dart';
import '../widgets/teacher_shell.dart';
import '../widgets/teacher_ui.dart';
import '../widgets/vocab_icon.dart';
import 'batch_upload_screen.dart';
import 'scan_object_screen.dart';

// Mirror of the server's _MAX_SUMMARY_QUESTIONS: a quiz of more than this many
// words is too long for young children, so "Send as Quiz" only quizzes the
// first N picked; "Add to Pool" keeps them all for the summary quiz.
const int _maxBatchQuizWords = 10;

/// Live Class Code session (teacher side).
///
/// Creates a session over REST, shows the projector-readable code, tracks the
/// live student count over the socket, lets the teacher scan an object to push
/// a quiz, and ends the session with a leaderboard.
///
/// This is a full-focus pushed route (not a shell body) so the code projects
/// cleanly. On a wide screen the projector column (code + join count + live
/// status) sits beside the teacher's controls; on a narrow screen they stack.
class TeacherClassSessionScreen extends StatefulWidget {
  final String teacherId;

  /// Non-null to run the session against a saved class: students tap their
  /// name to join and earn XP toward their roster entry. Null keeps the
  /// original type-your-nickname session with no saved progress.
  final String? classroomId;

  const TeacherClassSessionScreen({
    super.key,
    required this.teacherId,
    this.classroomId,
  });

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

  // Who is in the room, not just how many — the server sends this alongside
  // every count so the roster grid survives a reconnect.
  List<Map<String, dynamic>> _students = const [];

  // Saved-class extras, fetched once: the class name for the header and the
  // roster (name + avatar index) the student chips draw their faces from.
  // Both stay null/empty for a nickname-only session, which has no roster.
  String? _className;
  List<Map<String, dynamic>> _roster = const [];

  // Wall-clock length of the session, shown in the header.
  Timer? _ticker;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;

  bool _quizLive = false;
  int _answeredCount = 0;
  int _quizStudentCount = 0;
  String? _quizEnglishKey;

  // Distinct quizzable words the SERVER says this session has covered — the
  // same set it would build a summary quiz from. Server-derived rather than a
  // local tally of our own pushes, so it stays correct across a reconnect
  // (a local counter reset to 0 and left the button permanently disabled).
  int _wordCount = 0;

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
    final res = await ApiService.createClassSession(
      widget.teacherId,
      classroomId: widget.classroomId,
    );
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
      _startedAt = DateTime.now();
    });
    _startTicker();
    _loadClassInfo();

    _socket
      ..onConnectionChange = (c) {
        if (mounted) setState(() => _connected = c);
      }
      ..onStudentJoined = (d) {
        if (mounted) {
          setState(() {
            _studentCount = (d['student_count'] ?? 0) as int;
            // Present on our own join sync and on every student join, so the
            // count re-syncs after a dropped connection too.
            _wordCount = (d['word_count'] ?? _wordCount) as int;
            _students = _readStudents(d);
          });
        }
      }
      ..onStudentLeft = (d) {
        if (mounted) {
          setState(() {
            _studentCount = (d['student_count'] ?? 0) as int;
            _students = _readStudents(d);
          });
        }
      }
      ..onNewQuiz = (d) {
        if (mounted) {
          setState(() {
            _quizLive = true;
            _answeredCount = 0;
            _quizStudentCount = _studentCount;
            _quizEnglishKey = d['english_key'] as String?;
            _wordCount = (d['word_count'] ?? _wordCount) as int;
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
      ..onWordsStaged = (d) {
        // Batch photos added to the pool without a live quiz — refresh the
        // summary-quiz button gate so it enables/updates its count.
        if (mounted) {
          setState(() => _wordCount = (d['word_count'] ?? _wordCount) as int);
        }
      }
      ..connect(code: code, role: 'teacher');
  }

  /// The live roster carried on every join/leave payload. Falls back to the
  /// list we already hold if a payload arrives without one, so an older server
  /// simply leaves the grid as-is rather than blanking it.
  List<Map<String, dynamic>> _readStudents(Map<String, dynamic> d) {
    final raw = d['students'];
    if (raw is! List) return _students;
    return raw
        .whereType<Map>()
        .map((s) => Map<String, dynamic>.from(s))
        .toList();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final start = _startedAt;
      if (!mounted || start == null) return;
      setState(() => _elapsed = DateTime.now().difference(start));
    });
  }

  String get _elapsedLabel {
    two(int n) => n.toString().padLeft(2, '0');
    return '${two(_elapsed.inHours)}:${two(_elapsed.inMinutes.remainder(60))}'
        ':${two(_elapsed.inSeconds.remainder(60))}';
  }

  /// Name and roster for a saved class, used by the header and the student
  /// chips. Failure is silent — the session itself doesn't depend on this, so
  /// a hiccup here just means a generic title and letter-initial avatars.
  Future<void> _loadClassInfo() async {
    final classroomId = widget.classroomId;
    if (classroomId == null) return;
    try {
      final room = await ApiService.getClassroom(classroomId);
      if (!mounted) return;
      setState(() {
        _className = room['name'] as String?;
        _roster = (room['students'] as List? ?? const [])
            .whereType<Map>()
            .map((s) => Map<String, dynamic>.from(s))
            .toList();
      });
    } catch (_) {
      // See doc comment above.
    }
  }

  /// The roster avatar index for a joined student, matched on name the same
  /// case-insensitive way the server credits XP at end of session. Null when
  /// there's no roster entry — an ad-hoc nickname, or a class-free session.
  int? _avatarFor(String nickname) {
    final key = nickname.trim().toLowerCase();
    for (final s in _roster) {
      if ((s['name'] as String? ?? '').trim().toLowerCase() == key) {
        return (s['avatar'] as num?)?.toInt() ?? 0;
      }
    }
    return null;
  }

  Future<void> _scanForQuiz() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        // Labelled for clarity only — the live Class Code path is unchanged;
        // no guided-flow branch applies to it.
        builder: (_) => ScanObjectScreen(
          flowMode: LearningFlowMode.classSession,
          classSession: ClassSessionContext(
            sessionId: sessionId,
            socket: _socket,
          ),
        ),
      ),
    );
  }

  /// Opens the batch-upload flow: the teacher picks several photos at once,
  /// each is recognised, then sent as one quiz or staged into the word pool.
  Future<void> _batchUpload() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BatchUploadScreen(
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

  /// Lets the teacher pick from this class's prepared vocabulary (staged
  /// ahead of time via "Prep Photos" / "Add Vocabulary" on the class card) and
  /// push the selection as a quiz or add it to the pool — without re-uploading
  /// or re-scanning anything.
  Future<void> _pickFromPrepared() async {
    final sessionId = _sessionId;
    final classroomId = widget.classroomId;
    if (sessionId == null || classroomId == null) return;

    List<String> prepared;
    try {
      final room = await ApiService.getClassroom(classroomId);
      prepared = (room['prepared_words'] as List? ?? const [])
          .whereType<String>()
          .toList();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load prepared vocabulary: $e')),
      );
      return;
    }
    if (!mounted) return;

    if (prepared.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No prepared vocabulary yet — add some from "My Classes" before class.',
          ),
        ),
      );
      return;
    }

    final result = await showDialog<_PreparedVocabResult>(
      context: context,
      builder: (_) => _PreparedVocabDialog(englishKeys: prepared),
    );
    if (result == null || result.keys.isEmpty) return;

    if (result.sendNow) {
      _socket.pushBatchQuiz(sessionId, result.keys);
    } else {
      _socket.stageBatchWords(sessionId, result.keys);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.keys.length} word${result.keys.length == 1 ? '' : 's'} '
            'added to the pool',
          ),
        ),
      );
    }
  }

  void _endSession() {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    _socket.endSession(sessionId);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          _topBar(),
          Expanded(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppTheme.xl, AppTheme.lg, AppTheme.xl, AppTheme.sm),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: _buildBody(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The session banner. Full-bleed accent so a projected session reads as
  /// "we are live" from the back of the room, and so the status, elapsed time
  /// and class name sit together rather than scattered down the page.
  Widget _topBar() {
    final live = !_loading && _error == null && !_ended;
    return Material(
      color: TeacherShell.accent,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.md, vertical: 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Below this the meta trio is what gives, not the title or the
              // way out of the screen.
              final roomy = constraints.maxWidth >= 900;
              return Row(
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: Text(roomy ? 'Back to Teacher Dashboard' : 'Back'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      textStyle: AppTheme.body
                          .copyWith(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                  if (roomy) ...[
                    _barDivider(),
                    const Icon(Icons.cast_for_education_rounded,
                        size: 20, color: Colors.white),
                    const SizedBox(width: AppTheme.sm),
                  ],
                  Flexible(
                    child: Text(
                      'Live Class Session',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.subheading.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: roomy ? 19 : 16,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (live && roomy) ...[
                    _barStatus(),
                    _barDivider(),
                    _barMeta(Icons.schedule_rounded, _elapsedLabel),
                    if (_className != null) ...[
                      _barDivider(),
                      _barMeta(Icons.groups_rounded, _className!),
                    ],
                    const SizedBox(width: AppTheme.md),
                  ],
                  if (live)
                    OutlinedButton.icon(
                      onPressed: _endSession,
                      icon: const Icon(Icons.power_settings_new_rounded,
                          size: 16),
                      label: const Text('End Session'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.55)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        textStyle: AppTheme.body.copyWith(
                            fontWeight: FontWeight.w700, fontSize: 13.5),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm)),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _barDivider() => Container(
        width: 1,
        height: 22,
        margin: const EdgeInsets.symmetric(horizontal: AppTheme.md),
        color: Colors.white.withValues(alpha: 0.3),
      );

  Widget _barMeta(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTheme.caption.copyWith(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      );

  Widget _barStatus() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _connected ? AppTheme.success : AppTheme.warning,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _connected ? 'Connected' : 'Connecting…',
            style: AppTheme.caption.copyWith(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      );

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Column(
          children: [
            CircularProgressIndicator(color: TeacherShell.accent),
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
            TeacherSecondaryButton(
              label: 'Try Again',
              icon: Icons.refresh,
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _createSession();
              },
            ),
          ],
        ),
      );
    }

    if (_ended) {
      return Column(
        children: [
          const SizedBox(height: AppTheme.md),
          const Text('🎉', style: TextStyle(fontSize: 52)),
          const SizedBox(height: AppTheme.sm),
          Text(
            'Session Ended',
            style: AppTheme.heading
                .copyWith(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ClassLeaderboard(leaderboard: _leaderboard),
          ),
          const SizedBox(height: 20),
          TeacherSecondaryButton(
            label: 'Back to Teacher Panel',
            icon: Icons.home_outlined,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(height: AppTheme.xxl),
        ],
      );
    }

    // Live session: where-we-are stepper, then the projector column beside the
    // teacher's controls (stacked on a narrow screen).
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 860;
        final projector = _buildProjectorColumn();
        final controls = _buildControlsColumn();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStepper(),
            const SizedBox(height: AppTheme.lg),
            if (!wide) ...[
              projector,
              const SizedBox(height: AppTheme.lg),
              controls,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: projector),
                  const SizedBox(width: AppTheme.lg),
                  Expanded(flex: 6, child: controls),
                ],
              ),
            const SizedBox(height: AppTheme.xxl),
          ],
        );
      },
    );
  }

  /// Which of the four session stages we're in. Derived from state the screen
  /// already tracks rather than stored separately, so it can never disagree
  /// with what the buttons below it will actually do.
  int get _currentStep {
    if (_summaryLive) return 3;
    if (_quizLive) return 2;
    if (_wordCount > 0) return 1;
    return 0;
  }

  Widget _buildStepper() {
    const steps = <(IconData, String, String)>[
      (Icons.groups_rounded, 'Waiting Room', 'Students joining…'),
      (Icons.menu_book_rounded, 'Teaching', 'Send a word to begin'),
      (Icons.quiz_rounded, 'Live Quiz', 'Students answering'),
      (Icons.emoji_events_rounded, 'Summary', 'End of session quiz'),
    ];
    final current = _currentStep;

    return TeacherSectionCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.lg, vertical: AppTheme.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Four labelled steps need real width; below that the labels are
          // dropped to numbered dots rather than being squeezed unreadable.
          final labelled = constraints.maxWidth >= 720;
          return Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(
                          horizontal: AppTheme.sm),
                      color: i <= current
                          ? TeacherShell.accent.withValues(alpha: 0.45)
                          : AppTheme.textLight.withValues(alpha: 0.22),
                    ),
                  ),
                _buildStep(
                  index: i,
                  icon: steps[i].$1,
                  title: steps[i].$2,
                  subtitle: steps[i].$3,
                  current: current,
                  labelled: labelled,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildStep({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required int current,
    required bool labelled,
  }) {
    final done = index < current;
    final active = index == current;
    final tint = done || active ? TeacherShell.accent : AppTheme.textLight;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: active || done
                ? TeacherShell.accent
                : AppTheme.textLight.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: done
              ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
              : Text(
                  '${index + 1}',
                  style: AppTheme.caption.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: active ? Colors.white : AppTheme.textLight,
                  ),
                ),
        ),
        if (labelled) ...[
          const SizedBox(width: AppTheme.sm),
          Icon(icon, size: 19, color: tint),
          const SizedBox(width: AppTheme.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppTheme.body.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: active || done ? TeacherShell.accent : AppTheme.textDark,
                ),
              ),
              Text(
                subtitle,
                style: AppTheme.caption.copyWith(fontSize: 11.5),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildProjectorColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCodeCard(),
        const SizedBox(height: AppTheme.lg),
        _buildStudentsCard(),
      ],
    );
  }

  Widget _buildCodeCard() {
    return TeacherSectionCard(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Share this code with your students',
              textAlign: TextAlign.center,
              style: AppTheme.body
                  .copyWith(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: AppTheme.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: SelectableText(
              _code ?? '',
              style: AppTheme.heading.copyWith(
                fontSize: 64,
                fontWeight: FontWeight.w900,
                color: TeacherShell.accent,
                letterSpacing: 4,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.md),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _code ?? ''));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Code copied!')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Code'),
            style: OutlinedButton.styleFrom(
              foregroundColor: TeacherShell.accent,
              side: BorderSide(
                  color: TeacherShell.accent.withValues(alpha: 0.4)),
              minimumSize: const Size.fromHeight(42),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
              textStyle: AppTheme.body
                  .copyWith(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          const SizedBox(height: AppTheme.md),
          Text.rich(
            TextSpan(
              style: AppTheme.caption.copyWith(fontSize: 12.5),
              children: [
                const TextSpan(text: 'Ask students to enter this code on the '),
                TextSpan(
                  text: 'VocabScan Class Code',
                  style: AppTheme.caption.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: TeacherShell.accent),
                ),
                const TextSpan(text: ' page'),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.md),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: AppTheme.successLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: AppTheme.success, shape: BoxShape.circle),
                ),
                const SizedBox(width: 7),
                Text('Session is open',
                    style: AppTheme.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppTheme.textDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The live roster. Names come from the socket; faces come from the saved
  /// class roster where there is one, falling back to an initial for a student
  /// who typed a nickname that doesn't match any roster entry.
  Widget _buildStudentsCard() {
    final joined = _students.where((s) => s['connected'] == true).length;
    return TeacherSectionCard(
      title: 'Students',
      icon: Icons.groups_rounded,
      action: Text(
        _roster.isEmpty ? '$joined' : '$joined / ${_roster.length}',
        style: AppTheme.body.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: TeacherShell.accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_students.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                const columns = 3;
                const gap = AppTheme.sm;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final s in _students)
                      SizedBox(width: width, child: _buildStudentChip(s)),
                  ],
                );
              },
            ),
          if (_students.isNotEmpty) const SizedBox(height: AppTheme.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 14, color: AppTheme.textLight),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Students will appear here when they join this session.',
                  style: AppTheme.caption.copyWith(fontSize: 11.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentChip(Map<String, dynamic> student) {
    final nickname = student['nickname'] as String? ?? '';
    final online = student['connected'] == true;
    final avatar = _avatarFor(nickname);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.textLight.withValues(alpha: 0.18)),
      ),
      child: Opacity(
        // A student who dropped stays listed but reads as absent, so the
        // teacher can tell "left the room" from "never joined".
        opacity: online ? 1 : 0.45,
        child: Row(
          children: [
            if (avatar != null)
              StudentAvatar(avatar: avatar, size: 28)
            else
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: TeacherShell.accentLight,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  nickname.isEmpty ? '?' : nickname[0].toUpperCase(),
                  style: AppTheme.caption.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: TeacherShell.accent),
                ),
              ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: AppTheme.textDark),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: online ? AppTheme.success : AppTheme.textLight,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsColumn() {
    // Prepared vocabulary only exists for a saved class, so the grid is built
    // from whatever applies rather than showing a control that can't work.
    final tiles = <Widget>[
      _ActivityTile(
        icon: Icons.photo_camera_rounded,
        title: 'Scan Object',
        description: 'Recognise one object and immediately send a quiz.',
        featured: true,
        onTap: _scanForQuiz,
        footer: TeacherPrimaryButton(
          label: 'Scan and Send Quiz',
          icon: Icons.arrow_forward_rounded,
          onPressed: _scanForQuiz,
          expand: true,
        ),
      ),
      _ActivityTile(
        icon: Icons.photo_library_rounded,
        title: 'Upload Photos',
        description: 'Recognise several objects and create a quiz set.',
        onTap: _batchUpload,
      ),
      if (widget.classroomId != null)
        _ActivityTile(
          icon: Icons.menu_book_rounded,
          title: 'Prepared Vocabulary',
          description: 'Use words prepared for this classroom.',
          onTap: _pickFromPrepared,
        ),
      _ActivityTile(
        icon: Icons.autorenew_rounded,
        title: 'Revise a Past Word',
        description: 'Reuse vocabulary from an earlier session.',
        onTap: _revisePastWord,
      ),
    ];

    return TeacherSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_quizLive || _summaryLive) ...[
            _buildLiveBanner(),
            const SizedBox(height: AppTheme.lg),
          ],
          _sectionHeading(Icons.star_rounded, 'Start an Activity'),
          const SizedBox(height: AppTheme.md),
          _buildTileGrid(tiles),
          const SizedBox(height: AppTheme.lg),
          Divider(height: 1, color: AppTheme.textLight.withValues(alpha: 0.2)),
          const SizedBox(height: AppTheme.lg),
          _sectionHeading(Icons.emoji_events_rounded, 'Session Wrap-up'),
          const SizedBox(height: AppTheme.md),
          _buildSummaryCard(),
        ],
      ),
    );
  }

  Widget _sectionHeading(IconData icon, String label) => Row(
        children: [
          Icon(icon, size: 19, color: TeacherShell.accent),
          const SizedBox(width: AppTheme.sm),
          Text(label,
              style: AppTheme.body
                  .copyWith(fontWeight: FontWeight.w800, fontSize: 15.5)),
        ],
      );

  /// Two per row, each row given a common height so the grid doesn't read as
  /// ragged when one tile carries a button and its neighbour doesn't. Nothing
  /// inside [_ActivityTile] may be a LayoutBuilder or a scrollable, since
  /// IntrinsicHeight asks every descendant for its intrinsic height.
  Widget _buildTileGrid(List<Widget> tiles) {
    const columns = 2;
    const gap = AppTheme.md;
    return Column(
      children: [
        for (var start = 0; start < tiles.length; start += columns) ...[
          if (start > 0) const SizedBox(height: gap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = 0; c < columns; c++) ...[
                  if (c > 0) const SizedBox(width: gap),
                  // A short last row keeps its empty slot so the tiles above
                  // stay in the same columns.
                  Expanded(
                    child: start + c < tiles.length
                        ? tiles[start + c]
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryCard() {
    final locked = _wordCount == 0;
    final tint = locked ? AppTheme.textLight : TeacherShell.accent;

    return Container(
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: locked
            ? AppTheme.textLight.withValues(alpha: 0.07)
            : TeacherShell.accentLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: tint.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(
                locked ? Icons.lock_rounded : Icons.checklist_rtl_rounded,
                size: 21,
                color: tint),
          ),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Summary Quiz',
                    style: AppTheme.body.copyWith(
                        fontWeight: FontWeight.w800, fontSize: 14.5)),
                const SizedBox(height: 2),
                Text(
                  locked
                      ? 'Review all words used during this session. Available '
                          'after at least one word has been taught.'
                      : 'Review all $_wordCount word'
                          '${_wordCount == 1 ? '' : 's'} used during this '
                          'session.',
                  style: AppTheme.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.md),
          if (locked)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.textLight.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Text('Locked',
                  style: AppTheme.caption.copyWith(
                      fontWeight: FontWeight.w700, fontSize: 12.5)),
            )
          else
            TeacherPrimaryButton(
              label: 'Send Quiz',
              icon: Icons.send_rounded,
              onPressed: _sendSummaryQuiz,
            ),
        ],
      ),
    );
  }

  /// What the class is doing right now, shown above the activity grid so a
  /// teacher mid-quiz sees progress without hunting for it.
  Widget _buildLiveBanner() {
    final summary = _summaryLive;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: summary ? AppTheme.primaryLight : AppTheme.successLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          if (summary)
            const Icon(Icons.checklist_rtl_rounded,
                size: 34, color: AppTheme.primary)
          else
            // No answer-leak concern here — the teacher isn't taking the quiz,
            // so the icon shows regardless of question pattern.
            VocabIcon(englishKey: _quizEnglishKey, size: 36),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary ? 'Summary quiz sent! 📝' : 'Quiz sent! 🎯',
                    style: AppTheme.body.copyWith(
                        fontWeight: FontWeight.w800, fontSize: 14.5)),
                const SizedBox(height: 2),
                Text(
                  summary
                      ? '$_summaryFinished of $_quizStudentCount finished all '
                          '$_summaryTotal question'
                          '${_summaryTotal == 1 ? '' : 's'}'
                      : '$_answeredCount of $_quizStudentCount answered',
                  style: AppTheme.caption.copyWith(fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One tappable action in the "Start an Activity" grid. [featured] tints the
/// tile as the primary path; [footer] hangs a button beneath the description.
class _ActivityTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool featured;
  final Widget? footer;

  const _ActivityTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.featured = false,
    this.footer,
  });

  @override
  State<_ActivityTile> createState() => _ActivityTileState();
}

class _ActivityTileState extends State<_ActivityTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final featured = widget.featured;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(AppTheme.md),
          decoration: BoxDecoration(
            color: featured
                ? TeacherShell.accentLight
                : _hovering
                    ? TeacherShell.accent.withValues(alpha: 0.05)
                    : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: featured
                  ? TeacherShell.accent.withValues(alpha: 0.55)
                  : AppTheme.textLight.withValues(alpha: 0.2),
              width: featured ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: featured
                          ? AppTheme.surface
                          : TeacherShell.accentLight,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Icon(widget.icon,
                        size: 20, color: TeacherShell.accent),
                  ),
                  const SizedBox(width: AppTheme.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: AppTheme.body.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              color: TeacherShell.accent),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.description,
                          style: AppTheme.caption.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (!featured) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded,
                        size: 20, color: AppTheme.textLight),
                  ],
                ],
              ),
              if (widget.footer != null) ...[
                const SizedBox(height: AppTheme.md),
                widget.footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Outcome of [_PreparedVocabDialog]: the chosen keys, and whether to push
/// them as a live quiz right away (true) or just add them to the pool (false).
class _PreparedVocabResult {
  final List<String> keys;
  final bool sendNow;
  const _PreparedVocabResult(this.keys, this.sendNow);
}

/// Multi-select grid over a class's prepared vocabulary (staged ahead of time
/// via "Prep Photos" / "Add Vocabulary" on the class card), so a teacher can
/// push a quiz or top up the pool without re-uploading or re-scanning.
class _PreparedVocabDialog extends StatefulWidget {
  final List<String> englishKeys;

  const _PreparedVocabDialog({required this.englishKeys});

  @override
  State<_PreparedVocabDialog> createState() => _PreparedVocabDialogState();
}

class _PreparedVocabDialogState extends State<_PreparedVocabDialog> {
  final Set<String> _selected = {};

  String _labelFor(String key) {
    final spaced = key.replaceAll('_', ' ');
    return spaced.isEmpty ? spaced : spaced[0].toUpperCase() + spaced.substring(1);
  }

  void _toggle(String key) {
    setState(() {
      if (!_selected.remove(key)) _selected.add(key);
    });
  }

  @override
  Widget build(BuildContext context) {
    final overCap = _selected.length > _maxBatchQuizWords;
    return AlertDialog(
      title: const Text('Prepared Vocabulary'),
      content: SizedBox(
        width: 420,
        height: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pick words to send as a quiz or add to the pool.',
              style: AppTheme.caption,
            ),
            const SizedBox(height: AppTheme.sm),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.85,
                ),
                itemCount: widget.englishKeys.length,
                itemBuilder: (_, i) {
                  final key = widget.englishKeys[i];
                  final selected = _selected.contains(key);
                  return GestureDetector(
                    onTap: () => _toggle(key),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: selected
                            ? TeacherShell.accentLight
                            : AppTheme.background,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(
                          color: selected
                              ? TeacherShell.accent
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          VocabIcon(englishKey: key, size: 40),
                          const SizedBox(height: 6),
                          Text(
                            _labelFor(key),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.caption
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (overCap) ...[
              const SizedBox(height: AppTheme.sm),
              Text(
                'Only the first $_maxBatchQuizWords will be quizzed with '
                '"Send as Quiz". Use "Add to Pool" to keep them all for later.',
                style: AppTheme.caption.copyWith(color: AppTheme.textDark),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(
                    context,
                    _PreparedVocabResult(_selected.toList(), false),
                  ),
          child: const Text('Add to Pool'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(
                    context,
                    _PreparedVocabResult(
                      _selected.take(_maxBatchQuizWords).toList(),
                      true,
                    ),
                  ),
          style: AppTheme.smallButton,
          child: const Text('Send as Quiz'),
        ),
      ],
    );
  }
}
