import 'package:flutter/material.dart';

import '../avatar_config.dart';
import '../theme/app_theme.dart';
import '../widgets/child_avatar.dart';
import 'child_adventure_map_screen.dart';
import 'child_treasure_album_screen.dart';

/// A deliberately small settings hub for a child.
///
/// It owns no new state and no new API: everything shown here already comes
/// from the home summary, and every action routes to a screen that already
/// exists. The point is a real, working destination for the Settings nav item
/// — a profile summary plus quick links — rather than a placeholder page.
///
/// Nothing parent-facing lives here (no account, no family code, no reports),
/// keeping the child side self-contained.
class ChildSettingsScreen extends StatelessWidget {
  final String childId;
  final String nickname;
  final String? avatarId;
  final int avatarStage;

  const ChildSettingsScreen({
    super.key,
    required this.childId,
    required this.nickname,
    this.avatarId,
    this.avatarStage = 1,
  });

  String get _buddyName => avatarByIdOrDefault(avatarId).displayName;

  void _openAdventureMap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChildAdventureMapScreen(childId: childId),
      ),
    );
  }

  void _openTreasureAlbum(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChildTreasureAlbumScreen(childId: childId),
      ),
    );
  }

  void _finish(BuildContext context) {
    // Same unwind as the home screen's Logout: back to the very first route,
    // so the next child starts from the family code.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text('Back'),
                        style: AppTheme.backButtonStyle,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.md),
                  Text(
                    'Settings',
                    style: AppTheme.heading.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppTheme.lg),
                  _ProfileCard(
                    nickname: nickname,
                    buddyName: _buddyName,
                    avatarId: avatarId,
                    avatarStage: avatarStage,
                  ),
                  const SizedBox(height: AppTheme.lg),
                  _SettingsTile(
                    icon: Icons.map_rounded,
                    tint: AppTheme.success,
                    title: 'Adventure Map',
                    subtitle: 'See all your places',
                    onTap: () => _openAdventureMap(context),
                  ),
                  const SizedBox(height: AppTheme.md),
                  _SettingsTile(
                    icon: Icons.photo_album_rounded,
                    tint: AppTheme.secondary,
                    title: 'Treasure Album',
                    subtitle: 'Words you have collected',
                    onTap: () => _openTreasureAlbum(context),
                  ),
                  const SizedBox(height: AppTheme.md),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    tint: AppTheme.primary,
                    title: 'About VocabScan',
                    subtitle: 'Learn words by scanning the world',
                    onTap: () => showAboutDialog(
                      context: context,
                      applicationName: 'VocabScan',
                      applicationVersion: 'Home Adventure',
                    ),
                  ),
                  const SizedBox(height: AppTheme.xl),
                  FilledButton.icon(
                    onPressed: () => _finish(context),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Logout'),
                    style: FilledButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      backgroundColor: AppTheme.errorLight,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      textStyle:
                          AppTheme.body.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String nickname;
  final String buddyName;
  final String? avatarId;
  final int avatarStage;

  const _ProfileCard({
    required this.nickname,
    required this.buddyName,
    required this.avatarId,
    required this.avatarStage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEDE7FF), Color(0xFFE3F1FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          ChildAvatar(
            avatarId: avatarId,
            stage: avatarStage,
            size: 72,
            showStageBadge: true,
          ),
          const SizedBox(width: AppTheme.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.subheading.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Buddy: $buddyName · Stage $avatarStage',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppTheme.lg),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: const [
              BoxShadow(
                  color: AppTheme.shadowColor,
                  blurRadius: 12,
                  offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(icon, color: tint, size: 22),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.caption,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textLight),
            ],
          ),
        ),
      ),
    );
  }
}
