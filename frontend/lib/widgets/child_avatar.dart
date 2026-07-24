import 'package:flutter/material.dart';

import '../avatar_config.dart';
import '../theme/app_theme.dart';

/// A child's buddy at its current growth stage.
///
/// Used by the add-child wizard, the child profile picker, ChildHomeScreen and
/// the parent dashboard, so a buddy looks the same everywhere it appears.
/// Both the id and the stage are treated as untrusted: an unknown id falls
/// back to the default buddy and an out-of-range stage clamps, because a child
/// document written before avatars existed carries neither.
class ChildAvatar extends StatelessWidget {
  final String? avatarId;

  /// 1-3. Clamped, so 0 or a stage beyond the artwork still renders.
  final int stage;

  final double size;

  /// Draws a small numbered badge showing which stage the buddy has reached.
  final bool showStageBadge;

  /// Greys the buddy out — e.g. a locked or deactivated profile.
  final bool dimmed;

  const ChildAvatar({
    super.key,
    required this.avatarId,
    this.stage = 1,
    this.size = 72,
    this.showStageBadge = false,
    this.dimmed = false,
  });

  /// Stage is signalled by colour as well as by the artwork, so a child can
  /// see their buddy has grown even at sizes where the art reads small.
  static Color stageColor(int stage) {
    if (stage <= 1) return AppTheme.success;
    if (stage == 2) return AppTheme.adventure;
    return AppTheme.treasure;
  }

  @override
  Widget build(BuildContext context) {
    final avatar = avatarByIdOrDefault(avatarId);
    final safeStage = stage.clamp(1, 3);
    final ring = stageColor(safeStage);

    final circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ring.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: size < 48 ? 1.5 : 2.5),
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: EdgeInsets.all(size * 0.06),
        child: Image.asset(
          avatar.assetForStage(safeStage),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Icon(
            Icons.pets_rounded,
            size: size * 0.5,
            color: ring,
          ),
        ),
      ),
    );

    return Opacity(
      opacity: dimmed ? 0.4 : 1,
      child: showStageBadge
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                circle,
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: _StageBadge(stage: safeStage, color: ring),
                ),
              ],
            )
          : circle,
    );
  }
}

class _StageBadge extends StatelessWidget {
  final int stage;
  final Color color;

  const _StageBadge({required this.stage, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.surface, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        '$stage',
        style: AppTheme.caption.copyWith(
          color: AppTheme.surface,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
