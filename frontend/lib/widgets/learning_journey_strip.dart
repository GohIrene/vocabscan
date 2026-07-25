import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../adventure_assets.dart';
import '../theme/app_theme.dart';

/// The six connected stages of one learning adventure, shown on the home
/// dashboard as an interactive guide rather than a static diagram.
///
/// Every stage does something real:
/// * **Scan** starts the actual guided flow ([onStartFlow]).
/// * **Reward** and **Area Grows** jump to the screens where those live
///   ([onOpenTreasure], [onOpenMap]).
/// * The in-flow steps (AI Recognizes, Learn & Speak, Quiz) can't be opened on
///   their own — they only exist mid-cycle — so tapping them explains what
///   happens and offers to start.
///
/// On a wide screen the stages sit in a horizontal row with arrow connectors;
/// on a narrow one they become a vertical stepper, so nothing overflows.
class LearningJourneyStrip extends StatelessWidget {
  /// Below this the strip becomes a vertical stepper instead of a row.
  static const double _stackBreakpoint = 680;

  final VoidCallback onStartFlow;
  final VoidCallback onOpenTreasure;
  final VoidCallback onOpenMap;

  const LearningJourneyStrip({
    super.key,
    required this.onStartFlow,
    required this.onOpenTreasure,
    required this.onOpenMap,
  });

  List<_Stage> _stages(BuildContext context) => [
        _Stage(
          index: 1,
          title: 'Scan',
          subtitle: 'Point your camera at any object',
          iconAsset: LearningIcons.scan,
          tint: AppTheme.primary,
          primary: true,
          onTap: onStartFlow,
        ),
        _Stage(
          index: 2,
          title: 'AI Recognizes',
          subtitle: 'We name what you found',
          iconAsset: LearningIcons.ai,
          tint: AppTheme.secondary,
          onTap: () => _explain(
            context,
            title: 'AI Recognizes',
            body: 'After you scan, VocabScan looks at your photo and tells you '
                'what the object is — like "Chair" or "Apple".',
          ),
        ),
        _Stage(
          index: 3,
          title: 'Learn & Speak',
          subtitle: 'Hear it in 3 languages and say it',
          iconAsset: LearningIcons.speech,
          tint: AppTheme.success,
          onTap: () => _explain(
            context,
            title: 'Learn & Speak',
            body: 'You hear the word in English, Malay and Chinese, then press '
                'the microphone and say it out loud to practise.',
          ),
        ),
        _Stage(
          index: 4,
          title: 'Quiz',
          subtitle: 'A quick game to check',
          iconAsset: LearningIcons.quiz,
          tint: AppTheme.warning,
          onTap: () => _explain(
            context,
            title: 'Quiz',
            body: 'A short multiple-choice game makes sure you remember the new '
                'word before you move on.',
          ),
        ),
        _Stage(
          index: 5,
          title: 'Reward',
          subtitle: 'Earn XP, keys and stickers',
          iconAsset: LearningIcons.reward,
          tint: AppTheme.treasure,
          onTap: onOpenTreasure,
        ),
        _Stage(
          index: 6,
          title: 'Area Grows',
          subtitle: 'Your adventure world grows',
          iconAsset: LearningIcons.growth,
          tint: AppTheme.adventure,
          onTap: onOpenMap,
        ),
      ];

  Future<void> _explain(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        title: Text(title,
            style: AppTheme.subheading.copyWith(fontWeight: FontWeight.w800)),
        content: Text(body, style: AppTheme.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Got it'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onStartFlow();
            },
            style: AppTheme.smallButton,
            child: const Text('Start Scanning'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stages = _stages(context);

    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: const [
          BoxShadow(
              color: AppTheme.shadowColor, blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How Your Adventure Works',
            style: AppTheme.subheading.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Tap a step to try it or learn what it does.',
            style: AppTheme.caption,
          ),
          const SizedBox(height: AppTheme.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < _stackBreakpoint) {
                return _VerticalStepper(stages: stages);
              }
              return _HorizontalRow(stages: stages);
            },
          ),
        ],
      ),
    );
  }
}

/// Wide layout: fixed-width cards in a horizontal scroll, arrows between.
class _HorizontalRow extends StatelessWidget {
  final List<_Stage> stages;
  const _HorizontalRow({required this.stages});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < stages.length; i++) ...[
              SizedBox(width: 168, child: _StageCard(stage: stages[i])),
              if (i < stages.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Center(
                    child: Icon(Icons.arrow_forward_rounded,
                        size: 18, color: AppTheme.textLight),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Narrow layout: cards stacked with downward arrows.
class _VerticalStepper extends StatelessWidget {
  final List<_Stage> stages;
  const _VerticalStepper({required this.stages});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < stages.length; i++) ...[
          _StageCard(stage: stages[i]),
          if (i < stages.length - 1)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Icon(Icons.arrow_downward_rounded,
                  size: 18, color: AppTheme.textLight),
            ),
        ],
      ],
    );
  }
}

/// One reusable stage card, topped with the step's flat-vector illustration
/// (see [LearningIcons]).
class _StageCard extends StatefulWidget {
  final _Stage stage;
  const _StageCard({required this.stage});

  @override
  State<_StageCard> createState() => _StageCardState();
}

class _StageCardState extends State<_StageCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final stage = widget.stage;
    final primary = stage.primary;

    return Semantics(
      button: true,
      label: '${stage.title}. ${stage.subtitle}',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: stage.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(AppTheme.md),
            transform: _hovering
                ? (Matrix4.identity()..translateByDouble(0.0, -4.0, 0.0, 1.0))
                : Matrix4.identity(),
            decoration: BoxDecoration(
              color: primary ? null : AppTheme.background,
              gradient: primary
                  ? const LinearGradient(
                      colors: [AppTheme.primary, Color(0xFF6B4EFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: primary
                    ? Colors.transparent
                    : stage.tint.withValues(alpha: 0.2),
              ),
              boxShadow: _hovering
                  ? [
                      BoxShadow(
                        color: stage.tint.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: primary
                            ? Colors.white.withValues(alpha: 0.25)
                            : stage.tint.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${stage.index}',
                        style: AppTheme.caption.copyWith(
                          fontWeight: FontWeight.w800,
                          color: primary ? Colors.white : stage.tint,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // The step's flat-vector illustration. Self-coloured, so it
                    // isn't tinted to match the card — it reads as a little
                    // app-icon tile in either the plain or primary card.
                    SvgPicture.asset(
                      stage.iconAsset,
                      width: 30,
                      height: 30,
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.md),
                Text(
                  stage.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.body.copyWith(
                    fontWeight: FontWeight.w800,
                    color: primary ? Colors.white : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  stage.subtitle,
                  style: AppTheme.caption.copyWith(
                    fontSize: 12,
                    color: primary
                        ? Colors.white.withValues(alpha: 0.9)
                        : AppTheme.textLight,
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

/// Immutable description of one stage in the guide.
class _Stage {
  final int index;
  final String title;
  final String subtitle;
  final String iconAsset;
  final Color tint;
  final bool primary;
  final VoidCallback onTap;

  const _Stage({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.iconAsset,
    required this.tint,
    required this.onTap,
    this.primary = false,
  });
}
