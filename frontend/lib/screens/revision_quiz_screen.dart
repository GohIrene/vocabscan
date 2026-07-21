import 'package:flutter/material.dart';

import '../api_service.dart';
import '../theme/app_theme.dart';

/// Revision quiz — re-practises vocabulary the child has already learned,
/// without needing the physical object to scan again.
///
/// Questions come from `GET /revision/quiz/<childId>`, built server-side from
/// the child's own scan history (optionally narrowed to one day). Attempts are
/// logged through the same `/log/quiz` pipeline as the normal quiz, so revision
/// feeds mastery and the dashboard exactly like fresh practice does.
class RevisionQuizScreen extends StatefulWidget {
  final String childId;
  final String childNickname;

  /// "YYYY-MM-DD" (local/GMT+8) to revise a single day, or null for all words.
  final String? date;

  /// Human-readable label for [date], e.g. "Sunday, 19 Jul 2026".
  final String? dateLabel;

  const RevisionQuizScreen({
    super.key,
    required this.childId,
    required this.childNickname,
    this.date,
    this.dateLabel,
  });

  @override
  State<RevisionQuizScreen> createState() => _RevisionQuizScreenState();
}

class _RevisionQuizScreenState extends State<RevisionQuizScreen> {
  List<Map<String, dynamic>> _questions = [];
  bool _loading = true;
  String? _error;

  int _index = 0;
  int _score = 0;
  String? _selected;
  bool? _lastCorrect;
  String? _lastCorrectAnswer;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getRevisionQuiz(
        widget.childId,
        date: widget.date,
      );
      if (!mounted) return;
      setState(() {
        _questions = (data['questions'] as List? ?? const [])
            .whereType<Map>()
            .map((q) => Map<String, dynamic>.from(q))
            .toList();
        _loading = false;
        _index = 0;
        _score = 0;
        _selected = null;
        _lastCorrect = null;
        _lastCorrectAnswer = null;
        _done = _questions.isEmpty;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _answer(String chosen) {
    if (_lastCorrect != null || _index >= _questions.length) return;
    final q = _questions[_index];
    final correct = chosen == (q['correct_answer'] as String?);
    final key = q['english_key'] as String? ?? '';

    setState(() {
      _selected = chosen;
      _lastCorrect = correct;
      _lastCorrectAnswer = q['correct_answer'] as String?;
      if (correct) _score++;
    });

    // Fire and forget — revision counts towards mastery like normal practice.
    ApiService.logQuiz(widget.childId, key, correct);
  }

  void _next() {
    setState(() {
      _selected = null;
      _lastCorrect = null;
      _lastCorrectAnswer = null;
      if (_index + 1 >= _questions.length) {
        _done = true;
      } else {
        _index++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
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
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: _buildBody(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text('Could not load revision', style: AppTheme.subheading),
            const SizedBox(height: 8),
            Text(_error!, style: AppTheme.caption, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: AppTheme.primaryButton,
            ),
          ],
        ),
      );
    }

    if (_questions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            const Text('📭', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('Nothing to revise yet', style: AppTheme.subheading),
            const SizedBox(height: 8),
            Text(
              widget.dateLabel == null
                  ? 'Scan a few objects first, then come back to revise them.'
                  : 'No words were learned on ${widget.dateLabel}.',
              textAlign: TextAlign.center,
              style: AppTheme.body.copyWith(color: AppTheme.textLight),
            ),
          ],
        ),
      );
    }

    if (_done) {
      final total = _questions.length;
      final pct = total == 0 ? 0 : (_score / total * 100).round();
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Text(pct >= 80 ? '🌟' : '💪', style: const TextStyle(fontSize: 64)),
            const SizedBox(height: AppTheme.md),
            Text(
              'Revision Complete!',
              style: AppTheme.heading
                  .copyWith(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'You got $_score out of $total right ($pct%)',
              style: AppTheme.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Revise Again'),
              style: AppTheme.primaryButton,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Done'),
              style: AppTheme.secondaryButton,
            ),
            const SizedBox(height: AppTheme.xxl),
          ],
        ),
      );
    }

    if (_lastCorrect != null) {
      final correct = _lastCorrect!;
      final isLast = _index + 1 >= _questions.length;
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Text(correct ? '✅' : '❌', style: const TextStyle(fontSize: 72)),
            const SizedBox(height: AppTheme.md),
            Text(
              correct ? 'Correct!' : 'Not quite!',
              style: AppTheme.heading.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: correct ? AppTheme.success : AppTheme.error,
              ),
            ),
            if (!correct && _lastCorrectAnswer != null) ...[
              const SizedBox(height: 8),
              Text(
                'Answer: $_lastCorrectAnswer',
                style: AppTheme.body.copyWith(color: AppTheme.textLight),
              ),
            ],
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _next,
              icon: Icon(isLast ? Icons.flag_outlined : Icons.arrow_forward,
                  size: 18),
              label: Text(isLast ? 'See Results' : 'Next Question'),
              style: AppTheme.primaryButton,
            ),
            const SizedBox(height: AppTheme.xxl),
          ],
        ),
      );
    }

    final q = _questions[_index];
    final prompt = q['prompt'] as String? ?? '';
    final options = ((q['options'] ?? const []) as List).cast<String>();
    final total = _questions.length;

    return Column(
      children: [
        const SizedBox(height: AppTheme.md),
        const Text('🔁', style: TextStyle(fontSize: 48)),
        const SizedBox(height: AppTheme.sm),
        Text(
          'Revision Time!',
          style: AppTheme.heading
              .copyWith(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          widget.dateLabel == null
              ? 'Words ${widget.childNickname} has learned'
              : 'Words from ${widget.dateLabel}',
          style: AppTheme.caption,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text('Question ${_index + 1} of $total', style: AppTheme.caption),
        const SizedBox(height: AppTheme.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.sm),
          child: LinearProgressIndicator(
            value: (_index + 1) / total,
            minHeight: 8,
            backgroundColor: AppTheme.primaryLight,
            color: AppTheme.success,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTheme.xl),
          decoration: AppTheme.cardDecoration,
          child: Column(
            children: [
              Text(
                prompt,
                textAlign: TextAlign.center,
                style: AppTheme.subheading
                    .copyWith(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppTheme.xl),
              ...options.map(
                (opt) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.md),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _answer(opt),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textDark,
                        backgroundColor:
                            _selected == opt ? AppTheme.primaryLight : null,
                        side: BorderSide(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                        ),
                        padding:
                            const EdgeInsets.symmetric(vertical: AppTheme.lg),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: AppTheme.body.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text(opt),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.xxl),
      ],
    );
  }
}
