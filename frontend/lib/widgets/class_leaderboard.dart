import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shared leaderboard for the end of a Class Code session.
///
/// Rows are sorted by score descending. 🥇🥈🥉 mark the top three. When
/// [highlightNickname] is supplied (the student's own screen), that row is
/// highlighted.
class ClassLeaderboard extends StatelessWidget {
  final List<Map<String, dynamic>> leaderboard;
  final String? highlightNickname;

  const ClassLeaderboard({
    super.key,
    required this.leaderboard,
    this.highlightNickname,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<Map<String, dynamic>>.from(leaderboard)
      ..sort((a, b) =>
          ((b['score'] ?? 0) as num).compareTo((a['score'] ?? 0) as num));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🏆 Final Leaderboard',
            style: AppTheme.subheading.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.md),
              child: Text('No students joined.', style: AppTheme.caption),
            )
          else
            ...sorted.asMap().entries.map((e) {
              final i = e.key;
              final row = e.value;
              final nickname = (row['nickname'] ?? '').toString();
              final score = (row['score'] ?? 0);
              final isMe = highlightNickname != null &&
                  nickname == highlightNickname;
              final medal = switch (i) {
                0 => '🥇',
                1 => '🥈',
                2 => '🥉',
                _ => '⭐',
              };

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.lg,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isMe
                      ? AppTheme.primary.withValues(alpha: 0.14)
                      : AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                  border: isMe
                      ? Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.5),
                          width: 2,
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Text(medal, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: AppTheme.md),
                    Expanded(
                      child: Text(
                        isMe ? '$nickname (You)' : nickname,
                        style: AppTheme.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$score',
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
}
