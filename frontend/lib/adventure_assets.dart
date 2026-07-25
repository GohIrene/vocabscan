/// Asset paths for the flat-vector Adventure art (see `assets/adventure/**`,
/// `assets/icons/*.svg`, `assets/learning/*.svg`).
///
/// This is the *art* companion to [adventure_config.dart]: same area ids, same
/// order, but pointing at layered SVG decorations instead of emoji. It lets a
/// screen replace the emoji `_AreaScene` with real art without changing any of
/// the numbers — progress, `visual_stage`, keys and status still come from the
/// backend (`backend/adventure.py`), and this file only says which picture goes
/// with each of them.
///
/// Rendering these needs the `flutter_svg` package:
///   `flutter pub add flutter_svg`  then  `SvgPicture.asset(theme.iconAsset)`.
///
/// Growth model (mirrors `adventure.py`): an area's `visual_stage` is 0–5.
/// [decorationsForStage] returns the decorations earned so far, so the scene
/// fills in as a child learns — exactly like [AreaTheme.decorationsForStage],
/// but with SVG assets instead of emoji. Alternatively, [stageAssets] holds a
/// pre-composited full scene per stage if you prefer one image over a Stack.
///
/// Only Home Village has full art today — it is the one the reference board
/// detailed. The other five areas carry a map [iconAsset] only; their
/// backgrounds/decorations are left empty (TODO) so callers can fall back to
/// the emoji [AreaTheme] until that art exists.
library;

class AdventureAssetTheme {
  final String areaId;

  /// Circular map/list icon. Always present.
  final String iconAsset;

  /// Base scene (sky, ground, the area's fixed building), or null if not drawn
  /// yet — layer [decorationsForStage] on top of this in a Stack.
  final String? backgroundAsset;

  /// Every decoration for the area, in unlock order. Layer them bottom-to-top.
  final List<String> decorationAssets;

  /// Pre-composited full scene per visual stage (index 0–5), or empty to use
  /// [backgroundAsset] + [decorationsForStage] instead.
  final List<String> stageAssets;

  /// How many of [decorationAssets] are visible at each visual stage (index
  /// 0–5). Lets a single stage reveal more than one decoration at once — e.g.
  /// Home Village adds bench *and* lamp together at stage 3.
  final List<int> stageDecorationCounts;

  const AdventureAssetTheme({
    required this.areaId,
    required this.iconAsset,
    this.backgroundAsset,
    this.decorationAssets = const [],
    this.stageAssets = const [],
    this.stageDecorationCounts = const [0, 0, 0, 0, 0, 0],
  });

  /// The decoration assets earned at [visualStage] (0–5), in draw order.
  List<String> decorationsForStage(int visualStage) {
    if (decorationAssets.isEmpty || stageDecorationCounts.isEmpty) return const [];
    final s = visualStage.clamp(0, stageDecorationCounts.length - 1);
    final count = stageDecorationCounts[s].clamp(0, decorationAssets.length);
    return decorationAssets.take(count).toList();
  }

  /// The pre-composited scene for [visualStage], or null if none was exported.
  String? stageAsset(int visualStage) {
    if (stageAssets.isEmpty) return null;
    return stageAssets[visualStage.clamp(0, stageAssets.length - 1)];
  }
}

const String _adv = 'assets/adventure';

/// Same ids and order as `adventure.py` / [kAreaThemes]. Home Village is fully
/// arted; the rest are icon-only until their art is produced.
const List<AdventureAssetTheme> kAdventureAssetThemes = [
  AdventureAssetTheme(
    areaId: 'home_village',
    iconAsset: '$_adv/home_village/icon.svg',
    backgroundAsset: '$_adv/home_village/background.svg',
    decorationAssets: [
      '$_adv/home_village/decoration_tree.svg',
      '$_adv/home_village/decoration_flowers.svg',
      '$_adv/home_village/decoration_bench.svg',
      '$_adv/home_village/decoration_lamp.svg',
      '$_adv/home_village/decoration_windmill.svg',
      '$_adv/home_village/decoration_fountain.svg',
    ],
    stageAssets: [
      '$_adv/home_village/stage_0.svg',
      '$_adv/home_village/stage_1.svg',
      '$_adv/home_village/stage_2.svg',
      '$_adv/home_village/stage_3.svg',
      '$_adv/home_village/stage_4.svg',
      '$_adv/home_village/stage_5.svg',
    ],
    // stage: 0  1  2  3  4  5   (bench+lamp both arrive at stage 3)
    stageDecorationCounts: [0, 1, 2, 4, 5, 6],
  ),
  // TODO: art pending — icon only. Falls back to the emoji AreaTheme for now.
  AdventureAssetTheme(
    areaId: 'fruit_garden',
    iconAsset: '$_adv/fruit_garden/icon.svg',
  ),
  AdventureAssetTheme(
    areaId: 'animal_forest',
    iconAsset: '$_adv/animal_forest/icon.svg',
  ),
  AdventureAssetTheme(
    areaId: 'cozy_home_corner',
    iconAsset: '$_adv/cozy_home_corner/icon.svg',
  ),
  AdventureAssetTheme(
    areaId: 'vehicle_valley',
    iconAsset: '$_adv/vehicle_valley/icon.svg',
  ),
  AdventureAssetTheme(
    areaId: 'treasure_castle',
    iconAsset: '$_adv/treasure_castle/icon.svg',
  ),
];

/// Art for [areaId], or Home Village if the id is unknown (matches the
/// forgiving fallback in [areaThemeById]).
AdventureAssetTheme adventureAssetById(String? areaId) {
  for (final t in kAdventureAssetThemes) {
    if (t.areaId == areaId) return t;
  }
  return kAdventureAssetThemes.first;
}

/// True when [areaId] has full scene art (background + decorations), so a
/// screen can choose between the SVG scene and the emoji fallback.
bool hasSceneArt(String? areaId) {
  final t = adventureAssetById(areaId);
  return t.backgroundAsset != null && t.decorationAssets.isNotEmpty;
}

/// UI icons used throughout the adventure (XP, keys, treasure, …).
class AdventureIcons {
  static const String xp = 'assets/icons/xp.svg';
  static const String key = 'assets/icons/key.svg';
  static const String treasure = 'assets/icons/treasure.svg';
  static const String sticker = 'assets/icons/sticker.svg';
  static const String current = 'assets/icons/current.svg';
  static const String completed = 'assets/icons/completed.svg';
  static const String locked = 'assets/icons/locked.svg';
}

/// The six Learning Journey step icons (scan → AI → speak → quiz → reward →
/// grow), in flow order.
class LearningIcons {
  static const String scan = 'assets/learning/scan.svg';
  static const String ai = 'assets/learning/ai.svg';
  static const String speech = 'assets/learning/speech.svg';
  static const String quiz = 'assets/learning/quiz.svg';
  static const String reward = 'assets/learning/reward.svg';
  static const String growth = 'assets/learning/growth.svg';

  /// In flow order, for building the journey strip.
  static const List<String> inOrder = [scan, ai, speech, quiz, reward, growth];
}
