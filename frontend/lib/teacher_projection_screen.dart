import 'package:flutter/material.dart';
import 'theme/app_theme.dart';

/// Screen 8 – Teacher Projection Mode
/// Displays classroom stats, leaderboard, and class progress on a projector.
class TeacherProjectionScreen extends StatelessWidget {
  final String classCode;

  const TeacherProjectionScreen({super.key, required this.classCode});

  // ── Mock data ──
  static const _leaderboard = [
    {'name': 'Emma', 'rank': 1, 'score': 280, 'medal': '🥇'},
    {'name': 'Liam', 'rank': 2, 'score': 265, 'medal': '🥈'},
    {'name': 'Sophia', 'rank': 3, 'score': 250, 'medal': '🥉'},
    {'name': 'Noah', 'rank': 4, 'score': 235, 'medal': '⭐'},
    {'name': 'Olivia', 'rank': 5, 'score': 220, 'medal': '⭐'},
  ];

  static const _classProgress = [
    {'word': 'Book', 'done': 18, 'total': 24},
    {'word': 'Pencil', 'done': 15, 'total': 24},
    {'word': 'Ruler', 'done': 12, 'total': 24},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Exit button ──
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.md),
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Exit'),
                  style: AppTheme.backButtonStyle,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Column(
                      children: [
                        const Text('🏫', style: TextStyle(fontSize: 44)),
                        const SizedBox(height: AppTheme.xs),
                        Text(
                          'Teacher Projection',
                          style: AppTheme.heading.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          classCode,
                          style: AppTheme.body.copyWith(
                            fontSize: 15,
                            color: AppTheme.textLight,
                          ),
                        ),
                        const SizedBox(height: 22),

                        // ── Summary stat cards ──
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            _SummaryCard(
                              icon: '👥',
                              value: '24',
                              label: 'Total Students',
                              color: AppTheme.primary,
                            ),
                            _SummaryCard(
                              icon: '🎯',
                              value: '18',
                              label: 'Active Now',
                              color: AppTheme.success,
                            ),
                            _SummaryCard(
                              icon: '📚',
                              value: 'Book',
                              label: 'Current Object',
                              color: AppTheme.secondary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // ── Two columns ──
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth > 580) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _leaderboardPanel()),
                                  const SizedBox(width: AppTheme.lg),
                                  Expanded(child: _progressPanel()),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                _leaderboardPanel(),
                                const SizedBox(height: AppTheme.lg),
                                _progressPanel(),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        // ── Tip banner ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppTheme.lg,
                            horizontal: 20,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            '💡 Encourage students to practice pronunciation at home!',
                            textAlign: TextAlign.center,
                            style: AppTheme.caption.copyWith(
                              color: AppTheme.textLight,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
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

  // ── Leaderboard panel ──
  Widget _leaderboardPanel() {
    final rankColors = [
      AppTheme.warningLight,   // gold
      AppTheme.primaryLight,   // silver
      AppTheme.errorLight,     // bronze
      AppTheme.background,
      AppTheme.background,
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '👑 Top Learners',
            style: AppTheme.subheading.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          ..._leaderboard.asMap().entries.map((e) {
            final i = e.key;
            final s = e.value;
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.lg,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: rankColors[i],
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Text('${s['medal']}', style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: AppTheme.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${s['name']}',
                          style: AppTheme.body.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Rank #${s['rank']}',
                          style: AppTheme.caption,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${s['score']}',
                    style: AppTheme.subheading.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Class Progress panel ──
  Widget _progressPanel() {
    final totalDone = _classProgress.fold<int>(
      0,
      (sum, p) => sum + (p['done'] as int),
    );
    final totalAll = _classProgress.fold<int>(
      0,
      (sum, p) => sum + (p['total'] as int),
    );
    final overallPct = totalAll > 0
        ? (totalDone / totalAll * 100).toStringAsFixed(0)
        : '0';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📊 Class Progress',
            style: AppTheme.subheading.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          ..._classProgress.map((p) {
            final done = p['done'] as int;
            final total = p['total'] as int;
            final frac = total > 0 ? done / total : 0.0;
            final pct = (frac * 100).toStringAsFixed(0);
            return Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.lg),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${p['word']}',
                        style: AppTheme.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$done/$total',
                        style: AppTheme.caption,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Stack(
                    children: [
                      Container(
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: frac,
                        child: Container(
                          height: 22,
                          decoration: BoxDecoration(
                            color: AppTheme.success,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$pct%',
                            style: AppTheme.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.surface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),

          // Overall badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: 18,
              horizontal: AppTheme.lg,
            ),
            decoration: BoxDecoration(
              color: AppTheme.warningLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text('🌟', style: TextStyle(fontSize: 32)),
                const SizedBox(height: AppTheme.xs),
                Text(
                  'Great Job, Class!',
                  style: AppTheme.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                Text(
                  'Overall: $overallPct%',
                  style: AppTheme.caption.copyWith(color: AppTheme.textDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Summary stat card for the top row.
class _SummaryCard extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: AppTheme.sm),
          Text(
            value,
            style: AppTheme.heading.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppTheme.surface,
            ),
          ),
          const SizedBox(height: AppTheme.xs),
          Text(
            label,
            style: AppTheme.body.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.surface.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
