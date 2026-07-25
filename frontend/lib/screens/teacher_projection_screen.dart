import 'package:flutter/material.dart';
import '../api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/class_leaderboard.dart';
import '../widgets/teacher_shell.dart';
import '../widgets/teacher_ui.dart';

/// Teacher Class Reports.
///
/// Shows the real Class Code sessions this teacher has run (from MongoDB
/// `class_sessions`), each with its live/ended status, student count, quiz
/// count, and final leaderboard. No mock data.
///
/// [TeacherReportsView] is the embeddable body used inside `TeacherShell`;
/// [TeacherProjectionScreen] is a thin standalone wrapper around it.
class TeacherProjectionScreen extends StatelessWidget {
  final String teacherId;
  final String? teacherName;

  const TeacherProjectionScreen({
    super.key,
    required this.teacherId,
    this.teacherName,
  });

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
                  label: const Text('Back'),
                  style: AppTheme.backButtonStyle,
                ),
              ),
            ),
            Expanded(child: TeacherReportsView(teacherId: teacherId)),
          ],
        ),
      ),
    );
  }
}

/// Embeddable "Reports" body — no Scaffold, scrolls inside its host.
class TeacherReportsView extends StatefulWidget {
  final String teacherId;

  const TeacherReportsView({super.key, required this.teacherId});

  @override
  State<TeacherReportsView> createState() => _TeacherReportsViewState();
}

