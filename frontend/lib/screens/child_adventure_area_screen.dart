import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../adventure_config.dart';
import '../adventure_assets.dart';
import '../api_service.dart';
import '../learning_flow.dart';
import '../theme/app_theme.dart';
import '../widgets/adventure_art.dart';
import 'scan_object_screen.dart';

/// One adventure area up close: how far it has grown, the keys it has earned,
/// and — only when it's the area currently growing — a way to go and grow it.
///
/// Three states, all decided by the backend rather than here:
///   * current   — growable, shows the scan action
///   * completed — revisitable, celebratory, no scan action
///   * locked    — previewable only, shows what unlocks it
///
/// Scanning is never restricted by area. The scan action is just a shortcut
/// into the normal flow; every recognised object counts wherever the child is.
class ChildAdventureAreaScreen extends StatefulWidget {
  final String childId;
  final String areaId;

  const ChildAdventureAreaScreen({
    super.key,
    required this.childId,
    required this.areaId,
  });

  @override
  State<ChildAdventureAreaScreen> createState() =>
      _ChildAdventureAreaScreenState();
}

class _ChildAdventureAreaScreenState extends State<ChildAdventureAreaScreen> {
  Map<String, dynamic>? _area;
  String? _unlockedBy;

  /// Carried into a learning cycle so the speaking step can name the buddy.
  String? _avatarId;

  /// Child-wide totals for the stat header (XP, keys, treasures).
  int _totalXp = 0;
  int _totalKeys = 0;
  int _maxTotalKeys = 0;
  int _treasureCount = 0;

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
      final data = await ApiService.getChildAdventure(widget.childId);
      if (!mounted) return;

      final areas = (data['areas'] as List? ?? const [])
          .whereType<Map>()
          .map((a) => Map<String, dynamic>.from(a))
          .toList();
      final index = areas.indexWhere((a) => a['area_id'] == widget.areaId);

      setState(() {
        _avatarId = ((data['avatar'] as Map?)?['avatar_id']) as String?;
        _totalXp = (data['total_xp'] as num?)?.toInt() ?? 0;
        _totalKeys = (data['total_keys'] as num?)?.toInt() ?? 0;
        _maxTotalKeys = (data['max_total_keys'] as num?)?.toInt() ?? 0;
        _treasureCount = (data['treasure_count'] as num?)?.toInt() ?? 0;
        _area = index >= 0 ? areas[index] : null;
        // For a locked area, name the place that has to be finished first —
        // "locked" on its own tells a child nothing actionable.
        _unlockedBy = index > 0
            ? areaThemeById(areas[index - 1]['area_id'] as String?).name
            : null;
        _error = _area == null ? 'That place is not on the map' : null;
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

  void _goScan() {
    // Same guided cycle as ChildHome, anchored on this screen instead, so
    // finishing a word returns the child to the area they were growing.
    final cycle = LearningCycle(
      childId: widget.childId,
      mode: LearningFlowMode.childAdventure,
      completionAnchor: ModalRoute.of(context),
      avatarId: _avatarId,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanObjectScreen(
          childId: widget.childId,
          flowMode: LearningFlowMode.childAdventure,
          cycle: cycle,
        ),
      ),
    ).then((_) {
      if (mounted) _load();
    });
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
                  label: const Text('Back to Map'),
                  style: AppTheme.backButtonStyle,
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : (_error != null || _area == null)
                      ? _buildError()
                      : _buildArea(),
            ),
          ],
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
            const Text('🧭', style: TextStyle(fontSize: 52)),
            const SizedBox(height: AppTheme.lg),
            Text("We couldn't open this place",
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

  Widget _buildArea() {
    final area = _area!;
    final areaId = area['area_id'] as String?;
    final theme = areaThemeById(areaId);
    final status = area['status'] as String? ?? 'locked';
    final progress = (area['progress_percentage'] as num?)?.toInt() ?? 0;
    final stage = (area['visual_stage'] as num?)?.toInt() ?? 0;
    final keys = (area['keys'] as num?)?.toInt() ?? 0;
    final maxKeys = (area['max_keys'] as num?)?.toInt() ?? 5;
    final canGrow = area['can_grow'] == true;
    final isLocked = status == 'locked';
    final isCompleted = status == 'completed';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.xl, 0, AppTheme.xl, AppTheme.xxl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Child-wide totals, echoing the reference board's top strip.
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppTheme.sm,
                runSpacing: AppTheme.sm,
                children: [
                  _StatChip(
                    asset: AdventureIcons.xp,
                    label: '$_totalXp XP',
                    tint: AppTheme.treasure,
                  ),
                  _StatChip(
                    asset: AdventureIcons.key,
                    label: '$_totalKeys / $_maxTotalKeys Keys',
                    tint: AppTheme.warning,
                  ),
                  _StatChip(
                    asset: AdventureIcons.treasure,
                    label: '$_treasureCount Treasures',
                    tint: AppTheme.secondary,
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.xl),

              _AreaHero(
                theme: theme,
                areaId: areaId,
                stage: stage,
                progress: progress,
                locked: isLocked,
                completed: isCompleted,
                unlockedBy: _unlockedBy,
              ),

              // The whole growth path at a glance — the six painted scenes and
              // the percentage each one arrives at, exactly the milestones the
              // backend derives `visual_stage` from. Skipped for an area whose
              // art is still pending: six copies of the same badge would say
              // nothing about growing.
              if (hasSceneArt(areaId)) ...[
                const SizedBox(height: AppTheme.lg),
                _StageFilmstrip(
                  theme: theme,
                  areaId: areaId,
                  stage: stage,
                  locked: isLocked,
                ),
              ],
              const SizedBox(height: AppTheme.xl),

              if (!isLocked) ...[
                _ProgressPanel(
                  theme: theme,
                  progress: progress,
                  stage: stage,
                  keys: keys,
                  maxKeys: maxKeys,
                ),
                const SizedBox(height: AppTheme.xl),
              ],

              if (canGrow)
                FilledButton.icon(
                  onPressed: _goScan,
                  icon: const Icon(Icons.photo_camera_rounded, size: 20),
                  label: const Text('Scan to Grow This Place'),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(58),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    textStyle: AppTheme.buttonText.copyWith(fontSize: 17),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(AppTheme.lg),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppTheme.successLight
                        : AppTheme.warningLight,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        isCompleted
                            ? AdventureIcons.completed
                            : AdventureIcons.locked,
                        width: 26,
                        height: 26,
                      ),
                      const SizedBox(width: AppTheme.md),
                      Expanded(
                        child: Text(
                          isCompleted
                              ? 'This place is all grown. Your buddy is '
                                  'busy growing somewhere new!'
                              : 'You can look around, but you cannot grow '
                                  'this place yet.',
                          style: AppTheme.caption
                              .copyWith(color: AppTheme.textDark),
                        ),
                      ),
                    ],
                  ),
                ),

