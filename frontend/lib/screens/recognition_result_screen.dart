// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'quiz_practice_screen.dart';
import 'speech_practice_screen.dart';
import '../config.dart';
import '../socket_service.dart';
import '../theme/app_theme.dart';

/// Screen 3 – Recognition Result
/// Displays the object the AI recognised together with its trilingual vocabulary.
class RecognitionResultScreen extends StatefulWidget {
  final Map<String, dynamic> predictionData;
  final String? childId;

  /// Non-null only in Class Code mode (teacher scanning to push a quiz).
  final ClassSessionContext? classSession;

  const RecognitionResultScreen({
    super.key,
    required this.predictionData,
    this.childId,
    this.classSession,
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

  void _sendQuizToClass() {
    final cs = widget.classSession;
    if (cs == null) return;
    final englishKey = widget.predictionData['english_key'] as String? ?? '';
    cs.socket.pushQuiz(cs.sessionId, englishKey);
    // Returning true tells the scan screen to pop too, landing the teacher
    // back on the class session screen.
    Navigator.pop(context, true);
  }

  Future<void> _playAudio(String langCode, String wordText) async {
    // Tap again while playing → stop
    if (_playingLang == langCode) {
      await _player.stop();
      setState(() => _playingLang = null);
      return;
    }

    await _player.stop();
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
                        const Text('🎉', style: TextStyle(fontSize: 52)),
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
                              const Text('📦',
                                  style: TextStyle(fontSize: 56)),
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
                        if (widget.classSession != null) ...[
                          FilledButton.icon(
                            onPressed: _sendQuizToClass,
                            icon: const Text('🎯',
                                style: TextStyle(fontSize: 18)),
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
                              ),
                            ),
                          ),
                          icon: const Text('🎯',
                              style: TextStyle(fontSize: 18)),
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
