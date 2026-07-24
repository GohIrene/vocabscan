// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../api_service.dart';
import '../config.dart';
import '../theme/app_theme.dart';
import '../widgets/vocab_icon.dart';
import 'speech_practice_screen.dart';

/// Every word a child could learn, with the ones they've found filled in.
///
/// Driven entirely by `GET /child/treasures/<child_id>`: the word list, the
/// total and the found flags all come from the backend, so nothing here knows
/// how many words exist. Adding vocabulary grows the album with no UI change.
///
/// Undiscovered entries are shown as silhouettes so a child can see what's out
/// there, but they never gate anything — the adventure does not require a
/// complete album.
class ChildTreasureAlbumScreen extends StatefulWidget {
  final String childId;

  const ChildTreasureAlbumScreen({super.key, required this.childId});

  @override
  State<ChildTreasureAlbumScreen> createState() =>
      _ChildTreasureAlbumScreenState();
}

class _ChildTreasureAlbumScreenState extends State<ChildTreasureAlbumScreen> {
  /// Same playback approach as the recognition and speech screens: the
  /// pre-generated MP3 first, the browser's own voice as a fallback.
  final AudioPlayer _player = AudioPlayer();
  String? _playingKey;

  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  bool _foundOnly = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingKey = null);
    });
    _load();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getChildTreasures(widget.childId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _treasures =>
      (_data?['treasures'] as List? ?? const [])
          .whereType<Map>()
          .map((t) => Map<String, dynamic>.from(t))
          .toList();

  /// Plays one language of one word. Tapping the same button again stops it.
  Future<void> _play(
      Map<String, dynamic> treasure, String langCode, String word) async {
    final key = '${treasure['english_key']}_$langCode';
    if (_playingKey == key) {
      await _player.stop();
      if (!mounted) return;
      setState(() => _playingKey = null);
      return;
    }
    await _player.stop();
    if (!mounted) return;
    setState(() => _playingKey = key);

    final audio = (treasure['audio'] as Map?)?.cast<String, dynamic>();
    final path = audio?[langCode] as String?;
    try {
      if (path == null) throw Exception('no audio path');
      await _player.play(UrlSource('${AppConfig.baseUrl}$path'));
    } catch (_) {
      _speakFallback(word, _speechLang(langCode));
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

  /// "Practice again" opens the standalone three-language drill for that word
  /// — no scanning needed, and it reuses the existing screen untouched.
  void _practise(Map<String, dynamic> treasure) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SpeechPracticeScreen(
          vocab: treasure,
          childId: widget.childId,
        ),
      ),
    );
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
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildError()
                      : _buildAlbum(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📔', style: TextStyle(fontSize: 52)),
            const SizedBox(height: AppTheme.lg),
            Text("We couldn't open your album",
                style:
                    AppTheme.subheading.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppTheme.sm),
            Text(_error ?? '',
                textAlign: TextAlign.center, style: AppTheme.caption),
            const SizedBox(height: AppTheme.xl),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: AppTheme.primaryButton,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbum() {
    final found = (_data?['discovered_count'] as num?)?.toInt() ?? 0;
    final total = (_data?['total_count'] as num?)?.toInt() ?? 0;
    final visible =
        _foundOnly ? _treasures.where((t) => t['discovered'] == true).toList()
            : _treasures;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Column count from available width, so the grid reflows rather than
        // overflowing between breakpoints.
        final width = constraints.maxWidth;
        final columns = width >= 1100
            ? 4
            : width >= 820
                ? 3
                : width >= 520
                    ? 2
                    : 1;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              AppTheme.xl, 0, AppTheme.xl, AppTheme.xxl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Treasure Album',
                    textAlign: TextAlign.center,
                    style: AppTheme.heading.copyWith(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppTheme.xs),
                  Text(
                    found == 0
                        ? 'Scan an object to find your first treasure!'
                        : 'You have collected $found of $total words',
                    textAlign: TextAlign.center,
                    style: AppTheme.body.copyWith(color: AppTheme.textLight),
                  ),
                  const SizedBox(height: AppTheme.lg),
                  if (total > 0) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: found / total,
                        minHeight: 10,
                        backgroundColor:
                            AppTheme.secondary.withValues(alpha: 0.18),
                        color: AppTheme.secondary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.lg),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _FilterChip(
                        label: 'All words',
                        selected: !_foundOnly,
                        onTap: () => setState(() => _foundOnly = false),
                      ),
                      const SizedBox(width: AppTheme.sm),
                      _FilterChip(
                        label: 'Found ($found)',
                        selected: _foundOnly,
                        onTap: () => setState(() => _foundOnly = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.lg),
                  if (visible.isEmpty)
                    _buildEmpty(found)
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: visible.length,
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: AppTheme.md,
                        mainAxisSpacing: AppTheme.md,
                        // Tall enough for three languages plus the audio row.
                        mainAxisExtent: 250,
                      ),
                      itemBuilder: (context, i) {
                        final t = visible[i];
                        return t['discovered'] == true
                            ? _TreasureCard(
                                treasure: t,
                                playingKey: _playingKey,
                                onPlay: (code, word) => _play(t, code, word),
                                onPractise: () => _practise(t),
                              )
                            : const _UndiscoveredCard();
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmpty(int found) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.xxl),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          const Text('🔍', style: TextStyle(fontSize: 52)),
          const SizedBox(height: AppTheme.md),
          Text(
            found == 0
                ? 'No treasures yet!'
                : 'Nothing to show with this filter',
            textAlign: TextAlign.center,
            style: AppTheme.subheading.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppTheme.xs),
          Text(
            found == 0
                ? 'Every object you scan and learn becomes a treasure here.'
                : 'Switch back to All words to see what you can find.',
            textAlign: TextAlign.center,
            style: AppTheme.caption,
          ),
        ],
      ),
    );
  }
}

