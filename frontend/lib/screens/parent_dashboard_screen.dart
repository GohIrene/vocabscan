import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Screen 7 – Parent Dashboard
/// Shows mock learning stats: words practised, mastered, accuracy, review list.
class ParentDashboardScreen extends StatelessWidget {
  final String? parentUsername;
  final String? childId;

  const ParentDashboardScreen({
    super.key,
    this.parentUsername,
    this.childId,
  });

  // ── Mock data ──
  static const _recentlyLearned = [
    {
      'word': 'Book',
      'english': 'Book',
      'malay': 'Buku',
      'chinese': '书',
      'accuracy': 100,
    },
    {
      'word': 'Pencil',
      'english': 'Pencil',
      'malay': 'Pensel',
      'chinese': '铅笔',
      'accuracy': 75,
    },
    {
      'word': 'Bottle',
      'english': 'Bottle',
      'malay': 'Botol',
      'chinese': '水瓶',
      'accuracy': 80,
    },
    {
      'word': 'Cup',
      'english': 'Cup',
      'malay': 'Cawan',
      'chinese': '杯子',
      'accuracy': 60,
    },
  ];

  static const _wordsToReview = ['Cup', 'Ruler', 'Remote Control'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _backButton(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      children: [
                        const Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 6),
                        Text(
                          childId != null
                              ? "$childId's Progress"
                              : 'Parent Dashboard',
                          style: AppTheme.heading.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppTheme.xs),
                        Text(
                          parentUsername != null
                              ? 'Logged in as $parentUsername'
                              : "Track your child's learning progress",
                          style: AppTheme.body.copyWith(
                            fontSize: 15,
                            color: AppTheme.textLight,
                          ),
                        ),
                        const SizedBox(height: AppTheme.xl),

                        // ── Stat cards row ──
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: const [
                            _StatCard(
                              icon: '📖',
                              label: 'Words Practiced',
                              value: '10',
                              color: AppTheme.primary,
                            ),
                            _StatCard(
                              icon: '🏆',
                              label: 'Mastered Words',
                              value: '6',
                              color: AppTheme.secondary,
                            ),
                            _StatCard(
                              icon: '🎯',
                              label: 'Quiz Accuracy',
                              value: '78%',
                              color: AppTheme.success,
                            ),
                            _StatCard(
                              icon: '⏰',
                              label: 'To Review',
                              value: '3',
                              color: AppTheme.warningLight,
                              dark: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // ── Two-column layout ──
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth > 580) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _recentlyLearnedPanel()),
                                  const SizedBox(width: AppTheme.lg),
                                  Expanded(child: _wordsToReviewPanel()),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                _recentlyLearnedPanel(),
                                const SizedBox(height: AppTheme.lg),
                                _wordsToReviewPanel(),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: AppTheme.xxl),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentlyLearnedPanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '✨ Recently Learned',
            style: AppTheme.subheading.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          ..._recentlyLearned.asMap().entries.map((e) {
            final i = e.key;
            final w = e.value;
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${i + 1}. ${w['word']}',
                          style: AppTheme.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: AppTheme.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.success,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${w['accuracy']}%',
                          style: AppTheme.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.surface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.sm),
                  Row(
                    children: [
                      _LangChip(
                        label: 'English',
                        value: w['english'] as String,
                      ),
                      const SizedBox(width: AppTheme.sm),
                      _LangChip(label: 'Malay', value: w['malay'] as String),
                      const SizedBox(width: AppTheme.sm),
                      _LangChip(
                        label: 'Chinese',
                        value: w['chinese'] as String,
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _wordsToReviewPanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📚 Words to Review',
            style: AppTheme.subheading.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          ..._wordsToReview.asMap().entries.map((e) {
            final i = e.key;
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.lg,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: AppTheme.warningLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.warning,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: AppTheme.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.surface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    e.value,
                    style: AppTheme.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: AppTheme.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.lg,
              vertical: AppTheme.md,
            ),
            decoration: BoxDecoration(
              color: AppTheme.warningLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '💡 Practice these words again to improve!',
              textAlign: TextAlign.center,
              style: AppTheme.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _backButton(BuildContext context) {
    return Align(
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
    );
  }
}

/// Small language chip with label + value.
class _LangChip extends StatelessWidget {
  final String label;
  final String value;

  const _LangChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.sm),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label, style: AppTheme.caption.copyWith(fontSize: 10)),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppTheme.body.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stat card for the top row.
class _StatCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color color;
  final bool dark;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = dark ? AppTheme.textDark : AppTheme.surface;
    return Container(
      width: 170,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$icon $label',
            style: AppTheme.caption.copyWith(
              color: textColor.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: AppTheme.sm),
          Text(
            value,
            style: AppTheme.heading.copyWith(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
