// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../api_service.dart';
import '../config.dart';
import '../theme/app_theme.dart';

class SpeechPracticeScreen extends StatefulWidget {
  final Map<String, dynamic> vocab;
  final String? childId;

  const SpeechPracticeScreen({
    super.key,
    required this.vocab,
    this.childId,
  });

  @override
  State<SpeechPracticeScreen> createState() => _SpeechPracticeScreenState();
}

class _SpeechPracticeScreenState extends State<SpeechPracticeScreen> {
  final AudioPlayer _player = AudioPlayer();

  final List<Map<String, String>> _languages = [
    {'code': 'en', 'label': 'English', 'flag': '🇬🇧', 'speechLang': 'en-US'},
    {'code': 'ms', 'label': 'Malay', 'flag': '🇲🇾', 'speechLang': 'ms-MY'},
    {'code': 'zh', 'label': 'Chinese', 'flag': '🇨🇳', 'speechLang': 'zh-CN'},
  ];

  int _currentIndex = 0;
  bool _isListening = false;
  bool _hasResult = false;
  bool _isCorrect = false;
  String _transcript = '';
  final List<bool> _results = [];
  bool _speechSupported = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _speechSupported = globalContext.has('SpeechRecognition') ||
        globalContext.has('webkitSpeechRecognition');
    WidgetsBinding.instance.addPostFrameCallback((_) => _playAudio());
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _currentWord() {
    final code = _languages[_currentIndex]['code'];
    return switch (code) {
      'en' => widget.vocab['english_word'] ?? '',
      'ms' => widget.vocab['malay_word'] ?? '',
      'zh' => widget.vocab['chinese_word'] ?? '',
      _ => '',
    };
  }

  Future<void> _playAudio() async {
    final lang = _languages[_currentIndex];
    final audioMap = widget.vocab['audio'] as Map<String, dynamic>?;
    final path = audioMap?[lang['code']] as String?;
    try {
      if (path != null) {
        await _player.play(UrlSource('${AppConfig.baseUrl}$path'));
      } else {
        _speakFallback(_currentWord(), lang['speechLang']!);
      }
    } catch (_) {
      _speakFallback(_currentWord(), lang['speechLang']!);
    }
  }

  void _speakFallback(String text, String lang) {
    try {
      final utterance = html.SpeechSynthesisUtterance(text)..lang = lang;
      html.window.speechSynthesis?.speak(utterance);
    } catch (_) {}
  }

  void _startListening() {
    if (_isListening) return;
    setState(() {
      _isListening = true;
      _hasResult = false;
      _transcript = '';
      _errorMessage = null;
    });

    final lang = _languages[_currentIndex];
    final word = _currentWord().toLowerCase().trim();

    try {
      // Built via dart:js_interop/dart:js_interop_unsafe (dynamic JS object
      // access) rather than dart:html's typed SpeechRecognition wrapper:
      // dart:html's onError/onResult streams cast the native event to
      // SpeechRecognitionError / SpeechRecognitionEvent, which throws ("type
      // 'Event' is not a subtype of...") before our listener ever runs — a
      // documented dart:html binding bug (flutter/flutter#177733). Dynamic
      // JS property access sidesteps the cast entirely.
      final ctor = (globalContext['SpeechRecognition'] ??
          globalContext['webkitSpeechRecognition']) as JSFunction;
      final recognition = ctor.callAsConstructor<JSObject>();
      recognition['lang'] = lang['speechLang']!.toJS;
      recognition['continuous'] = false.toJS;
      recognition['interimResults'] = false.toJS;

      void onResult(JSObject event) {
        final results = event['results'] as JSObject;
        final firstResult = results['0'] as JSObject;
        final alternative = firstResult['0'] as JSObject;
        final transcript =
            (alternative['transcript'] as JSString).toDart.toLowerCase().trim();
        final correct = transcript == word ||
            transcript.contains(word) ||
            word.contains(transcript);

        final cid = widget.childId;
        final englishKey = widget.vocab['english_key'] as String? ?? '';
        if (cid != null) {
          ApiService.logSpeech(cid, englishKey, lang['code']!, correct);
        }

        if (mounted) {
          setState(() {
            _isListening = false;
            _hasResult = true;
            _isCorrect = correct;
            _transcript = transcript;
          });
        }
      }

      void onEnd(JSObject event) {
        if (mounted && _isListening) {
          setState(() {
            _isListening = false;
            _errorMessage ??=
                'No speech detected. Check your microphone and try again.';
          });
        }
      }

      void onError(JSObject event) {
        final errorJS = event['error'];
        final errorType = errorJS != null ? (errorJS as JSString).toDart : null;
        if (mounted) {
          setState(() {
            _isListening = false;
            _errorMessage = 'Speech error: ${errorType ?? 'unknown'}';
          });
        }
        // ignore: avoid_print
        print('SpeechRecognition error: $errorType');
      }

      recognition['onresult'] = onResult.toJS;
      recognition['onend'] = onEnd.toJS;
      recognition['onerror'] = onError.toJS;

      (recognition['start'] as JSFunction).callAsFunction(recognition);
    } catch (e) {
      setState(() {
        _isListening = false;
        _errorMessage = 'Speech error: $e';
      });
      // ignore: avoid_print
      print('SpeechRecognition start failed: $e');
    }
  }

