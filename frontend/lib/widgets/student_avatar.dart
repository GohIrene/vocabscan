import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The avatar set a child picks from. Index into this list is what the backend
/// stores, so the order must stay stable — append new avatars, never reorder.
const List<String> kAvatarAssets = [
  'assets/icons/boy1.png',
  'assets/icons/girl1.png',
  'assets/icons/boy2.png',
  'assets/icons/girl2.png',
  'assets/icons/boy3.png',
  'assets/icons/butterfly.png',
  'assets/icons/teddy bear.png',
  'assets/icons/rainbow.png',
];

/// Backing colour per avatar, so a grid of children reads as varied at a
/// glance. Cycles if the avatar list ever outgrows it.
const List<Color> _avatarColors = [
  AppTheme.primary,
  AppTheme.blossom,
  AppTheme.secondary,
  AppTheme.adventure,
  AppTheme.success,
  AppTheme.treasure,
];

Color avatarColor(int index) =>
    _avatarColors[index.abs() % _avatarColors.length];

/// A child's avatar as a coloured circle. Used on the roster grid, the
/// tap-your-name join screen, and the in-session progress header.
class StudentAvatar extends StatelessWidget {
  final int avatar;
  final double size;

  /// Dims the avatar for a child who is already connected in this session.
  final bool dimmed;

  const StudentAvatar({
    super.key,
    required this.avatar,
    this.size = 56,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final index = avatar.abs() % kAvatarAssets.length;
    final color = avatarColor(avatar);
    return Opacity(
      opacity: dimmed ? 0.35 : 1,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
        alignment: Alignment.center,
        child: Padding(
          padding: EdgeInsets.all(size * 0.16),
          child: Image.asset(
            kAvatarAssets[index],
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                Icon(Icons.face, size: size * 0.55, color: color),
          ),
        ),
      ),
    );
  }
}
