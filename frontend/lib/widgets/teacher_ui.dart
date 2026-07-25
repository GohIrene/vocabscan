import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'teacher_shell.dart';

/// Shared Teacher Mode building blocks.
///
/// These mirror the Parent Mode pieces (`ParentCard`, `ParentStat`) so the two
/// dashboards read as one design system, but carry Teacher Mode's classroom
/// accent. Everything reads its colours, spacing and radii from [AppTheme], so
/// the whole look still retunes from that one file.

// ── Buttons ──────────────────────────────────────────────────────────────────

/// The filled call-to-action button. Same shape and size as the rest of the
/// app; tinted with the Teacher accent to reinforce role identity.
class TeacherPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expand;

  const TeacherPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      backgroundColor: TeacherShell.accent,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppTheme.textLight.withValues(alpha: 0.25),
      minimumSize: expand ? const Size.fromHeight(50) : const Size(140, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      textStyle: AppTheme.buttonText.copyWith(fontSize: 15),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    );
    if (icon == null) {
      return FilledButton(onPressed: onPressed, style: style, child: Text(label));
    }
    return FilledButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

/// The outlined secondary button, in the Teacher accent.
class TeacherSecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expand;
  final Color? tint;

  const TeacherSecondaryButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.expand = false,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final color = tint ?? TeacherShell.accent;
    final style = OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(color: color.withValues(alpha: 0.5), width: 1.6),
      minimumSize: expand ? const Size.fromHeight(50) : const Size(120, 46),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      textStyle: AppTheme.body.copyWith(fontWeight: FontWeight.w700, fontSize: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    );
    if (icon == null) {
      return OutlinedButton(onPressed: onPressed, style: style, child: Text(label));
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

// ── Cards ────────────────────────────────────────────────────────────────────

/// A rounded white panel — the dashboard's basic building block. Optional
/// header row with an icon, title and trailing action.
class TeacherSectionCard extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Color? iconTint;
  final Widget child;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  const TeacherSectionCard({
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
                  Icon(icon, size: 18, color: iconTint ?? TeacherShell.accent),
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

/// One labelled number, used across the dashboard and reports. Tinted tile with
/// an icon, big value and a small label/caption.
class TeacherStatCard extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String label;
  final String value;
  final String? caption;

  const TeacherStatCard({
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

/// A compact, tappable class summary tile for the dashboard's "recent classes"
/// row: name, a line of meta, and a trailing chevron/action.
class TeacherClassCard extends StatefulWidget {
  final String name;
  final String meta;
  final VoidCallback onTap;
  final Widget? trailing;

  const TeacherClassCard({
    super.key,
    required this.name,
    required this.meta,
    required this.onTap,
    this.trailing,
  });

  @override
  State<TeacherClassCard> createState() => _TeacherClassCardState();
}

class _TeacherClassCardState extends State<TeacherClassCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(AppTheme.md),
          decoration: BoxDecoration(
            color: _hovering
                ? TeacherShell.accent.withValues(alpha: 0.06)
                : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: const [
              BoxShadow(color: AppTheme.shadowColor, blurRadius: 12,
                  offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: TeacherShell.accentLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(Icons.school_rounded,
                    size: 22, color: TeacherShell.accent),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body.copyWith(
                          fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    Text(
                      widget.meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.caption,
                    ),
                  ],
                ),
              ),
              widget.trailing ??
                  const Icon(Icons.chevron_right_rounded,
                      color: AppTheme.textLight),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small rounded status pill. [tone] picks the colour; [label] is the text.
enum TeacherStatusTone { live, neutral, warning }

class TeacherStatusChip extends StatelessWidget {
  final String label;
  final TeacherStatusTone tone;
  final bool solid;

  const TeacherStatusChip({
    super.key,
    required this.label,
    this.tone = TeacherStatusTone.neutral,
    this.solid = false,
  });

  Color get _color => switch (tone) {
        TeacherStatusTone.live => AppTheme.success,
        TeacherStatusTone.warning => AppTheme.warning,
        TeacherStatusTone.neutral => AppTheme.textLight,
      };

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tone == TeacherStatusTone.live) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: solid ? Colors.white : color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: AppTheme.caption.copyWith(
              color: solid ? Colors.white : color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty / first-run placeholder: an emoji or icon, a title, a message and an
/// optional call to action. Used wherever a list has nothing in it yet.
class TeacherEmptyState extends StatelessWidget {
  final String? emoji;
  final IconData? icon;
  final String title;
  final String message;
  final Widget? action;

  const TeacherEmptyState({
    super.key,
    this.emoji,
    this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return TeacherSectionCard(
      padding: const EdgeInsets.all(AppTheme.xxl),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            if (emoji != null)
              Text(emoji!, style: const TextStyle(fontSize: 44))
            else if (icon != null)
              Icon(icon, size: 44, color: AppTheme.textLight),
            const SizedBox(height: AppTheme.md),
            Text(title,
                textAlign: TextAlign.center,
                style:
                    AppTheme.subheading.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppTheme.xs),
            Text(message,
                textAlign: TextAlign.center, style: AppTheme.caption),
            if (action != null) ...[
              const SizedBox(height: AppTheme.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
