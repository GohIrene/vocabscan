import 'package:flutter/material.dart';
import '../adventure_config.dart';
import '../api_service.dart';
import '../avatar_config.dart';
import '../theme/app_theme.dart';
import '../widgets/child_avatar.dart';
import 'revision_quiz_screen.dart';

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

  /// Buddy, XP, treasures, streak and adventure standing.
  ///
  /// Reads the `profile` block the report now returns. Renders nothing at all
  /// when it's absent, so an older backend still shows the original report
  /// rather than an empty panel.
  Widget _buildAdventureOverview() {
    final profile = (_data?['profile'] as Map?)?.cast<String, dynamic>();
    if (profile == null) return const SizedBox.shrink();

    final avatar =
        (profile['avatar'] as Map?)?.cast<String, dynamic>() ?? const {};
    final adventure =
        (profile['adventure'] as Map?)?.cast<String, dynamic>() ?? const {};
    final stage = (avatar['stage'] as num?)?.toInt() ?? 1;
    final totalXp = (avatar['total_xp'] as num?)?.toInt() ?? 0;
    final nextXp = (avatar['next_stage_xp'] as num?)?.toInt();
    final theme = areaThemeById(adventure['current_area_id'] as String?);
    final progress = (adventure['progress_percentage'] as num?)?.toInt() ?? 0;
    final completed = (adventure['completed_areas'] as num?)?.toInt() ?? 0;
    final areaCount = (adventure['area_count'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.lg),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: const [
              BoxShadow(color: AppTheme.shadowColor, blurRadius: 14,
                  offset: Offset(0, 5)),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  ChildAvatar(
                    avatarId: avatar['avatar_id'] as String?,
                    stage: stage,
                    size: 62,
                    showStageBadge: true,
                  ),
                  const SizedBox(width: AppTheme.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${avatarByIdOrDefault(avatar['avatar_id'] as String?).displayName}'
                          ' · Stage $stage',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.body
                              .copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            // Null once fully grown — a filled bar reads
                            // better than progress toward nothing.
                            value: nextXp == null || nextXp == 0
                                ? 1.0
                                : (totalXp / nextXp).clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor:
                                AppTheme.primary.withValues(alpha: 0.15),
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          nextXp == null
                              ? '$totalXp XP · fully grown'
                              : '$totalXp / $nextXp XP to next stage',
                          style: AppTheme.caption.copyWith(fontSize: 11),
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
                    child: Text(
                      'Adventure: ${theme.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.caption
                          .copyWith(color: AppTheme.textDark),
                    ),
                  ),
                  Text('$progress%',
                      style: AppTheme.caption.copyWith(
                          fontWeight: FontWeight.w800, color: theme.accent)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress / 100,
                  minHeight: 10,
                  backgroundColor: theme.accent.withValues(alpha: 0.18),
                  color: theme.accent,
                ),
              ),
              const SizedBox(height: AppTheme.md),
              Wrap(
                spacing: 14,
                runSpacing: 10,
                children: [
                  _MiniFact(
                      emoji: '🎁',
                      label: 'Treasures',
                      value: '${profile['treasure_count'] ?? 0}'),
                  _MiniFact(
                      emoji: '🔥',
                      label: 'Streak',
                      value: '${profile['streak_days'] ?? 0} days'),
                  _MiniFact(
                      emoji: '🗺️',
                      label: 'Areas done',
                      value: '$completed / $areaCount'),
                  _MiniFact(
                      emoji: '🔑',
                      label: 'Keys here',
                      value: '${adventure['keys'] ?? 0}'),
                  _MiniFact(
                      emoji: '🏆',
                      label: 'Achievements',
                      value: '${profile['achievement_count'] ?? 0}'
                          ' / ${profile['achievement_total'] ?? 0}'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/icons/family.png',
                    width: 48,
                    height: 48,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.people, size: 48);
                    },
                  ),
                  const SizedBox(width: AppTheme.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${widget.childNickname}'s Progress",
                          style: AppTheme.heading.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          "Overview of ${widget.childNickname}'s learning journey",
                          style: AppTheme.body.copyWith(
                            fontSize: 15,
                            color: AppTheme.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.xl),

              // ── Home Adventure standing ──
              // Added above the original stat cards rather than replacing
              // them: everything below here — the day-by-day chart, mastery
              // lists, common mistakes and both revision entry points —
              // continues to work exactly as before.
              _buildAdventureOverview(),

              // ── Stat cards ──
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _StatCard(
                    icon: 'assets/icons/book.png',
                    label: 'Words Learned',
                    value: '$totalWords',
                    caption: 'Total words',
                    color: AppTheme.primary,
                  ),
                  _StatCard(
                    icon: 'assets/icons/camera.png',
                    label: 'Total Scans',
                    value: '$totalScans',
                    caption: 'Scans completed',
                    color: AppTheme.secondary,
                  ),
                  _StatCard(
                    icon: 'assets/icons/target.png',
                    label: 'Quiz Accuracy',
                    value: '${quizAccuracy.toStringAsFixed(0)}%',
                    caption: 'Overall accuracy',
                    color: AppTheme.success,
                  ),
                  _StatCard(
                    icon: 'assets/icons/star.png',
                    label: 'To Review',
                    value: '${mistakes.length}',
                    caption: 'Words to review',
                    color: AppTheme.warning,
                  ),
                  _StatCard(
                    icon: 'assets/icons/calendar.png',
                    label: 'Active Days',
                    value: '$activeDays',
                    caption: 'This week',
                    color: AppTheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Revise everything learned so far ──
              FilledButton.icon(
                onPressed: () => _revise(),
                icon: const Icon(Icons.refresh, size: 20),
                label: Text('Revise ${widget.childNickname}\'s Words'),
                style: AppTheme.primaryButton,
              ),
              const SizedBox(height: 28),

              // ── Day-by-day progress + recent activity, side by side ──
              if (daily.isNotEmpty || recentActivity.isNotEmpty) ...[
                LayoutBuilder(
                  builder: (context, constraints) {
                    final left = daily.isNotEmpty ? _buildDailyPanel(daily) : null;
                    final right = recentActivity.isNotEmpty
                        ? _buildRecentActivity(recentActivity)
                        : null;
                    if (left != null && right != null) {
                      if (constraints.maxWidth > 700) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: left),
                            const SizedBox(width: AppTheme.lg),
                            Expanded(flex: 2, child: right),
                          ],
                        );
                      }
                      return Column(children: [
                        left,
                        const SizedBox(height: AppTheme.lg),
                        right,
                      ]);
                    }
                    return left ?? right!;
                  },
                ),
                const SizedBox(height: AppTheme.lg),
              ],

              // ── Words learned / words to review ──
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/icons/calendar.png',
                width: 20,
                height: 20,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(width: 20, height: 20);
                },
              ),
              const SizedBox(width: 8),
              Text(
                'Day-by-Day Progress',
                style: AppTheme.subheading.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tap a day to revise the words learned that day ',
                style: AppTheme.caption.copyWith(fontSize: 12),
              ),
              Image.asset(
                'assets/icons/repeat.png',
                width: 12,
                height: 12,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(width: 12, height: 12);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

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
            // Only days that actually produced words can be revised.
            final canRevise = wordsPractised > 0;
            final label = '$weekday, ${_prettyDate(date)}';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: canRevise
                      ? () => _revise(date: date, dateLabel: label)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
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
                        _Badge(
                          label: '$scans',
                          color: AppTheme.secondary,
                          iconPath: 'assets/icons/camera.png',
                        ),
                        const SizedBox(width: 6),
                        _Badge(
                          label: '$wordsPractised',
                          color: AppTheme.primary,
                          iconPath: 'assets/icons/book.png',
                        ),
                        if (attempts > 0) ...[
                          const SizedBox(width: 6),
                          _Badge(
                            label: '${accuracy.toStringAsFixed(0)}%',
                            color: accuracy >= 80
                                ? AppTheme.success
                                : AppTheme.warning,
                          ),
                        ],
                        if (canRevise) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right,
                              size: 18, color: AppTheme.primary),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Opens a revision quiz. [date] null revises everything the child has
  /// learned; otherwise only the words from that local (GMT+8) day. Refreshes
  /// the report afterwards so new attempts show up in the stats immediately.
  Future<void> _revise({String? date, String? dateLabel}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RevisionQuizScreen(
          childId: widget.childId,
          childNickname: widget.childNickname,
          date: date,
          dateLabel: dateLabel,
        ),
      ),
    );
    if (mounted) _loadReport();
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/icons/sparkles.png',
                width: 20,
                height: 20,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(width: 20, height: 20);
                },
              ),
              const SizedBox(width: 8),
              Text(
                'Words Learned',
                style: AppTheme.subheading.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
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
                    label: isMastered ? 'Mastered' : 'Learning',
                    color: isMastered ? AppTheme.success : AppTheme.warning,
                    iconPath: isMastered
                        ? 'assets/icons/star.png'
                        : 'assets/icons/book.png',
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/icons/book.png',
                width: 20,
                height: 20,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(width: 20, height: 20);
                },
              ),
              const SizedBox(width: 8),
              Text(
                'Words to Review',
                style: AppTheme.subheading.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/icons/confetti.png',
                    width: 20,
                    height: 20,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox(width: 20, height: 20);
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Great job! No words to review.',
                      textAlign: TextAlign.center,
                      style: AppTheme.body,
                    ),
                  ),
                ],
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/icons/lightbulb.png',
                    width: 16,
                    height: 16,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox(width: 16, height: 16);
                    },
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Practice these words again to improve!',
                      textAlign: TextAlign.center,
                      style: AppTheme.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                ],
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
                  Image.asset(
                    'assets/icons/camera.png',
                    width: 20,
                    height: 20,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.camera_alt, size: 20);
                    },
                  ),
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
  final String? iconPath;

  const _Badge({
    required this.label,
    required this.color,
    this.iconPath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: iconPath != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  iconPath!,
                  width: 11,
                  height: 11,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox(width: 11, height: 11);
                  },
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.surface,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            )
          : Text(
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
  final String caption;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Image.asset(
                  icon,
                  width: 20,
                  height: 20,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Text(
                    '?',
                    style: TextStyle(fontSize: 16, color: color),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  style: AppTheme.caption.copyWith(fontSize: 12.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.md),
          Text(
            value,
            style: AppTheme.heading.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: AppTheme.caption.copyWith(fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

/// One emoji-labelled fact in the adventure overview.
class _MiniFact extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;

  const _MiniFact({
    required this.emoji,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.md, vertical: AppTheme.sm),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: AppTheme.body.copyWith(
                      fontWeight: FontWeight.w800, fontSize: 14)),
              Text(label, style: AppTheme.caption.copyWith(fontSize: 10.5)),
            ],
          ),
        ],
      ),
    );
  }
}
