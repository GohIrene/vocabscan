/// The animal buddies a child picks from, and the artwork for each of their
/// three growth stages.
///
/// This is the single source of truth for avatars across the app — the add-
/// child wizard, the child profile picker, ChildHomeScreen and the parent
/// dashboard all read it rather than keeping their own copies. The backend
/// stores only [AvatarOption.avatarId], never a list index, so avatars can be
/// reordered or retired here without rewriting stored child documents.
///
/// Asset paths deliberately live on this side rather than being served by the
/// API: Flutter bundles assets at build time, so a path the server invented at
/// runtime could not be loaded anyway. The backend validates the id only
/// (`backend/avatars.py`), and the two id lists must be kept in step.
library;

/// One buddy, with the artwork for each stage it can grow into.
class AvatarOption {
  final String avatarId;
  final String displayName;
  final String stage1Asset;
  final String stage2Asset;
  final String stage3Asset;

  /// Retired avatars stay in the list so children who already chose one keep
  /// rendering, but they're hidden from the picker.
  final bool isActive;

  /// Display order in the picker. Stable and unique; see `assertAvatarConfig`.
  final int sortOrder;

  const AvatarOption({
    required this.avatarId,
    required this.displayName,
    required this.stage1Asset,
    required this.stage2Asset,
    required this.stage3Asset,
    required this.sortOrder,
    this.isActive = true,
  });

  /// Artwork for [stage], clamped to the range the art actually covers.
  /// Anything at or below 1 shows the baby art and anything at or above 3
  /// shows the final art, so an out-of-range or missing stage from an older
  /// child document can never fail to render.
  String assetForStage(int stage) {
    if (stage <= 1) return stage1Asset;
    if (stage == 2) return stage2Asset;
    return stage3Asset;
  }
}

/// Every buddy, in picker order.
const List<AvatarOption> kAvatars = [
  AvatarOption(
    avatarId: 'kitten',
    displayName: 'Kitten',
    stage1Asset: 'assets/images/avatars/kitten_stage1.png',
    stage2Asset: 'assets/images/avatars/kitten_stage2.png',
    stage3Asset: 'assets/images/avatars/kitten_stage3.png',
    sortOrder: 1,
  ),
  AvatarOption(
    avatarId: 'panda',
    displayName: 'Panda',
    stage1Asset: 'assets/images/avatars/panda_stage1.png',
    stage2Asset: 'assets/images/avatars/panda_stage2.png',
    stage3Asset: 'assets/images/avatars/panda_stage3.png',
    sortOrder: 2,
  ),
  AvatarOption(
    avatarId: 'elephant',
    displayName: 'Elephant',
    stage1Asset: 'assets/images/avatars/elephant_stage1.png',
    stage2Asset: 'assets/images/avatars/elephant_stage2.png',
    stage3Asset: 'assets/images/avatars/elephant_stage3.png',
    sortOrder: 3,
  ),
  AvatarOption(
    avatarId: 'penguin',
    displayName: 'Penguin',
    stage1Asset: 'assets/images/avatars/penguin_stage1.png',
    stage2Asset: 'assets/images/avatars/penguin_stage2.png',
    stage3Asset: 'assets/images/avatars/penguin_stage3.png',
    sortOrder: 4,
  ),
  AvatarOption(
    avatarId: 'unicorn',
    displayName: 'Unicorn',
    stage1Asset: 'assets/images/avatars/unicorn_stage1.png',
    stage2Asset: 'assets/images/avatars/unicorn_stage2.png',
    stage3Asset: 'assets/images/avatars/unicorn_stage3.png',
    sortOrder: 5,
  ),
];

/// Assigned when a child has no avatar yet — every legacy profile created
/// before avatars existed reads as this one. Must match `DEFAULT_AVATAR_ID`
/// in `backend/avatars.py`.
const String kDefaultAvatarId = 'kitten';

/// The buddies offered in the picker, in [AvatarOption.sortOrder] order.
List<AvatarOption> get kSelectableAvatars {
  final active = kAvatars.where((a) => a.isActive).toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return active;
}

/// The buddy with [avatarId], or null when the id isn't one we know.
AvatarOption? avatarById(String? avatarId) {
  if (avatarId == null || avatarId.isEmpty) return null;
  for (final a in kAvatars) {
    if (a.avatarId == avatarId) return a;
  }
  return null;
}

/// The buddy with [avatarId], falling back to the default rather than null —
/// for render paths that must always produce something, such as a child
/// document written before avatars existed or one naming a retired avatar.
AvatarOption avatarByIdOrDefault(String? avatarId) =>
    avatarById(avatarId) ?? avatarById(kDefaultAvatarId) ?? kAvatars.first;
