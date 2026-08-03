/// Asset paths for the painted Adventure artwork (see `assets/adventure/**`,
/// `assets/icons/*.svg`, `assets/learning/*.svg`).
///
/// This is the *art* companion to [adventure_config.dart]: same area ids, same
/// order, but pointing at the painted scenes instead of emoji. It lets a screen
/// render real art without changing any of the numbers — progress,
/// `visual_stage`, keys and status still come from the backend
/// (`backend/adventure.py`), and this file only says which picture goes with
/// each of them.
///
/// Growth model (mirrors `adventure.py`): an area's `visual_stage` is 0-5, one
/// step per 20 points of progress. [AdventureAssetTheme.stageAssets] holds one
/// painted scene per stage, so index 0 is the bare starting scene and index 5
/// the finished one — the place visibly fills in as a child learns.
///
/// Every area except Animal Forest is fully painted. Animal Forest has no stage
/// art yet ([AdventureAssetTheme.hasArt] is false for it), so callers fall back
/// to its [AdventureAssetTheme.iconAsset] badge until the scenes are dropped in.
library;

class AdventureAssetTheme {
  /// Must match `AREAS` in `backend/adventure.py` — note the fourth area is
  /// `home_corner`, not `cozy_home_corner` (that is only the folder name).
  final String areaId;

  /// Circular badge, used only where no painted scene exists. Null once an area
  /// is fully painted: its own artwork makes a better icon than a flat badge.
  final String? iconAsset;

  /// One painted scene per `visual_stage`, index 0-5. Empty while an area's art
  /// is still being produced.
  final List<String> stageAssets;

  /// Where this area sits on [AdventureArt.mapBackground], as a fraction of the
  /// map's width and height. These match the spot the background painting
  /// already draws for the area, so a pin lands on its own island.
  final double mapX;
  final double mapY;

  const AdventureAssetTheme({
    required this.areaId,
    required this.mapX,
    required this.mapY,
    this.iconAsset,
    this.stageAssets = const [],
  });

  /// True once painted scenes exist for this area.
  bool get hasArt => stageAssets.isNotEmpty;

  /// The painted scene for [visualStage], or null while the art is pending.
  String? stageAsset(int visualStage) {
    if (stageAssets.isEmpty) return null;
    return stageAssets[visualStage.clamp(0, stageAssets.length - 1)];
  }

  /// The finished scene — the "postcard" of the place. Used where we want to
  /// show what an area *is* rather than how far this child has grown it.
  String? get postcardAsset => stageAssets.isEmpty ? null : stageAssets.last;
}

const String _adv = 'assets/adventure';

/// Art that belongs to the adventure as a whole rather than to one area.
class AdventureArt {
  /// The painted route every area sits on. Its six illustrated spots are in the
  /// same order as [kAdventureAssetThemes], which is what the `mapX`/`mapY`
  /// fractions below are measured against.
  static const String mapBackground =
      '$_adv/map/AdventureMap_BackgroundPicture.png';

  /// The map painting's own aspect ratio (1448 x 1086), so it is never squashed.
  static const double mapAspectRatio = 1448 / 1086;
}

/// The progress percentage each `visual_stage` starts at, mirroring
/// `PROGRESS_PER_STAGE` in `backend/adventure.py`. Labels a stage filmstrip
/// without inventing thresholds of its own.
const List<int> kStageMilestones = [0, 20, 40, 60, 80, 100];

/// The `visual_stage` a 0-100 progress value falls in — the same fixed bands as
/// `visual_stage()` in `backend/adventure.py`.
///
/// For display only, where a screen has a percentage but not the stage the
/// server already derived from it. Prefer the server's `visual_stage` whenever
/// the response carries one.
int visualStageForProgress(int progress) =>
    (progress.clamp(0, 100) ~/ 20).clamp(0, kStageMilestones.length - 1);

