import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Badge metadata, mirroring `progress.BADGES` on the backend.
///
/// The server sends full badge objects when one is newly earned, but a roster
/// carries only ids — so the labels live here too, keyed by the same ids.
const Map<String, ({String label, String emoji})> kBadges = {
  'first_steps': (label: 'First Steps', emoji: '🌱'),
  'word_hunter': (label: 'Word Hunter', emoji: '🔎'),
  'champion': (label: 'Champion', emoji: '🏆'),
  'explorer': (label: 'Explorer', emoji: '🧭'),
  'word_wizard': (label: 'Word Wizard', emoji: '🪄'),
  'unstoppable': (label: 'Unstoppable', emoji: '🚀'),
};

/// Level number plus a progress bar toward the next level.
class LevelBar extends StatelessWidget {
  final int level;
  final int xpIntoLevel;
  final int xpPerLevel;

  /// Compact form for headers; the full form adds the "N / M XP" caption.
  final bool compact;

  const LevelBar({
    super.key,
    required this.level,
    required this.xpIntoLevel,
    required this.xpPerLevel,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final fraction =
        xpPerLevel <= 0 ? 0.0 : (xpIntoLevel / xpPerLevel).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.treasure,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Text(
                'Level $level',
                style: AppTheme.caption.copyWith(
                  color: AppTheme.textDark,
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 12 : 13,
                ),
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: AppTheme.sm),
              Text('$xpIntoLevel / $xpPerLevel XP', style: AppTheme.caption),
            ],
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.sm),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: compact ? 7 : 10,
            backgroundColor: AppTheme.primaryLight,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppTheme.adventure),
          ),
        ),
      ],
    );
  }
}

/// The badges a child has earned. Renders nothing when they have none, so an
/// empty strip never sits there looking like a failure.
class BadgeStrip extends StatelessWidget {
  final List<String> badgeIds;
  final double size;

  const BadgeStrip({super.key, required this.badgeIds, this.size = 13});

  @override
  Widget build(BuildContext context) {
    final known = badgeIds.where(kBadges.containsKey).toList();
    if (known.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: known.map((id) {
        final badge = kBadges[id]!;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.warningLight,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Text(
            '${badge.emoji} ${badge.label}',
            style: AppTheme.caption.copyWith(
              fontSize: size,
              color: AppTheme.textDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }
}
