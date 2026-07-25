import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../adventure_assets.dart';
import '../adventure_config.dart';
import '../api_service.dart';
import '../theme/app_theme.dart';
import 'child_adventure_area_screen.dart';

/// The adventure route: every area, in order, with the one currently growing
/// highlighted and the rest either finished or still locked.
///
/// A locked area is deliberately still tappable — a child can look ahead at
/// where they're going, they just can't grow it yet. Growing is gated by the
/// backend's `can_grow`, never by hiding the destination.
class ChildAdventureMapScreen extends StatefulWidget {
  final String childId;

  const ChildAdventureMapScreen({super.key, required this.childId});

  @override
  State<ChildAdventureMapScreen> createState() =>
      _ChildAdventureMapScreenState();
}

class _ChildAdventureMapScreenState extends State<ChildAdventureMapScreen> {
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
      final data = await ApiService.getChildAdventure(widget.childId);
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

  List<Map<String, dynamic>> get _areas =>
      (_data?['areas'] as List? ?? const [])
          .whereType<Map>()
          .map((a) => Map<String, dynamic>.from(a))
          .toList();

  void _openArea(Map<String, dynamic> area) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChildAdventureAreaScreen(
          childId: widget.childId,
          areaId: area['area_id'] as String? ?? '',
        ),
      ),
    ).then((_) {
      // Progress may have moved while the child was inside the area.
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
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildError()
                      : _buildMap(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.md),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Back'),
            style: AppTheme.backButtonStyle,
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
            const Text('🗺️', style: TextStyle(fontSize: 52)),
            const SizedBox(height: AppTheme.lg),
            Text("We couldn't open the map",
                style: AppTheme.subheading.copyWith(
                    fontWeight: FontWeight.w700)),
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

  Widget _buildMap() {
    final completed = (_data?['completed_count'] as num?)?.toInt() ?? 0;
    final total = (_data?['area_count'] as num?)?.toInt() ?? 0;
    final keys = (_data?['total_keys'] as num?)?.toInt() ?? 0;
    final maxKeys = (_data?['max_total_keys'] as num?)?.toInt() ?? 0;

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
                'Adventure Map',
                textAlign: TextAlign.center,
                style: AppTheme.heading.copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppTheme.xs),
              Text(
                'Explore, learn and unlock new places!',
                textAlign: TextAlign.center,
                style: AppTheme.body.copyWith(color: AppTheme.textLight),
              ),
              const SizedBox(height: AppTheme.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MapStat(
                      icon: Icons.flag_rounded,
                      label: '$completed / $total places',
                      tint: AppTheme.success),
                  const SizedBox(width: AppTheme.md),
                  _MapStat(
                      icon: Icons.vpn_key_rounded,
                      iconAsset: AdventureIcons.key,
                      label: '$keys / $maxKeys keys',
                      tint: AppTheme.treasure),
                ],
              ),
              const SizedBox(height: AppTheme.xl),
              for (var i = 0; i < _areas.length; i++) ...[
                _AreaRow(
                  area: _areas[i],
                  onTap: () => _openArea(_areas[i]),
                ),
                // Dotted trail between stops, like a path on a real map.
                if (i < _areas.length - 1) const _TrailConnector(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MapStat extends StatelessWidget {
  final IconData icon;

  /// Optional flat-vector icon in place of [icon]; self-coloured.
  final String? iconAsset;
  final String label;
  final Color tint;

  const _MapStat({
    required this.icon,
    this.iconAsset,
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
          if (iconAsset != null)
            SvgPicture.asset(iconAsset!, width: 17, height: 17)
          else
            Icon(icon, size: 15, color: tint),
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

class _TrailConnector extends StatelessWidget {
  const _TrailConnector();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            3,
            (_) => Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.textLight.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One stop on the route. Its appearance is driven entirely by the backend's
/// `status` — completed, current or locked — so the map can never show an
/// area as open when the server would refuse to grow it.
class _AreaRow extends StatefulWidget {
  final Map<String, dynamic> area;
  final VoidCallback onTap;

  const _AreaRow({required this.area, required this.onTap});

  @override
  State<_AreaRow> createState() => _AreaRowState();
}

class _AreaRowState extends State<_AreaRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final area = widget.area;
    final theme = areaThemeById(area['area_id'] as String?);
    final status = area['status'] as String? ?? 'locked';
    final progress = (area['progress_percentage'] as num?)?.toInt() ?? 0;
    final isCurrent = status == 'current';
    final isCompleted = status == 'completed';
    final isLocked = status == 'locked';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(AppTheme.lg),
          transform: _hovering
              ? (Matrix4.identity()..translateByDouble(0.0, -3.0, 0.0, 1.0))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: isLocked ? AppTheme.surface : theme.tint,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            // Only the area actually growing gets the heavy ring, so the
            // child's eye lands on the one place they can affect right now.
            border: Border.all(
              color: isCurrent
                  ? theme.accent
                  : theme.accent.withValues(alpha: isLocked ? 0.18 : 0.35),
              width: isCurrent ? 3 : 1.5,
            ),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: theme.accent.withValues(alpha: 0.3),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Opacity(
                opacity: isLocked ? 0.45 : 1,
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: theme.accent.withValues(alpha: 0.4), width: 2),
                  ),
                  alignment: Alignment.center,
                  // The area's flat-vector badge. Every area has one (unlike the
                  // scene art), so all six rows use it, locked or not.
                  child: SvgPicture.asset(
                    adventureAssetById(area['area_id'] as String?).iconAsset,
                    width: 46,
                    height: 46,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      theme.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.subheading.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isLocked
                            ? AppTheme.textLight
                            : AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isCompleted
                          ? 'Finished! Come back any time'
                          : isCurrent
                              ? 'Growing now'
                              : 'Locked — finish the place before this one',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.caption.copyWith(fontSize: 12),
                    ),
                    if (!isLocked) ...[
                      const SizedBox(height: AppTheme.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress / 100,
                          minHeight: 7,
                          backgroundColor:
                              theme.accent.withValues(alpha: 0.18),
                          color: theme.accent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.md),
              if (isCompleted)
                SvgPicture.asset(AdventureIcons.completed,
                    width: 30, height: 30)
              else if (isLocked)
                SvgPicture.asset(AdventureIcons.locked, width: 26, height: 26)
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.sm, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$progress%',
                    style: AppTheme.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
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
