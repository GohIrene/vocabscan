import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'child_avatar.dart';

/// The destinations in Child Adventure mode.
///
/// Every one is listed from Phase 3 so the navigation reads as a complete
/// place rather than growing an item at a time, but only the ones whose
/// screens exist are selectable — see [ChildNavSidebar.enabled].
///
/// These are plain Material icons on purpose. Painterly icons cropped from the
/// reference art were tried here and reverted: they are 3/4-view illustrations
/// with soft edges and fine internal detail, none of it legible once shrunk to
/// a 30px nav row. The Avatar row is the one exception — see [_NavIcon], which
/// swaps in the child's live [ChildAvatar], since no static icon can represent
/// whichever of the 5 buddies a given child actually picked.
enum ChildNavItem {
  home('Home', Icons.home_rounded),
  adventureMap('Adventure Map', Icons.map_rounded),
  treasureAlbum('Treasure Album', Icons.photo_album_rounded),
  avatar('Avatar', Icons.pets_rounded),
  achievements('Achievements', Icons.emoji_events_rounded),
  settings('Settings', Icons.settings_rounded);

  final String label;
  final IconData icon;
  const ChildNavItem(this.label, this.icon);
}

/// Left navigation for Child Adventure mode.
///
/// Rendered as a persistent rail on a desktop browser and inside a Drawer on
/// a narrow one; the same widget serves both, so the two can't drift apart.
///
/// Deliberately contains nothing parent-facing — no reports, no family code,
/// no account settings.
class ChildNavSidebar extends StatelessWidget {
  final ChildNavItem selected;

  /// Which destinations can be opened. Phase 4 adds the map, Phase 6 the
  /// treasure album; until then those items render but don't navigate.
  final Set<ChildNavItem> enabled;

  final ValueChanged<ChildNavItem> onSelect;
  final VoidCallback onExit;

  /// The child's current buddy, shown live on the Avatar row instead of a
  /// fixed icon — see [ChildNavItem].
  final String? avatarId;
  final int avatarStage;

  const ChildNavSidebar({
    super.key,
    required this.selected,
    required this.enabled,
    required this.onSelect,
    required this.onExit,
    this.avatarId,
    this.avatarStage = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 232,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [
          BoxShadow(color: AppTheme.shadowColor, blurRadius: 18,
              offset: Offset(2, 0)),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppTheme.lg, AppTheme.xl, AppTheme.lg, AppTheme.lg),
              child: Image.asset(
                'assets/images/Logo/VocabScanLogo.png',
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                errorBuilder: (_, _, _) => Text(
                  'VocabScan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.heading.copyWith(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ),
            Divider(
              height: 1,
              color: AppTheme.primary.withValues(alpha: 0.12),
              indent: AppTheme.lg,
              endIndent: AppTheme.lg,
            ),
            const SizedBox(height: AppTheme.md),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.md),
                children: [
                  for (final item in ChildNavItem.values)
                    _NavTile(
                      item: item,
                      selected: item == selected,
                      enabled: enabled.contains(item),
                      onTap: () => onSelect(item),
                      avatarId: avatarId,
                      avatarStage: avatarStage,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppTheme.md),
              child: TextButton.icon(
                onPressed: onExit,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Logout'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  backgroundColor: AppTheme.errorLight,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  textStyle: AppTheme.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatefulWidget {
  final ChildNavItem item;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final String? avatarId;
  final int avatarStage;

  const _NavTile({
    required this.item,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.avatarId,
    this.avatarStage = 1,
  });

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final enabled = widget.enabled;
    final color = selected ? AppTheme.primary : AppTheme.textDark;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.md, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryLight
                : (_hovering
                    ? AppTheme.primary.withValues(alpha: 0.06)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Opacity(
            // Dimmed rather than hidden: a child can see the place exists and
            // is worth unlocking, which is the point of showing it at all.
            opacity: enabled ? 1 : 0.45,
            child: Row(
              children: [
                _NavIcon(
                  item: widget.item,
                  color: color,
                  avatarId: widget.avatarId,
                  avatarStage: widget.avatarStage,
                ),
                const SizedBox(width: AppTheme.md),
                Expanded(
                  child: Text(
                    widget.item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.body.copyWith(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                if (!enabled)
                  const Icon(Icons.lock_outline,
                      size: 14, color: AppTheme.textLight),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One nav row's leading icon: the child's live buddy for the Avatar row, the
/// item's Material icon everywhere else.
///
/// Both are drawn in a 30px box so the labels line up whichever one a row uses.
class _NavIcon extends StatelessWidget {
  final ChildNavItem item;
  final Color color;
  final String? avatarId;
  final int avatarStage;

  const _NavIcon({
    required this.item,
    required this.color,
    required this.avatarId,
    required this.avatarStage,
  });

  @override
  Widget build(BuildContext context) {
    if (item == ChildNavItem.avatar) {
      return ChildAvatar(avatarId: avatarId, stage: avatarStage, size: 30);
    }

    return SizedBox(
      width: 30,
      height: 30,
      child: Icon(item.icon, size: 22, color: color),
    );
  }
}
