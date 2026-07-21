import 'package:flutter/material.dart';
import '../api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/class_leaderboard.dart';

/// Screen 8 – Teacher Class Reports
///
/// Shows the real Class Code sessions this teacher has run (from MongoDB
/// `class_sessions`), each with its live/ended status, student count, quiz
/// count, and final leaderboard. No mock data.
class TeacherProjectionScreen extends StatefulWidget {
  final String teacherId;
  final String? teacherName;

  const TeacherProjectionScreen({
    super.key,
    required this.teacherId,
    this.teacherName,
  });

  @override
  State<TeacherProjectionScreen> createState() =>
      _TeacherProjectionScreenState();
}

class _TeacherProjectionScreenState extends State<TeacherProjectionScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

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
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(context),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildError()
                      : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
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
          TextButton.icon(
            onPressed: _loading ? null : _loadSessions,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh'),
            style: AppTheme.backButtonStyle,
          ),
        ],
      ),
    );
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
            FilledButton.icon(
              onPressed: _loadSessions,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: AppTheme.primaryButton,
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

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            children: [
              const Text('🏫', style: TextStyle(fontSize: 44)),
              const SizedBox(height: AppTheme.xs),
              Text(
                'Class Reports',
                style: AppTheme.heading.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (widget.teacherName != null) ...[
                const SizedBox(height: AppTheme.xs),
                Text(
                  widget.teacherName!,
                  style: AppTheme.body.copyWith(
                    fontSize: 15,
                    color: AppTheme.textLight,
                  ),
                ),
              ],
              const SizedBox(height: 22),

              // ── Summary stat cards ──
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _SummaryCard(
                    icon: '📋',
                    value: '$sessionCount',
                    label: 'Sessions Run',
                    color: AppTheme.primary,
                  ),
                  _SummaryCard(
                    icon: '👥',
                    value: '$totalStudents',
                    label: 'Total Students',
                    color: AppTheme.secondary,
                  ),
                  _SummaryCard(
                    icon: '🟢',
                    value: '$liveCount',
                    label: 'Live Now',
                    color: AppTheme.success,
                  ),
                ],
              ),
              const SizedBox(height: 28),

              ..._buildSessionsByDate(sessions),
              const SizedBox(height: AppTheme.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🧑‍🏫', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('No class sessions yet!', style: AppTheme.subheading),
            const SizedBox(height: 8),
            Text(
              'Create a Class Session and run a quiz — '
              'the results will show up here.',
              textAlign: TextAlign.center,
              style: AppTheme.body.copyWith(color: AppTheme.textLight),
            ),
          ],
        ),
      ),
    );
  }

  /// Groups sessions under a heading per teaching day, newest day first.
  /// `sessions` already arrives newest-first from the backend, and each carries
  /// a `local_date`/`local_weekday` pre-converted to Malaysia time (GMT+8), so
  /// a late-evening class can't be filed under the previous day.
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
    final label = date.isEmpty
        ? 'Undated'
        : '$weekday, ${_prettyDate(date)}';
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
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count session${count == 1 ? '' : 's'}',
              style: AppTheme.caption.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
          const Expanded(child: Divider(indent: 12)),
        ],
      ),
    );
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

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppTheme.lg),
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row: code + status ──
          Row(
            children: [
              const Text('🔗', style: TextStyle(fontSize: 20)),
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
              _statusBadge(status, isLive),
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
              _miniStat('👥', '$studentCount',
                  studentCount == 1 ? 'student' : 'students'),
              const SizedBox(width: AppTheme.lg),
              _miniStat('🎯', '$quizCount',
                  quizCount == 1 ? 'quiz' : 'quizzes'),
            ],
          ),
          const SizedBox(height: AppTheme.md),

          // ── Leaderboard ──
          ClassLeaderboard(leaderboard: leaderboard),
        ],
      ),
    );
  }

  Widget _statusBadge(String status, bool isLive) {
    final label = switch (status) {
      'quiz' => 'Live · Quiz',
      'waiting' => 'Live · Waiting',
      _ => 'Ended',
    };
    final color = isLive ? AppTheme.success : AppTheme.textLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTheme.caption.copyWith(
          color: AppTheme.surface,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _miniStat(String icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
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

/// Summary stat card for the top row.
class _SummaryCard extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: AppTheme.sm),
          Text(
            value,
            style: AppTheme.heading.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppTheme.surface,
            ),
          ),
          const SizedBox(height: AppTheme.xs),
          Text(
            label,
            style: AppTheme.body.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.surface.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
