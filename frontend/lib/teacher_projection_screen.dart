import 'package:flutter/material.dart';

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
      backgroundColor: const Color(0xFFF1ECFF),
      body: SafeArea(
        child: Column(
          children: [
            // ── Exit button ──
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Exit'),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF17234D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
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
                        const SizedBox(height: 4),
                        const Text(
                          'Teacher Projection',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF17234D),
                          ),
                        ),
                        Text(
                          classCode,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF65708C),
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
                              color: const Color(0xFF9B8CF2),
                            ),
                            _SummaryCard(
                              icon: '🎯',
                              value: '18',
                              label: 'Active Now',
                              color: const Color(0xFF80DFA7),
                            ),
                            _SummaryCard(
                              icon: '📚',
                              value: 'Book',
                              label: 'Current Object',
                              color: const Color(0xFF7EC8F2),
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
                                  const SizedBox(width: 16),
                                  Expanded(child: _progressPanel()),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                _leaderboardPanel(),
                                const SizedBox(height: 16),
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
                            vertical: 16,
                            horizontal: 20,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0DCF0),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Text(
                            '💡 Encourage students to practice pronunciation at home!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF4D5573),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
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
    // Different background colours per rank
    const rankColors = [
      Color(0xFFFFF8E1), // gold
      Color(0xFFE8E4F0), // silver
      Color(0xFFFFE0CC), // bronze
      Color(0xFFF1ECFF),
      Color(0xFFF1ECFF),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '👑 Top Learners',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF17234D),
            ),
          ),
          const SizedBox(height: 14),
          ..._leaderboard.asMap().entries.map((e) {
            final i = e.key;
            final s = e.value;
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: rankColors[i],
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Text('${s['medal']}', style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${s['name']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF17234D),
                          ),
                        ),
                        Text(
                          'Rank #${s['rank']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF65708C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${s['score']}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF17234D),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 Class Progress',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF17234D),
            ),
          ),
          const SizedBox(height: 14),
          ..._classProgress.map((p) {
            final done = p['done'] as int;
            final total = p['total'] as int;
            final frac = total > 0 ? done / total : 0.0;
            final pct = (frac * 100).toStringAsFixed(0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${p['word']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF17234D),
                        ),
                      ),
                      Text(
                        '$done/$total',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF65708C),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Stack(
                    children: [
                      Container(
                        height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0DCF0),
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: frac,
                        child: Container(
                          height: 22,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$pct%',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
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
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFCCBC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text('🌟', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 4),
                const Text(
                  'Great Job, Class!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8B4513),
                  ),
                ),
                Text(
                  'Overall: $overallPct%',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8B4513),
                  ),
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
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
