import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../adventure_assets.dart';
import '../adventure_config.dart';
import '../theme/app_theme.dart';

/// Shared rendering for the painted Adventure artwork.
///
/// Every screen that shows a place — the map pins, the area hero and filmstrip,
/// the home panel — goes through [AreaArtwork], so a place looks the same
/// wherever it appears and only one widget knows how to fall back when an
/// area's art hasn't been painted yet.
///
/// Nothing here decides *which* stage to draw: callers pass the `visual_stage`
/// the backend already derived. This widget only picks the matching picture.

/// Drains the colour out of a locked place without hiding what it is — a child
/// can still see where they're heading, it just reads as not-yet-theirs.
const ColorFilter kAdventureGreyscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);

class AreaArtwork extends StatelessWidget {
  final String? areaId;

  /// The backend's `visual_stage` (0-5) for this area.
  final int stage;

  /// Draw the finished scene instead of [stage] — for places we want to show as
  /// a destination ("this is Fruit Garden") rather than as this child's progress.
  final bool postcard;

  /// Greyscale + dim, for an area the child hasn't unlocked.
  final bool locked;

  /// Roughly how wide this will be drawn, in logical pixels. The source scenes
  /// are ~1250px square, so decoding them at display size keeps six of them on
  /// screen from costing far more memory than they need to.
  final double displayWidth;

  final BoxFit fit;
  final Alignment alignment;

  const AreaArtwork({
    super.key,
    required this.areaId,
    required this.stage,
    required this.displayWidth,
    this.postcard = false,
    this.locked = false,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final art = adventureAssetById(areaId);
    final scene = postcard ? art.postcardAsset : art.stageAsset(stage);

    if (scene == null) return _buildFallback(context, art);

    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
    final image = Image.asset(
      scene,
      fit: fit,
      alignment: alignment,
      cacheWidth: (displayWidth * dpr).round().clamp(1, 1400),
      // A missing or half-written PNG should cost a placeholder, not a red box
      // in the middle of a child's map.
      errorBuilder: (context, error, stack) => _buildFallback(context, art),
    );

    if (!locked) return image;
    return ColorFiltered(
      colorFilter: kAdventureGreyscale,
      child: Opacity(opacity: 0.75, child: image),
    );
  }

  /// Stands in for an area whose scenes haven't been painted yet: the area's own
  /// colours plus its badge, so it still reads as that place and never as an
  /// error.
  Widget _buildFallback(BuildContext context, AdventureAssetTheme art) {
    final theme = areaThemeById(areaId);
    final badge = art.iconAsset;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: locked
              ? [
                  AppTheme.background,
                  AppTheme.textLight.withValues(alpha: 0.12),
                ]
              : [theme.tint, theme.accent.withValues(alpha: 0.28)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Opacity(
          opacity: locked ? 0.4 : 1,
          child: FractionallySizedBox(
            widthFactor: 0.5,
            heightFactor: 0.5,
            child: badge != null
                ? SvgPicture.asset(badge, fit: BoxFit.contain)
                : FittedBox(
                    fit: BoxFit.contain,
                    child: Text(theme.emoji),
                  ),
          ),
        ),
      ),
    );
  }
}

/// A circular crop of an area's artwork with a ring around it — the shape used
/// for map pins, the home panel's route stops and the current-area badge.
class AreaMedallion extends StatelessWidget {
  final String? areaId;
  final int stage;
  final double size;
  final bool postcard;
  final bool locked;

  /// Ring colour and thickness. A thicker ring is how the one area a child can
  /// actually grow right now is set apart from the rest.
  final Color ringColor;
  final double ringWidth;

  /// Optional glow, used only for the area currently growing.
  final bool glow;

  const AreaMedallion({
    super.key,
    required this.areaId,
    required this.stage,
    required this.size,
    required this.ringColor,
    this.ringWidth = 2,
    this.postcard = false,
    this.locked = false,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.surface,
        border: Border.all(color: ringColor, width: ringWidth),
        boxShadow: [
          if (glow)
            BoxShadow(
              color: ringColor.withValues(alpha: 0.45),
              blurRadius: 16,
              spreadRadius: 1,
            )
          else
            const BoxShadow(
              color: AppTheme.shadowColor,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
        ],
      ),
      child: ClipOval(
        child: AreaArtwork(
          areaId: areaId,
          stage: stage,
          postcard: postcard,
          locked: locked,
          displayWidth: size,
        ),
      ),
    );
  }
}
