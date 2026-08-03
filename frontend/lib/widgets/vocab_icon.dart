import 'package:flutter/material.dart';

/// english_key -> photo asset path. Mirrors the 30 words in backend/vocab.py;
/// filenames don't follow the key naming (spaces, abbreviations) because they
/// were added ad hoc before this mapping existed.
///
/// These are full-bleed photos (not transparent icon cutouts), so [VocabIcon]
/// crops them with `ClipRRect` + `BoxFit.cover` rather than laying them over
/// a background with the default fit.
const Map<String, String> _vocabIconAssets = {
  'apple': 'assets/classes/apple_v2.png',
  'backpack': 'assets/classes/backpack_v2.png',
  'ball': 'assets/classes/ball_v2.png',
  'banana': 'assets/classes/banana_v2.png',
  'book': 'assets/classes/book_v2.png',
  'bottle': 'assets/classes/bottle_v2.png',
  'bowl': 'assets/classes/bowl_v2.png',
  'bread': 'assets/classes/bread_v2.png',
  'chair': 'assets/classes/chair_v2.png',
  'clock': 'assets/classes/clock_v2.png',
  'cup': 'assets/classes/cup_v2.png',
  'fork': 'assets/classes/fork_v2.png',
  'glasses': 'assets/classes/glasses_v2.png',
  'keyboard': 'assets/classes/keyboard_v2.png',
  'knife': 'assets/classes/knife_v2.png',
  'lamp': 'assets/classes/lamp_v2.png',
  'laptop': 'assets/classes/laptop_v2.png',
  'mobile_phone': 'assets/classes/mobile_phone_v2.png',
  'orange': 'assets/classes/orange_v2.png',
  'pen': 'assets/classes/pen_v2.png',
  'plate': 'assets/classes/plate_v2.png',
  'remote_control': 'assets/classes/remotecontrol_v2.png',
  'ruler': 'assets/classes/ruler_v2.png',
  'scissors': 'assets/classes/scissor_v2.png',
  'shoe': 'assets/classes/shoe_v2.png',
  'spoon': 'assets/classes/spoon_v2.png',
  'table': 'assets/classes/table_v2.png',
  'teddy_bear': 'assets/classes/teddybear_v2.png',
  'toothbrush': 'assets/classes/toothbrush_v2.png',
  'umbrella': 'assets/classes/umbrella_v2.png',
};

/// Renders the object icon for [englishKey], or nothing when there's no
/// usable key/asset — callers pass `null` on purpose to hide the icon for a
/// question pattern where the picture would give away the answer (e.g. "which
/// English word matches this?" when the picture IS that word).
class VocabIcon extends StatelessWidget {
  final String? englishKey;
  final double size;

  const VocabIcon({super.key, required this.englishKey, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final asset = englishKey == null ? null : _vocabIconAssets[englishKey];
    if (asset == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.18),
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      ),
    );
  }
}
