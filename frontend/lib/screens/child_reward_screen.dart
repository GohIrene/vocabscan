import 'package:flutter/material.dart';

import '../adventure_config.dart';
import '../api_service.dart';
import '../learning_flow.dart';
import '../theme/app_theme.dart';
import '../widgets/child_avatar.dart';
import 'child_adventure_area_screen.dart';

/// The payoff at the end of one guided learning cycle.
///
/// This is the only screen that calls `POST /learning/complete`, and it calls
/// it once per cycle using the cycle's `completionId`. The endpoint is
/// idempotent on that id, so retrying after a failure — or a child hammering
/// the button — replays the original reward instead of awarding it twice.
///
/// PHASE 5 SCOPE: shows every reward the backend reports. Phase 6 restyles it
/// and adds the Treasure Album entry point.
class ChildRewardScreen extends StatefulWidget {
  final LearningCycle cycle;
  final Map<String, dynamic> vocab;

  /// The child's buddy, so an evolution can be shown with the right artwork.
  final String? avatarId;

  const ChildRewardScreen({
    super.key,
    required this.cycle,
    required this.vocab,
    this.avatarId,
  });

  @override
  State<ChildRewardScreen> createState() => _ChildRewardScreenState();
}

class _ChildRewardScreenState extends State<ChildRewardScreen> {
  Map<String, dynamic>? _result;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _submit();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cycle = widget.cycle;
      final result = await ApiService.completeLearning(
        childId: cycle.childId,
        // Minted once when the cycle began — this is what makes a retry safe.
        completionId: cycle.completionId,
        englishKey: widget.vocab['english_key'] as String? ?? '',
        speech: (cycle.speech ?? const SpeechOutcome()).toJson(),
        quiz: (cycle.quiz ?? const QuizOutcome()).toJson(),
      );
      if (!mounted) return;
      setState(() {
        _result = result;
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

  Map<String, dynamic> _section(String key) =>
      (_result?[key] as Map?)?.cast<String, dynamic>() ?? const {};

  void _scanAgain() {
    // Back to where the cycle began — ChildHome or the area screen — which
    // starts a fresh cycle with a fresh completion id on the next tap. This
    // is a new word to learn, not a retry of the one just finished.
    widget.cycle.returnToStart(context);
  }

  /// Unwinds the flow, then opens the area that just grew.
  void _viewArea() {
    final areaId = _section('adventure')['area_id'] as String?;
    final navigator = Navigator.of(context);
    widget.cycle.returnToStart(context);
    if (areaId == null || areaId.isEmpty) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ChildAdventureAreaScreen(
          childId: widget.cycle.childId,
          areaId: areaId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : _buildReward(),
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
            const Text('🎁', style: TextStyle(fontSize: 56)),
            const SizedBox(height: AppTheme.lg),
            Text("We couldn't save your reward",
                textAlign: TextAlign.center,
                style:
                    AppTheme.subheading.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppTheme.sm),
            Text(
              'Your learning still counted — try again in a moment.',
              textAlign: TextAlign.center,
              style: AppTheme.caption,
            ),
            const SizedBox(height: AppTheme.xl),
            FilledButton.icon(
              // Safe to retry: the same completion id either applies the
              // reward once or replays what was already applied.
              onPressed: _submit,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: AppTheme.primaryButton,
            ),
            const SizedBox(height: AppTheme.md),
            TextButton(
              onPressed: _scanAgain,
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReward() {
    final rewards = _section('rewards');
    final avatar = _section('avatar');
    final adventure = _section('adventure');
    final isNew = _result?['is_new_word'] == true;
    final xp = (rewards['xp_earned'] as num?)?.toInt() ?? 0;
    final areaPoints = (rewards['area_points_earned'] as num?)?.toInt() ?? 0;
    // Bonus practice in extra languages is called out on its own line, since
    // it's the one reward a child chose to go and earn.
    final breakdown =
        (rewards['xp_breakdown'] as Map?)?.cast<String, dynamic>() ?? const {};
    final spokenLanguages =
        (_section('speech')['languages_succeeded'] as num?)?.toInt() ?? 0;
    final speechBonus = (breakdown['speech_bonus'] as num?)?.toInt() ?? 0;
    final evolved = avatar['evolved'] == true;
    final areaCompleted = adventure['area_completed'] == true;
    // Keys are derived from progress, so a gain here means a stage boundary
    // was crossed — the same moment a new decoration appears.
    final keysGained = ((adventure['keys'] as num?)?.toInt() ?? 0) -
        ((adventure['previous_keys'] as num?)?.toInt() ?? 0);
    final decorationUnlocked = adventure['decoration_unlocked'] == true;
    final nextArea = adventure['next_area_unlocked'] as String?;
    final theme = areaThemeById(adventure['area_id'] as String?);
    final english = widget.vocab['english_word'] as String? ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              const SizedBox(height: AppTheme.xl),
              const Text('🎉', style: TextStyle(fontSize: 60)),
              const SizedBox(height: AppTheme.sm),
              Text(
                isNew ? 'New word learned!' : 'Great practice!',
                textAlign: TextAlign.center,
                style: AppTheme.heading.copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppTheme.xs),
              Text(
                isNew
                    ? 'You added "$english" to your Treasure Album'
                    : 'You practised "$english" again',
                textAlign: TextAlign.center,
                style: AppTheme.body.copyWith(color: AppTheme.textLight),
              ),
              const SizedBox(height: AppTheme.xl),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.xl),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  children: [
                    _RewardRow(
                        emoji: '⭐',
                        label: 'XP earned',
                        value: '+$xp',
                        tint: AppTheme.treasure),
                    if (rewards['new_treasure'] == true) ...[
                      const SizedBox(height: AppTheme.md),
                      _RewardRow(
                          emoji: '🎁',
                          label: 'Treasure added',
                          value: '+1',
                          tint: AppTheme.secondary),
                    ],
                    if (spokenLanguages > 0) ...[
                      const SizedBox(height: AppTheme.md),
                      _RewardRow(
                        emoji: '🗣️',
                        label: spokenLanguages == 1
                            ? 'Said in 1 language'
                            : 'Said in $spokenLanguages languages!',
                        value: '+$speechBonus',
                        tint: AppTheme.primary,
                      ),
                    ],
                    if (areaPoints > 0) ...[
                      const SizedBox(height: AppTheme.md),
                      _RewardRow(
                        emoji: theme.emoji,
                        label: '${theme.name} grew',
                        value: '+$areaPoints%',
                        tint: theme.accent,
                      ),
                    ],
                    if (keysGained > 0) ...[
                      const SizedBox(height: AppTheme.md),
                      _RewardRow(
                        emoji: '🔑',
                        label: keysGained == 1 ? 'New key' : 'New keys',
                        value: '+$keysGained',
                        tint: AppTheme.treasure,
                      ),
                    ],
                  ],
                ),
              ),

              if (areaPoints > 0) ...[
                const SizedBox(height: AppTheme.lg),
                _AreaGrowth(
                  theme: theme,
                  from: (adventure['previous_progress'] as num?)?.toInt() ?? 0,
                  to: (adventure['current_progress'] as num?)?.toInt() ?? 0,
                  stage: (adventure['visual_stage'] as num?)?.toInt() ?? 0,
                  previousStage:
                      (adventure['previous_visual_stage'] as num?)?.toInt() ?? 0,
                  decorationUnlocked: decorationUnlocked,
                ),
              ],

              if (evolved) ...[
                const SizedBox(height: AppTheme.lg),
                _Celebration(
                  tint: AppTheme.primary,
                  child: Column(
                    children: [
                      ChildAvatar(
                        avatarId:
                            widget.avatarId ?? avatar['avatar_id'] as String?,
                        stage: (avatar['current_stage'] as num?)?.toInt() ?? 1,
                        size: 92,
                        showStageBadge: true,
                      ),
                      const SizedBox(height: AppTheme.sm),
                      Text(
                        'Your buddy grew to Stage '
                        '${(avatar['current_stage'] as num?)?.toInt() ?? 1}!',
                        textAlign: TextAlign.center,
                        style: AppTheme.subheading.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (areaCompleted) ...[
                const SizedBox(height: AppTheme.lg),
                _Celebration(
                  tint: AppTheme.success,
                  child: Column(
                    children: [
                      Text('${theme.emoji} ${theme.name} is complete!',
                          textAlign: TextAlign.center,
                          style: AppTheme.subheading.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.success,
                          )),
                      if (nextArea != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${areaThemeById(nextArea).name} is now unlocked!',
                          textAlign: TextAlign.center,
                          style: AppTheme.caption
                              .copyWith(color: AppTheme.textDark),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppTheme.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _scanAgain,
                  icon: const Icon(Icons.photo_camera_rounded, size: 20),
                  label: const Text('Scan Another Object'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 58),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    textStyle: AppTheme.buttonText.copyWith(fontSize: 17),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.md),
              OutlinedButton.icon(
                onPressed: _viewArea,
                icon: const Icon(Icons.map_rounded, size: 18),
                label: Text('View ${theme.name}'),
                style: AppTheme.secondaryButton,
              ),
              const SizedBox(height: AppTheme.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final Color tint;

  const _RewardRow({
    required this.emoji,
    required this.label,
    required this.value,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: AppTheme.md),
        Expanded(
          child: Text(label,
              style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
        ),
        Text(
          value,
          style: AppTheme.subheading.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: tint,
          ),
        ),
      ],
    );
  }
}

/// The area's progress bar, shown at its new value with the old one marked,
/// so the growth is visible rather than just asserted.
class _AreaGrowth extends StatelessWidget {
  final AreaTheme theme;
  final int from;
  final int to;
  final int stage;
  final int previousStage;

  /// True when this cycle crossed a stage boundary, so a decoration that
  /// wasn't there before has appeared.
  final bool decorationUnlocked;

  const _AreaGrowth({
    required this.theme,
    required this.from,
    required this.to,
    required this.stage,
    required this.previousStage,
    required this.decorationUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: theme.tint,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: theme.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(theme.name,
                    style:
                        AppTheme.body.copyWith(fontWeight: FontWeight.w800)),
              ),
              Text('$from% → $to%',
                  style: AppTheme.caption.copyWith(
                      fontWeight: FontWeight.w700, color: AppTheme.textDark)),
            ],
          ),
          const SizedBox(height: AppTheme.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: to / 100,
              minHeight: 12,
              backgroundColor: theme.accent.withValues(alpha: 0.18),
              color: theme.accent,
            ),
          ),
          const SizedBox(height: AppTheme.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < theme.decorations.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _Decoration(
                    emoji: theme.decorations[i],
                    earned: i < stage,
                    // The one that appeared just now, highlighted so the
                    // child can see exactly what they added.
                    isNew: i >= previousStage && i < stage,
                    accent: theme.accent,
                  ),
                ),
            ],
          ),
          if (decorationUnlocked) ...[
            const SizedBox(height: AppTheme.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('✨', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  'Something new appeared in ${theme.name}!',
                  style: AppTheme.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.accent,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Decoration extends StatelessWidget {
  final String emoji;
  final bool earned;
  final bool isNew;
  final Color accent;

  const _Decoration({
    required this.emoji,
    required this.earned,
    required this.isNew,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final item = Opacity(
      opacity: earned ? 1 : 0.22,
      child: Text(emoji, style: TextStyle(fontSize: earned ? 26 : 20)),
    );
    if (!isNew) return item;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: accent, width: 2),
      ),
      child: item,
    );
  }
}

class _Celebration extends StatelessWidget {
  final Color tint;
  final Widget child;

  const _Celebration({required this.tint, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: tint.withValues(alpha: 0.4), width: 2),
      ),
      child: child,
    );
  }
}
