import 'dart:async';
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
  bool _isProcessing = false;
  bool _hasResult = false;
  bool _isCorrect = false;
  String _transcript = '';
  final List<bool> _results = [];
  bool _speechSupported = true;
  bool _recordingSupported = false;
  String? _errorMessage;
  Timer? _listenTimer;
  Timer? _stopFallbackTimer;
  JSObject? _activeRecognition;
  JSObject? _mediaRecorder;
  JSObject? _mediaStream;

  static const _listenTimeout = Duration(seconds: 10);

  /// Languages Chrome's Web Speech API can't recognise reliably are routed
  /// through the backend (MediaRecorder → Whisper) instead. Malay is the one
  /// that doesn't work in the browser today.
  static const _serverLangCodes = {'ms'};

  bool get _isServerLang =>
      _serverLangCodes.contains(_languages[_currentIndex]['code']);

  /// Whether the mic can be used for the current language given browser
  /// capabilities: recording languages need MediaRecorder + getUserMedia,
  /// browser languages need SpeechRecognition.
  bool get _micSupported =>
      _isServerLang ? _recordingSupported : _speechSupported;

  @override
  void initState() {
    super.initState();
    _speechSupported = globalContext.has('SpeechRecognition') ||
        globalContext.has('webkitSpeechRecognition');
    final mediaDevices =
        (globalContext['navigator'] as JSObject?)?['mediaDevices'];
    _recordingSupported =
        globalContext.has('MediaRecorder') && mediaDevices != null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _playAudio());
  }

  @override
  void dispose() {
    _listenTimer?.cancel();
    _stopFallbackTimer?.cancel();
    _stopRecognition();
    _stopRecording();
    _releaseStream();
    _player.dispose();
    super.dispose();
  }

  /// Mic tap dispatches to the browser or backend path depending on language.
  void _startActive() => _isServerLang ? _startRecording() : _startListening();
  void _stopActive() => _isServerLang ? _stopRecording() : _stopRecognition();

  void _stopRecognition() {
    final recognition = _activeRecognition;
    if (recognition == null) return;
    try {
      (recognition['stop'] as JSFunction).callAsFunction(recognition);
    } catch (_) {}
    // Some languages (notably ms-MY) are poorly supported by Chrome's Web
    // Speech service, which then never fires onend/onerror after stop(). That
    // leaves _isListening stuck true and the mic frozen in the "Listening..."
    // state. This fallback force-stops the recognition and resets the UI if
    // the browser callbacks haven't fired shortly after we asked it to stop.
    _stopFallbackTimer?.cancel();
    _stopFallbackTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || !_isListening) return;
      try {
        (recognition['abort'] as JSFunction).callAsFunction(recognition);
      } catch (_) {}
      _listenTimer?.cancel();
      _listenTimer = null;
      _activeRecognition = null;
      setState(() => _isListening = false);
    });
  }

  // ---------------------------------------------------------------------------
  // Backend recording path (used for languages the browser can't recognise).
  // Records a short clip with MediaRecorder, then POSTs it to /speech/transcribe
  // where Whisper handles languages like Malay that Web Speech doesn't support.
  // ---------------------------------------------------------------------------

  Future<void> _startRecording() async {
    if (_isListening || _isProcessing) return;
    setState(() {
      _isListening = true;
      _hasResult = false;
      _transcript = '';
      _errorMessage = null;
    });

    try {
      final mediaDevices =
          (globalContext['navigator'] as JSObject)['mediaDevices'] as JSObject;
      final constraints = JSObject();
      constraints['audio'] = true.toJS;
      final streamPromise = (mediaDevices['getUserMedia'] as JSFunction)
          .callAsFunction(mediaDevices, constraints) as JSPromise;
      final stream = (await streamPromise.toDart) as JSObject;
      _mediaStream = stream;

      final recorder = (globalContext['MediaRecorder'] as JSFunction)
          .callAsConstructor<JSObject>(stream);
      _mediaRecorder = recorder;

      // Collect the audio Blob parts as they arrive; combined on stop.
      final chunks =
          (globalContext['Array'] as JSFunction).callAsConstructor<JSObject>();

      void onData(JSObject event) {
        final data = event['data'];
        if (data != null) {
          (chunks['push'] as JSFunction).callAsFunction(chunks, data);
        }
      }

      void onStop(JSObject event) {
        _finishRecording(chunks);
      }

      recorder['ondataavailable'] = onData.toJS;
      recorder['onstop'] = onStop.toJS;
      (recorder['start'] as JSFunction).callAsFunction(recorder);

      _listenTimer = Timer(_listenTimeout, _stopRecording);
    } catch (e) {
      _releaseStream();
      if (mounted) {
        setState(() {
          _isListening = false;
          _errorMessage = 'Microphone error: $e';
        });
      }
    }
  }

  void _stopRecording() {
    _listenTimer?.cancel();
    _listenTimer = null;
    final recorder = _mediaRecorder;
    if (recorder == null) return;
    try {
      final state = (recorder['state'] as JSString?)?.toDart;
      if (state != 'inactive') {
        (recorder['stop'] as JSFunction).callAsFunction(recorder);
      }
    } catch (_) {}
  }

  /// Stops the mic tracks so the browser's recording indicator clears.
  void _releaseStream() {
    final stream = _mediaStream;
    _mediaStream = null;
    _mediaRecorder = null;
    if (stream == null) return;
    try {
      final tracks = (stream['getTracks'] as JSFunction)
          .callAsFunction(stream) as JSObject;
      final length = (tracks['length'] as JSNumber).toDartInt;
      for (var i = 0; i < length; i++) {
        final track = tracks[i.toString()] as JSObject;
        (track['stop'] as JSFunction).callAsFunction(track);
      }
    } catch (_) {}
  }

  Future<void> _finishRecording(JSObject chunks) async {
    _releaseStream();
    if (mounted) {
      setState(() {
        _isListening = false;
        _isProcessing = true;
      });
    }

    try {
      final opts = JSObject();
      opts['type'] = 'audio/webm'.toJS;
      final blob = (globalContext['Blob'] as JSFunction)
          .callAsConstructor<JSObject>(chunks, opts);
      final bufferPromise =
          (blob['arrayBuffer'] as JSFunction).callAsFunction(blob) as JSPromise;
      final buffer = (await bufferPromise.toDart) as JSArrayBuffer;
      final bytes = buffer.toDart.asUint8List();

      final lang = _languages[_currentIndex];
      final result = await ApiService.transcribeSpeech(
        audioBytes: bytes,
        lang: lang['code']!,
        target: _currentWord(),
      );
      final transcript = _normalize((result['transcript'] as String?) ?? '');
      final correct = (result['correct'] as bool?) ?? false;

      final cid = widget.childId;
      final englishKey = widget.vocab['english_key'] as String? ?? '';
      if (cid != null) {
        ApiService.logSpeech(cid, englishKey, lang['code']!, correct);
      }

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        if (transcript.isEmpty) {
          _errorMessage =
              'No speech detected. Check your microphone and try again.';
        } else {
          _hasResult = true;
          _isCorrect = correct;
          _transcript = transcript;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Could not transcribe: $e';
        });
      }
    }
  }

  /// Skips the current word (counts as not correct) and moves on — the escape
  /// hatch when recognition just won't cooperate.
  void _skip() {
    _listenTimer?.cancel();
    if (_isServerLang) {
      _stopRecording();
      _releaseStream();
    } else {
      _stopRecognition();
    }
    setState(() {
      _isListening = false;
      _isProcessing = false;
      _isCorrect = false;
    });
    _nextLanguage();
  }

  /// Lowercases, strips punctuation (incl. Chinese full-width punctuation
  /// the ASR sometimes appends) and collapses whitespace, so matching isn't
  /// thrown off by cosmetic differences between transcript and target word.
  static String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[。！？，、,.!?~～]+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

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
      final synthesis = globalContext['speechSynthesis'] as JSObject?;
      if (synthesis == null) return;
      final ctor = globalContext['SpeechSynthesisUtterance'] as JSFunction;
      final utterance = ctor.callAsConstructor<JSObject>(text.toJS);
      utterance['lang'] = lang.toJS;
      (synthesis['speak'] as JSFunction).callAsFunction(synthesis, utterance);
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
    final word = _normalize(_currentWord());
    final buffer = StringBuffer();

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
      // continuous: true + our own timer (below) gives a longer ~10s speaking
      // window instead of the browser's own short built-in silence cutoff,
      // which was cutting off slower/longer utterances (esp. Chinese).
      recognition['continuous'] = true.toJS;
      recognition['interimResults'] = false.toJS;
      _activeRecognition = recognition;

      void onResult(JSObject event) {
        // In continuous mode `results` accumulates every finalized segment
        // across the whole session; `resultIndex` marks where the newly
        // finalized entries start, so we only append what's new.
        final results = event['results'] as JSObject;
        final length = (results['length'] as JSNumber).toDartInt;
        final startIndex =
            (event['resultIndex'] as JSNumber?)?.toDartInt ?? 0;
        for (var i = startIndex; i < length; i++) {
          final result = results[i.toString()] as JSObject;
          final alternative = result['0'] as JSObject;
          final piece = (alternative['transcript'] as JSString).toDart;
          if (buffer.isNotEmpty) buffer.write(' ');
          buffer.write(piece);
        }
      }

      void finish() {
        _listenTimer?.cancel();
        _listenTimer = null;
        _stopFallbackTimer?.cancel();
        _stopFallbackTimer = null;
        _activeRecognition = null;
        final transcript = _normalize(buffer.toString());

        if (transcript.isEmpty) {
          if (mounted) {
            setState(() {
              _isListening = false;
              _errorMessage ??=
                  'No speech detected. Check your microphone and try again.';
            });
          }
          return;
        }

        // Exact match only (no more substring/contains matching): a loose
        // "transcript.contains(word) || word.contains(transcript)" check was
        // marking background-noise hallucinations or unrelated short words as
        // correct whenever they happened to be a substring of the target.
        final correct = transcript == word;

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
        if (_isListening) finish();
      }

      void onError(JSObject event) {
        _listenTimer?.cancel();
        _listenTimer = null;
        _stopFallbackTimer?.cancel();
        _stopFallbackTimer = null;
        _activeRecognition = null;
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
      _listenTimer = Timer(_listenTimeout, () {
        (recognition['stop'] as JSFunction).callAsFunction(recognition);
      });
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
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Image.asset(
                                            _isCorrect
                                                ? 'assets/icons/checkmark.png'
                                                : 'assets/icons/cross.png',
                                            width: 20,
                                            height: 20,
                                            errorBuilder: (context, error,
                                                stackTrace) {
                                              return Icon(
                                                _isCorrect
                                                    ? Icons.check_circle
                                                    : Icons.cancel,
                                                size: 20,
                                                color: _isCorrect
                                                    ? AppTheme.success
                                                    : Colors.red,
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _isCorrect
                                                ? 'Correct!'
                                                : 'Try again',
                                            style:
                                                AppTheme.subheading.copyWith(
                                              color: _isCorrect
                                                  ? AppTheme.success
                                                  : Colors.red,
                                              fontSize: 20,
                                            ),
                                          ),
                                        ],
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
                              if (!_micSupported)
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
                        if (_micSupported && !_hasResult && !_isProcessing)
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
                              onPressed: _isListening
                                  ? _stopActive
                                  : _startActive,
                              icon: Icon(
                                _isListening ? Icons.mic : Icons.mic_none,
                                size: 64,
                                color: _isListening
                                    ? Colors.red
                                    : AppTheme.primary,
                              ),
                              tooltip: _isListening
                                  ? 'Tap to stop'
                                  : 'Tap to speak',
                            ),
                          ),
                        if (_isProcessing)
                          Column(
                            children: [
                              const SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(strokeWidth: 3),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Transcribing...',
                                style: AppTheme.caption
                                    .copyWith(color: AppTheme.primary),
                              ),
                            ],
                          ),
                        if (_isListening)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Listening... (tap mic to stop)',
                              style: AppTheme.caption
                                  .copyWith(color: Colors.red),
                            ),
                          ),
                        if (!_hasResult && !_isListening && !_isProcessing)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: TextButton(
                              onPressed: _skip,
                              child: Text(
                                _currentIndex < 2
                                    ? 'Skip this word →'
                                    : 'Skip & see results →',
                                style: AppTheme.caption.copyWith(
                                  color: AppTheme.textLight,
                                ),
                              ),
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
                  Image.asset(
                    score == total
                        ? 'assets/icons/confetti.png'
                        : score > 0
                            ? 'assets/icons/smiley.png'
                            : 'assets/icons/strong.png',
                    width: 72,
                    height: 72,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        score == total
                            ? Icons.celebration
                            : score > 0
                                ? Icons.sentiment_satisfied
                                : Icons.fitness_center,
                        size: 72,
                        color: AppTheme.primary,
                      );
                    },
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
