import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../adventure_assets.dart';
import '../adventure_config.dart';
import '../api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/adventure_art.dart';
import 'child_adventure_area_screen.dart';

/// The adventure route, drawn as the painted map itself: every area sits on the
/// island the background painting already gives it, with the one currently
/// growing highlighted and the rest either finished or still locked.
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

    final areas = _areas;
    // The one area the child can act on now, surfaced under the map so the
    // next step is never something they have to hunt for among six pins.
    final current = areas.cast<Map<String, dynamic>?>().firstWhere(
          (a) => a?['status'] == 'current',
          orElse: () => null,
        );

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
              const SizedBox(height: AppTheme.lg),
              _PaintedMap(areas: areas, onOpenArea: _openArea),
              if (current != null) ...[
                const SizedBox(height: AppTheme.lg),
                _CurrentAreaCard(
                  area: current,
                  onTap: () => _openArea(current),
                ),
              ],
              const SizedBox(height: AppTheme.md),
              Text(
                'Tap any place to look around.',
                textAlign: TextAlign.center,
                style: AppTheme.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The map painting with one pin per area, each dropped on the island the
/// painting already draws for it (see `mapX`/`mapY` in [adventure_assets.dart]).
class _PaintedMap extends StatelessWidget {
  final List<Map<String, dynamic>> areas;
  final void Function(Map<String, dynamic>) onOpenArea;

  const _PaintedMap({required this.areas, required this.onOpenArea});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.25), width: 2),
        ),
        child: AspectRatio(
          aspectRatio: AdventureArt.mapAspectRatio,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final mapW = constraints.maxWidth;
              final mapH = constraints.maxHeight;
              // Everything on the map is sized off its width, so the pins keep
              // their proportions on a phone and on a tablet alike. The pin and
              // its name plate together stay inside the painting: at this size
              // the lowest row reaches about 96% of the map's height.
              final pinSize = (mapW * 0.128).clamp(40.0, 76.0);
              final labelSize = (mapW * 0.026).clamp(8.5, 12.5);
              // Wide enough for the longest area name without the neighbouring
              // pins' labels running into each other.
              final slotW = mapW * 0.30;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      AdventureArt.mapBackground,
                      fit: BoxFit.cover,
                      cacheWidth: (mapW *
                              (MediaQuery.maybeOf(context)?.devicePixelRatio ??
                                  1.0))
                          .round()
                          .clamp(1, 1448),
                    ),
                  ),
                  for (final area in areas)
                    _positionedPin(
                      area: area,
                      mapW: mapW,
                      mapH: mapH,
                      slotW: slotW,
                      pinSize: pinSize,
                      labelSize: labelSize,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _positionedPin({
    required Map<String, dynamic> area,
    required double mapW,
    required double mapH,
    required double slotW,
    required double pinSize,
    required double labelSize,
  }) {
    final art = adventureAssetById(area['area_id'] as String?);

    return Positioned(
      left: mapW * art.mapX - slotW / 2,
      top: mapH * art.mapY - pinSize / 2,
      width: slotW,
      child: _MapPin(
        area: area,
        size: pinSize,
        labelSize: labelSize,
        onTap: () => onOpenArea(area),
      ),
    );
  }
}

/// One stop on the route. Its appearance is driven entirely by the backend's
/// `status` — completed, current or locked — so the map can never show an area
/// as open when the server would refuse to grow it.
class _MapPin extends StatefulWidget {
  final Map<String, dynamic> area;
  final double size;
  final double labelSize;
  final VoidCallback onTap;

  const _MapPin({
    required this.area,
    required this.size,
    required this.labelSize,
    required this.onTap,
  });

  @override
  State<_MapPin> createState() => _MapPinState();
}

class _MapPinState extends State<_MapPin> with SingleTickerProviderStateMixin {
  AnimationController? _pulse;
  bool _hovering = false;

