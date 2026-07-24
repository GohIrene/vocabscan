import 'package:flutter/material.dart';

import 'theme/app_theme.dart';

/// Look and feel for each adventure area.
///
/// Mirrors the route in `backend/adventure.py` — same ids, same order. The
/// backend owns all the *numbers* (progress, stage, keys, locked/current/
/// completed); this file only says what an area should look like, so the two
/// can't disagree about a child's actual progress.
///
/// Areas are a visual theme and nothing more. Nothing here filters what can
/// be scanned: a child growing Fruit Garden can still scan a chair, a car or
/// a cat, and every one of them counts.
class AreaTheme {
  final String areaId;
  final String name;
  final String emoji;
  final Color accent;
  final Color tint;

  /// One decoration per growth stage. The first `visual_stage` of these are
  /// shown, so the place visibly fills in as a child learns — stage 0 is bare
  /// ground and stage 5 is the finished scene.
  final List<String> decorations;

  const AreaTheme({
    required this.areaId,
    required this.name,
    required this.emoji,
    required this.accent,
    required this.tint,
    required this.decorations,
  });

  /// The decorations earned at [visualStage] (0-5).
  List<String> decorationsForStage(int visualStage) =>
      decorations.take(visualStage.clamp(0, decorations.length)).toList();
}

const List<AreaTheme> kAreaThemes = [
  AreaTheme(
    areaId: 'home_village',
    name: 'Home Village',
    emoji: '🏡',
    accent: AppTheme.success,
    tint: AppTheme.successLight,
    decorations: ['🌱', '🌿', '🌷', '🌳', '🏠'],
  ),
  AreaTheme(
    areaId: 'fruit_garden',
    name: 'Fruit Garden',
    emoji: '🍎',
    accent: AppTheme.blossom,
    tint: Color(0xFFFFE7F1),
    decorations: ['🌱', '🌿', '🌸', '🍏', '🍎'],
  ),
  AreaTheme(
    areaId: 'animal_forest',
    name: 'Animal Forest',
    emoji: '🦊',
    accent: Color(0xFF2FA98C),
    tint: Color(0xFFDDF5EE),
    decorations: ['🌱', '🌿', '🦋', '🐿️', '🦊'],
  ),
  AreaTheme(
    areaId: 'home_corner',
    name: 'Cozy Home Corner',
    emoji: '🛋️',
    accent: AppTheme.adventure,
    tint: AppTheme.adventureLight,
    decorations: ['🪴', '🛋️', '🖼️', '📚', '🛏️'],
  ),
  AreaTheme(
    areaId: 'vehicle_valley',
    name: 'Vehicle Valley',
    emoji: '🚗',
    accent: AppTheme.secondary,
    tint: AppTheme.secondaryLight,
    decorations: ['🛣️', '🚲', '🚗', '🚌', '🚂'],
  ),
  AreaTheme(
    areaId: 'treasure_castle',
    name: 'Treasure Castle',
    emoji: '🏰',
    accent: AppTheme.primary,
    tint: AppTheme.primaryLight,
    decorations: ['🧱', '🚪', '🗝️', '👑', '🏰'],
  ),
];

/// Falls back to the first area rather than null, so an id the client doesn't
/// recognise (an area added server-side ahead of a client release) still
/// renders something sensible instead of crashing the map.
AreaTheme areaThemeById(String? areaId) {
  for (final theme in kAreaThemes) {
    if (theme.areaId == areaId) return theme;
  }
  return kAreaThemes.first;
}
