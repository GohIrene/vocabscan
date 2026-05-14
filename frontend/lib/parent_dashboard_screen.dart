import 'package:flutter/material.dart';

/// Screen 7 – Parent Dashboard
/// Shows mock learning stats: words practised, mastered, accuracy, review list.
class ParentDashboardScreen extends StatelessWidget {
  const ParentDashboardScreen({super.key});

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
      backgroundColor: const Color(0xFFF1ECFF),
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
                        const Text(
                          '👨‍👩‍👧‍👦',
                          style: TextStyle(fontSize: 48),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Parent Dashboard',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF17234D),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Track your child's learning progress",
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF65708C),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Stat cards row ──
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: const [
                            _StatCard(
                              icon: '📖',
                              label: 'Words Practiced',
                              value: '10',
                              color: Color(0xFF9B8CF2),
                            ),
                            _StatCard(
                              icon: '🏆',
                              label: 'Mastered Words',
                              value: '6',
                              color: Color(0xFF7EC8F2),
                            ),
                            _StatCard(
                              icon: '🎯',
                              label: 'Quiz Accuracy',
                              value: '78%',
                              color: Color(0xFF80DFA7),
                            ),
                            _StatCard(
                              icon: '⏰',
                              label: 'To Review',
                              value: '3',
                              color: Color(0xFFFFF3CD),
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
                                  const SizedBox(width: 16),
                                  Expanded(child: _wordsToReviewPanel()),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                _recentlyLearnedPanel(),
                                const SizedBox(height: 16),
                                _wordsToReviewPanel(),
                              ],
                            );
                          },
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

  Widget _recentlyLearnedPanel() {
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
            '✨ Recently Learned',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF17234D),
            ),
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
                color: const Color(0xFFF1ECFF),
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
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7C6CF2),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF80DFA7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${w['accuracy']}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _LangChip(
                        label: 'English',
                        value: w['english'] as String,
                      ),
                      const SizedBox(width: 8),
                      _LangChip(label: 'Malay', value: w['malay'] as String),
                      const SizedBox(width: 8),
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
            '📚 Words to Review',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF17234D),
            ),
          ),
          const SizedBox(height: 14),
          ..._wordsToReview.asMap().entries.map((e) {
            final i = e.key;
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFDD835),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    e.value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF17234D),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFCCBC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              '💡 Practice these words again to improve!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8B4513),
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
        padding: const EdgeInsets.all(12),
        child: TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Back'),
          style: TextButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF17234D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF65708C)),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF17234D),
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
    final textColor = dark ? const Color(0xFF17234D) : Colors.white;
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
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
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