  bool get _isCurrent => widget.area['status'] == 'current';

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _MapPin old) {
    super.didUpdateWidget(old);
    _syncPulse();
  }

  /// Only the area a child can actually grow gets a heartbeat, so the animation
  /// points at the one thing they can do rather than decorating the whole map.
  void _syncPulse() {
    if (_isCurrent && _pulse == null) {
      _pulse = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1600),
      )..repeat();
    } else if (!_isCurrent && _pulse != null) {
      _pulse!.dispose();
      _pulse = null;
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final area = widget.area;
    final theme = areaThemeById(area['area_id'] as String?);
    final status = area['status'] as String? ?? 'locked';
    final progress = (area['progress_percentage'] as num?)?.toInt() ?? 0;
    final stage = (area['visual_stage'] as num?)?.toInt() ?? 0;
    final isCurrent = status == 'current';
    final isCompleted = status == 'completed';
    final isLocked = status == 'locked';

    final ringColor = isCompleted
        ? AppTheme.success
        : isCurrent
            ? theme.accent
            : AppTheme.textLight;

    return Semantics(
      button: true,
      label: '${theme.name}, '
          '${isCompleted ? 'finished' : isLocked ? 'locked' : '$progress per cent grown'}',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: _hovering ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 160),
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      if (_pulse != null)
                        _PulseHalo(controller: _pulse!, color: theme.accent),
                      // The place itself, grown exactly as far as the backend
                      // says — a child sees their own village on the map.
                      AreaMedallion(
                        areaId: area['area_id'] as String?,
                        stage: stage,
                        size: widget.size,
                        locked: isLocked,
                        glow: isCurrent,
                        ringColor: ringColor,
                        ringWidth: isCurrent ? 3.5 : 2.5,
                      ),
                      if (isCurrent)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _ProgressRingPainter(
                              progress: progress / 100,
                              color: theme.accent,
                              width: widget.size * 0.075,
                            ),
                          ),
                        ),
                      if (isLocked)
                        Container(
                          width: widget.size * 0.42,
                          height: widget.size * 0.42,
                          decoration: BoxDecoration(
                            color: AppTheme.surface.withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                          ),
                          padding: EdgeInsets.all(widget.size * 0.08),
                          child: SvgPicture.asset(AdventureIcons.locked),
                        ),
                      if (isCompleted)
                        Positioned(
                          right: -widget.size * 0.04,
                          bottom: -widget.size * 0.04,
                          child: SvgPicture.asset(
                            AdventureIcons.completed,
                            width: widget.size * 0.36,
                            height: widget.size * 0.36,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: widget.size * 0.09),
              // Name only. The percentage is already on the ring around the pin
              // and spelled out on the card below the map, and a second line
              // here would push the lowest pins off the bottom of the painting.
              _PinLabel(
                name: theme.name,
                fontSize: widget.labelSize,
                accent: ringColor,
                highlight: isCurrent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The name plate under a pin. Kept opaque rather than tinted so it stays
/// readable over grass, water and stone alike.
class _PinLabel extends StatelessWidget {
  final String name;
  final double fontSize;
  final Color accent;
  final bool highlight;

  const _PinLabel({
    required this.name,
    required this.fontSize,
    required this.accent,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: fontSize * 0.55, vertical: fontSize * 0.22),
      decoration: BoxDecoration(
        color: highlight ? accent : AppTheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: highlight ? accent : accent.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
              color: AppTheme.shadowColor, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          height: 1.15,
          color: highlight ? Colors.white : AppTheme.textDark,
        ),
      ),
    );
  }
}

/// The slow ring that breathes out from the area currently growing.
class _PulseHalo extends StatelessWidget {
  final AnimationController controller;
  final Color color;

  const _PulseHalo({required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        return Transform.scale(
          scale: 1 + t * 0.5,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: (1 - t) * 0.55),
                width: 3,
              ),
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

/// The arc around a growing pin. Draws the backend's percentage and nothing
/// else — no easing, no rounding — so the ring and the number always agree.
class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double width;

  const _ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.width,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawArc(
      rect.deflate(width / 2),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) =>
      old.progress != progress || old.color != color || old.width != width;
}

/// The area currently growing, restated under the map as the obvious next step.
class _CurrentAreaCard extends StatelessWidget {
  final Map<String, dynamic> area;
  final VoidCallback onTap;

  const _CurrentAreaCard({required this.area, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = areaThemeById(area['area_id'] as String?);
    final progress = (area['progress_percentage'] as num?)?.toInt() ?? 0;
    final stage = (area['visual_stage'] as num?)?.toInt() ?? 0;
    final keys = (area['keys'] as num?)?.toInt() ?? 0;
    final maxKeys = (area['max_keys'] as num?)?.toInt() ?? 5;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.lg),
        decoration: BoxDecoration(
          color: theme.tint,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: theme.accent, width: 2),
          boxShadow: [
            BoxShadow(
              color: theme.accent.withValues(alpha: 0.22),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            AreaMedallion(
              areaId: area['area_id'] as String?,
              stage: stage,
              size: 60,
              ringColor: theme.accent,
              ringWidth: 2.5,
            ),
            const SizedBox(width: AppTheme.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Growing now',
                    style: AppTheme.caption.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.accent,
                      letterSpacing: 0.4,
                    ),
                  ),
                  Text(
                    theme.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.subheading.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppTheme.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress / 100,
                      minHeight: 8,
                      backgroundColor: theme.accent.withValues(alpha: 0.2),
                      color: theme.accent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      SvgPicture.asset(AdventureIcons.key,
                          width: 15, height: 15),
                      const SizedBox(width: 5),
                      Text(
                        '$keys / $maxKeys keys  ·  $progress%',
                        style: AppTheme.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.accent, size: 26),
          ],
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
