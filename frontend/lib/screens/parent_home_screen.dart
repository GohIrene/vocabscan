import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../adventure_config.dart';
import '../api_service.dart';
import '../auth_service.dart';
import '../avatar_config.dart';
import '../theme/app_theme.dart';
import '../widgets/child_avatar.dart';
import '../widgets/parent_shell.dart';
import '../widgets/pin_confirm_dialog.dart';
import 'add_child_screen.dart';
import 'child_home_screen.dart';
import 'child_adventure_map_screen.dart';
import 'child_treasure_album_screen.dart';
import 'parent_dashboard_screen.dart';
import 'parent_edit_child_screen.dart';
import 'scan_object_screen.dart';
import 'welcome_screen.dart';

/// Parent Mode: a dashboard, not a launcher.
///
/// The six sections are views of one screen rather than six routes — the rail
/// stays put and only the body swaps, which is both how the design reads and
/// what keeps the navigation stack flat in an app with no route table.
/// Screens that deserve full focus (add, edit, a child's report) are pushed.
///
/// Tapping a child card no longer starts a scan. Child Mode is one explicit
/// action among several, so a parent opening the app lands on information
/// about their children rather than inside their child's learning flow.
class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  ParentNavItem _section = ParentNavItem.dashboard;

  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  // Dashboard-only view state — which child the weekly chart is filtered to.
  // Null means "All Children" (the grouped view).
  String? _weekFilterChildId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data =
          await ApiService.getParentSummary(user['user_id'] as String);
      if (!mounted) return;
      setState(() {
        _data = data;
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

  // ── Derived ────────────────────────────────────────────────────────────────

  String get _username =>
      AuthService.instance.currentUser?['username'] as String? ?? '';

  String? get _parentId =>
      AuthService.instance.currentUser?['user_id'] as String?;

  List<Map<String, dynamic>> _list(String key) =>
      (_data?[key] as List? ?? const [])
          .whereType<Map>()
          .map((c) => Map<String, dynamic>.from(c))
          .toList();

  List<Map<String, dynamic>> get _children => _list('children');
  List<Map<String, dynamic>> get _inactive => _list('inactive_children');
  String? get _familyCode => _data?['family_code'] as String?;

  // ── Actions ────────────────────────────────────────────────────────────────

  void _logout() {
    AuthService.instance.logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  /// Re-checks the parent's PIN for protected profile and account actions.
  Future<bool> _confirmParent(String message) async {
    final ok = await showPinConfirmDialog(context, message: message);
    return ok && mounted;
  }

  Future<void> _addChild() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddChildScreen()),
    );
    if (mounted) _load();
  }

  Future<void> _editChild(Map<String, dynamic> child) async {
    if (!await _confirmParent('Enter your PIN to edit this profile.')) return;
    if (!mounted) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ParentEditChildScreen(child: child)),
    );
    if (saved == true && mounted) _load();
  }

  void _viewProgress(Map<String, dynamic> child) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParentDashboardScreen(
          childId: child['child_id'] as String? ?? '',
          childNickname: child['nickname'] as String? ?? '',
          parentUsername: _username,
        ),
      ),
    ).then((_) {
      if (mounted) _load();
    });
  }

  void _viewAdventure(Map<String, dynamic> child) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChildAdventureMapScreen(
          childId: child['child_id'] as String? ?? '',
        ),
      ),
    );
  }

  void _viewAlbum(Map<String, dynamic> child) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChildTreasureAlbumScreen(
          childId: child['child_id'] as String? ?? '',
        ),
      ),
    );
  }

  /// FR34: a parent running scan → result → quiz/speech with a child outside
  /// the guided Home Adventure flow. `ScanObjectScreen`'s default flow mode
  /// (`LearningFlowMode.parentRevision`) already gives free navigation and
  /// logs against this child, so this is just wiring the entry point.
  void _practiceWithChild(Map<String, dynamic> child) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanObjectScreen(
          childId: child['child_id'] as String? ?? '',
        ),
      ),
    ).then((_) {
      if (mounted) _load();
    });
  }

  /// Hands the device over to the child, in their own mode.
  void _openChildMode(Map<String, dynamic> child) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'child_home'),
        builder: (_) => ChildHomeScreen(
          childId: child['child_id'] as String? ?? '',
          nickname: child['nickname'] as String? ?? '',
          avatarId: child['avatar_id'] as String?,
          avatarStage: (child['avatar_stage'] as num?)?.toInt() ?? 1,
        ),
      ),
    ).then((_) {
      if (mounted) _load();
    });
  }

  Future<void> _setActive(Map<String, dynamic> child, bool active) async {
    final name = child['nickname'] ?? 'this child';
    if (!await _confirmParent(
        'Enter your PIN to ${active ? 'reactivate' : 'deactivate'} $name.')) {
      return;
    }
    final result = await ApiService.updateChild(
      child['child_id'] as String? ?? '',
      isActive: active,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['status'] == 'ok'
            ? (active ? '$name reactivated' : '$name deactivated')
            : (result['message'] as String? ?? 'Could not update profile')),
      ),
    );
    _load();
  }

  Future<void> _deleteChild(Map<String, dynamic> child) async {
    final name = child['nickname'] ?? 'this child';
    if (!await _confirmParent('Enter your PIN to delete $name.')) return;
    if (!mounted) return;

    // Irreversible and takes their whole history with it, so the consequence
    // is spelled out rather than implied by the word "delete".
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $name?'),
        content: Text(
          "This permanently removes $name's profile and everything they have "
          'learned — words, treasures, quiz and speech history. This cannot '
          'be undone.\n\nTo keep the history instead, deactivate the profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;

    final result =
        await ApiService.deleteChild(child['child_id'] as String? ?? '');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['status'] == 'ok'
            ? '$name deleted'
            : (result['message'] as String? ?? 'Could not delete profile')),
      ),
    );
    _load();
  }

  Future<void> _copyCode() async {
    final code = _familyCode;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Family code copied')),
    );
  }

  Future<void> _regenerateCode() async {
    final parentId = _parentId;
    if (parentId == null) return;
    if (!await _confirmParent('Enter your PIN to create a new family code.')) {
      return;
    }
    if (!mounted) return;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New family code?'),
        content: const Text(
          'Your current code will stop working straight away. Anyone using '
          'it will need the new one.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create new code'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;

    final result = await ApiService.regenerateFamilyCode(parentId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['status'] == 'ok'
            ? 'New family code created'
            : 'Could not create a new code — please try again'),
      ),
    );
    _load();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (_section) {
      ParentNavItem.dashboard => (
          '${ParentShell.greeting()}, $_username! 👋',
          "Here's how your little explorers are doing today."
        ),
      ParentNavItem.children => (
          'My Children',
          'Manage your child profiles.'
        ),
      ParentNavItem.activity => (
          'Activity Log',
          'Everything your children have been learning.'
        ),
      ParentNavItem.reports => (
          'Progress & Reports',
          'Choose a child to see their full report.'
        ),
      ParentNavItem.familyCode => (
          'Family Code',
          'The code your children use to start learning.'
        ),
      ParentNavItem.settings => ('Settings', 'Your account and this device.'),
    };

    return ParentShell(
      selected: _section,
      onSelect: (item) => setState(() => _section = item),
      onLogout: _logout,
      username: _username,
      title: title,
      subtitle: subtitle,
      headerAction: _section == ParentNavItem.dashboard ||
              _section == ParentNavItem.children
          ? FilledButton.icon(
              onPressed: _addChild,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add New Child'),
              style: AppTheme.smallButton.copyWith(
                  backgroundColor:
                      const WidgetStatePropertyAll(AppTheme.primary)),
            )
          : null,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                        AppTheme.xl, 0, AppTheme.xl, AppTheme.xxl),
                    child: switch (_section) {
                      ParentNavItem.dashboard => _buildDashboard(),
                      ParentNavItem.children => _buildChildren(),
                      ParentNavItem.activity => ParentActivityView(
                          parentId: _parentId, children: _children),
                      ParentNavItem.reports => _buildReports(),
                      ParentNavItem.familyCode => _buildFamilyCode(),
                      ParentNavItem.settings => _buildSettings(),
                    },
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: AppTheme.textLight),
            const SizedBox(height: AppTheme.lg),
            Text('Could not load your dashboard',
                style:
                    AppTheme.subheading.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppTheme.sm),
            Text(_error ?? '',
                textAlign: TextAlign.center, style: AppTheme.caption),
            const SizedBox(height: AppTheme.xl),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: AppTheme.primaryButton.copyWith(
                  backgroundColor:
                      const WidgetStatePropertyAll(AppTheme.primary)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dashboard ──────────────────────────────────────────────────────────────

  Widget _buildDashboard() {
    final today = (_data?['today'] as Map?)?.cast<String, dynamic>() ?? {};
    final week = (_data?['week'] as Map?)?.cast<String, dynamic>() ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('My Children',
            style: AppTheme.subheading.copyWith(
                fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: AppTheme.md),
        if (_children.isEmpty)
          _buildNoChildren()
        else
          Wrap(
            spacing: AppTheme.md,
            runSpacing: AppTheme.md,
            children: [
              for (final child in _children)
                SizedBox(width: 320, child: _buildChildCard(child)),
              SizedBox(width: 320, child: _AddChildCard(onTap: _addChild)),
            ],
          ),
        const SizedBox(height: AppTheme.xl),

        _responsiveRow([
          (3, _LearningHighlightsCard(children: _children)),
          (2, _buildTodayCard(today)),
          (3, _buildWeekCard(week)),
        ]),
        const SizedBox(height: AppTheme.md),
        _responsiveRow([
          (2, _buildFamilyCodeCard(compact: true)),
          (3, _RecentActivityPreview(
              parentId: _parentId,
              onViewAll: () =>
                  setState(() => _section = ParentNavItem.activity))),
        ]),
      ],
    );
  }

  /// Lays cards out side by side above [breakpoint], stacked below it — the
  /// same rule the dashboard's card row has always used.
  ///
  /// Side by side, the cards are given a common height so the row doesn't read
  /// as ragged. That relies on IntrinsicHeight, which asks every descendant
  /// for its intrinsic height — so nothing inside a card passed here may be a
  /// LayoutBuilder or a scrollable (ListView/GridView/SingleChildScrollView),
  /// both of which throw rather than answer. Measure with a fixed layout
  /// instead, as [_LearningHighlightsCardState._buildTiles] does.
  Widget _responsiveRow(List<(int, Widget)> items, {double breakpoint = 900}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            children: [
              for (final (_, card) in items) ...[
                card,
                const SizedBox(height: AppTheme.md),
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: AppTheme.md),
                Expanded(flex: items[i].$1, child: items[i].$2),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoChildren() {
    return ParentCard(
      padding: const EdgeInsets.all(AppTheme.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('👶', style: TextStyle(fontSize: 48)),
          const SizedBox(height: AppTheme.md),
          Text('No child profiles yet',
              style:
                  AppTheme.subheading.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: AppTheme.xs),
          Text(
            'Add your first child to start their learning adventure.',
            textAlign: TextAlign.center,
            style: AppTheme.caption,
          ),
          const SizedBox(height: AppTheme.lg),
          FilledButton.icon(
            onPressed: _addChild,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add New Child'),
            style: AppTheme.primaryButton.copyWith(
                backgroundColor:
                    const WidgetStatePropertyAll(AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildChildCard(Map<String, dynamic> child) {
    final adventure =
        (child['adventure'] as Map?)?.cast<String, dynamic>() ?? {};
    final theme = areaThemeById(adventure['current_area_id'] as String?);
    final progress = (adventure['progress_percentage'] as num?)?.toInt() ?? 0;
    final buddy = avatarByIdOrDefault(child['avatar_id'] as String?);

    return ParentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ChildAvatar(
                avatarId: child['avatar_id'] as String?,
                stage: (child['avatar_stage'] as num?)?.toInt() ?? 1,
                size: 54,
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            child['nickname'] as String? ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.subheading.copyWith(
                                fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _Pill(
                            label: buddy.displayName, tint: AppTheme.primary),
                      ],
                    ),
                    Text('Age ${child['age'] ?? '—'}',
                        style: AppTheme.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Adventure: ${theme.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.caption.copyWith(color: AppTheme.textDark),
                ),
              ),
              Text('$progress%',
                  style: AppTheme.caption.copyWith(
                      fontWeight: FontWeight.w800, color: theme.accent)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress / 100,
              minHeight: 8,
              backgroundColor: theme.accent.withValues(alpha: 0.18),
              color: theme.accent,
            ),
          ),
          const SizedBox(height: AppTheme.md),
          Row(
            children: [
              _MiniStat(
                  label: 'Words', value: '${child['words_learned'] ?? 0}'),
              _MiniStat(
                  label: 'Treasures',
                  value: '${child['treasure_count'] ?? 0}'),
              _MiniStat(
                  label: 'Streak',
                  value: '${child['streak_days'] ?? 0}d'),
            ],
          ),
          const SizedBox(height: AppTheme.md),
          // Two explicit primary actions, neither of which is "start
          // scanning" — a stray tap on the card must never drop a parent
          // into the child's flow. Editing lives in "My Children" instead,
          // so this pair stays the two things a parent reaches for most.
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _viewProgress(child),
                  icon: const Icon(Icons.insights_rounded, size: 16),
                  label: const Text('View Progress'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(
                        color: AppTheme.primary.withValues(alpha: 0.4)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm)),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openChildMode(child),
                  icon: const Icon(Icons.play_circle_rounded, size: 16),
                  label: const Text('Enter Child Mode'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.md),
          Text('Child Quick Access',
              style: AppTheme.caption.copyWith(
                  fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppTheme.sm),
          Row(
            children: [
              Expanded(
                child: _CardAction(
                  icon: Icons.map_rounded,
                  label: 'Adventure',
                  centered: true,
                  onTap: () => _viewAdventure(child),
                ),
              ),
              const SizedBox(width: AppTheme.sm),
              Expanded(
                child: _CardAction(
                  icon: Icons.photo_album_rounded,
                  label: 'Album',
                  centered: true,
                  onTap: () => _viewAlbum(child),
                ),
              ),
              const SizedBox(width: AppTheme.sm),
              Expanded(
                child: _CardAction(
                  icon: Icons.camera_alt_rounded,
                  label: 'Practice',
                  centered: true,
                  onTap: () => _practiceWithChild(child),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayCard(Map<String, dynamic> today) {
    return ParentCard(
      title: "Today's Family Activity",
      icon: Icons.today_rounded,
      iconTint: AppTheme.secondary,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ParentStat(
                  icon: Icons.photo_camera_rounded,
                  tint: AppTheme.success,
                  label: 'Scans',
                  value: '${today['scans'] ?? 0}',
                ),
              ),
              const SizedBox(width: AppTheme.sm),
              Expanded(
                child: ParentStat(
                  icon: Icons.quiz_rounded,
                  tint: AppTheme.secondary,
                  label: 'Quiz Attempts',
                  value: '${today['quiz_attempts'] ?? 0}',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sm),
          Row(
            children: [
              Expanded(
                child: ParentStat(
                  icon: Icons.mic_rounded,
                  tint: AppTheme.blossom,
                  label: 'Speech Attempts',
                  value: '${today['speech_attempts'] ?? 0}',
                ),
              ),
              const SizedBox(width: AppTheme.sm),
              Expanded(
                child: ParentStat(
                  icon: Icons.text_fields_rounded,
                  tint: AppTheme.adventure,
                  label: 'New Words',
                  value: '${today['new_words'] ?? 0}',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  setState(() => _section = ParentNavItem.activity),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('View Activity Log'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: BorderSide(
                    color: AppTheme.primary.withValues(alpha: 0.35)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekCard(Map<String, dynamic> week) {
    final days = (week['days'] as List? ?? const [])
        .whereType<Map>()
        .map((d) => Map<String, dynamic>.from(d))
        .toList();
    final allSeries = (week['series'] as List? ?? const [])
        .whereType<Map>()
        .map((s) => Map<String, dynamic>.from(s))
        .toList();

    // "All Children" (null) shows every child's bars grouped by day, same
    // data the backend already returns; picking one child just narrows the
    // same series down to a single bar per day.
    final filterId = _weekFilterChildId;
    final series = filterId == null
        ? allSeries
        : allSeries.where((s) => s['child_id'] == filterId).toList();
    final max = series.isEmpty
        ? 0
        : series
            .map((s) => (s['scans'] as List? ?? const [])
                .whereType<num>()
                .fold(0, (m, v) => v.toInt() > m ? v.toInt() : m))
            .fold(0, (m, v) => v > m ? v : m);

    return ParentCard(
      title: 'Weekly Activity',
      icon: Icons.show_chart_rounded,
      iconTint: AppTheme.secondary,
      action: allSeries.length > 1
          ? DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: filterId,
                isDense: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                style: AppTheme.caption.copyWith(
                    color: AppTheme.textDark, fontWeight: FontWeight.w700),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('All Children')),
                  for (final s in allSeries)
                    DropdownMenuItem(
                      value: s['child_id'] as String?,
                      child: Text(s['nickname'] as String? ?? ''),
                    ),
                ],
                onChanged: (id) => setState(() => _weekFilterChildId = id),
              ),
            )
          : null,
      child: series.isEmpty || days.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.lg),
              child: Text('No activity yet this week.',
                  style: AppTheme.caption),
            )
          : Column(
              children: [
                // A grouped bar chart rather than a line chart: with three or
                // four children, overlapping lines at this size are unreadable.
                SizedBox(
                  height: 92,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var d = 0; d < days.length; d++)
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  for (final s in series)
                                    _Bar(
                                      value: ((s['scans'] as List?)
                                                  ?[d] as num?)
                                              ?.toInt() ??
                                          0,
                                      max: max,
                                      color: _seriesColor(
                                          allSeries.indexOf(s)),
                                      tooltip: '${s['nickname']} · '
                                          '${((s['scans'] as List?)?[d] as num?)?.toInt() ?? 0} scans',
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                days[d]['weekday'] as String? ?? '',
                                style: AppTheme.caption.copyWith(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (series.length > 1) ...[
                  const SizedBox(height: AppTheme.sm),
                  Wrap(
                    spacing: AppTheme.md,
                    runSpacing: 4,
                    children: [
                      for (final s in series)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: _seriesColor(allSeries.indexOf(s)),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(s['nickname'] as String? ?? '',
                                style:
                                    AppTheme.caption.copyWith(fontSize: 11)),
                          ],
                        ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }

  static Color _seriesColor(int index) => const [
        AppTheme.secondary,
        AppTheme.adventure,
        AppTheme.blossom,
        AppTheme.primary,
        AppTheme.success,
        AppTheme.treasure,
      ][index % 6];

  Widget _buildFamilyCodeCard({bool compact = false}) {
    final code = _familyCode;
    return ParentCard(
      title: 'Family Access Code',
      icon: Icons.vpn_key_rounded,
      iconTint: AppTheme.secondary,
      action: compact
          ? TextButton(
              onPressed: () =>
                  setState(() => _section = ParentNavItem.familyCode),
              child: const Text('View All'),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.center,
            child: Icon(Icons.auto_awesome_rounded,
                size: 14, color: AppTheme.primary.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 4),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: AppTheme.md),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                alignment: Alignment.center,
                child: Text(
                  code ?? '——————',
                  style: AppTheme.heading.copyWith(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 8,
                    color:
                        code == null ? AppTheme.textLight : AppTheme.textDark,
                  ),
                ),
              ),
              Positioned(left: AppTheme.lg, child: _DotCluster()),
              Positioned(right: AppTheme.lg, child: _DotCluster()),
            ],
          ),
          const SizedBox(height: AppTheme.sm),
          Text(
            'Share this code with your child to let them access their '
            'profiles.',
            style: AppTheme.caption,
          ),
          const SizedBox(height: AppTheme.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: code == null ? null : _copyCode,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy Code'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppTheme.surface,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm)),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _regenerateCode,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Regenerate Code'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(
                        color: AppTheme.primary.withValues(alpha: 0.35)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── My Children ────────────────────────────────────────────────────────────

  Widget _buildChildren() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_children.isEmpty)
          _buildNoChildren()
        else ...[
          for (final child in _children) ...[
            ParentCard(child: _buildChildRow(child, active: true)),
            const SizedBox(height: AppTheme.md),
          ],
          _buildAddAnotherChild(),
        ],
        if (_inactive.isNotEmpty) ...[
          const SizedBox(height: AppTheme.lg),
          ParentCard(
            title: 'Inactive Children',
            icon: Icons.visibility_off_rounded,
            iconTint: AppTheme.textLight,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'These profiles are hidden from the family code and '
                    'cannot be opened by a child. Their history is kept.',
                    style: AppTheme.caption,
                  ),
                ),
                const SizedBox(height: AppTheme.md),
                for (var i = 0; i < _inactive.length; i++) ...[
                  if (i > 0)
                    Divider(
                        height: AppTheme.lg,
                        color: AppTheme.primary.withValues(alpha: 0.1)),
                  _buildChildRow(_inactive[i], active: false),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildChildRow(Map<String, dynamic> child, {required bool active}) {
    final buddy = avatarByIdOrDefault(child['avatar_id'] as String?);
    return Row(
      children: [
        ChildAvatar(
          avatarId: child['avatar_id'] as String?,
          stage: (child['avatar_stage'] as num?)?.toInt() ?? 1,
          size: 46,
          dimmed: !active,
        ),
        const SizedBox(width: AppTheme.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      child['nickname'] as String? ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body.copyWith(
                          fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _Pill(
                    label: active ? buddy.displayName : 'Inactive',
                    tint: active ? AppTheme.primary : AppTheme.textLight,
                  ),
                  if (active && child['has_pin'] == true) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.lock_outline,
                        size: 13, color: AppTheme.textLight),
                  ],
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 12, color: AppTheme.textLight),
                  const SizedBox(width: 4),
                  Text('Age ${child['age'] ?? '—'}', style: AppTheme.caption),
                ],
              ),
            ],
          ),
        ),
        Container(
          width: 1,
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: AppTheme.md),
          color: AppTheme.primary.withValues(alpha: 0.12),
        ),
        if (active) ...[
          _ChildAction(
              icon: Icons.edit_rounded,
              label: 'Edit',
              color: AppTheme.primary,
              onTap: () => _editChild(child)),
          const SizedBox(width: 8),
          _ChildAction(
              icon: Icons.insights_rounded,
              label: 'Progress',
              color: AppTheme.primary,
              onTap: () => _viewProgress(child)),
          const SizedBox(width: 8),
          _ChildAction(
            icon: Icons.visibility_off_rounded,
            label: 'Deactivate',
            color: AppTheme.error,
            onTap: () => _setActive(child, false),
          ),
        ] else ...[
          _ChildAction(
            icon: Icons.restart_alt_rounded,
            label: 'Reactivate',
            color: AppTheme.primary,
            onTap: () => _setActive(child, true),
          ),
          const SizedBox(width: 8),
          _ChildAction(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: AppTheme.error,
            onTap: () => _deleteChild(child),
          ),
        ],
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right_rounded, color: AppTheme.textLight),
      ],
    );
  }

  Widget _buildAddAnotherChild() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.lg),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.group_add_rounded,
                color: AppTheme.primary, size: 32),
          ),
          const SizedBox(height: AppTheme.md),
          Text('Add another child',
              style:
                  AppTheme.subheading.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(
            'Create a new profile to start their learning journey.',
            style: AppTheme.caption,
          ),
          const SizedBox(height: AppTheme.lg),
          FilledButton.icon(
            onPressed: _addChild,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add New Child'),
            style: AppTheme.primaryButton.copyWith(
                backgroundColor:
                    const WidgetStatePropertyAll(AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  // ── Reports ────────────────────────────────────────────────────────────────

  Widget _buildReports() {
    if (_children.isEmpty) return _buildNoChildren();
    return ParentCard(
      child: Column(
        children: [
          for (var i = 0; i < _children.length; i++) ...[
            if (i > 0)
              Divider(
                  height: AppTheme.lg,
                  color: AppTheme.primary.withValues(alpha: 0.1)),
            Row(
              children: [
                ChildAvatar(
                  avatarId: _children[i]['avatar_id'] as String?,
                  stage:
                      (_children[i]['avatar_stage'] as num?)?.toInt() ?? 1,
                  size: 46,
                ),
                const SizedBox(width: AppTheme.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _children[i]['nickname'] as String? ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body.copyWith(
                            fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      Text(
                        '${_children[i]['words_learned'] ?? 0} words · '
                        '${_children[i]['treasure_count'] ?? 0} treasures',
                        style: AppTheme.caption,
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _viewProgress(_children[i]),
                  icon: const Icon(Icons.insights_rounded, size: 16),
                  label: const Text('View Report'),
                  style: AppTheme.smallButton.copyWith(
                      backgroundColor:
                          const WidgetStatePropertyAll(AppTheme.primary)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Family code (full view) ────────────────────────────────────────────────

  Widget _buildFamilyCode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: _buildFamilyCodeCard(),
        ),
        const SizedBox(height: AppTheme.lg),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ParentCard(
            title: 'How your child signs in',
            icon: Icons.help_outline_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Step(
                  n: 1,
                  text: 'On the welcome screen, they tap '
                      '"I\'m Learning at Home".',
                  trailingIcon: Icons.home_rounded,
                ),
                _Step(
                  n: 2,
                  text: 'They type this family code.',
                  trailingIcon: Icons.tablet_mac_rounded,
                ),
                _Step(
                  n: 3,
                  text: 'They tap their own buddy to pick their '
                      'profile.',
                  trailingIcon: Icons.person_rounded,
                ),
                _Step(
                  n: 4,
                  text: 'If you set a child PIN, they type it — '
                      'otherwise they start straight away.',
                  trailingIcon: Icons.lock_rounded,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Settings ───────────────────────────────────────────────────────────────

  Widget _buildSettings() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ParentCard(
            title: 'Account',
            icon: Icons.person_rounded,
            child: Column(
              children: [
                _SettingRow(
                    icon: Icons.person_rounded,
                    label: 'Username',
                    value: _username),
                const Divider(height: AppTheme.lg),
                _SettingRow(
                    icon: Icons.shield_rounded, label: 'Role', value: 'Parent'),
                const Divider(height: AppTheme.lg),
                _SettingRow(
                    icon: Icons.groups_rounded,
                    label: 'Child profiles',
                    value: '${_children.length} active, '
                        '${_inactive.length} inactive'),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.lg),
          ParentCard(
            title: 'Safety',
            icon: Icons.shield_rounded,
            iconTint: AppTheme.success,
            child: Column(
              children: [
                _SafetyItem(
                  icon: Icons.lock_rounded,
                  title: 'PIN protection',
                  description:
                      'Your PIN is asked for before editing, deactivating or '
                      'deleting a child, and before regenerating the family '
                      'code — in case your child is holding the device.',
                ),
                const SizedBox(height: AppTheme.sm),
                _SafetyItem(
                  icon: Icons.photo_camera_rounded,
                  title: 'Privacy by design',
                  description:
                      'Camera images are never stored. Only recognition, '
                      'quiz and speech outcomes are recorded.',
                ),
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
    );
  }
}

// ── Activity view ────────────────────────────────────────────────────────────

/// The combined activity feed. Loads on its own so opening the dashboard
/// doesn't pay for a log a parent may never look at.
class ParentActivityView extends StatefulWidget {
  final String? parentId;

  /// Every child (active and inactive), so the child filter can list a child
  /// even before they have any logged activity. Falls back to deriving the
  /// list from the fetched events when the dashboard hasn't loaded yet.
  final List<Map<String, dynamic>> children;

  const ParentActivityView(
      {super.key, required this.parentId, this.children = const []});

  @override
  State<ParentActivityView> createState() => _ParentActivityViewState();
}

class _ParentActivityViewState extends State<ParentActivityView> {
  List<Map<String, dynamic>>? _events;
  String? _error;
  Map<String, dynamic>? _summary;

  final _searchController = TextEditingController();
  String _search = '';
  String? _childFilter;
  String _typeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
    _loadSummary();
    _searchController.addListener(() {
      setState(() => _search = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final parentId = widget.parentId;
    if (parentId == null) return;
    try {
      final data = await ApiService.getParentActivity(parentId);
      if (!mounted) return;
      setState(() {
        _events = (data['activity'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  /// The header's weekly stats. Loaded separately from the timeline, and
  /// failures here stay silent — the timeline is the part that matters, and
  /// still works without this.
  Future<void> _loadSummary() async {
    final parentId = widget.parentId;
    if (parentId == null) return;
    try {
      final data = await ApiService.getParentActivitySummary(parentId);
      if (!mounted) return;
      setState(() => _summary = data);
    } catch (_) {
      // Header just stays hidden; see doc comment above.
    }
  }

  List<Map<String, dynamic>> get _childOptions {
    if (widget.children.isNotEmpty) return widget.children;
    final seen = <String>{};
    final opts = <Map<String, dynamic>>[];
    for (final e in _events ?? const []) {
      final id = e['child_id'] as String?;
      if (id == null || !seen.add(id)) continue;
      opts.add({'child_id': id, 'nickname': e['child_nickname'] ?? ''});
    }
    return opts;
  }

  List<Map<String, dynamic>> get _filtered {
    Iterable<Map<String, dynamic>> events = _events ?? const [];
    if (_childFilter != null) {
      events = events.where((e) => e['child_id'] == _childFilter);
    }
    if (_typeFilter != 'all') {
      events = events.where((e) => e['type'] == _typeFilter);
    }
    if (_search.isNotEmpty) {
      events = events.where((e) {
        final desc = (e['description'] as String? ?? '').toLowerCase();
        final word = (e['english_word'] as String? ?? '').toLowerCase();
        return desc.contains(_search) || word.contains(_search);
      });
    }
    return events.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFilters(),
        const SizedBox(height: AppTheme.md),
        _buildSummary(),
        const SizedBox(height: AppTheme.lg),
        _buildTimeline(),
      ],
    );
  }

  // ── Filters ────────────────────────────────────────────────────────────────

  Widget _buildFilters() {
    return Wrap(
      spacing: AppTheme.sm,
      runSpacing: AppTheme.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          child: TextField(
            controller: _searchController,
            style: AppTheme.body.copyWith(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search word or activity',
              hintStyle: AppTheme.caption,
              prefixIcon:
                  Icon(Icons.search_rounded, size: 20, color: AppTheme.textLight),
              isDense: true,
              filled: true,
              fillColor: AppTheme.surface,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                borderSide:
                    BorderSide(color: AppTheme.primary.withValues(alpha: 0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                borderSide:
                    BorderSide(color: AppTheme.primary.withValues(alpha: 0.2)),
              ),
            ),
          ),
        ),
        if (_childOptions.length > 1) _buildChildDropdown(),
        _buildTypePills(),
      ],
    );
  }

  Widget _buildChildDropdown() {
    final options = _childOptions;
    final valuePresent = options.any((c) => c['child_id'] == _childFilter);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: valuePresent ? _childFilter : null,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          style: AppTheme.caption
              .copyWith(color: AppTheme.textDark, fontWeight: FontWeight.w700),
          items: [
            const DropdownMenuItem(value: null, child: Text('All Children')),
            for (final c in options)
              DropdownMenuItem(
                value: c['child_id'] as String?,
                child: Text(c['nickname'] as String? ?? ''),
              ),
          ],
          onChanged: (id) => setState(() => _childFilter = id),
        ),
      ),
    );
  }

  Widget _buildTypePills() {
    const options = [
      ('all', 'All'),
      ('scan', 'Scans'),
      ('quiz', 'Quiz'),
      ('speech', 'Speech'),
      ('treasure', 'Treasures'),
    ];
    return Wrap(
      spacing: 6,
      children: [
        for (final (value, label) in options)
          _ActivityFilterChip(
            label: label,
            selected: _typeFilter == value,
            onTap: () => setState(() => _typeFilter = value),
          ),
      ],
    );
  }

  // ── Weekly summary ────────────────────────────────────────────────────────

  Widget _buildSummary() {
    final summary = _summary;
    if (summary == null) return const SizedBox.shrink();

    final thisWeek = (summary['this_week'] as Map?)?.cast<String, dynamic>();
    final lastWeek = (summary['last_week'] as Map?)?.cast<String, dynamic>();
    final mostActive =
        (summary['most_active_child'] as Map?)?.cast<String, dynamic>();

    final tiles = _buildStatTiles(thisWeek, lastWeek);
    final sideCards = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDonutCard(thisWeek),
        if (mostActive != null) ...[
          const SizedBox(height: AppTheme.md),
          _buildMostActiveCard(mostActive),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            children: [tiles, const SizedBox(height: AppTheme.md), sideCards],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: tiles),
            const SizedBox(width: AppTheme.md),
            Expanded(flex: 2, child: sideCards),
          ],
        );
      },
    );
  }

  Widget _buildStatTiles(
      Map<String, dynamic>? thisWeek, Map<String, dynamic>? lastWeek) {
    final tw = thisWeek ?? const {};
    final lw = lastWeek ?? const {};
    final items = [
      ('Total Activities', 'total', Icons.insights_rounded, AppTheme.primary),
      ('Scans', 'scans', Icons.photo_camera_rounded, AppTheme.success),
      ('Quiz Attempts', 'quiz_attempts', Icons.quiz_rounded,
          AppTheme.secondary),
      ('Speech Attempts', 'speech_attempts', Icons.mic_rounded,
          AppTheme.blossom),
    ];

    return ParentCard(
      title: "This Week's Activity",
      icon: Icons.calendar_today_rounded,
      iconTint: AppTheme.secondary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const columns = 2;
          const gap = AppTheme.sm;
          final tileWidth =
              (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final (label, key, icon, tint) in items)
                SizedBox(
                  width: tileWidth,
                  child: ParentStat(
                    icon: icon,
                    tint: tint,
                    label: label,
                    value: '${(tw[key] as num?)?.toInt() ?? 0}',
                    caption: _weeklyDelta((tw[key] as num?)?.toInt() ?? 0,
                        (lw[key] as num?)?.toInt() ?? 0),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDonutCard(Map<String, dynamic>? thisWeek) {
    final tw = thisWeek ?? const {};
    final segments = [
      _DonutSegment('Scans', (tw['scans'] as num?)?.toInt() ?? 0,
          AppTheme.success),
      _DonutSegment('Quiz', (tw['quiz_attempts'] as num?)?.toInt() ?? 0,
          AppTheme.secondary),
      _DonutSegment('Speech', (tw['speech_attempts'] as num?)?.toInt() ?? 0,
          AppTheme.blossom),
      _DonutSegment('Treasures', (tw['treasures'] as num?)?.toInt() ?? 0,
          AppTheme.treasure),
    ];
    final total = segments.fold(0, (sum, s) => sum + s.value);

    return ParentCard(
      title: 'Activity Summary',
      icon: Icons.pie_chart_rounded,
      iconTint: AppTheme.primary,
      child: Row(
        children: [
          _DonutChart(segments: segments, total: total),
          const SizedBox(width: AppTheme.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in segments)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                              color: s.color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(s.label,
                              style: AppTheme.caption.copyWith(fontSize: 12)),
                        ),
                        Text(
                          total == 0
                              ? '0'
                              : '${s.value} '
                                  '(${(s.value / total * 100).round()}%)',
                          style: AppTheme.caption.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textDark),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMostActiveCard(Map<String, dynamic> child) {
    final now = (child['activities_this_week'] as num?)?.toInt() ?? 0;
    final before = (child['activities_last_week'] as num?)?.toInt() ?? 0;
    final delta = _weeklyDelta(now, before);

    return ParentCard(
      title: 'Most Active Child',
      icon: Icons.emoji_events_rounded,
      iconTint: AppTheme.adventure,
      child: Row(
        children: [
          ChildAvatar(avatarId: child['avatar_id'] as String?, size: 44),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(child['nickname'] as String? ?? '',
                    style: AppTheme.body.copyWith(fontWeight: FontWeight.w800)),
                Text('$now activities this week', style: AppTheme.caption),
                if (delta != null)
                  Text(delta,
                      style: AppTheme.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: now >= before
                              ? AppTheme.success
                              : AppTheme.textLight)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Timeline ──────────────────────────────────────────────────────────────

  Widget _buildTimeline() {
    if (_error != null) {
      return ParentCard(
        child: Column(
          children: [
            Text('Could not load the activity log', style: AppTheme.body),
            const SizedBox(height: AppTheme.sm),
            Text(_error!, style: AppTheme.caption),
            const SizedBox(height: AppTheme.md),
            FilledButton(
              onPressed: _load,
              style: AppTheme.smallButton.copyWith(
                  backgroundColor:
                      const WidgetStatePropertyAll(AppTheme.primary)),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }
    if (_events == null) {
      return const Padding(
        padding: EdgeInsets.all(AppTheme.xxl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_events!.isEmpty) {
      return ParentCard(
        padding: const EdgeInsets.all(AppTheme.xxl),
        child: Column(
          children: [
            const Text('📋', style: TextStyle(fontSize: 44)),
            const SizedBox(height: AppTheme.md),
            Text('No activity yet',
                style:
                    AppTheme.subheading.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppTheme.xs),
            Text('Learning your children do will appear here.',
                textAlign: TextAlign.center, style: AppTheme.caption),
          ],
        ),
      );
    }

    final events = _filtered;
    if (events.isEmpty) {
      return ParentCard(
        padding: const EdgeInsets.all(AppTheme.xxl),
        child: Column(
          children: [
            const Text('🔍', style: TextStyle(fontSize: 44)),
            const SizedBox(height: AppTheme.md),
            Text('No matching activity',
                style:
                    AppTheme.subheading.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppTheme.xs),
            Text('Try a different search or filter.',
                textAlign: TextAlign.center, style: AppTheme.caption),
          ],
        ),
      );
    }

    // Grouped by local day, the same GMT+8 bucketing the report uses.
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final e in events) {
      grouped.putIfAbsent(e['local_date'] as String? ?? '', () => []).add(e);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.only(
                bottom: AppTheme.sm, top: AppTheme.sm),
            child: Text(
              '${entry.value.first['local_weekday']}, ${entry.key}',
              style: AppTheme.caption.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          ParentCard(
            child: Column(
              children: [
                for (var i = 0; i < entry.value.length; i++) ...[
                  if (i > 0)
                    Divider(
                        height: AppTheme.md,
                        color: AppTheme.primary.withValues(alpha: 0.08)),
                  Builder(
                    builder: (context) {
                      final e = entry.value[i];
                      final (icon, tint) =
                          _activityStyle(e['type'] as String? ?? '');
                      final statusPill = _statusPillFor(e);
                      return Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: tint.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, size: 16, color: tint),
                          ),
                          const SizedBox(width: AppTheme.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e['description'] as String? ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.body.copyWith(fontSize: 14),
                                ),
                                Text(
                                  e['child_nickname'] as String? ?? '',
                                  style: AppTheme.caption
                                      .copyWith(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          if (statusPill != null) ...[
                            statusPill,
                            const SizedBox(width: AppTheme.sm),
                          ],
                          Text(e['local_time'] as String? ?? '',
                              style: AppTheme.caption.copyWith(fontSize: 11)),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget? _statusPillFor(Map<String, dynamic> e) {
    final type = e['type'] as String? ?? '';
    if (type == 'treasure') {
      return const _Pill(label: 'New Treasure', tint: AppTheme.treasure);
    }
    if (type == 'quiz' || type == 'speech') {
      final correct = e['correct'];
      if (correct == true) {
        return const _Pill(label: 'Correct', tint: AppTheme.success);
      }
      if (correct == false) {
        return _Pill(
            label: type == 'speech' ? 'Try Again' : 'Incorrect',
            tint: AppTheme.error);
      }
    }
    return null;
  }
}

/// Percent change vs. last week, formatted for a [ParentStat] caption. Null
/// when there's nothing meaningful to compare (both weeks empty).
String? _weeklyDelta(int now, int before) {
  if (before == 0) return now > 0 ? 'New this week' : null;
  final pct = ((now - before) / before * 100).round();
  if (pct == 0) return 'Same as last week';
  final arrow = pct > 0 ? '↑' : '↓';
  return '$arrow${pct.abs()}% vs last week';
}

class _ActivityFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ActivityFilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected
                  ? AppTheme.primary
                  : AppTheme.primary.withValues(alpha: 0.2)),
        ),
        child: Text(
          label,
          style: AppTheme.caption.copyWith(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppTheme.textDark,
          ),
        ),
      ),
    );
  }
}

class _DonutSegment {
  final String label;
  final int value;
  final Color color;
  const _DonutSegment(this.label, this.value, this.color);
}

/// A ring chart with the total centred inside it — no charting package, just
/// a small [CustomPainter] arc per segment.
class _DonutChart extends StatelessWidget {
  final List<_DonutSegment> segments;
  final int total;

  const _DonutChart({required this.segments, required this.total});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      height: 108,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(108, 108),
            painter: _DonutPainter(segments: segments, total: total),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$total',
                  style: AppTheme.heading
                      .copyWith(fontSize: 24, fontWeight: FontWeight.w800)),
              Text('Total', style: AppTheme.caption.copyWith(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<_DonutSegment> segments;
  final int total;

  const _DonutPainter({required this.segments, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(9);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.butt;

    if (total <= 0) {
      paint.color = AppTheme.textLight.withValues(alpha: 0.15);
      canvas.drawArc(rect, 0, 2 * math.pi, false, paint);
      return;
    }

    var start = -math.pi / 2;
    for (final s in segments) {
      if (s.value <= 0) continue;
      final sweep = (s.value / total) * 2 * math.pi;
      paint.color = s.color;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.segments != segments || oldDelegate.total != total;
}

/// Shared by the full Activity Log and the dashboard's recent-activity
/// preview, so the two stay visually in sync.
(IconData, Color) _activityStyle(String type) => switch (type) {
      'treasure' => (Icons.card_giftcard_rounded, AppTheme.treasure),
      'scan' => (Icons.photo_camera_rounded, AppTheme.success),
      'quiz' => (Icons.quiz_rounded, AppTheme.secondary),
      'speech' => (Icons.mic_rounded, AppTheme.blossom),
      _ => (Icons.circle, AppTheme.textLight),
    };

// ── Learning Highlights (dashboard) ──────────────────────────────────────────

/// Per-child breakdown, picked from a dropdown. Loads on demand from the same
/// `/report/<child_id>` the full report screen already reads — no new data,
/// just one extra call scoped to whichever child is selected.
class _LearningHighlightsCard extends StatefulWidget {
  final List<Map<String, dynamic>> children;

  const _LearningHighlightsCard({required this.children});

  @override
  State<_LearningHighlightsCard> createState() =>
      _LearningHighlightsCardState();
}

class _LearningHighlightsCardState extends State<_LearningHighlightsCard> {
  String? _childId;
  Map<String, dynamic>? _report;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _childId = widget.children.isEmpty
        ? null
        : widget.children.first['child_id'] as String?;
    _load();
  }

  @override
  void didUpdateWidget(_LearningHighlightsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The selected child may have been deactivated/deleted elsewhere — fall
    // back to the first remaining child rather than showing a stale report.
    final stillPresent =
        widget.children.any((c) => c['child_id'] == _childId);
    if (!stillPresent) {
      setState(() {
        _childId = widget.children.isEmpty
            ? null
            : widget.children.first['child_id'] as String?;
        _report = null;
      });
      _load();
    }
  }

  Future<void> _load() async {
    final id = _childId;
    if (id == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getReport(id);
      if (!mounted) return;
      setState(() {
        _report = data;
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

  String? get _nickname => widget.children
      .firstWhere((c) => c['child_id'] == _childId,
          orElse: () => const <String, dynamic>{})['nickname'] as String?;

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) {
      return ParentCard(
        title: 'Learning Highlights',
        icon: Icons.auto_awesome_rounded,
        iconTint: AppTheme.secondary,
        child: Text('Add a child to see their highlights.',
            style: AppTheme.caption),
      );
    }

    return ParentCard(
      title: _nickname == null
          ? 'Learning Highlights'
          : 'Learning Highlights — $_nickname',
      icon: Icons.auto_awesome_rounded,
      iconTint: AppTheme.secondary,
      action: widget.children.length > 1
          ? DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _childId,
                isDense: true,
                icon:
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                items: [
                  for (final c in widget.children)
                    DropdownMenuItem(
                      value: c['child_id'] as String,
                      child: Text(c['nickname'] as String? ?? ''),
                    ),
                ],
                onChanged: (id) {
                  if (id == null || id == _childId) return;
                  setState(() {
                    _childId = id;
                    _report = null;
                  });
                  _load();
                },
              ),
            )
          : null,
      child: _loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: AppTheme.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          : _error != null
              ? Text('Could not load highlights', style: AppTheme.caption)
              : _buildTiles(),
    );
  }

  Widget _buildTiles() {
    final report = _report;
    final profile = (report?['profile'] as Map?)?.cast<String, dynamic>();
    final adventure =
        (profile?['adventure'] as Map?)?.cast<String, dynamic>();
    final streakDays = (profile?['streak_days'] as num?)?.toInt() ?? 0;
    final progress =
        (adventure?['progress_percentage'] as num?)?.toInt() ?? 0;

    final tiles = [
      ('New Words', '${report?['total_words'] ?? 0}',
          Icons.text_fields_rounded, AppTheme.secondary),
      ('Treasures', '${profile?['treasure_count'] ?? 0}',
          Icons.card_giftcard_rounded, AppTheme.treasure),
      ('Streak', '${streakDays}d', Icons.local_fire_department_rounded,
          AppTheme.blossom),
      ('Adventure Progress', '$progress%', Icons.map_rounded,
          AppTheme.adventure),
      ('Quiz Accuracy', '${report?['quiz_accuracy'] ?? 0}%',
          Icons.quiz_rounded, AppTheme.success),
      ('Speech Accuracy', '${report?['speech_accuracy'] ?? 0}%',
          Icons.mic_rounded, AppTheme.primary),
    ];

    // Fixed 3-wide rows of Expanded rather than a width-measuring
    // LayoutBuilder + Wrap. Same result — the old code always divided the
    // width into exactly 3 columns, so it never reflowed — but this card sits
    // inside the dashboard's IntrinsicHeight row (see [_responsiveRow]), and
    // a LayoutBuilder cannot answer an intrinsic-height query.
    const columns = 3;
    const gap = AppTheme.sm;
    return Column(
      children: [
        for (var start = 0; start < tiles.length; start += columns) ...[
          if (start > 0) const SizedBox(height: gap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) const SizedBox(width: gap),
                // A short last row keeps its empty slots, so the tiles above
                // and below stay in the same columns.
                Expanded(
                  child: start + c < tiles.length
                      ? ParentStat(
                          icon: tiles[start + c].$3,
                          tint: tiles[start + c].$4,
                          label: tiles[start + c].$1,
                          value: tiles[start + c].$2,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

// ── Recent Family Activity (dashboard preview) ───────────────────────────────

/// A short, flat preview of the same feed the full Activity Log shows — the
/// last five events, fetched directly (rather than reusing
/// [ParentActivityView]'s day-grouped state) so the dashboard card stays a
/// simple list.
class _RecentActivityPreview extends StatefulWidget {
  final String? parentId;
  final VoidCallback onViewAll;

  const _RecentActivityPreview(
      {required this.parentId, required this.onViewAll});

  @override
  State<_RecentActivityPreview> createState() =>
      _RecentActivityPreviewState();
}

class _RecentActivityPreviewState extends State<_RecentActivityPreview> {
  List<Map<String, dynamic>>? _events;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final parentId = widget.parentId;
    if (parentId == null) return;
    try {
      final data = await ApiService.getParentActivity(parentId, n: 5);
      if (!mounted) return;
      setState(() {
        _events = (data['activity'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ParentCard(
      title: 'Recent Family Activity',
      icon: Icons.history_rounded,
      iconTint: AppTheme.secondary,
      action: TextButton(
        onPressed: widget.onViewAll,
        child: const Text('View All Activity'),
      ),
      child: _error != null
          ? Text('Could not load activity', style: AppTheme.caption)
          : _events == null
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppTheme.lg),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _events!.isEmpty
                  ? Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppTheme.md),
                      child:
                          Text('No activity yet.', style: AppTheme.caption),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < _events!.length; i++) ...[
                          if (i > 0)
                            Divider(
                                height: AppTheme.md,
                                color: AppTheme.primary
                                    .withValues(alpha: 0.08)),
                          _buildRow(_events![i]),
                        ],
                      ],
                    ),
    );
  }

  Widget _buildRow(Map<String, dynamic> e) {
    final (icon, tint) = _activityStyle(e['type'] as String? ?? '');
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: tint),
          ),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  e['description'] as String? ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.body.copyWith(fontSize: 14),
                ),
                Text(
                  e['child_nickname'] as String? ?? '',
                  style: AppTheme.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Text(e['local_time'] as String? ?? '',
              style: AppTheme.caption.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Small pieces ─────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final String label;
  final Color tint;
  const _Pill({required this.label, required this.tint});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTheme.caption.copyWith(
            fontSize: 10.5, fontWeight: FontWeight.w700, color: tint),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: AppTheme.subheading
                  .copyWith(fontSize: 17, fontWeight: FontWeight.w800)),
          Text(label, style: AppTheme.caption.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Centers the row instead of hugging its content — used when the action
  /// fills an [Expanded] slot in the "Child Quick Access" row.
  final bool centered;

  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: centered ? double.infinity : null,
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: AppTheme.primary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A bordered icon-over-label button used in a child row (Edit, Progress,
/// Deactivate, ...).
class _ChildAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ChildAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Container(
          width: 76,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.caption.copyWith(
                    fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddChildCard extends StatefulWidget {
  final VoidCallback onTap;
  const _AddChildCard({required this.onTap});

  @override
  State<_AddChildCard> createState() => _AddChildCardState();
}

class _AddChildCardState extends State<_AddChildCard> {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        hoverColor: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          constraints: const BoxConstraints(minHeight: 240),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                    color: AppTheme.primary, shape: BoxShape.circle),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(height: AppTheme.md),
              Text('Add New Child',
                  style: AppTheme.body.copyWith(
                      fontWeight: FontWeight.w800, color: AppTheme.primary)),
              const SizedBox(height: 2),
              Text('Create a new child profile',
                  style: AppTheme.caption.copyWith(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String value;
  const _SettingRow({this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 15, color: AppTheme.primary),
          ),
          const SizedBox(width: AppTheme.sm),
        ],
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

/// One boxed safety fact in the Settings > Safety card: icon, short title
/// plus description, and a trailing "verified" checkmark badge.
class _SafetyItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  const _SafetyItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: AppTheme.primary),
          ),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.body.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppTheme.xs),
                Text(description, style: AppTheme.caption),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.sm),
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: AppTheme.success,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                size: 14, color: AppTheme.surface),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int n;
  final String text;
  final IconData? trailingIcon;
  const _Step({required this.n, required this.text, this.trailingIcon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
                color: AppTheme.primaryLight, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('$n',
                style: AppTheme.caption.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                    fontSize: 11)),
          ),
          const SizedBox(width: AppTheme.sm),
          Expanded(child: Text(text, style: AppTheme.caption)),
          if (trailingIcon != null) ...[
            const SizedBox(width: AppTheme.sm),
            Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                  color: AppTheme.primaryLight, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(trailingIcon, size: 14, color: AppTheme.primary),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small decorative dot grid used to flank the family code display.
class _DotCluster extends StatelessWidget {
  const _DotCluster();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (_) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              3,
              (_) => Container(
                width: 3,
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final int value;
  final int max;
  final Color color;
  final String tooltip;

  const _Bar({
    required this.value,
    required this.max,
    required this.color,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    // 3px floor so a zero-activity day still reads as a bar rather than a
    // gap — the same convention the day-by-day report chart uses.
    final height = max <= 0 ? 3.0 : 3 + (value / max) * 55;
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 6,
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: value == 0 ? color.withValues(alpha: 0.25) : color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}
