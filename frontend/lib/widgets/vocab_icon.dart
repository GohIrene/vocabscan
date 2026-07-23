import 'package:flutter/material.dart';

/// english_key -> icon asset path. Mirrors the 30 words in backend/vocab.py;
/// filenames don't follow the key naming (spaces, abbreviations) because they
/// were added ad hoc before this mapping existed.
const Map<String, String> _vocabIconAssets = {
  'apple': 'assets/icons/apple.png',
  'backpack': 'assets/icons/bagpack.png',
  'ball': 'assets/icons/ball.png',
  'banana': 'assets/icons/banana.png',
  'book': 'assets/icons/book.png',
  'bottle': 'assets/icons/bottle.png',
  'bowl': 'assets/icons/bowl.png',
  'bread': 'assets/icons/bread.png',
  'chair': 'assets/icons/chair.png',
  'clock': 'assets/icons/clock.png',
  'cup': 'assets/icons/coffee-cup.png',
  'fork': 'assets/icons/fork.png',
  'glasses': 'assets/icons/glasses.png',
  'keyboard': 'assets/icons/keyboard.png',
  'knife': 'assets/icons/knife.png',
  'lamp': 'assets/icons/lamp.png',
  'laptop': 'assets/icons/laptop.png',
  'mobile_phone': 'assets/icons/phone.png',
  'orange': 'assets/icons/orange.png',
  'pen': 'assets/icons/pen.png',
  'plate': 'assets/icons/plate.png',
  'remote_control': 'assets/icons/remote control.png',
  'ruler': 'assets/icons/ruler.png',
  'scissors': 'assets/icons/scissor.png',
  'shoe': 'assets/icons/shoe.png',
  'spoon': 'assets/icons/spoon.png',
  'table': 'assets/icons/table.png',
  'teddy_bear': 'assets/icons/teddy bear.png',
  'toothbrush': 'assets/icons/toothbrush.png',
  'umbrella': 'assets/icons/umbrella.png',
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
    return Image.asset(
      asset,
      width: size,
      height: size,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}
