import 'dart:math';

import 'package:flutter/widgets.dart';

/// Which experience a scan belongs to.
///
/// Only [childAdventure] changes any behaviour. The other three describe the
/// existing flows and are treated identically to how the app worked before
/// this existed, so labelling a call site can never alter it — in particular
/// [teacherProjection] and [classSession] must stay exactly as they are.
enum LearningFlowMode {
  /// Guided Home Adventure: scan → word → speaking → quiz → reward, in order,
  /// with no way to skip between steps.
  childAdventure,

  /// A parent revisiting words with their child. Free navigation, as before.
  parentRevision,

  /// Teacher scanning onto a projector. Display only, nothing logged.
  teacherProjection,

  /// Teacher scanning inside a live Class Code session.
  classSession;

  /// True only for the guided flow. Every branch added in Phase 5 tests this
  /// rather than testing for the absence of a mode, so an unrecognised or
  /// defaulted mode always falls through to the original behaviour.
  bool get isGuidedChildFlow => this == LearningFlowMode.childAdventure;
}

/// How speech practice went, per language.
///
/// One language is required to progress; the other two are optional bonus
/// practice worth extra XP. [languages] holds one entry per language the child
/// actually tried — the counts are derived from it rather than tracked
/// separately, so they can never disagree with the outcomes.
class SpeechOutcome {
  /// Attempts made in the language the child was last practising. Used for
  /// the "two genuine tries and you may continue" rule, not for scoring.
  final int attempts;

  final bool skipped;

  /// `[{'language': 'en', 'correct': true}, ...]`, one entry per attempted
  /// language. The authoritative per-attempt record is still `/log/speech`.
  final List<Map<String, dynamic>> languages;

  const SpeechOutcome({
    this.attempts = 0,
    this.skipped = false,
    this.languages = const [],
  });

  int get languagesAttempted => languages.length;

  int get languagesSucceeded =>
      languages.where((l) => l['correct'] == true).length;

  bool get attempted => languages.isNotEmpty;

  /// At least one language said correctly — what unlocks progression.
  bool get success => languagesSucceeded > 0;

  Map<String, dynamic> toJson() => {
        'attempted': attempted,
        'success': success,
        'attempts': attempts,
        'skipped': skipped,
        'languages': languages,
        // Sent for completeness; the backend re-derives them regardless.
        'languages_attempted': languagesAttempted,
        'languages_succeeded': languagesSucceeded,
      };
}

/// How the mini quiz went.
class QuizOutcome {
  final int score;
  final int total;
  final List<Map<String, dynamic>> answers;

  const QuizOutcome({
    this.score = 0,
    this.total = 0,
    this.answers = const [],
  });

  bool get isPerfect => total > 0 && score >= total;

  Map<String, dynamic> toJson() => {
        'score': score,
        'total': total,
        'answers': answers,
      };
}

/// One pass through the guided flow, from scan to reward.
///
/// Threaded down the stack instead of adding a parameter per screen, which
/// keeps the chain short and — more importantly — means [completionId] is
/// minted exactly once per cycle. The reward endpoint is idempotent on that
/// id, so a double-tapped Continue or a retried request replays the original
/// reward instead of awarding twice.
///
/// Deliberately mutable: each step fills in its own outcome as the child
/// finishes it, and the reward screen submits the whole thing.
class LearningCycle {
  final String childId;
  final LearningFlowMode mode;

  /// The ChildHome (or area) route the flow returns to. Held as a route
  /// *instance* rather than a name: naming a route makes Flutter Web put it
  /// in the address bar, and a reload there has nowhere to restore to in an
  /// app with no route table. Null is safe — callers fall back to popping to
  /// the first route.
  final Route<dynamic>? completionAnchor;

  /// Minted once, when the cycle starts.
  final String completionId;

  /// The child's buddy, so mid-flow screens can address it by name ("Teach
  /// Kitty the word Chair!") and the reward screen can show an evolution.
  final String? avatarId;

  SpeechOutcome? speech;
  QuizOutcome? quiz;

  LearningCycle({
    required this.childId,
    required this.mode,
    this.completionAnchor,
    this.avatarId,
    String? completionId,
  }) : completionId = completionId ?? _newCompletionId();

  static final Random _random = Random();

  /// Unique enough for one child's device: the clock keeps ids ordered and
  /// the random suffix separates two cycles begun in the same millisecond.
  static String _newCompletionId() {
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    // Do not spell this as `1 << 32`: Dart Web compiles bitwise operations to
    // JavaScript's 32-bit integers, where that expression wraps to zero and
    // makes nextInt throw as soon as a child taps Start Exploring.
    final salt = _random.nextInt(0x100000000).toRadixString(36);
    return 'lc_${stamp}_$salt';
  }

  /// Unwinds to the screen this cycle started from.
  ///
  /// Falls back to the first route when there's no anchor, or when the anchor
  /// is no longer in the stack — never leaves the child stranded mid-flow.
  void returnToStart(BuildContext context) {
    final anchor = completionAnchor;
    final navigator = Navigator.of(context);
    if (anchor == null) {
      navigator.popUntil((route) => route.isFirst);
      return;
    }
    var found = false;
    navigator.popUntil((route) {
      if (identical(route, anchor)) found = true;
      return found || route.isFirst;
    });
  }
}
