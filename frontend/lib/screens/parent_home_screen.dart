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

  /// Hands the device over to the child, in their own mode.
  void _openChildMode(Map<String, dynamic> child) {
    Navigator.push(
      context,
      MaterialPageRoute(
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
              style: AppTheme.smallButton,
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
                      ParentNavItem.activity =>
                        ParentActivityView(parentId: _parentId),
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
              style: AppTheme.primaryButton,
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

        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final cards = [
              _buildTodayCard(today),
              _buildWeekCard(week),
              _buildFamilyCodeCard(compact: true),
            ];
            if (!wide) {
              return Column(
                children: [
                  for (final card in cards) ...[
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
                  Expanded(flex: 3, child: cards[0]),
                  const SizedBox(width: AppTheme.md),
                  Expanded(flex: 4, child: cards[1]),
                  const SizedBox(width: AppTheme.md),
                  Expanded(flex: 4, child: cards[2]),
                ],
              ),
            );
          },
        ),
      ],
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
            style: AppTheme.primaryButton,
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
                        _Pill(label: buddy.displayName, tint: AppTheme.primary),
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
          // Explicit actions, none of which is "start scanning" — a stray tap
          // on the card must never drop a parent into the child's flow.
          Wrap(
            spacing: AppTheme.sm,
            runSpacing: AppTheme.sm,
            children: [
              _CardAction(
                icon: Icons.insights_rounded,
                label: 'Progress',
                onTap: () => _viewProgress(child),
              ),
              _CardAction(
                icon: Icons.map_rounded,
                label: 'Adventure',
                onTap: () => _viewAdventure(child),
              ),
              _CardAction(
                icon: Icons.photo_album_rounded,
                label: 'Album',
                onTap: () => _viewAlbum(child),
              ),
              _CardAction(
                icon: Icons.edit_rounded,
                label: 'Edit',
                onTap: () => _editChild(child),
              ),
              _CardAction(
                icon: Icons.play_circle_rounded,
                label: 'Child Mode',
                primary: true,
                onTap: () => _openChildMode(child),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayCard(Map<String, dynamic> today) {
    return ParentCard(
      title: "Today's Activity",
      icon: Icons.today_rounded,
      iconTint: AppTheme.success,
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
                  label: 'Quiz',
                  value: '${today['quiz_attempts'] ?? 0}',
                ),
              ),
              const SizedBox(width: AppTheme.sm),
              Expanded(
                child: ParentStat(
                  icon: Icons.mic_rounded,
                  tint: AppTheme.blossom,
                  label: 'Speech',
                  value: '${today['speech_attempts'] ?? 0}',
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
    final series = (week['series'] as List? ?? const [])
        .whereType<Map>()
        .map((s) => Map<String, dynamic>.from(s))
        .toList();
    final max = (week['max'] as num?)?.toInt() ?? 0;

    return ParentCard(
      title: 'Scans This Week',
      icon: Icons.show_chart_rounded,
      iconTint: AppTheme.secondary,
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
                                  for (var s = 0; s < series.length; s++)
                                    _Bar(
                                      value: ((series[s]['scans'] as List?)
                                                  ?[d] as num?)
                                              ?.toInt() ??
                                          0,
                                      max: max,
                                      color: _seriesColor(s),
                                      tooltip:
                                          '${series[s]['nickname']} · '
                                          '${((series[s]['scans'] as List?)?[d] as num?)?.toInt() ?? 0} scans',
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
                const SizedBox(height: AppTheme.sm),
                Wrap(
                  spacing: AppTheme.md,
                  runSpacing: 4,
                  children: [
                    for (var s = 0; s < series.length; s++)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: _seriesColor(s),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(series[s]['nickname'] as String? ?? '',
                              style: AppTheme.caption.copyWith(fontSize: 11)),
                        ],
                      ),
                  ],
                ),
              ],
            ),
    );
  }

  static Color _seriesColor(int index) => const [
        AppTheme.primary,
        AppTheme.adventure,
        AppTheme.blossom,
        AppTheme.secondary,
        AppTheme.success,
        AppTheme.treasure,
      ][index % 6];

  Widget _buildFamilyCodeCard({bool compact = false}) {
    final code = _familyCode;
    return ParentCard(
      title: 'Family Access Code',
      icon: Icons.vpn_key_rounded,
      iconTint: AppTheme.treasure,
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
                color: code == null ? AppTheme.textLight : AppTheme.textDark,
              ),
            ),
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
                child: OutlinedButton.icon(
                  onPressed: code == null ? null : _copyCode,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(
                        color: AppTheme.primary.withValues(alpha: 0.35)),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm)),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.sm),
              Expanded(
                child: TextButton.icon(
                  onPressed: _regenerateCode,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Regenerate'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textLight),
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
        else
          ParentCard(
            child: Column(
              children: [
                for (var i = 0; i < _children.length; i++) ...[
                  if (i > 0)
                    Divider(
                        height: AppTheme.lg,
                        color: AppTheme.primary.withValues(alpha: 0.1)),
                  _buildChildRow(_children[i], active: true),
                ],
              ],
            ),
          ),
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
              Text('Age ${child['age'] ?? '—'}', style: AppTheme.caption),
            ],
          ),
        ),
        if (active) ...[
          _RowAction(
              icon: Icons.edit_rounded,
              tooltip: 'Edit',
              onTap: () => _editChild(child)),
          _RowAction(
              icon: Icons.insights_rounded,
              tooltip: 'View progress',
              onTap: () => _viewProgress(child)),
          _RowAction(
            icon: Icons.visibility_off_rounded,
            tooltip: 'Deactivate',
            onTap: () => _setActive(child, false),
          ),
        ] else ...[
          _RowAction(
            icon: Icons.restart_alt_rounded,
            tooltip: 'Reactivate',
            onTap: () => _setActive(child, true),
          ),
          _RowAction(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Delete',
            tint: AppTheme.error,
            onTap: () => _deleteChild(child),
          ),
        ],
      ],
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
                  style: AppTheme.smallButton,
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
                _Step(n: 1, text: 'On the welcome screen, they tap '
                    '"I\'m Learning at Home".'),
                _Step(n: 2, text: 'They type this family code.'),
                _Step(n: 3, text: 'They tap their own buddy to pick their '
                    'profile.'),
                _Step(n: 4, text: 'If you set a child PIN, they type it — '
                    'otherwise they start straight away.'),
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
                _SettingRow(label: 'Username', value: _username),
                const SizedBox(height: AppTheme.sm),
                _SettingRow(label: 'Role', value: 'Parent'),
                const SizedBox(height: AppTheme.sm),
                _SettingRow(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your PIN is asked for before editing, deactivating or '
                  'deleting a child, and before regenerating the family code '
                  '— in case your child is holding the device.',
                  style: AppTheme.caption,
                ),
                const SizedBox(height: AppTheme.md),
                Text(
                  'Camera images are never stored. Only recognition, quiz and '
                  'speech outcomes are recorded.',
                  style: AppTheme.caption,
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

  const ParentActivityView({super.key, required this.parentId});

  @override
  State<ParentActivityView> createState() => _ParentActivityViewState();
}

