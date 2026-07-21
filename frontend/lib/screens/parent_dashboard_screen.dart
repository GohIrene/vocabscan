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
    // Newest day first, already bucketed by Malaysian (GMT+8) calendar day.
    final daily = (data['daily'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final activeDays = (data['active_days'] as num? ?? 0).toInt();

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
                  _StatCard(
                    icon: '📅',
                    label: 'Active Days',
                    value: '$activeDays',
                    color: const Color(0xFF8B5CF6), // violet
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Day-by-day progress ──
              if (daily.isNotEmpty) ...[
                _buildDailyPanel(daily),
                const SizedBox(height: AppTheme.lg),
              ],

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

  /// Day-by-day progress: a compact scans-per-day bar chart over the most
  /// recent fortnight, then a detail row per day. All days are Malaysian
  /// (GMT+8) calendar days — the backend has already applied the offset.
  Widget _buildDailyPanel(List<Map<String, dynamic>> daily) {
    // `daily` arrives newest-first; the chart reads left→right like a calendar.
    final chartDays = daily.take(14).toList().reversed.toList();
    var maxScans = 1;
    for (final d in chartDays) {
      final s = (d['scans'] as num? ?? 0).toInt();
      if (s > maxScans) maxScans = s;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📅 Day-by-Day Progress',
            style: AppTheme.subheading.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            'Scans per day • Malaysia time (GMT+8)',
            style: AppTheme.caption.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 16),

          // ── Bar chart ──
          SizedBox(
            height: 132,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: chartDays.map((d) {
                final scans = (d['scans'] as num? ?? 0).toInt();
                final weekday = d['weekday'] as String? ?? '';
                final date = d['date'] as String? ?? '';
                // Floor of 4px keeps zero-activity days visible as a stub.
                final barHeight =
                    scans == 0 ? 4.0 : 4.0 + (scans / maxScans) * 86.0;
                return Expanded(
                  child: Tooltip(
                    message: '$weekday, ${_prettyDate(date)}\n'
                        '$scans scan${scans == 1 ? '' : 's'}',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '$scans',
                            style: AppTheme.caption.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: scans == 0
                                  ? AppTheme.textLight
                                  : AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: scans == 0
                                  ? AppTheme.primaryLight
                                  : AppTheme.primary,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            weekday.isEmpty ? '' : weekday.substring(0, 3),
                            style: AppTheme.caption.copyWith(fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),

          // ── Per-day detail rows ──
          ...daily.take(10).map((d) {
            final weekday = d['weekday'] as String? ?? '';
            final date = d['date'] as String? ?? '';
            final scans = (d['scans'] as num? ?? 0).toInt();
            final wordsPractised =
                (d['words_practised'] as num? ?? 0).toInt();
            final accuracy = (d['accuracy'] as num? ?? 0).toDouble();
            final attempts = ((d['quiz_attempts'] as num? ?? 0) +
                    (d['speech_attempts'] as num? ?? 0))
                .toInt();
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          weekday,
                          style: AppTheme.body
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          _prettyDate(date),
                          style: AppTheme.caption.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  _Badge(label: '📷 $scans', color: AppTheme.secondary),
                  const SizedBox(width: 6),
                  _Badge(label: '📚 $wordsPractised', color: AppTheme.primary),
                  if (attempts > 0) ...[
                    const SizedBox(width: 6),
                    _Badge(
                      label: '${accuracy.toStringAsFixed(0)}%',
                      color: accuracy >= 80
                          ? AppTheme.success
                          : AppTheme.warning,
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// "2026-07-21" → "21 Jul 2026".
  static String _prettyDate(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final month = int.tryParse(parts[1]) ?? 0;
    if (month < 1 || month > 12) return iso;
    final day = int.tryParse(parts[2]) ?? 0;
    return '$day ${months[month - 1]} ${parts[0]}';
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
            // Backend supplies these pre-converted to Malaysia time (GMT+8);
            // the raw created_at is UTC and would read 8 hours behind.
            final weekday = a['local_weekday'] as String? ?? '';
            final localDate = a['local_date'] as String? ?? '';
            final localTime = a['local_time'] as String? ?? '';
            final when = localDate.isEmpty
                ? (a['created_at'] as String? ?? '')
                : '$weekday, ${_prettyDate(localDate)} · $localTime';
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
                          'Confidence: ${(confidence * 100).toStringAsFixed(0)}%  •  $when',
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
