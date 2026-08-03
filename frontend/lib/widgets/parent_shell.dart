import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The sections of Parent Mode.
enum ParentNavItem {
  dashboard('Dashboard', Icons.dashboard_rounded),
  children('My Children', Icons.groups_rounded),
  activity('Activity Log', Icons.receipt_long_rounded),
  reports('Progress & Reports', Icons.insights_rounded),
  familyCode('Family Code', Icons.vpn_key_rounded),
  settings('Settings', Icons.settings_rounded);

  final String label;
  final IconData icon;
  const ParentNavItem(this.label, this.icon);
}

/// Dashboard chrome for Parent Mode: a persistent left rail on a desktop
/// browser, a Drawer below [ParentShell.wideBreakpoint].
///
/// The rail stays put while the body swaps, rather than pushing a new route
/// per section — the sections are views of one dashboard, and keeping the
/// stack flat also keeps the browser's back button out of trouble in an app
/// with no route table. Screens that deserve full focus (add child, edit,
/// a child's report) are pushed on top as usual.
class ParentShell extends StatefulWidget {
  static const double wideBreakpoint = 1000;

  final ParentNavItem selected;
  final ValueChanged<ParentNavItem> onSelect;
  final VoidCallback onLogout;

  /// Shown in the header: greeting line, subtitle and the account chip.
  final String username;
  final String title;
  final String subtitle;

  final Widget child;

  /// Optional action rendered at the right of the header (e.g. Add New Child).
  final Widget? headerAction;

  const ParentShell({
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
  State<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends State<ParentShell> {
  // Held on the State, not created in build(): a key rebuilt every frame
  // would never resolve to the live Scaffold.
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= ParentShell.wideBreakpoint;

    final sidebar = _ParentSidebar(
      selected: widget.selected,
      onSelect: (item) {
        // Close the drawer first on a narrow layout, so the parent isn't left
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
                  _ParentHeader(
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

class _ParentSidebar extends StatelessWidget {
  final ParentNavItem selected;
  final ValueChanged<ParentNavItem> onSelect;
  final VoidCallback onLogout;

  const _ParentSidebar({
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
                  Row(
                    children: [
                      Text(
                        'VocabScan',
                        style: AppTheme.heading.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.auto_awesome_rounded,
                          size: 16, color: AppTheme.primary),
                    ],
                  ),
                  const SizedBox(height: AppTheme.sm),
                  // Makes it unmistakable which side of the app this is —
                  // the same device is used by the child. Purple is Parent
                  // Mode's theme throughout (AppTheme.primary), matching
                  // parent_dashboard_screen.dart and parent_edit_child_screen.dart.
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.md, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield_rounded,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          'Parent Mode',
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
              color: AppTheme.primary.withValues(alpha: 0.12),
              indent: AppTheme.lg,
              endIndent: AppTheme.lg,
            ),
            const SizedBox(height: AppTheme.md),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.md),
                children: [
                  for (final item in ParentNavItem.values)
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
  final ParentNavItem item;
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
  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final color = selected ? AppTheme.primary : AppTheme.textDark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppTheme.primaryLight : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: InkWell(
          onTap: widget.onTap,
          hoverColor: selected
              ? AppTheme.primaryLight
              : AppTheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.md, vertical: 13),
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
      ),
    );
  }
}

class _ParentHeader extends StatelessWidget {
  final bool isWide;
  final String username;
  final String title;
  final String subtitle;
  final Widget? action;
  final VoidCallback onMenu;

  const _ParentHeader({
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
                    backgroundColor: AppTheme.primaryLight,
                    child: Text(
                      username.isEmpty ? '?' : username[0].toUpperCase(),
                      style: AppTheme.body.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
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
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 18, color: AppTheme.textLight),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Shared dashboard pieces ──────────────────────────────────────────────────

/// A rounded white panel — the dashboard's basic building block.
class ParentCard extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Color? iconTint;
  final Widget child;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  const ParentCard({
    super.key,
    this.title,
    this.icon,
    this.iconTint,
    this.action,
    this.padding = const EdgeInsets.all(AppTheme.lg),
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: const [
          BoxShadow(color: AppTheme.shadowColor, blurRadius: 14,
              offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: iconTint ?? AppTheme.primary),
                  const SizedBox(width: AppTheme.sm),
                ],
                Expanded(
                  child: Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.body.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: AppTheme.md),
          ],
          child,
        ],
      ),
    );
  }
}

/// One labelled number, used across the dashboard and the report.
class ParentStat extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String label;
  final String value;
  final String? caption;

  const ParentStat({
    super.key,
    required this.icon,
    required this.tint,
    required this.label,
    required this.value,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: tint.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tint),
          const SizedBox(height: AppTheme.sm),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.heading.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.caption.copyWith(fontSize: 12),
          ),
          if (caption != null)
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.caption.copyWith(fontSize: 11),
            ),
        ],
      ),
    );
  }
}