              // Scanning is never restricted by area — spelled out so the
              // rule is visible to the child, not just to the code.
              if (canGrow) ...[
                const SizedBox(height: AppTheme.md),
                Text(
                  'Scan anything you like — every object helps this place grow!',
                  textAlign: TextAlign.center,
                  style: AppTheme.caption,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The place itself, painted at exactly the stage the child has grown it to.
///
/// The scene is the screen's centrepiece, so the area's name and its one-line
/// status sit on top of the artwork rather than above it — the same framing the
/// reference boards use. An area whose art is still being produced falls back to
/// its badge on the area's own colours (handled inside [AreaArtwork]), so no
/// area ever renders blank.
class _AreaHero extends StatelessWidget {
  final AreaTheme theme;
  final String? areaId;
  final int stage;
  final int progress;
  final bool locked;
  final bool completed;

  /// The place that has to be finished first, named so "locked" tells a child
  /// something they can act on.
  final String? unlockedBy;

  const _AreaHero({
    required this.theme,
    required this.areaId,
    required this.stage,
    required this.progress,
    required this.locked,
    required this.completed,
    required this.unlockedBy,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = completed
        ? 'You grew this place all the way! 🎉'
        : locked
            ? 'Finish ${unlockedBy ?? 'the place before this'} to unlock it'
            : 'Keep learning words to grow this place';

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final titleSize = (w * 0.075).clamp(22.0, 38.0);

        return ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(
                  color: theme.accent.withValues(alpha: 0.35), width: 2),
            ),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AreaArtwork(
                    areaId: areaId,
                    stage: stage,
                    locked: locked,
                    displayWidth: w,
                  ),
                  // Scrims top and bottom. Without them white text lands on
                  // bright sky or pale grass and stops being readable.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.0, 0.45, 0.72, 1.0],
                        colors: [
                          Color(0x8C000000),
                          Color(0x00000000),
                          Color(0x00000000),
                          Color(0x73000000),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    theme.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.heading.copyWith(
                                      fontSize: titleSize,
                                      height: 1.1,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      shadows: const [
                                        Shadow(
                                            color: Color(0x99000000),
                                            blurRadius: 8,
                                            offset: Offset(0, 2)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.body.copyWith(
                                      color: Colors.white
                                          .withValues(alpha: 0.95),
                                      fontWeight: FontWeight.w600,
                                      shadows: const [
                                        Shadow(
                                            color: Color(0x99000000),
                                            blurRadius: 6,
                                            offset: Offset(0, 1)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppTheme.sm),
                            if (locked)
                              _HeroBadge(
                                child: SvgPicture.asset(
                                    AdventureIcons.locked,
                                    width: 20,
                                    height: 20),
                              )
                            else if (completed)
                              _HeroBadge(
                                child: SvgPicture.asset(
                                    AdventureIcons.completed,
                                    width: 22,
                                    height: 22),
                              ),
                          ],
                        ),
                        const Spacer(),
                        if (!locked)
                          Row(
                            children: [
                              _HeroPill(
                                // 5 growth steps, 0-5, matching MAX_STAGE in
                                // backend/adventure.py.
                                label: 'Stage $stage of '
                                    '${kStageMilestones.length - 1}',
                                accent: theme.accent,
                              ),
                              const SizedBox(width: AppTheme.sm),
                              _HeroPill(
                                label: '$progress% grown',
                                accent: theme.accent,
                                filled: true,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A round, frosted badge for the hero's top-right corner.
class _HeroBadge extends StatelessWidget {
  final Widget child;

  const _HeroBadge({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
              color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}

/// A small label sitting on the artwork — stage and percentage.
class _HeroPill extends StatelessWidget {
  final String label;
  final Color accent;
  final bool filled;

  const _HeroPill({
    required this.label,
    required this.accent,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppTheme.md, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? accent : AppTheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        label,
        style: AppTheme.caption.copyWith(
          fontWeight: FontWeight.w800,
          color: filled ? Colors.white : accent,
        ),
      ),
    );
  }
}

/// The six painted scenes laid out as a growth path, with the percentage each
/// one arrives at.
///
/// The milestones come from [kStageMilestones], which mirrors
/// `PROGRESS_PER_STAGE` in `backend/adventure.py` — the filmstrip reports the
/// server's bands rather than inventing its own. Scenes past the child's stage
/// stay visible but drained of colour, so they read as "coming next" instead of
/// being hidden.
class _StageFilmstrip extends StatelessWidget {
  final AreaTheme theme;
  final String? areaId;
  final int stage;
  final bool locked;

  const _StageFilmstrip({
    required this.theme,
    required this.areaId,
    required this.stage,
    required this.locked,
  });

  @override
  Widget build(BuildContext context) {
    final art = adventureAssetById(areaId);
    final count = art.stageAssets.length;
    if (count == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.eco_rounded, size: 18, color: theme.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'How this place grows',
                  style: AppTheme.body.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.md),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 6.0;
              final itemW =
                  (constraints.maxWidth - gap * (count - 1)) / count;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < count; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    SizedBox(
                      width: itemW,
                      child: _StageThumb(
                        areaId: areaId,
                        index: i,
                        milestone: i < kStageMilestones.length
                            ? kStageMilestones[i]
                            : 100,
                        // A locked area shows the whole path as still to come.
                        reached: !locked && i <= stage,
                        isNow: !locked && i == stage,
                        accent: theme.accent,
                        width: itemW,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StageThumb extends StatelessWidget {
  final String? areaId;
  final int index;
  final int milestone;
  final bool reached;
  final bool isNow;
  final Color accent;
  final double width;

  const _StageThumb({
    required this.areaId,
    required this.index,
    required this.milestone,
    required this.reached,
    required this.isNow,
    required this.accent,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final labelSize = (width * 0.22).clamp(8.0, 12.0);

    return Semantics(
      label: 'Stage $index at $milestone per cent, '
          '${reached ? 'reached' : 'not yet reached'}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isNow
                      ? accent
                      : reached
                          ? accent.withValues(alpha: 0.45)
                          : AppTheme.textLight.withValues(alpha: 0.25),
                  width: isNow ? 2.5 : 1.2,
                ),
                boxShadow: isNow
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.5),
                child: AreaArtwork(
                  areaId: areaId,
                  stage: index,
                  locked: !reached,
                  displayWidth: width,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$milestone%',
            maxLines: 1,
            style: TextStyle(
              fontSize: labelSize,
              fontWeight: FontWeight.w800,
              color: reached ? accent : AppTheme.textLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  final AreaTheme theme;
  final int progress;
  final int stage;
  final int keys;
  final int maxKeys;

  const _ProgressPanel({
    required this.theme,
    required this.progress,
    required this.stage,
    required this.keys,
    required this.maxKeys,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Growth',
                    style:
                        AppTheme.body.copyWith(fontWeight: FontWeight.w800)),
              ),
              Text(
                '$progress%',
                style: AppTheme.subheading.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress / 100,
              minHeight: 12,
              backgroundColor: theme.accent.withValues(alpha: 0.15),
              color: theme.accent,
            ),
          ),
          const SizedBox(height: AppTheme.lg),
          Row(
            children: [
              Expanded(
                child: Text('Keys earned',
                    style:
                        AppTheme.body.copyWith(fontWeight: FontWeight.w800)),
              ),
              Text('$keys / $maxKeys',
                  style: AppTheme.caption.copyWith(
                      fontWeight: FontWeight.w700, color: AppTheme.textDark)),
            ],
          ),
          const SizedBox(height: AppTheme.sm),
          Row(
            children: [
              for (var i = 0; i < maxKeys; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Opacity(
                    opacity: i < keys ? 1 : 0.22,
                    child: SvgPicture.asset(AdventureIcons.key,
                        width: 24, height: 24),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.sm),
          Text(
            // Says plainly that keys are a view of progress, not a currency
            // to be spent — otherwise a child waits for a "use keys" button.
            'You earn a key every time this place grows a little more.',
            style: AppTheme.caption,
          ),
        ],
      ),
    );
  }
}

/// A rounded pill with a cute flat-vector icon and a value, for the child-wide
/// totals strip at the top of the area screen.
class _StatChip extends StatelessWidget {
  final String asset;
  final String label;
  final Color tint;

  const _StatChip({
    required this.asset,
    required this.label,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.md, vertical: AppTheme.sm),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: tint.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(asset, width: 18, height: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTheme.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
