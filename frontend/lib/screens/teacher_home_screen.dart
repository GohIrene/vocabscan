import 'package:flutter/material.dart';

import '../api_service.dart';
import '../auth_service.dart';
import '../learning_flow.dart';
import '../theme/app_theme.dart';
import '../widgets/teacher_shell.dart';
import '../widgets/teacher_ui.dart';
import 'classroom_manage_screen.dart';
import 'scan_object_screen.dart';
import 'teacher_class_session_screen.dart';
import 'teacher_projection_screen.dart';
import 'welcome_screen.dart';

/// Teacher Mode: a dashboard, not a launcher.
///
/// The sections are views of one screen rather than separate routes — the rail
/// stays put and only the body swaps, mirroring Parent Mode. Screens that
/// deserve full focus (a live session, projection, batch upload) are pushed on
/// top. Every displayed number comes from the existing classroom and
/// class-session APIs.
class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  TeacherNavItem _section = TeacherNavItem.dashboard;

  List<Map<String, dynamic>> _classrooms = const [];
  Map<String, dynamic>? _sessionsSummary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _username =>
      AuthService.instance.currentUser?['username'] as String? ?? '';

  String get _teacherId {
    final user = AuthService.instance.currentUser ?? const {};
    return (user['user_id'] ?? user['username'] ?? '').toString();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // A failure in either call shouldn't blank the whole dashboard, so each
      // is tolerated independently.
      final rooms = await ApiService.getClassrooms(_teacherId)
          .catchError((_) => <Map<String, dynamic>>[]);
      Map<String, dynamic>? summary;
      try {
        summary = await ApiService.getClassSessions(_teacherId);
      } catch (_) {
        summary = null;
      }
      if (!mounted) return;
      setState(() {
        _classrooms = rooms;
        _sessionsSummary = summary;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _logout() {
    AuthService.instance.logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  // ── Derived stats (all from real data) ──────────────────────────────────────

  int get _savedClasses => _classrooms.length;

  int get _totalStudents => _classrooms.fold(
      0, (sum, r) => sum + (r['student_count'] as num? ?? 0).toInt());

  int get _sessionCount =>
      (_sessionsSummary?['session_count'] as num? ?? 0).toInt();

  int get _liveCount => (_sessionsSummary?['live_count'] as num? ?? 0).toInt();

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Running a session against a saved class is what lets students tap their
  /// name and earn XP. Teachers with no saved classes — or who just want a
  /// quick session — go straight through to the original nickname flow.
  Future<void> _startClassSession() async {
    final teacherId = _teacherId;
    List<Map<String, dynamic>> rooms = _classrooms;
    if (rooms.isEmpty) {
      try {
        rooms = await ApiService.getClassrooms(teacherId);
      } catch (_) {
        // A class list we can't load must never block starting a session.
      }
    }
    if (!mounted) return;

    String? classroomId;
    if (rooms.isNotEmpty) {
      // Empty string is the sentinel for "no class", so dismissing the dialog
      // (null) can be told apart from deliberately choosing a quick session.
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text('Which class?', style: AppTheme.subheading),
          children: [
            ...rooms.map(
              (r) => SimpleDialogOption(
                onPressed: () =>
                    Navigator.pop(ctx, r['classroom_id'] as String? ?? ''),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.sm),
                  child: Row(
                    children: [
                      const Icon(Icons.school_rounded,
                          size: 20, color: TeacherShell.accent),
                      const SizedBox(width: AppTheme.md),
                      Expanded(
                        child: Text(
                          '${r['name']}  ·  ${r['student_count']} student'
                          '${r['student_count'] == 1 ? '' : 's'}',
                          style: AppTheme.body,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, ''),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.sm),
                child: Row(
                  children: [
                    const Icon(Icons.flash_on_outlined,
                        size: 20, color: AppTheme.textLight),
                    const SizedBox(width: AppTheme.md),
                    Expanded(
                      child: Text(
                        'Quick session — students type their name',
                        style:
                            AppTheme.body.copyWith(color: AppTheme.textLight),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
      if (choice == null) return;
      classroomId = choice.isEmpty ? null : choice;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherClassSessionScreen(
          teacherId: teacherId,
          classroomId: classroomId,
        ),
      ),
    );
    if (mounted) _load();
  }

  void _openProjectMode() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ScanObjectScreen(
          flowMode: LearningFlowMode.teacherProjection,
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (_section) {
      TeacherNavItem.dashboard => (
          '${TeacherShell.greeting()}, $_username! 👋',
          'Manage your classroom and live learning sessions.'
        ),
      TeacherNavItem.classes => (
          'My Classes',
          'Saved rosters, XP, levels, badges and prepared vocabulary.'
        ),
      TeacherNavItem.liveSession => (
          'Live Session',
          'Start a class session and push quizzes in real time.'
        ),
      TeacherNavItem.reports => (
          'Reports',
          'Session summaries and leaderboards from real class data.'
        ),
      TeacherNavItem.settings => ('Settings', 'Your account and this device.'),
    };

    return TeacherShell(
      selected: _section,
      onSelect: (item) => setState(() => _section = item),
      onLogout: _logout,
      username: _username,
      title: title,
      subtitle: subtitle,
      headerAction: (_section == TeacherNavItem.dashboard ||
              _section == TeacherNavItem.liveSession)
          ? TeacherPrimaryButton(
              label: 'Create Session',
              icon: Icons.add_rounded,
              onPressed: _startClassSession,
            )
          : null,
      child: _buildSection(),
    );
  }

  Widget _buildSection() {
    if (_loading && _section == TeacherNavItem.dashboard) {
      return const Center(child: CircularProgressIndicator());
    }
    return switch (_section) {
      TeacherNavItem.dashboard => _buildDashboard(),
      TeacherNavItem.classes =>
        ClassroomManageView(teacherId: _teacherId, onChanged: _load),
      TeacherNavItem.liveSession => _buildLiveSession(),
      TeacherNavItem.reports => TeacherReportsView(teacherId: _teacherId),
      TeacherNavItem.settings => _buildSettings(),
    };
  }

  // ── Dashboard ────────────────────────────────────────────────────────────

  Widget _buildDashboard() {
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(AppTheme.xl, 0, AppTheme.xl, AppTheme.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              _buildErrorBanner(),
              const SizedBox(height: AppTheme.lg),
            ],
            // ── Stat tiles (real data only) ──
            LayoutBuilder(
              builder: (context, constraints) {
                final tiles = [
                  TeacherStatCard(
                    icon: Icons.class_rounded,
                    tint: TeacherShell.accent,
                    value: '$_savedClasses',
                    label: 'Saved Classes',
                  ),
                  TeacherStatCard(
                    icon: Icons.groups_rounded,
                    tint: AppTheme.primary,
                    value: '$_totalStudents',
                    label: 'Total Students',
                  ),
                  TeacherStatCard(
                    icon: Icons.assignment_rounded,
                    tint: AppTheme.adventure,
                    value: '$_sessionCount',
                    label: 'Sessions Run',
                  ),
                  TeacherStatCard(
                    icon: Icons.podcasts_rounded,
                    tint: AppTheme.success,
                    value: '$_liveCount',
                    label: 'Live Now',
                  ),
                ];
                final cols = constraints.maxWidth >= 720
                    ? 4
                    : constraints.maxWidth >= 420
                        ? 2
                        : 1;
                return _grid(tiles, cols);
              },
            ),
            const SizedBox(height: AppTheme.xl),

            Text('Quick Actions',
                style: AppTheme.subheading
                    .copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: AppTheme.md),
            Wrap(
              spacing: AppTheme.md,
              runSpacing: AppTheme.md,
              children: [
                _QuickAction(
                  icon: Icons.podcasts_rounded,
                  tint: TeacherShell.accent,
                  title: 'Start Live Session',
                  subtitle: 'Create a code for students to join',
                  onTap: _startClassSession,
                ),
                _QuickAction(
                  icon: Icons.center_focus_strong_rounded,
                  tint: AppTheme.primary,
                  title: 'Project Mode',
                  subtitle: 'Scan objects to display for your class',
                  onTap: _openProjectMode,
                ),
                _QuickAction(
                  icon: Icons.groups_rounded,
                  tint: AppTheme.adventure,
                  title: 'Manage Classes',
                  subtitle: 'Rosters and prepared vocabulary',
                  onTap: () =>
                      setState(() => _section = TeacherNavItem.classes),
                ),
                _QuickAction(
                  icon: Icons.insights_rounded,
                  tint: AppTheme.success,
                  title: 'View Reports',
                  subtitle: 'Session summaries and progress',
                  onTap: () =>
                      setState(() => _section = TeacherNavItem.reports),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.xl),

            Row(
              children: [
                Expanded(
                  child: Text('Recent Classes',
                      style: AppTheme.subheading.copyWith(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _section = TeacherNavItem.classes),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.md),
            if (_classrooms.isEmpty)
              TeacherEmptyState(
                emoji: '📚',
                title: 'No classes yet',
                message:
                    'Create a class to save your roster and prepare vocabulary.',
                action: TeacherSecondaryButton(
                  label: 'Manage Classes',
                  icon: Icons.groups_rounded,
                  onPressed: () =>
                      setState(() => _section = TeacherNavItem.classes),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth >= 720 ? 2 : 1;
                  final cards = _classrooms.take(6).map((r) {
                    final count = (r['student_count'] as num? ?? 0).toInt();
                    final prepared =
                        ((r['prepared_words'] as List?) ?? const []).length;
                    return TeacherClassCard(
                      name: r['name'] as String? ?? 'Class',
                      meta: '$count student${count == 1 ? '' : 's'}'
                          '${prepared == 0 ? '' : ' · $prepared prepared'}',
                      onTap: () =>
                          setState(() => _section = TeacherNavItem.classes),
                    );
                  }).toList();
                  return _grid(cards, cols);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.errorLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppTheme.error, size: 20),
          const SizedBox(width: AppTheme.sm),
          Expanded(
            child: Text('Some data could not load. Pull to refresh.',
                style: AppTheme.caption.copyWith(color: AppTheme.textDark)),
          ),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  /// Simple responsive grid: lays [items] into [cols] equal columns.
  Widget _grid(List<Widget> items, int cols) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += cols) {
      final rowItems = items.skip(i).take(cols).toList();
      rows.add(Padding(
        padding: EdgeInsets.only(
            bottom: i + cols < items.length ? AppTheme.md : 0.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var j = 0; j < cols; j++) ...[
              if (j > 0) const SizedBox(width: AppTheme.md),
              Expanded(
                child: j < rowItems.length
                    ? rowItems[j]
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ));
    }
    return Column(children: rows);
  }

  // ── Live Session section ───────────────────────────────────────────────────

  Widget _buildLiveSession() {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(AppTheme.xl, 0, AppTheme.xl, AppTheme.xxl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TeacherSectionCard(
                title: 'Create Live Session',
                icon: Icons.podcasts_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Generate a class code students enter to join. Pick a '
                      'saved class so they tap their name and keep their XP, '
                      'or run a quick session where they type a nickname.',
                      style: AppTheme.caption,
                    ),
                    const SizedBox(height: AppTheme.lg),
                    TeacherPrimaryButton(
                      label: 'Create Session',
                      icon: Icons.add_rounded,
                      onPressed: _startClassSession,
                      expand: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.lg),
              TeacherSectionCard(
                title: 'Project Mode',
                icon: Icons.center_focus_strong_rounded,
                iconTint: AppTheme.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan real objects and display the trilingual word '
                      '(English, Bahasa Melayu, 中文) for the whole class — no '
                      'code needed.',
                      style: AppTheme.caption,
                    ),
                    const SizedBox(height: AppTheme.lg),
                    TeacherSecondaryButton(
                      label: 'Open Project Mode',
                      icon: Icons.center_focus_strong_rounded,
                      onPressed: _openProjectMode,
                      tint: AppTheme.primary,
                      expand: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Settings ───────────────────────────────────────────────────────────────

  Widget _buildSettings() {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(AppTheme.xl, 0, AppTheme.xl, AppTheme.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TeacherSectionCard(
              title: 'Account',
              icon: Icons.person_rounded,
              child: Column(
                children: [
                  _settingRow('Username', _username),
                  const SizedBox(height: AppTheme.sm),
                  _settingRow('Role', 'Teacher'),
                  const SizedBox(height: AppTheme.sm),
                  _settingRow('Saved classes', '$_savedClasses'),
                  const SizedBox(height: AppTheme.sm),
                  _settingRow('Total students', '$_totalStudents'),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.lg),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Log Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.error,
                side: BorderSide(color: AppTheme.error.withValues(alpha: 0.5)),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingRow(String label, String value) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppTheme.caption)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.body.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// A tappable quick-action tile on the dashboard.
class _QuickAction extends StatefulWidget {
  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 240,
          padding: const EdgeInsets.all(AppTheme.lg),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: [
              BoxShadow(
                color: _hovering
                    ? widget.tint.withValues(alpha: 0.28)
                    : AppTheme.shadowColor,
                blurRadius: _hovering ? 20 : 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          transform: _hovering
              ? (Matrix4.identity()..translateByDouble(0.0, -3.0, 0.0, 1.0))
              : Matrix4.identity(),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.tint.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(widget.icon, color: widget.tint, size: 22),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body
                            .copyWith(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(widget.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.caption.copyWith(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