class _TeacherReportsViewState extends State<TeacherReportsView> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  /// Day being viewed, as "yyyy-MM-dd" in local (GMT+8) terms. Null until
  /// data loads, then defaults to the most recent day that has sessions.
  String? _selectedDate;

  /// Escape hatch from the one-day view back to the full history.
  bool _showAllDays = false;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getClassSessions(widget.teacherId);
      if (mounted) {
        setState(() {
          _data = data;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) return _buildError();
    return _buildContent();
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text('Failed to load reports', style: AppTheme.subheading),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AppTheme.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TeacherPrimaryButton(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: _loadSessions,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final data = _data!;
    final sessionCount = (data['session_count'] as num? ?? 0).toInt();
    final totalStudents = (data['total_students'] as num? ?? 0).toInt();
    final liveCount = (data['live_count'] as num? ?? 0).toInt();
    final sessions = (data['sessions'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    if (sessions.isEmpty) return _buildEmpty();

    // One-day view: default to the newest day that has sessions (the list
    // arrives newest-first), or whatever day the calendar picked.
    final viewDate =
        _selectedDate ?? (sessions.first['local_date'] as String? ?? '');
    final visibleSessions = _showAllDays
        ? sessions
        : sessions
            .where((s) => (s['local_date'] as String? ?? '') == viewDate)
            .toList();

    return RefreshIndicator(
      onRefresh: _loadSessions,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(AppTheme.xl, 0, AppTheme.xl, AppTheme.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Summary stat cards ──
            LayoutBuilder(
              builder: (context, constraints) {
                final cards = [
                  TeacherStatCard(
                    icon: Icons.assignment_rounded,
                    tint: TeacherShell.accent,
                    value: '$sessionCount',
                    label: 'Sessions Run',
                  ),
                  TeacherStatCard(
                    icon: Icons.groups_rounded,
                    tint: AppTheme.primary,
                    value: '$totalStudents',
                    label: 'Total Students',
                  ),
                  TeacherStatCard(
                    icon: Icons.podcasts_rounded,
                    tint: AppTheme.success,
                    value: '$liveCount',
                    label: 'Live Now',
                  ),
                ];
                final wide = constraints.maxWidth >= 560;
                if (wide) {
                  return Row(
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(width: AppTheme.md),
                        Expanded(child: cards[i]),
                      ],
                    ],
                  );
                }
                return Column(
                  children: [
                    for (final c in cards) ...[
                      c,
                      const SizedBox(height: AppTheme.sm),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: AppTheme.xl),

            // ── Day picker row ──
            Row(
              children: [
                Expanded(
                  child: Text(
                    _showAllDays ? 'All days' : 'Viewing one day',
                    style: AppTheme.caption.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                TeacherSecondaryButton(
                  label: _showAllDays ? 'Pick a day' : _prettyDate(viewDate),
                  icon: Icons.calendar_month,
                  onPressed: () => _pickDay(sessions),
                ),
                const SizedBox(width: AppTheme.sm),
                TextButton(
                  onPressed: () => setState(() => _showAllDays = !_showAllDays),
                  child: Text(_showAllDays ? 'One day' : 'Show all'),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.md),

            if (visibleSessions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    const Text('🗓️', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: AppTheme.md),
                    Text(
                      'No sessions on ${_prettyDate(viewDate)}',
                      style: AppTheme.subheading,
                    ),
                    const SizedBox(height: AppTheme.xs),
                    Text(
                      'Pick another day, or "Show all" for the full history.',
                      style: AppTheme.caption,
                    ),
                  ],
                ),
              )
            else
              ..._buildSessionsByDate(visibleSessions),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppTheme.xl, 0, AppTheme.xl, AppTheme.xxl),
      child: TeacherEmptyState(
        icon: Icons.assignment_outlined,
        title: 'No class sessions yet!',
        message: 'Create a Class Session and run a quiz — '
            'the results will show up here.',
      ),
    );
  }

  /// Groups sessions under a heading per teaching day, newest day first.
  List<Widget> _buildSessionsByDate(List<Map<String, dynamic>> sessions) {
    final order = <String>[];
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final s in sessions) {
      final date = s['local_date'] as String? ?? '';
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
        order.add(date);
      }
      grouped[date]!.add(s);
    }

    final widgets = <Widget>[];
    for (final date in order) {
      final daySessions = grouped[date]!;
      final weekday = daySessions.first['local_weekday'] as String? ?? '';
      widgets.add(_dateHeading(date, weekday, daySessions.length));
      widgets.addAll(daySessions.map(_buildSessionCard));
    }
    return widgets;
  }

  Widget _dateHeading(String date, String weekday, int count) {
    final label = date.isEmpty ? 'Undated' : '$weekday, ${_prettyDate(date)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.md, top: AppTheme.xs),
      child: Row(
        children: [
          const Text('🗓️', style: TextStyle(fontSize: 18)),
          const SizedBox(width: AppTheme.sm),
          Text(
            label,
            style: AppTheme.subheading.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: AppTheme.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: TeacherShell.accentLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count session${count == 1 ? '' : 's'}',
              style: AppTheme.caption.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: TeacherShell.accent,
              ),
            ),
          ),
          const Expanded(child: Divider(indent: 12)),
        ],
      ),
    );
  }

  /// Calendar picker for the one-day view. Bounded by the oldest session so
  /// the teacher can't scroll into years with nothing in them.
  Future<void> _pickDay(List<Map<String, dynamic>> sessions) async {
    DateTime? oldest;
    for (final s in sessions) {
      final d = DateTime.tryParse(s['local_date'] as String? ?? '');
      if (d != null && (oldest == null || d.isBefore(oldest))) oldest = d;
    }
    final now = DateTime.now();
    final initial = DateTime.tryParse(_selectedDate ?? '') ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: oldest ?? DateTime(now.year - 1),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDate =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
      _showAllDays = false;
    });
  }

  /// "2026-07-21" → "21 Jul 2026".
  static String _prettyDate(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final month = int.tryParse(parts[1]) ?? 0;
    if (month < 1 || month > 12) return iso;
    final day = int.tryParse(parts[2]) ?? 0;
    return '$day ${months[month - 1]} ${parts[0]}';
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final code = session['code'] as String? ?? '';
    final status = session['status'] as String? ?? 'ended';
    final studentCount = (session['student_count'] as num? ?? 0).toInt();
    final quizCount = (session['quiz_count'] as num? ?? 0).toInt();
    // Local (GMT+8) start time; the calendar date is shown in the day heading.
    final localTime = session['local_time'] as String? ?? '';
    final leaderboard = (session['leaderboard'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    final isLive = status != 'ended';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.lg),
      child: TeacherSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row: code + status ──
            Row(
              children: [
                const Icon(Icons.link_rounded,
                    size: 20, color: TeacherShell.accent),
                const SizedBox(width: AppTheme.sm),
                Expanded(
                  child: Text(
                    'Code: $code',
                    style: AppTheme.subheading.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                TeacherStatusChip(
                  label: switch (status) {
                    'quiz' => 'Live · Quiz',
                    'waiting' => 'Live · Waiting',
                    _ => 'Ended',
                  },
                  tone: isLive
                      ? TeacherStatusTone.live
                      : TeacherStatusTone.neutral,
                  solid: isLive,
                ),
              ],
            ),
            if (localTime.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Started $localTime',
                  style: AppTheme.caption.copyWith(fontSize: 12)),
            ],
            const SizedBox(height: AppTheme.md),

            // ── Mini stats ──
            Row(
              children: [
                _miniStat(Icons.groups_rounded, '$studentCount',
                    studentCount == 1 ? 'student' : 'students'),
                const SizedBox(width: AppTheme.lg),
                _miniStat(Icons.quiz_rounded, '$quizCount',
                    quizCount == 1 ? 'quiz' : 'quizzes'),
              ],
            ),
            const SizedBox(height: AppTheme.md),

            // ── Leaderboard ──
            ClassLeaderboard(leaderboard: leaderboard),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppTheme.textLight),
        const SizedBox(width: 6),
        Text(
          value,
          style: AppTheme.body.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTheme.caption),
      ],
    );
  }
}