  void _nextLanguage() {
    _results.add(_isCorrect);
    if (_currentIndex < 2) {
      setState(() {
        _currentIndex++;
        _hasResult = false;
        _isCorrect = false;
        _transcript = '';
        _errorMessage = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _playAudio());
    } else {
      setState(() => _currentIndex = 3);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentIndex >= 3) {
      final score = _results.where((r) => r).length;
      return _buildSummary(score);
    }

    final lang = _languages[_currentIndex];
    final word = _currentWord();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _backButton(context),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_currentIndex + 1} / 3',
                          style: AppTheme.caption.copyWith(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: (_currentIndex + 1) / 3,
                            minHeight: 8,
                            backgroundColor: AppTheme.primaryLight,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(lang['flag']!,
                            style: const TextStyle(fontSize: 56)),
                        const SizedBox(height: 8),
                        Text(
                          lang['label']!,
                          style: AppTheme.caption.copyWith(fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppTheme.xl),
                          decoration: AppTheme.cardDecoration,
                          child: Column(
                            children: [
                              Text(
                                word,
                                style: AppTheme.heading.copyWith(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w800,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (_hasResult) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _isCorrect
                                        ? AppTheme.success
                                            .withValues(alpha: 0.15)
                                        : Colors.red.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        _isCorrect
                                            ? '✅ Correct!'
                                            : '❌ Try again',
                                        style: AppTheme.subheading.copyWith(
                                          color: _isCorrect
                                              ? AppTheme.success
                                              : Colors.red,
                                          fontSize: 20,
                                        ),
                                      ),
                                      if (_transcript.isNotEmpty)
                                        Text(
                                          'You said: "$_transcript"',
                                          style: AppTheme.caption,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                              if (!_speechSupported)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    'Repeat after me',
                                    style: AppTheme.caption.copyWith(
                                      color: AppTheme.textLight,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        OutlinedButton.icon(
                          onPressed: _playAudio,
                          icon: const Icon(Icons.volume_up),
                          label: const Text('Listen Again'),
                          style: AppTheme.secondaryButton,
                        ),
                        const SizedBox(height: 16),
                        if (_speechSupported && !_hasResult)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isListening
                                  ? Colors.red.withValues(alpha: 0.15)
                                  : AppTheme.primary.withValues(alpha: 0.1),
                            ),
                            child: IconButton(
                              iconSize: 64,
                              onPressed:
                                  _isListening ? null : _startListening,
                              icon: Icon(
                                _isListening ? Icons.mic : Icons.mic_none,
                                size: 64,
                                color: _isListening
                                    ? Colors.red
                                    : AppTheme.primary,
                              ),
                              tooltip: _isListening
                                  ? 'Listening...'
                                  : 'Tap to speak',
                            ),
                          ),
                        if (_isListening)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Listening...',
                              style: AppTheme.caption
                                  .copyWith(color: Colors.red),
                            ),
                          ),
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _errorMessage!,
                              style: AppTheme.caption
                                  .copyWith(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        if (_hasResult)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: FilledButton(
                              onPressed: _nextLanguage,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                minimumSize: const Size(200, 52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                _currentIndex < 2
                                    ? 'Next Language →'
                                    : 'See Results',
                                style: AppTheme.buttonText,
                              ),
                            ),
                          ),
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

  Widget _buildSummary(int score) {
    final total = _results.length;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    score == total ? '🎉' : score > 0 ? '😊' : '💪',
                    style: const TextStyle(fontSize: 72),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$score / $total Correct!',
                    style: AppTheme.heading.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    score == total
                        ? 'Perfect! You said all words correctly!'
                        : score > 0
                            ? 'Good try! Keep practising!'
                            : 'Keep listening and try again!',
                    style: AppTheme.body,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      minimumSize: const Size(200, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Done'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _currentIndex = 0;
                        _hasResult = false;
                        _isCorrect = false;
                        _transcript = '';
                        _errorMessage = null;
                        _results.clear();
                      });
                      WidgetsBinding.instance
                          .addPostFrameCallback((_) => _playAudio());
                    },
                    style: AppTheme.secondaryButton,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
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
