import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../adventure_assets.dart';
import '../api_service.dart';
import '../avatar_config.dart';
import '../theme/app_theme.dart';
import '../widgets/child_avatar.dart';

/// A dedicated page for admiring a child's buddy and its growth progress.
///
/// The real system only tracks 3 growth stages (`backend/avatars.py`,
/// `ChildAvatar`'s own 1-3 clamp): stages 4 and 5 are shown as locked
/// "Coming Soon" placeholders rather than invented art or reward names, so
/// the page never promises content that doesn't exist yet.
///
/// Driven entirely by `GET /child/home/<child_id>` — the same call
/// `ChildHomeScreen` uses — so no new backend endpoint was needed.
class ChildAvatarScreen extends StatefulWidget {
  final String childId;

  const ChildAvatarScreen({super.key, required this.childId});

  @override
  State<ChildAvatarScreen> createState() => _ChildAvatarScreenState();
}

class _ChildAvatarScreenState extends State<ChildAvatarScreen> {
  static const double _compactBreakpoint = 760;

  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getChildHome(widget.childId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Map<String, dynamic> get _avatarData =>
      (_data?['avatar'] as Map?)?.cast<String, dynamic>() ?? const {};

  String? get _avatarId => _avatarData['avatar_id'] as String?;
  int get _stage => (_avatarData['stage'] as num?)?.toInt() ?? 1;
  int get _totalXp => (_avatarData['total_xp'] as num?)?.toInt() ?? 0;
  int? get _nextStageXp => (_avatarData['next_stage_xp'] as num?)?.toInt();

  int get _treasureCount => (_data?['treasure_count'] as num?)?.toInt() ?? 0;
  int get _achievementCount =>
      (_data?['achievement_count'] as num?)?.toInt() ?? 0;
  int get _achievementTotal =>
      (_data?['achievement_total'] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.md),
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back'),
                  style: AppTheme.backButtonStyle,
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildError()
                      : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🐾', style: TextStyle(fontSize: 52)),
            const SizedBox(height: AppTheme.lg),
            Text(
              "We couldn't load your buddy",
              style: AppTheme.subheading.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppTheme.sm),
            Text(_error ?? '',
                textAlign: TextAlign.center, style: AppTheme.caption),
            const SizedBox(height: AppTheme.xl),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: AppTheme.primaryButton,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final avatar = avatarByIdOrDefault(_avatarId);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _compactBreakpoint;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            compact ? AppTheme.lg : AppTheme.xxl,
            0,
            compact ? AppTheme.lg : AppTheme.xxl,
            AppTheme.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: AppTheme.xl),
              _buildHero(avatar, compact),
              const SizedBox(height: AppTheme.xl),
              Text(
                "${avatar.displayName}'s Growth Journey",
                style: AppTheme.subheading.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppTheme.md),
              _buildGrowthJourney(avatar),
              const SizedBox(height: AppTheme.xl),
              Text(
                'What You Unlock',
                style: AppTheme.subheading.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppTheme.md),
              _buildUnlocks(),
              const SizedBox(height: AppTheme.xl),
              Text(
                'Your Stats',
                style: AppTheme.subheading.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppTheme.md),
              _buildStats(compact),
              const SizedBox(height: AppTheme.xl),
              Center(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.explore_rounded, size: 18),
                  label: const Text('Continue Learning'),
                  style: AppTheme.primaryButton,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'My Avatar',
          textAlign: TextAlign.center,
          style: AppTheme.heading.copyWith(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          'Grow your buddy as you learn more words!',
          textAlign: TextAlign.center,
          style: AppTheme.body.copyWith(color: AppTheme.textLight),
        ),
      ],
    );
  }

  Widget _buildHero(AvatarOption avatar, bool compact) {
    final ring = ChildAvatar.stageColor(_stage);
    final nextXp = _nextStageXp;
    final atMax = nextXp == null;
    final progress = atMax ? 1.0 : (nextXp == 0 ? 1.0 : _totalXp / nextXp);

    final heroImage = Image.asset(
      avatar.assetForStage(_stage),
      height: compact ? 140 : 180,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Icon(
        Icons.pets_rounded,
        size: compact ? 100 : 140,
        color: ring,
      ),
    );

    final infoCard = Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: const [
          BoxShadow(color: AppTheme.shadowColor, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Buddy', style: AppTheme.caption),
                    Text(
                      avatar.displayName,
                      style: AppTheme.heading.copyWith(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.md, vertical: AppTheme.sm),
                decoration: BoxDecoration(
                  color: ring.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: ring, width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'LEVEL',
                      style: AppTheme.caption.copyWith(
                        fontSize: 10, color: ring, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '$_stage',
                      style: AppTheme.heading.copyWith(
                        fontSize: 22, color: ring, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.lg),
          Row(
            children: [
              Expanded(
                child: Text('XP Progress',
                    style: AppTheme.body.copyWith(fontWeight: FontWeight.w700)),
              ),
              Text(
                atMax ? '$_totalXp XP' : '$_totalXp / $nextXp XP',
                style: AppTheme.caption.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 12,
              backgroundColor: ring.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(ring),
            ),
          ),
          const SizedBox(height: AppTheme.sm),
          Text(
            atMax
                ? 'Fully grown — amazing work!'
                : '${nextXp - _totalXp} XP to the next stage!',
            style: AppTheme.caption,
          ),
        ],
      ),
    );

    if (compact) {
      return Column(
        children: [
          heroImage,
          const SizedBox(height: AppTheme.lg),
          infoCard,
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          heroImage,
          const SizedBox(width: AppTheme.xl),
          Expanded(child: infoCard),
        ],
      ),
    );
  }

  Widget _buildGrowthJourney(AvatarOption avatar) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const cards = 5;
        const spacing = AppTheme.md;
        final cardWidth =
            ((constraints.maxWidth - spacing * (cards - 1)) / cards).clamp(90.0, 160.0);
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var stage = 1; stage <= 3; stage++)
              SizedBox(
                width: cardWidth,
                child: _StageCard(
                  label: 'Stage $stage',
                  asset: avatar.assetForStage(stage),
                  completed: stage < _stage,
                  current: stage == _stage,
                  reached: stage <= _stage,
                ),
              ),
            for (var i = 0; i < 2; i++)
              SizedBox(width: cardWidth, child: const _MysteryStageCard()),
          ],
        );
      },
    );
  }

  Widget _buildUnlocks() {
    // Real, backend-defined rewards only (`backend/child_progress.py`
    // ACHIEVEMENTS) — no invented flavor text for stages that don't exist.
    final unlocks = [
      ('Stage 1', '🐣', 'New Buddy'),
      ('Stage 2', '✨', 'Buddy Grew!'),
      ('Stage 3', '💛', 'Best Friends'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        const cards = 5;
        const spacing = AppTheme.md;
        final cardWidth =
            ((constraints.maxWidth - spacing * (cards - 1)) / cards).clamp(90.0, 160.0);
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var i = 0; i < unlocks.length; i++)
              SizedBox(
                width: cardWidth,
                child: _UnlockCard(
                  label: unlocks[i].$1,
                  emoji: unlocks[i].$2,
                  name: unlocks[i].$3,
                  unlocked: (i + 1) <= _stage,
                ),
              ),
            for (var i = 0; i < 2; i++)
              SizedBox(width: cardWidth, child: const _MysteryStageCard()),
          ],
        );
      },
    );
  }

  Widget _buildStats(bool compact) {
    final nextXp = _nextStageXp;
    final tiles = [
      _StatTile(
        icon: Icons.shield_rounded,
        tint: AppTheme.primary,
        label: 'Current Level',
        value: 'Stage $_stage',
      ),
      _StatTile(
        icon: Icons.star_rounded,
        tint: AppTheme.treasure,
        label: 'XP to Next Level',
        value: nextXp == null ? 'Max!' : '${nextXp - _totalXp} XP',
      ),
      _StatTile(
        icon: Icons.menu_book_rounded,
        tint: AppTheme.secondary,
        label: 'Words Learned',
        value: '$_treasureCount',
      ),
      _StatTile(
        icon: Icons.emoji_events_rounded,
        tint: AppTheme.adventure,
        label: 'Achievements',
        value: '$_achievementCount / $_achievementTotal',
      ),
    ];
    final columns = compact ? 2 : 4;
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AppTheme.md;
        final tileWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles) SizedBox(width: tileWidth, child: tile),
          ],
        );
      },
    );
  }
}

