import 'package:flutter/material.dart';

import '../adventure_config.dart';
import '../theme/app_theme.dart';

/// A compact Adventure preview for the home dashboard.
///
/// Deliberately not the whole map: it shows only what the home summary already
/// knows — the area currently growing, its progress and the child's keys — and
/// a single "Open Adventure Map" action that hands off to the real screen. The
/// row of area stops underneath is a visual teaser of the route (drawn from the
/// static [kAreaThemes]), not live per-area status; the full locked/unlocked
/// state lives on the map screen, which stays the one source of truth for it.
class ChildAdventurePanel extends StatelessWidget {
  final String? currentAreaId;
  final String currentAreaName;
  final int progressPercentage;
  final int keys;
  final int maxKeys;
  final VoidCallback onOpenMap;

  const ChildAdventurePanel({
    super.key,
    required this.currentAreaId,
    required this.currentAreaName,
    required this.progressPercentage,
    required this.keys,
    required this.maxKeys,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = areaThemeById(currentAreaId);

    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: const [
          BoxShadow(
              color: AppTheme.shadowColor, blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.map_rounded, size: 20, color: AppTheme.primary),
              const SizedBox(width: AppTheme.sm),
              Expanded(
                child: Text(
                  'Adventure Map',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.subheading.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Explore, learn and unlock new places!',
            style: AppTheme.caption,
          ),
          const SizedBox(height: AppTheme.lg),

          // The one area the child can affect right now, given the loud ring.
          Container(
            padding: const EdgeInsets.all(AppTheme.md),
            decoration: BoxDecoration(
              color: theme.tint,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: theme.accent, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: theme.accent.withValues(alpha: 0.4), width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(theme.emoji, style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: AppTheme.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentAreaName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: (progressPercentage / 100).clamp(0.0, 1.0),
                                minHeight: 7,
                                backgroundColor:
                                    theme.accent.withValues(alpha: 0.18),
                                color: theme.accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$progressPercentage%',
                            style: AppTheme.caption.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.md),

          // Keys toward the next area.
          Row(
            children: [
              const Icon(Icons.vpn_key_rounded,
                  size: 16, color: AppTheme.treasure),
              const SizedBox(width: 6),
              Text(
                '$keys / $maxKeys keys',
                style: AppTheme.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.md),

          // A quiet teaser of the whole route. Current stop is highlighted; the
          // rest are dimmed and carry no status claim — that's the map's job.
          _RouteTrail(currentAreaId: currentAreaId),
          const SizedBox(height: AppTheme.lg),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onOpenMap,
              icon: const Icon(Icons.explore_rounded, size: 18),
              label: const Text('Open Adventure Map'),
              style: AppTheme.primaryButton,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteTrail extends StatelessWidget {
  final String? currentAreaId;
  const _RouteTrail({required this.currentAreaId});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Adventure route preview',
      child: Wrap(
        spacing: AppTheme.sm,
        runSpacing: AppTheme.sm,
        children: [
          for (final area in kAreaThemes)
            _TrailStop(
              theme: area,
              isCurrent: area.areaId == currentAreaId,
            ),
        ],
      ),
    );
  }
}

class _TrailStop extends StatelessWidget {
  final AreaTheme theme;
  final bool isCurrent;

  const _TrailStop({required this.theme, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: theme.name,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isCurrent ? theme.tint : AppTheme.background,
          shape: BoxShape.circle,
          border: Border.all(
            color: isCurrent
                ? theme.accent
                : AppTheme.textLight.withValues(alpha: 0.25),
            width: isCurrent ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Opacity(
          opacity: isCurrent ? 1 : 0.55,
          child: Text(theme.emoji, style: const TextStyle(fontSize: 18)),
        ),
      ),
    );
  }
}
