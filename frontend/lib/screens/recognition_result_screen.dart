// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'quiz_practice_screen.dart';
import 'speech_practice_screen.dart';
import '../config.dart';
import '../learning_flow.dart';
import '../object_icons.dart';
import '../socket_service.dart';
import '../theme/app_theme.dart';
import '../widgets/child_avatar.dart';

/// Screen 3 – Recognition Result
/// Displays the object the AI recognised together with its trilingual vocabulary.
class RecognitionResultScreen extends StatefulWidget {
  final Map<String, dynamic> predictionData;
  final String? childId;

  /// Non-null only in Class Code mode (teacher scanning to push a quiz).
  final ClassSessionContext? classSession;

  /// Defaults to the free-navigation behaviour; only the guided child flow
  /// changes what buttons appear.
  final LearningFlowMode flowMode;
  final LearningCycle? cycle;

  const RecognitionResultScreen({
    super.key,
    required this.predictionData,
    this.childId,
    this.classSession,
    this.flowMode = LearningFlowMode.parentRevision,
    this.cycle,
  });

  @override
  State<RecognitionResultScreen> createState() =>
      _RecognitionResultScreenState();
}

class _RecognitionResultScreenState extends State<RecognitionResultScreen> {
  final AudioPlayer _player = AudioPlayer();
  String? _playingLang;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingLang = null);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String get _englishKey =>
      widget.predictionData['english_key'] as String? ?? '';

  void _sendQuizToClass() {
    final cs = widget.classSession;
    if (cs == null || _englishKey.isEmpty) return;
    cs.socket.pushQuiz(cs.sessionId, _englishKey);
    // Returning true tells the scan screen to pop too, landing the teacher
    // back on the class session screen.
    Navigator.pop(context, true);
  }

  /// Guided flow: the only way forward, straight into speaking practice.
  void _continueToSpeaking() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SpeechPracticeScreen(
          vocab: widget.predictionData,
          childId: widget.childId,
          flowMode: widget.flowMode,
          cycle: widget.cycle,
          avatarId: widget.cycle?.avatarId,
        ),
      ),
    );
  }

  Future<void> _playAudio(String langCode, String wordText) async {
    // Every await below can outlive this screen — the quiz flow above it can be
    // unwound mid-playback — and touching a disposed AudioPlayer or calling
    // setState on a dead element both throw. Re-check mounted after each.
    // Tap again while playing → stop
    if (_playingLang == langCode) {
      await _player.stop();
      if (!mounted) return;
      setState(() => _playingLang = null);
      return;
    }

    await _player.stop();
    if (!mounted) return;
    setState(() => _playingLang = langCode);

    final audioMap = widget.predictionData['audio'] as Map<String, dynamic>?;
    final path = audioMap?[langCode] as String?;

    try {
      if (path == null) throw Exception('no audio path');
      await _player.play(UrlSource('${AppConfig.baseUrl}$path'));
    } catch (_) {
      _speakFallback(wordText, _speechLang(langCode));
    }
  }

  static String _speechLang(String code) => switch (code) {
        'ms' => 'ms-MY',
        'zh' => 'zh-CN',
        _ => 'en-US',
      };

  void _speakFallback(String text, String lang) {
    try {
      final utterance = html.SpeechSynthesisUtterance(text)..lang = lang;
      html.window.speechSynthesis?.speak(utterance);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (widget.flowMode.isGuidedChildFlow) {
      return _buildGuidedResult(context);
    }
    return _buildStandardResult(context);
  }

  Widget _buildStandardResult(BuildContext context) {
    final english = widget.predictionData['english_word'] ?? '';
    final malay = widget.predictionData['malay_word'] ?? '';
    final chinese = widget.predictionData['chinese_word'] ?? '';
    final confidence = widget.predictionData['confidence'] ?? 0.0;
    final pct = ((confidence as num) * 100).toStringAsFixed(0);

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
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      children: [
                        const SizedBox(height: AppTheme.sm),
                        Image.asset(
                          'assets/icons/confetti.png',
                          width: 52,
                          height: 52,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.celebration, size: 52);
                          },
                        ),
                        const SizedBox(height: AppTheme.sm),
                        Text(
                          'Object Recognised!',
                          style: AppTheme.heading.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Confidence: $pct%',
                          style: AppTheme.body.copyWith(
                            fontSize: 15,
                            color: AppTheme.textLight,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── Vocabulary card ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppTheme.xl),
                          decoration: AppTheme.cardDecoration,
                          child: Column(
                            children: [
                              Image.asset(
                                'assets/icons/box.png',
                                width: 56,
                                height: 56,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.card_giftcard, size: 56);
                                },
                              ),
                              const SizedBox(height: AppTheme.lg),
                              _VocabRow(
                                flag: '🇬🇧',
                                label: 'English',
                                value: english,
                                isPlaying: _playingLang == 'en',
                                onPlay: () => _playAudio('en', english),
                              ),
                              const SizedBox(height: AppTheme.md),
                              _VocabRow(
                                flag: '🇲🇾',
                                label: 'Malay',
                                value: malay,
                                isPlaying: _playingLang == 'ms',
                                onPlay: () => _playAudio('ms', malay),
                              ),
                              const SizedBox(height: AppTheme.md),
                              _VocabRow(
                                flag: '🇨🇳',
                                label: 'Chinese',
                                value: chinese,
                                isPlaying: _playingLang == 'zh',
                                onPlay: () => _playAudio('zh', chinese),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── Class Code mode: push this word as a quiz ──
                        // Hidden without a usable key: pushing an empty one
                        // gives the whole class a blank question.
                        if (widget.classSession != null &&
                            _englishKey.isNotEmpty) ...[
                          FilledButton.icon(
                            onPressed: _sendQuizToClass,
                            icon: Image.asset(
                              'assets/icons/target.png',
                              width: 18,
                              height: 18,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.center_focus_strong,
                                    size: 18);
                              },
                            ),
                            label: const Text('Send Quiz to Class'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.secondary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(200, 52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: AppTheme.buttonText,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.xxl,
                                vertical: AppTheme.lg,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // ── Practice quiz ──
                        FilledButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QuizPracticeScreen(
                                vocab: widget.predictionData,
                                childId: widget.childId,
                                classSession: widget.classSession,
                              ),
                            ),
                          ),
                          icon: Image.asset(
                            'assets/icons/target.png',
                            width: 18,
                            height: 18,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.center_focus_strong,
                                  size: 18);
                            },
                          ),
                          label: const Text('Practice Quiz'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            foregroundColor: AppTheme.textDark,
                            minimumSize: const Size(200, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: AppTheme.buttonText.copyWith(
                              color: AppTheme.textDark,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.xxl,
                              vertical: AppTheme.lg,
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ── Speech Practice ──
                        FilledButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SpeechPracticeScreen(
                                vocab: widget.predictionData,
                                childId: widget.childId,
                              ),
                            ),
                          ),
                          icon: const Text('🎤',
                              style: TextStyle(fontSize: 18)),
                          label: const Text('Speech Practice'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(200, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: AppTheme.buttonText,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.xxl,
                              vertical: AppTheme.lg,
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ── Scan another ──
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.camera_alt, size: 18),
                          label: const Text('Scan Another Object'),
                          style: AppTheme.secondaryButton,
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

  // ── Guided child flow: reward-style result screen ──────────────────────
  //
  // Visuals only — the single "Practice Speaking" button below still calls
  // the same _continueToSpeaking as before, so the no-skip guided sequence
  // (scan → speak → quiz → reward) is unchanged.

  Widget _buildGuidedResult(BuildContext context) {
    final english = (widget.predictionData['english_word'] as String?) ?? '';
    final malay = (widget.predictionData['malay_word'] as String?) ?? '';
    final chinese = (widget.predictionData['chinese_word'] as String?) ?? '';
    final confidence = (widget.predictionData['confidence'] as num?) ?? 0.0;
    final pct = (confidence * 100).toStringAsFixed(0);
    final avatarId = widget.cycle?.avatarId;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/ScanningPage_background.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(color: AppTheme.background),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _backButton(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(
                          children: [
                            const SizedBox(height: AppTheme.sm),
                            _buildGuidedHeader(english),
                            const SizedBox(height: AppTheme.xl),
                            _buildGuidedBody(english, pct, avatarId),
                            const SizedBox(height: AppTheme.lg),
                            _buildGuidedLangRow(english, malay, chinese),
                            const SizedBox(height: AppTheme.lg),
                            _buildDidYouKnowBanner(),
                            const SizedBox(height: AppTheme.xl),
                            _buildPracticeSpeakingButton(),
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
        ],
      ),
    );
  }

  Widget _buildGuidedHeader(String english) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome,
                size: 18, color: Color(0xFFFFC94D)),
            const SizedBox(width: 10),
            Text(
              english.isEmpty ? 'I found something!' : 'I found a $english!',
              textAlign: TextAlign.center,
              style: AppTheme.heading.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.auto_awesome,
                size: 18, color: Color(0xFFFFC94D)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          "Great job! You're learning so well! 💜",
          style:
              AppTheme.body.copyWith(fontSize: 15, color: AppTheme.textLight),
        ),
      ],
    );
  }

  Widget _buildGuidedBody(String english, String pct, String? avatarId) {
    final resultCard = _buildResultCard(english, pct);
    final buddy = _buildBuddyReaction(english, avatarId);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            children: [
              resultCard,
              const SizedBox(height: AppTheme.lg),
              buddy,
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: resultCard),
              const SizedBox(width: AppTheme.lg),
              Expanded(flex: 2, child: buddy),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResultCard(String english, String pct) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.xl),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: const [
          BoxShadow(
              color: AppTheme.shadowColor, blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.18),
                  AppTheme.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
            alignment: Alignment.center,
            child: ClipOval(
              child: Image.asset(
                objectIconFor(english),
                width: 116,
                height: 116,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.card_giftcard, size: 84),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.lg),
          _pillBadge(
            icon: Icons.check_circle_rounded,
            label: 'Object Recognised!',
            color: AppTheme.success,
            background: AppTheme.successLight,
          ),
          const SizedBox(height: AppTheme.md),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  english.isEmpty ? "It's a match!" : "It's a $english!",
                  textAlign: TextAlign.center,
                  style: AppTheme.heading
                      .copyWith(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.star_rounded,
                  color: AppTheme.treasure, size: 22),
            ],
          ),
          const SizedBox(height: AppTheme.md),
          _pillBadge(
            icon: Icons.star_rounded,
            label: '$pct% match!',
            color: AppTheme.success,
            background: AppTheme.successLight,
          ),
        ],
      ),
    );
  }

  Widget _pillBadge({
    required IconData icon,
    required String label,
    required Color color,
    required Color background,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppTheme.lg, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTheme.body.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuddyReaction(String english, String? avatarId) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTheme.md),
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: const [
              BoxShadow(
                  color: AppTheme.shadowColor,
                  blurRadius: 12,
                  offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              Text(
                english.isEmpty
                    ? 'Yay! Great find!'
                    : 'Yay! You found a $english!',
                textAlign: TextAlign.center,
                style: AppTheme.body
                    .copyWith(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                "Let's learn more together! 💗",
                textAlign: TextAlign.center,
                style: AppTheme.caption.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.sm),
        ChildAvatar(avatarId: avatarId, size: 96),
      ],
    );
  }

  Widget _buildGuidedLangRow(String english, String malay, String chinese) {
    final cards = [
      _LangCard(
        code: 'EN',
        word: english,
        color: AppTheme.primary,
        background: AppTheme.primaryLight,
        isPlaying: _playingLang == 'en',
        onPlay: () => _playAudio('en', english),
      ),
      _LangCard(
        code: 'MS',
        word: malay,
        color: AppTheme.success,
        background: AppTheme.successLight,
        isPlaying: _playingLang == 'ms',
        onPlay: () => _playAudio('ms', malay),
      ),
      _LangCard(
        code: 'CN',
        word: chinese,
        color: AppTheme.error,
        background: AppTheme.errorLight,
        isPlaying: _playingLang == 'zh',
        onPlay: () => _playAudio('zh', chinese),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 460) {
          return Column(
            children: [
              for (final c in cards) ...[
                c,
                if (c != cards.last) const SizedBox(height: AppTheme.sm),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (final c in cards) ...[
              Expanded(child: c),
              if (c != cards.last) const SizedBox(width: AppTheme.sm),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDidYouKnowBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.lg, vertical: AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.warningLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          const Text('💡', style: TextStyle(fontSize: 22)),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Did you know?',
                    style: AppTheme.body.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  'Practising new words every day helps you remember them '
                  'better!',
                  style: AppTheme.caption.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeSpeakingButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _continueToSpeaking,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.success,
          foregroundColor: AppTheme.textDark,
          minimumSize: const Size(double.infinity, 58),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: AppTheme.buttonText.copyWith(fontSize: 17),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('🎤', style: TextStyle(fontSize: 18)),
            SizedBox(width: 10),
            Text('Practice Speaking'),
            SizedBox(width: 10),
            Icon(Icons.arrow_forward_rounded, size: 18),
          ],
        ),
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

/// One row inside the vocabulary card with a speaker button.
class _VocabRow extends StatelessWidget {
  final String flag;
  final String label;
  final String value;
  final bool isPlaying;
  final VoidCallback onPlay;

  const _VocabRow({
    required this.flag,
    required this.label,
    required this.value,
    required this.isPlaying,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.lg, vertical: 14),
      decoration: BoxDecoration(
        color: isPlaying
            ? AppTheme.primary.withValues(alpha: 0.12)
            : AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(14),
        border: isPlaying
            ? Border.all(color: AppTheme.primary.withValues(alpha: 0.4))
            : null,
      ),
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTheme.caption.copyWith(fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTheme.subheading.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isPlaying
                  ? AppTheme.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: onPlay,
              tooltip: isPlaying ? 'Stop' : 'Play audio',
              icon: Icon(
                isPlaying ? Icons.volume_up : Icons.volume_up_outlined,
                color:
                    isPlaying ? AppTheme.primary : AppTheme.textLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One language's word in the guided-flow result screen: a colour-coded
/// language pill, the word itself, and a speaker button — the same
/// [_playAudio] behind it as [_VocabRow], just laid out as a standalone card.
class _LangCard extends StatelessWidget {
  final String code;
  final String word;
  final Color color;
  final Color background;
  final bool isPlaying;
  final VoidCallback onPlay;

  const _LangCard({
    required this.code,
    required this.word,
    required this.color,
    required this.background,
    required this.isPlaying,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: AppTheme.lg, horizontal: AppTheme.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: isPlaying ? Border.all(color: color, width: 2) : null,
      ),
      child: Column(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              code,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.sm),
          Text(
            word,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.heading.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: AppTheme.sm),
          InkWell(
            onTap: onPlay,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(
                isPlaying ? Icons.volume_up : Icons.volume_up_outlined,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