/// A real (art-backed) growth stage: reached-and-passed, current, or a real
/// future stage shown dimmed with a lock, since the art already exists.
class _StageCard extends StatelessWidget {
  final String label;
  final String asset;
  final bool completed;
  final bool current;
  final bool reached;

  const _StageCard({
    required this.label,
    required this.asset,
    required this.completed,
    required this.current,
    required this.reached,
  });

  @override
  Widget build(BuildContext context) {
    final color = current ? AppTheme.primary : AppTheme.textLight;

    return Container(
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: current ? AppTheme.primaryLight : AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: current ? AppTheme.primary : AppTheme.shadowColor,
          width: current ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: reached ? 1 : 0.4,
                child: Image.asset(
                  asset,
                  height: 56,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.pets_rounded, size: 40),
                ),
              ),
              if (completed)
                const Positioned(
                  right: -4,
                  top: -4,
                  child: Icon(Icons.check_circle_rounded,
                      size: 18, color: AppTheme.success),
                ),
              if (!reached)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Icon(Icons.lock_rounded, size: 16, color: AppTheme.textLight),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.sm),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTheme.caption.copyWith(fontWeight: FontWeight.w700, color: color),
          ),
          if (current) ...[
            const SizedBox(height: 2),
            Text(
              'CURRENT',
              style: AppTheme.caption.copyWith(
                fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.primary),
            ),
          ],
        ],
      ),
    );
  }
}

/// A stage the real system doesn't define yet — no art, no name, no reward
/// text invented for it. Mirrors the locked-area treatment already used on
/// the Adventure Map (`AdventureIcons.locked`).
class _MysteryStageCard extends StatelessWidget {
  const _MysteryStageCard();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.45,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.md),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.shadowColor),
        ),
        child: Column(
          children: [
            SvgPicture.asset(AdventureIcons.locked, width: 40, height: 40),
            const SizedBox(height: AppTheme.sm),
            Text(
              '???',
              style: AppTheme.caption.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              'Coming Soon',
              style: AppTheme.caption.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnlockCard extends StatelessWidget {
  final String label;
  final String emoji;
  final String name;
  final bool unlocked;

  const _UnlockCard({
    required this.label,
    required this.emoji,
    required this.name,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: unlocked ? 1 : 0.5,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.md),
        decoration: BoxDecoration(
          color: unlocked ? AppTheme.successLight : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: unlocked ? AppTheme.success.withValues(alpha: 0.4) : AppTheme.shadowColor,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: AppTheme.sm),
            Text(
              label,
              style: AppTheme.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w700),
            ),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.caption.copyWith(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// One stat readout, matching the visual pattern of the Home screen's own
/// stat tiles (icon + tint + label + value).
class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.tint,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: const [
          BoxShadow(color: AppTheme.shadowColor, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: tint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.caption.copyWith(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sm),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.subheading.copyWith(fontSize: 19, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