/// Same ids and order as `adventure.py` / [kAreaThemes].
const List<AdventureAssetTheme> kAdventureAssetThemes = [
  AdventureAssetTheme(
    areaId: 'home_village',
    // Top-left cottage island on the map painting.
    mapX: 0.155,
    mapY: 0.340,
    stageAssets: [
      '$_adv/home_village/HomeVillage_Stage1.png',
      '$_adv/home_village/HomeVillage_Stage2.png',
      '$_adv/home_village/HomeVillage_Stage3.png',
      '$_adv/home_village/HomeVillage_Stage4.png',
      '$_adv/home_village/HomeVillage_Stage5.png',
      '$_adv/home_village/HomeVillage_Stage6.png',
    ],
  ),
  AdventureAssetTheme(
    areaId: 'fruit_garden',
    // Top-centre orchard island.
    mapX: 0.505,
    mapY: 0.330,
    stageAssets: [
      '$_adv/fruit_garden/FruitGarden_S1.png',
      '$_adv/fruit_garden/FruitGarden_S2.png',
      '$_adv/fruit_garden/FruitGarden_S3.png',
      '$_adv/fruit_garden/FruitGarden_S4.png',
      '$_adv/fruit_garden/FruitGarden_S5.png',
      '$_adv/fruit_garden/FruitGarden_S6.png',
    ],
  ),
  AdventureAssetTheme(
    areaId: 'animal_forest',
    // Top-right woodland island, where the deer and rabbit stand.
    mapX: 0.825,
    mapY: 0.340,
    iconAsset: '$_adv/animal_forest/icon.svg',
    stageAssets: [
      '$_adv/animal_forest/AnimalForest_S1.png',
      '$_adv/animal_forest/AnimalForest_S2.png',
      '$_adv/animal_forest/AnimalForest_S3.png',
      '$_adv/animal_forest/AnimalForest_S4.png',
      '$_adv/animal_forest/AnimalForest_S5.png',
      '$_adv/animal_forest/AnimalForest_S6.png',
    ],
  ),
  AdventureAssetTheme(
    // `home_corner` server-side; `cozy_home_corner` is only the asset folder.
    areaId: 'home_corner',
    // Bottom-left living-room platform.
    mapX: 0.160,
    mapY: 0.795,
    // Already 0-indexed by stage, unlike the other areas' 1-based file names.
    stageAssets: [
      '$_adv/cozy_home_corner/CozyHome_S0.png',
      '$_adv/cozy_home_corner/CozyHome_S1.png',
      '$_adv/cozy_home_corner/CozyHome_S2.png',
      '$_adv/cozy_home_corner/CozyHome_S3.png',
      '$_adv/cozy_home_corner/CozyHome_S4.png',
      '$_adv/cozy_home_corner/CozyHome_S5.png',
    ],
  ),
  AdventureAssetTheme(
    areaId: 'vehicle_valley',
    // Bottom-centre road platform with the red car.
    mapX: 0.505,
    mapY: 0.805,
    stageAssets: [
      '$_adv/vehicle_valley/VehicleValley_S1.png',
      '$_adv/vehicle_valley/VehicleValley_S2.png',
      '$_adv/vehicle_valley/VehicleValley_S3.png',
      '$_adv/vehicle_valley/VehicleValley_S4.png',
      '$_adv/vehicle_valley/VehicleValley_S5.png',
      '$_adv/vehicle_valley/VehicleValley_S6.png',
    ],
  ),
  AdventureAssetTheme(
    areaId: 'treasure_castle',
    // Bottom-right castle.
    mapX: 0.845,
    mapY: 0.785,
    stageAssets: [
      '$_adv/treasure_castle/TreasureCastle_S1.png',
      '$_adv/treasure_castle/TreasureCastle_S2.png',
      '$_adv/treasure_castle/TreasureCastle_S3.png',
      '$_adv/treasure_castle/TreasureCastle_S4.png',
      '$_adv/treasure_castle/TreasureCastle_S5.png',
      '$_adv/treasure_castle/TreasureCastle_S6.png',
    ],
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

/// True when [areaId] has painted scene art, so a screen can choose between the
/// real artwork and the badge fallback.
bool hasSceneArt(String? areaId) => adventureAssetById(areaId).hasArt;

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
