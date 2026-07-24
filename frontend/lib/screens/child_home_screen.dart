import 'package:flutter/material.dart';

import '../api_service.dart';
import '../avatar_config.dart';
import '../theme/app_theme.dart';
import '../widgets/child_avatar.dart';
import '../widgets/child_nav_sidebar.dart';
import 'scan_object_screen.dart';

/// Home base for a child in Home Adventure mode.
///
/// Responsive rather than mobile-only: a persistent navigation rail and a
/// two-column body on a desktop browser, collapsing to a drawer and a single
/// column on a narrow one. Everything it draws arrives from one request
/// (`GET /child/home/<child_id>`), so the screen never shows several
/// spinners resolving at different times.
///
/// Nothing parent-facing appears here by design: no reports, no family-code
/// display, no account settings. English is the interface language.
class ChildHomeScreen extends StatefulWidget {
  final String childId;

  /// Known from the profile picker, so the greeting and buddy can render
  /// immediately instead of leaving the screen blank while the summary loads.
  final String nickname;
  final String? avatarId;
  final int avatarStage;

  const ChildHomeScreen({
    super.key,
    required this.childId,
    required this.nickname,
    this.avatarId,
    this.avatarStage = 1,
  });

  @override
  State<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends State<ChildHomeScreen> {
  /// Below this the navigation rail becomes a drawer.
  static const double _wideBreakpoint = 980;

  /// Below this the stat tiles stack instead of sitting side by side.
  static const double _compactBreakpoint = 640;

  /// Destinations whose screens exist. Phase 4 adds the adventure map,
  /// Phase 6 the treasure album; the rest of the sidebar renders as locked.
  static const Set<ChildNavItem> _enabledNav = {ChildNavItem.home};

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getChildHome(widget.childId);
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

  // ── Derived view data ──────────────────────────────────────────────────────

  Map<String, dynamic> _section(String key) =>
      (_data?[key] as Map?)?.cast<String, dynamic>() ?? const {};

  String get _nickname =>
      _section('child')['nickname'] as String? ?? widget.nickname;

  String? get _avatarId =>
      _section('avatar')['avatar_id'] as String? ?? widget.avatarId;

  int get _avatarStage =>
      (_section('avatar')['stage'] as num?)?.toInt() ?? widget.avatarStage;

  String get _buddyName => avatarByIdOrDefault(_avatarId).displayName;

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 18) return 'Good Afternoon';
    return 'Good Evening';
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _startExploring() {
    // Phase 5 threads a LearningFlowMode and this route as the completion
    // anchor, so the guided sequence returns here. Until then it opens the
    // existing scan flow unchanged.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanObjectScreen(childId: widget.childId),
      ),
      // Refresh on return so a word just learned shows up in the mission,
      // streak and treasure counts straight away.
    ).then((_) {
      if (mounted) _load();
    });
  }

  void _onNavSelect(ChildNavItem item) {
    if (!_enabledNav.contains(item)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.label} is coming very soon!')),
      );
      return;
    }
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
  }

  void _exit() {
    // Unwinds the whole child session back to Welcome, so the next child
    // starts from the family code rather than inheriting this one's screen.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= _wideBreakpoint;

    final sidebar = ChildNavSidebar(
      selected: ChildNavItem.home,
      enabled: _enabledNav,
      onSelect: _onNavSelect,
      onExit: _exit,
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.background,
      drawer: isWide ? null : Drawer(child: sidebar),
      body: Row(
        children: [
          if (isWide) sidebar,
          Expanded(
            child: SafeArea(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildError()
                      : _buildContent(isWide, width),
            ),
          ),
        ],
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
            const Text('🙈', style: TextStyle(fontSize: 56)),
            const SizedBox(height: AppTheme.lg),
            Text(
              "We couldn't load your adventure",
              textAlign: TextAlign.center,
              style: AppTheme.subheading.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppTheme.sm),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: AppTheme.caption,
            ),
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

  Widget _buildContent(bool isWide, double width) {
    final compact = width < _compactBreakpoint;

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppTheme.lg : AppTheme.xl,
          vertical: AppTheme.lg,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(isWide),
                const SizedBox(height: AppTheme.lg),
                _buildHero(compact),
                const SizedBox(height: AppTheme.lg),
                _buildStatTiles(width),
                const SizedBox(height: AppTheme.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isWide) {
    return Row(
      children: [
        if (!isWide)
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: const Icon(Icons.menu_rounded),
            tooltip: 'Menu',
            color: AppTheme.textDark,
          ),
        const Spacer(),
        ChildAvatar(avatarId: _avatarId, stage: _avatarStage, size: 40),
        const SizedBox(width: AppTheme.sm),
        Flexible(
          child: Text(
            _nickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.body.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  /// Greeting, the Start Exploring card, the daily mission and the streak.
  Widget _buildHero(bool compact) {
    final scanCard = _StartExploringCard(onTap: _startExploring);
    final missionCard = _DailyMissionCard(mission: _section('daily_mission'));
    final streakCard = _StreakCard(
      days: (_data?['streak_days'] as num?)?.toInt() ?? 0,
    );

    return Container(
      padding: EdgeInsets.all(compact ? AppTheme.lg : AppTheme.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEDE7FF), Color(0xFFE3F1FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_greeting()}, $_nickname! ☀️',
            style: AppTheme.heading.copyWith(
              fontSize: compact ? 24 : 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$_buddyName is ready for a new adventure!',
            style: AppTheme.body.copyWith(color: AppTheme.textLight),
          ),
          const SizedBox(height: AppTheme.lg),
          if (compact) ...[
            Center(
              child:
                  ChildAvatar(avatarId: _avatarId, stage: _avatarStage, size: 96),
            ),
            const SizedBox(height: AppTheme.lg),
            scanCard,
            const SizedBox(height: AppTheme.md),
            missionCard,
            const SizedBox(height: AppTheme.md),
            streakCard,
          ] else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChildAvatar(
                      avatarId: _avatarId, stage: _avatarStage, size: 116),
                  const SizedBox(width: AppTheme.lg),
                  // The scan card gets the most space of anything on screen —
                  // it is the one action this whole page exists to invite.
                  Expanded(flex: 5, child: scanCard),
                  const SizedBox(width: AppTheme.md),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        missionCard,
                        const SizedBox(height: AppTheme.md),
                        streakCard,
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

  Widget _buildStatTiles(double width) {
    final adventure = _section('adventure');
    final avatar = _section('avatar');

    final totalXp = (avatar['total_xp'] as num?)?.toInt() ?? 0;
    final nextXp = (avatar['next_stage_xp'] as num?)?.toInt();
    final keys = (adventure['keys'] as num?)?.toInt() ?? 0;
    final maxKeys = (adventure['max_keys'] as num?)?.toInt() ?? 5;
    final areaProgress =
        (adventure['progress_percentage'] as num?)?.toInt() ?? 0;

    final tiles = <Widget>[
      _StatTile(
        icon: Icons.park_rounded,
        tint: AppTheme.success,
        label: 'Adventure Progress',
        value: adventure['current_area_name'] as String? ?? 'Home Village',
        progress: areaProgress / 100,
        trailing: '$areaProgress%',
      ),
      _StatTile(
        icon: Icons.vpn_key_rounded,
        tint: AppTheme.treasure,
        label: 'My Keys',
        value: '$keys',
        caption: 'of $maxKeys keys',
      ),
      _StatTile(
        icon: Icons.photo_album_rounded,
        tint: AppTheme.secondary,
        label: 'Treasure Album',
        value: '${(_data?['treasure_count'] as num?)?.toInt() ?? 0}',
        caption: 'words collected',
      ),
      _StatTile(
        icon: Icons.pets_rounded,
        tint: AppTheme.primary,
        label: _buddyName,
        value: 'Stage $_avatarStage',
        // Null once fully grown — show a finished bar rather than progress
        // toward a target that doesn't exist.
        progress: nextXp == null || nextXp == 0 ? 1.0 : totalXp / nextXp,
        trailing: nextXp == null ? '$totalXp XP' : '$totalXp / $nextXp',
      ),
      _StatTile(
        icon: Icons.emoji_events_rounded,
        tint: AppTheme.adventure,
        label: 'Achievements',
        value: '${(_data?['achievement_count'] as num?)?.toInt() ?? 0}',
        caption: 'of ${(_data?['achievement_total'] as num?)?.toInt() ?? 0} '
            'unlocked',
      ),
    ];

    // Sized by available width rather than a fixed count, so the row reflows
    // instead of overflowing between the breakpoints.
    final columns = width >= 1080
        ? 5
        : width >= 820
            ? 3
            : width >= _compactBreakpoint
                ? 2
                : 1;
    const spacing = AppTheme.md;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles)
              SizedBox(width: tileWidth.clamp(150.0, 400.0), child: tile),
          ],
        );
      },
    );
  }
}

// ── Hero pieces ──────────────────────────────────────────────────────────────

/// The primary call to action, and deliberately the loudest thing on screen:
/// full-bleed brand colour, the largest icon, and its own shadow.
class _StartExploringCard extends StatefulWidget {
  final VoidCallback onTap;
  const _StartExploringCard({required this.onTap});

  @override
  State<_StartExploringCard> createState() => _StartExploringCardState();
}

class _StartExploringCardState extends State<_StartExploringCard> {
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
          padding: const EdgeInsets.symmetric(
              vertical: AppTheme.xl, horizontal: AppTheme.lg),
          transform: _hovering
              ? (Matrix4.identity()..translateByDouble(0.0, -5.0, 0.0, 1.0))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, Color(0xFF6B4EFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: _hovering ? 0.5 : 0.32),
                blurRadius: _hovering ? 28 : 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(Icons.photo_camera_rounded,
                    size: 40, color: Colors.white),
              ),
              const SizedBox(height: AppTheme.md),
              Text(
                'Start Exploring',
                textAlign: TextAlign.center,
                style: AppTheme.heading.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Scan any object to learn it!',
                textAlign: TextAlign.center,
                style: AppTheme.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyMissionCard extends StatelessWidget {
  final Map<String, dynamic> mission;
  const _DailyMissionCard({required this.mission});

  int _n(String key) => (mission[key] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Learn new words', _n('new_words_completed'), _n('new_words_target')),
      ('Say words out loud', _n('speech_completed'), _n('speech_target')),
      ('Finish quizzes', _n('quiz_completed'), _n('quiz_target')),
    ];

    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: const [
          BoxShadow(color: AppTheme.shadowColor, blurRadius: 12,
              offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded, size: 18, color: AppTheme.error),
              const SizedBox(width: AppTheme.sm),
              Expanded(
                child: Text('Daily Mission',
                    style: AppTheme.body.copyWith(fontWeight: FontWeight.w800)),
              ),
              const Text('🎁', style: TextStyle(fontSize: 18)),
            ],
          ),
          const SizedBox(height: AppTheme.md),
          for (final (label, done, target) in rows) ...[
            Row(
              children: [
                Icon(
                  done >= target && target > 0
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 17,
                  color: done >= target && target > 0
                      ? AppTheme.success
                      : AppTheme.textLight.withValues(alpha: 0.5),
                ),
                const SizedBox(width: AppTheme.sm),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.textDark,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  '$done/$target',
                  style: AppTheme.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
            if (label != rows.last.$1) const SizedBox(height: AppTheme.sm),
          ],
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final int days;
  const _StreakCard({required this.days});

  /// A single week of flames: enough to feel achievable, and it keeps the
  /// row from wrapping once a child gets to a long streak.
  static const int _flames = 7;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.adventureLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.adventure.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 18)),
              const SizedBox(width: AppTheme.sm),
              Expanded(
                child: Text('Scan Streak',
                    style: AppTheme.body.copyWith(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            days == 1 ? 'Day 1' : 'Day $days',
            style: AppTheme.heading.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.adventure,
            ),
          ),
          const SizedBox(height: AppTheme.sm),
          Row(
            children: [
              for (var i = 0; i < _flames; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Opacity(
                    opacity: i < days ? 1 : 0.25,
                    child: const Text('🔥', style: TextStyle(fontSize: 15)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One number from the summary, optionally with a progress bar under it.
class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String label;
  final String value;
  final String? caption;
  final double? progress;
  final String? trailing;

  const _StatTile({
    required this.icon,
    required this.tint,
    required this.label,
    required this.value,
    this.caption,
    this.progress,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: const [
          BoxShadow(color: AppTheme.shadowColor, blurRadius: 12,
              offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: tint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.caption.copyWith(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sm),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.subheading.copyWith(
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(caption!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.caption.copyWith(fontSize: 11)),
          ],
          if (progress != null) ...[
            const SizedBox(height: AppTheme.sm),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress!.clamp(0.0, 1.0),
                      minHeight: 7,
                      backgroundColor: tint.withValues(alpha: 0.15),
                      color: tint,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    trailing!,
                    style: AppTheme.caption.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
