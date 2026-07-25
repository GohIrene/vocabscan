import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The sections of Teacher Mode.
///
/// These are views of one dashboard rather than six routes — the rail stays
/// put and only the body swaps, mirroring Parent Mode. Screens that deserve
/// full focus (a live session, batch upload, the student join flow) are still
/// pushed on top as usual.
enum TeacherNavItem {
  dashboard('Dashboard', Icons.dashboard_rounded),
  classes('My Classes', Icons.groups_rounded),
  liveSession('Live Session', Icons.podcasts_rounded),
  reports('Reports', Icons.insights_rounded),
  settings('Settings', Icons.settings_rounded);

  final String label;
  final IconData icon;
  const TeacherNavItem(this.label, this.icon);
}

/// Dashboard chrome for Teacher Mode: a persistent left rail on a desktop
/// browser, a Drawer below [TeacherShell.wideBreakpoint].
///
/// A deliberate sibling of `ParentShell` — same proportions, spacing and
/// header structure so the two modes read as one application — but with its
/// own "Teacher Mode" identity (professional secondary-blue accent rather than
/// the calm parent purple).
class TeacherShell extends StatefulWidget {
  static const double wideBreakpoint = 1000;

  /// The accent that marks this as Teacher Mode. Secondary (classroom blue)
  /// rather than the parent purple, while every other token stays shared.
  static const Color accent = AppTheme.secondary;
  static const Color accentLight = AppTheme.secondaryLight;

  final TeacherNavItem selected;
  final ValueChanged<TeacherNavItem> onSelect;
  final VoidCallback onLogout;

  /// Shown in the header: title, subtitle and the account chip.
  final String username;
  final String title;
  final String subtitle;

  final Widget child;

  /// Optional action rendered at the right of the header (e.g. Create Session).
  final Widget? headerAction;

  const TeacherShell({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onLogout,
    required this.username,
    required this.title,
    required this.subtitle,
    required this.child,
    this.headerAction,
  });

  static String greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  State<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends State<TeacherShell> {
  // Held on the State, not created in build(): a key rebuilt every frame
  // would never resolve to the live Scaffold.
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= TeacherShell.wideBreakpoint;

    final sidebar = _TeacherSidebar(
      selected: widget.selected,
      onSelect: (item) {
        // Close the drawer first on a narrow layout, so the teacher isn't left
        // looking at the menu on top of the section they just opened.
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          Navigator.pop(context);
        }
        widget.onSelect(item);
      },
      onLogout: widget.onLogout,
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.background,
      drawer: isWide ? null : Drawer(child: sidebar),
      body: Row(
        children: [
          if (isWide) sidebar,
          Expanded(
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TeacherHeader(
                    isWide: isWide,
                    username: widget.username,
                    title: widget.title,
                    subtitle: widget.subtitle,
                    action: widget.headerAction,
                    onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherSidebar extends StatelessWidget {
  final TeacherNavItem selected;
  final ValueChanged<TeacherNavItem> onSelect;
  final VoidCallback onLogout;

  const _TeacherSidebar({
    required this.selected,
    required this.onSelect,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 244,
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
                  AppTheme.lg, AppTheme.xl, AppTheme.lg, AppTheme.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VocabScan',
                    style: AppTheme.heading.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: TeacherShell.accent,
                    ),
                  ),
                  const SizedBox(height: AppTheme.sm),
                  // Makes it unmistakable which side of the app this is.
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.md, vertical: 6),
                    decoration: BoxDecoration(
                      color: TeacherShell.accent,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.school_rounded,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          'Teacher Mode',
                          style: AppTheme.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: TeacherShell.accent.withValues(alpha: 0.12),
              indent: AppTheme.lg,
              endIndent: AppTheme.lg,
            ),
            const SizedBox(height: AppTheme.md),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.md),
                children: [
                  for (final item in TeacherNavItem.values)
                    _NavTile(
                      item: item,
                      selected: item == selected,
                      onTap: () => onSelect(item),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppTheme.md),
              child: TextButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Log Out'),
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
  final TeacherNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.selected,
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
    final color = selected ? TeacherShell.accent : AppTheme.textDark;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.md, vertical: 13),
          decoration: BoxDecoration(
            color: selected
                ? TeacherShell.accentLight
                : (_hovering
                    ? TeacherShell.accent.withValues(alpha: 0.06)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Row(
            children: [
              Icon(widget.item.icon, size: 19, color: color),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: Text(
                  widget.item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.body.copyWith(
                    fontSize: 14.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherHeader extends StatelessWidget {
  final bool isWide;
  final String username;
  final String title;
  final String subtitle;
  final Widget? action;
  final VoidCallback onMenu;

  const _TeacherHeader({
    required this.isWide,
    required this.username,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.xl, AppTheme.lg, AppTheme.xl, AppTheme.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isWide) ...[
            IconButton(
              onPressed: onMenu,
              icon: const Icon(Icons.menu_rounded),
              color: AppTheme.textDark,
              tooltip: 'Menu',
            ),
            const SizedBox(width: AppTheme.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.heading.copyWith(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.body.copyWith(color: AppTheme.textLight),
                ),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: AppTheme.md),
            action!,
          ],
          if (isWide) ...[
            const SizedBox(width: AppTheme.lg),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.md, vertical: AppTheme.sm),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(color: AppTheme.shadowColor, blurRadius: 10,
                      offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: TeacherShell.accentLight,
                    child: Text(
                      username.isEmpty ? '?' : username[0].toUpperCase(),
                      style: AppTheme.body.copyWith(
                        fontWeight: FontWeight.w800,
                        color: TeacherShell.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 130),
                    child: Text(
                      username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body.copyWith(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