class _ParentActivityViewState extends State<ParentActivityView> {
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

  static (IconData, Color) _style(String type) => switch (type) {
        'treasure' => (Icons.card_giftcard_rounded, AppTheme.treasure),
        'scan' => (Icons.photo_camera_rounded, AppTheme.success),
        'quiz' => (Icons.quiz_rounded, AppTheme.secondary),
        'speech' => (Icons.mic_rounded, AppTheme.blossom),
        _ => (Icons.circle, AppTheme.textLight),
      };

  @override
  Widget build(BuildContext context) {
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
              style: AppTheme.smallButton,
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

    // Grouped by local day, the same GMT+8 bucketing the report uses.
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final e in _events!) {
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
                          _style(e['type'] as String? ?? '');
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
  final bool primary;

  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: primary ? AppTheme.primary : AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 14,
                  color: primary ? Colors.white : AppTheme.primary),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTheme.caption.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: primary ? Colors.white : AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? tint;

  const _RowAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 19),
      color: tint ?? AppTheme.primary,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
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
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 240),
          decoration: BoxDecoration(
            color: _hovering
                ? AppTheme.primary.withValues(alpha: 0.06)
                : AppTheme.surface,
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
  final String label;
  final String value;
  const _SettingRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
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

class _Step extends StatelessWidget {
  final int n;
  final String text;
  const _Step({required this.n, required this.text});

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
        ],
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
