import 'package:flutter/material.dart';
import '../api_service.dart';
import '../theme/app_theme.dart';

class ParentDashboardScreen extends StatefulWidget {
  final String childId;
  final String childNickname;
  final String? parentUsername;

  const ParentDashboardScreen({
    super.key,
    required this.childId,
    required this.childNickname,
    this.parentUsername,
  });

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getReport(widget.childId);
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _backButton(context),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text('Failed to load report', style: AppTheme.subheading),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AppTheme.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadReport,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: AppTheme.primaryButton,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final data = _data!;
    final totalWords = (data['total_words'] as num? ?? 0).toInt();
    final totalScans = (data['total_scans'] as num? ?? 0).toInt();
    final quizAccuracy = (data['quiz_accuracy'] as num? ?? 0.0).toDouble();
    final words = (data['words'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final mistakes = (data['common_mistakes'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final recentActivity = (data['recent_activity'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    if (totalWords == 0) return _buildEmpty();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              const Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 6),
              Text(
                "${widget.childNickname}'s Progress",
                style: AppTheme.heading.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (widget.parentUsername != null) ...[
                const SizedBox(height: AppTheme.xs),
                Text(
                  'Logged in as ${widget.parentUsername}',
                  style: AppTheme.body.copyWith(
                    fontSize: 15,
                    color: AppTheme.textLight,
                  ),
                ),
              ],
              const SizedBox(height: AppTheme.xl),

              // ── Stat cards ──
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _StatCard(
                    icon: '📚',
                    label: 'Words Learned',
                    value: '$totalWords',
                    color: AppTheme.primary,
                  ),
                  _StatCard(
                    icon: '📷',
                    label: 'Total Scans',
                    value: '$totalScans',
                    color: AppTheme.secondary,
                  ),
                  _StatCard(
                    icon: '🎯',
                    label: 'Quiz Accuracy',
                    value: '${quizAccuracy.toStringAsFixed(0)}%',
                    color: AppTheme.success,
                  ),
                  _StatCard(
                    icon: '⚠️',
                    label: 'To Review',
                    value: '${mistakes.length}',
                    color: AppTheme.warningLight,
                    dark: true,
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Two-column panels ──
              LayoutBuilder(
                builder: (context, constraints) {
                  final left = _buildWordsPanel(words);
                  final right = _buildMistakesPanel(mistakes);
                  if (constraints.maxWidth > 580) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: left),
                        const SizedBox(width: AppTheme.lg),
                        Expanded(child: right),
                      ],
                    );
                  }
                  return Column(children: [
                    left,
                    const SizedBox(height: AppTheme.lg),
                    right,
                  ]);
                },
              ),

              // ── Recent activity ──
              if (recentActivity.isNotEmpty) ...[
                const SizedBox(height: AppTheme.lg),
                _buildRecentActivity(recentActivity),
              ],

              const SizedBox(height: AppTheme.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📚', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('No learning data yet!', style: AppTheme.subheading),
            const SizedBox(height: 8),
            Text(
              'Start scanning objects to track ${widget.childNickname}\'s progress.',
              textAlign: TextAlign.center,
              style: AppTheme.body.copyWith(color: AppTheme.textLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordsPanel(List<Map<String, dynamic>> words) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '✨ Words Learned',
            style: AppTheme.subheading.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          ...words.asMap().entries.map((e) {
            final i = e.key;
            final w = e.value;
            final key = w['english_key'] as String? ?? '';
            final accuracy = (w['accuracy'] as num? ?? 0).toDouble();
            final mastery = w['mastery'] as String? ?? 'learning';
            final isMastered = mastery == 'mastered';
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${i + 1}. ${_label(key)}',
                      style: AppTheme.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _Badge(
                    label: isMastered ? '⭐ Mastered' : '📖 Learning',
                    color: isMastered ? AppTheme.success : AppTheme.warning,
                  ),
                  const SizedBox(width: 6),
                  _Badge(
                    label: '${accuracy.toStringAsFixed(0)}%',
                    color: AppTheme.primary,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMistakesPanel(List<Map<String, dynamic>> mistakes) {
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
          if (mistakes.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '🎉 Great job! No words to review.',
                textAlign: TextAlign.center,
                style: AppTheme.body,
              ),
            )
          else ...[
            ...mistakes.asMap().entries.map((e) {
              final i = e.key;
              final w = e.value;
              final key = w['english_key'] as String? ?? '';
              final accuracy = (w['accuracy'] as num? ?? 0).toDouble();
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.lg, vertical: 14),
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
                    Expanded(
                      child: Text(
                        _label(key),
                        style: AppTheme.body.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    _Badge(
                      label: '${accuracy.toStringAsFixed(0)}%',
                      color: AppTheme.warning,
                    ),
                  ],
                ),
              );
            }),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.lg, vertical: AppTheme.md),
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
        ],
      ),
    );
  }

  Widget _buildRecentActivity(List<Map<String, dynamic>> activity) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🕐 Recent Activity',
            style: AppTheme.subheading.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          ...activity.map((a) {
            final key = a['english_key'] as String? ?? '';
            final confidence = (a['confidence'] as num? ?? 0).toDouble();
            final createdAt = a['created_at'] as String? ?? '';
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text('📷', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _label(key),
                          style: AppTheme.body
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Confidence: ${(confidence * 100).toStringAsFixed(0)}%  •  $createdAt',
                          style: AppTheme.caption.copyWith(fontSize: 11),
                        ),
                      ],
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

  /// Converts "remote_control" → "Remote Control".
  static String _label(String key) => key
      .split('_')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

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

// ── Shared widgets ────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: AppTheme.caption.copyWith(
          color: AppTheme.surface,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

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
            style: AppTheme.caption
                .copyWith(color: textColor.withValues(alpha: 0.85)),
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
