import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_service.dart';
import '../learning_flow.dart';
import '../socket_service.dart';
import '../theme/app_theme.dart';
import '../widgets/class_leaderboard.dart';
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
    });

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
          });
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
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.xl, vertical: AppTheme.sm),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
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
            label: const Text('Exit'),
            style: AppTheme.backButtonStyle,
          ),
          const Spacer(),
          if (!_loading && _error == null && !_ended)
            TeacherStatusChip(
              label: _connected ? 'Live' : 'Connecting…',
              tone: _connected
                  ? TeacherStatusTone.live
                  : TeacherStatusTone.warning,
              solid: _connected,
            ),
        ],
      ),
    );
  }

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

    // Live session: projector column + controls column (side-by-side when wide).
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 860;
        final projector = _buildProjectorColumn();
        final controls = _buildControlsColumn();
        if (!wide) {
          return Column(
            children: [
              projector,
              const SizedBox(height: AppTheme.lg),
              controls,
              const SizedBox(height: AppTheme.xxl),
            ],
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: AppTheme.sm, bottom: AppTheme.xxl),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: projector),
              const SizedBox(width: AppTheme.lg),
              Expanded(flex: 4, child: controls),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProjectorColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Big projector-readable code ──
        TeacherSectionCard(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
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
                    fontSize: 92,
                    fontWeight: FontWeight.w900,
                    color: TeacherShell.accent,
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
        const SizedBox(height: AppTheme.lg),

        // ── Live student count ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          decoration: BoxDecoration(
            color: TeacherShell.accentLight,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.groups_rounded,
                  size: 26, color: TeacherShell.accent),
              const SizedBox(width: 10),
              Text(
                '$_studentCount student${_studentCount == 1 ? '' : 's'} joined',
                style: AppTheme.subheading.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),

        // ── Live quiz status ──
        if (_quizLive) ...[
          const SizedBox(height: AppTheme.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: AppTheme.successLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Column(
              children: [
                // No answer-leak concern here — the teacher isn't taking the
                // quiz, so the icon shows regardless of question pattern.
                VocabIcon(englishKey: _quizEnglishKey, size: 40),
                const SizedBox(height: 6),
                Text('Quiz sent! 🎯',
                    style:
                        AppTheme.body.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  '$_answeredCount of $_quizStudentCount answered',
                  style: AppTheme.caption,
                ),
              ],
            ),
          ),
        ],

        // ── Live summary-quiz status ──
        if (_summaryLive) ...[
          const SizedBox(height: AppTheme.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
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
        ],
      ],
    );
  }

  Widget _buildControlsColumn() {
    return TeacherSectionCard(
      title: 'Session Controls',
      icon: Icons.tune_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TeacherPrimaryButton(
            label: 'Scan Object → Send Quiz',
            icon: Icons.center_focus_strong,
            onPressed: _scanForQuiz,
            expand: true,
          ),
          const SizedBox(height: AppTheme.md),
          TeacherSecondaryButton(
            label: 'Upload Photos → Quiz Set',
            icon: Icons.photo_library_outlined,
            onPressed: _batchUpload,
            expand: true,
          ),
          if (widget.classroomId != null) ...[
            const SizedBox(height: AppTheme.md),
            TeacherSecondaryButton(
              label: 'Prepared Vocabulary',
              icon: Icons.collections_bookmark_outlined,
              onPressed: _pickFromPrepared,
              expand: true,
            ),
          ],
          const SizedBox(height: AppTheme.md),
          TeacherSecondaryButton(
            label: 'Revise a Past Word',
            icon: Icons.history,
            onPressed: _revisePastWord,
            expand: true,
          ),
          const SizedBox(height: AppTheme.md),
          TeacherSecondaryButton(
            label: _wordCount == 0
                ? 'Summary Quiz (send a word first)'
                : 'Send Summary Quiz 📝 ($_wordCount word'
                    '${_wordCount == 1 ? '' : 's'})',
            icon: Icons.checklist_rtl,
            onPressed: _wordCount == 0 ? null : _sendSummaryQuiz,
            expand: true,
          ),
          const SizedBox(height: AppTheme.lg),
          const Divider(height: 1),
          const SizedBox(height: AppTheme.lg),
          TeacherSecondaryButton(
            label: 'End Session',
            icon: Icons.stop_circle_outlined,
            onPressed: _endSession,
            tint: AppTheme.error,
            expand: true,
          ),
        ],
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