// ── Cards ────────────────────────────────────────────────────────────────────

class _TreasureCard extends StatelessWidget {
  final Map<String, dynamic> treasure;
  final String? playingKey;
  final void Function(String langCode, String word) onPlay;
  final VoidCallback onPractise;

  const _TreasureCard({
    required this.treasure,
    required this.playingKey,
    required this.onPlay,
    required this.onPractise,
  });

  @override
  Widget build(BuildContext context) {
    final key = treasure['english_key'] as String? ?? '';
    final english = treasure['english_word'] as String? ?? '';
    final malay = treasure['malay_word'] as String? ?? '';
    final chinese = treasure['chinese_word'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.3)),
        boxShadow: const [
          BoxShadow(color: AppTheme.shadowColor, blurRadius: 10,
              offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Falls back to a generic icon when a word has no artwork, so
              // vocabulary added later still renders.
              VocabIcon(englishKey: key, size: 40),
              const SizedBox(width: AppTheme.sm),
              Expanded(
                child: Text(
                  english,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.subheading.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sm),
          _LangLine(
            label: 'Malay',
            value: malay,
            playing: playingKey == '${key}_ms',
            onPlay: () => onPlay('ms', malay),
          ),
          const SizedBox(height: 2),
          _LangLine(
            label: 'Chinese',
            value: chinese,
            playing: playingKey == '${key}_zh',
            onPlay: () => onPlay('zh', chinese),
          ),
          const Spacer(),
          Row(
            children: [
              _AudioButton(
                label: 'EN',
                playing: playingKey == '${key}_en',
                onTap: () => onPlay('en', english),
              ),
              const SizedBox(width: 6),
              _AudioButton(
                label: 'MS',
                playing: playingKey == '${key}_ms',
                onTap: () => onPlay('ms', malay),
              ),
              const SizedBox(width: 6),
              _AudioButton(
                label: '中',
                playing: playingKey == '${key}_zh',
                onTap: () => onPlay('zh', chinese),
              ),
              const Spacer(),
              IconButton(
                onPressed: onPractise,
                icon: const Icon(Icons.mic_rounded, size: 20),
                color: AppTheme.primary,
                tooltip: 'Practice again',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A word not yet found. Deliberately inert — the album is a record of
/// progress, not a checklist a child has to clear.
class _UndiscoveredCard extends StatelessWidget {
  const _UndiscoveredCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.textLight.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '?',
              style: AppTheme.heading.copyWith(
                fontSize: 46,
                fontWeight: FontWeight.w800,
                color: AppTheme.textLight.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: AppTheme.sm),
            Text(
              'Not found yet',
              textAlign: TextAlign.center,
              style: AppTheme.caption.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              'Scan to discover!',
              textAlign: TextAlign.center,
              style: AppTheme.caption.copyWith(
                fontSize: 11,
                color: AppTheme.textLight.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LangLine extends StatelessWidget {
  final String label;
  final String value;
  final bool playing;
  final VoidCallback onPlay;

  const _LangLine({
    required this.label,
    required this.value,
    required this.playing,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: onPlay,
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Text(label, style: AppTheme.caption.copyWith(fontSize: 11)),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.body.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: playing ? AppTheme.primary : AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioButton extends StatelessWidget {
  final String label;
  final bool playing;
  final VoidCallback onTap;

  const _AudioButton({
    required this.label,
    required this.playing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: playing ? AppTheme.primary : AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                playing ? Icons.volume_up_rounded : Icons.volume_up_outlined,
                size: 13,
                color: playing ? Colors.white : AppTheme.primary,
              ),
              const SizedBox(width: 3),
              Text(
                label,
                style: AppTheme.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: playing ? Colors.white : AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.lg, vertical: AppTheme.sm),
          decoration: BoxDecoration(
            color: selected ? AppTheme.secondary : AppTheme.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: selected
                  ? AppTheme.secondary
                  : AppTheme.secondary.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: AppTheme.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppTheme.textDark,
            ),
          ),
        ),
      ),
    );
  }
}
