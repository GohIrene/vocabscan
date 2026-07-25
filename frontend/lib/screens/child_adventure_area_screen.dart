import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../adventure_config.dart';
import '../adventure_assets.dart';
import '../api_service.dart';
import '../learning_flow.dart';
import '../theme/app_theme.dart';
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
    final theme = areaThemeById(area['area_id'] as String?);
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
              Text(
                theme.name,
                textAlign: TextAlign.center,
                style: AppTheme.heading.copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppTheme.xs),
              Text(
                isCompleted
                    ? 'You grew this place all the way! 🎉'
                    : isLocked
                        ? 'Finish ${_unlockedBy ?? 'the place before this'} '
                            'to unlock it'
                        : 'Keep learning words to grow this place',
                textAlign: TextAlign.center,
                style: AppTheme.body.copyWith(color: AppTheme.textLight),
              ),
              const SizedBox(height: AppTheme.lg),

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

              _AreaScene(
                theme: theme,
                areaId: area['area_id'] as String?,
                stage: stage,
                locked: isLocked,
              ),
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

/// The area itself, filling in one decoration per growth stage.
///
/// Two renderings behind one shell: an area with real SVG scene art (currently
/// only Home Village, per [hasSceneArt]) shows the pre-composited stage scene;
/// every other area keeps the emoji fallback, so no area ever renders blank
/// while its art is still pending.
class _AreaScene extends StatelessWidget {
  final AreaTheme theme;
  final String? areaId;
  final int stage;
  final bool locked;

  const _AreaScene({
    required this.theme,
    required this.areaId,
    required this.stage,
    required this.locked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.tint, AppTheme.surface],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: theme.accent.withValues(alpha: 0.3), width: 2),
      ),
      child: hasSceneArt(areaId) ? _buildArtScene() : _buildEmojiScene(),
    );
  }

  /// The SVG scene for an arted area. A locked area shows the bare base scene
  /// dimmed to a silhouette; otherwise the composited stage scene grows in.
  Widget _buildArtScene() {
    final art = adventureAssetById(areaId);
    // Guarded by hasSceneArt, so backgroundAsset is non-null; the stage scene
    // falls back to it defensively.
    final scene = locked
        ? art.backgroundAsset!
        : (art.stageAsset(stage) ?? art.backgroundAsset!);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: locked ? 0.35 : 1,
              child: SvgPicture.asset(
                scene,
                fit: BoxFit.cover,
                alignment: Alignment.bottomCenter,
              ),
            ),
          ),
          if (!locked)
            Positioned(
              left: 0,
              right: 0,
              bottom: AppTheme.sm,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Stage $stage of ${theme.decorations.length}',
                    style: AppTheme.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.accent,
                    ),
                  ),
                ),
              ),
            ),
          if (locked)
            Positioned(
              right: AppTheme.lg,
              top: AppTheme.lg,
              child: SvgPicture.asset(AdventureIcons.locked,
                  width: 28, height: 28),
            ),
        ],
      ),
    );
  }

  /// Emoji fallback for areas whose art hasn't been produced yet.
  Widget _buildEmojiScene() {
    final earned = theme.decorationsForStage(stage);
    final total = theme.decorations.length;

    return Stack(
      children: [
        Center(
          child: Opacity(
            // A locked area is shown as a silhouette: recognisable enough
            // to be worth wanting, not so clear it feels already visited.
            opacity: locked ? 0.25 : 1,
            child: Text(theme.emoji, style: const TextStyle(fontSize: 78)),
          ),
        ),
        if (!locked)
          Positioned(
            left: 0,
            right: 0,
            bottom: AppTheme.lg,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < total; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Opacity(
                          // Not-yet-earned decorations stay faintly visible
                          // so a child can see exactly what's still coming.
                          opacity: i < earned.length ? 1 : 0.2,
                          child: Text(
                            theme.decorations[i],
                            style: TextStyle(
                                fontSize: i < earned.length ? 30 : 24),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppTheme.sm),
                Text(
                  'Stage $stage of $total',
                  style: AppTheme.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.accent,
                  ),
                ),
              ],
            ),
          ),
        if (locked)
          Positioned(
            right: AppTheme.lg,
            top: AppTheme.lg,
            child: SvgPicture.asset(AdventureIcons.locked,
                width: 28, height: 28),
          ),
      ],
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
