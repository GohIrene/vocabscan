import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The destinations in Child Adventure mode.
///
/// Every one is listed from Phase 3 so the navigation reads as a complete
/// place rather than growing an item at a time, but only the ones whose
/// screens exist are selectable — see [ChildNavSidebar.enabled].
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

  const ChildNavSidebar({
    super.key,
    required this.selected,
    required this.enabled,
    required this.onSelect,
    required this.onExit,
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
              child: Row(
                children: [
                  // A small brand mark before the wordmark, matching the
                  // dashboard design. Drawn from theme colours rather than a
                  // logo asset so it stays crisp at any DPI.
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primary, Color(0xFF6B4EFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.center_focus_strong_rounded,
                        size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: AppTheme.sm),
                  Flexible(
                    child: Text(
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
                ],
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

  const _NavTile({
    required this.item,
    required this.selected,
    required this.enabled,
    required this.onTap,
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
                Icon(widget.item.icon, size: 20, color: color),
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
