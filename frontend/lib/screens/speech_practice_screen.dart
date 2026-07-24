import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../api_service.dart';
import '../avatar_config.dart';
import '../config.dart';
import '../learning_flow.dart';
import '../theme/app_theme.dart';
import 'quiz_practice_screen.dart';

class SpeechPracticeScreen extends StatefulWidget {
  final Map<String, dynamic> vocab;
  final String? childId;

  /// Defaults to the existing standalone drill; only the guided child flow
  /// changes the wording, the progression rules and where "next" leads.
  final LearningFlowMode flowMode;
  final LearningCycle? cycle;

  /// The child's buddy, so the guided flow can say "Teach Kitty the word
  /// Chair!" instead of a generic instruction.
  final String? avatarId;

  const SpeechPracticeScreen({
    super.key,
    required this.vocab,
    this.childId,
    this.flowMode = LearningFlowMode.parentRevision,
    this.cycle,
    this.avatarId,
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

  // ── Guided child flow ──────────────────────────────────────────────────────
  // Trilingual learning is the point of the app, so the guided step offers all
  // three languages — but only ONE is required, and it defaults to English.
  // The other two are optional bonus practice worth extra XP and can never
  // block progress.
  //
  // Speech recognition is also the least reliable part of this app, especially
  // for a young voice, so the step must never become a wall: a child may move
  // on once any language succeeds, after two genuine tries in the language
  // they're on, by skipping, or immediately if the browser can't listen.

  /// Best result per language index — once a language is said correctly it
  /// stays correct, so a later failed retry can't take the bonus away.
  final Map<int, bool> _langCorrect = {};

  /// Genuine attempts per language: a result came back, or the recogniser
  /// errored. A silent timeout doesn't count, so an untouched mic can't
  /// unlock Continue.
  final Map<int, int> _langAttempts = {};

  final Map<int, String> _langTranscript = {};

  bool get _guided => widget.flowMode.isGuidedChildFlow;

  static const int _attemptsToUnlock = 2;

  /// Guided-only labels. The standalone drill keeps its own wording, which
  /// must not change.
  static const List<String> _guidedLabels = [
    'English',
    'Bahasa Melayu',
    'Chinese',
  ];

  bool get _anyLanguageSucceeded => _langCorrect.values.any((ok) => ok);

  int get _currentAttempts => _langAttempts[_currentIndex] ?? 0;

  bool get _canContinue =>
      _anyLanguageSucceeded ||
      _currentAttempts >= _attemptsToUnlock ||
      !_micSupported;

  bool get _canSkip => _currentAttempts >= 1 || !_micSupported;

  void _recordAttempt() {
    if (!_guided) return;
    _langAttempts[_currentIndex] = _currentAttempts + 1;
  }

  /// Files a finished attempt against the language it belongs to.
  void _recordLanguageResult(bool correct, String transcript) {
    if (!_guided) return;
    _langCorrect[_currentIndex] = (_langCorrect[_currentIndex] ?? false) || correct;
    _langTranscript[_currentIndex] = transcript;
  }

  /// The buddy's name, for "Teach Kitty the word Chair!".
  String get _buddyName => avatarByIdOrDefault(widget.avatarId).displayName;

  /// The word for the language currently selected.
  String _wordFor(int index) {
    final code = _languages[index]['code'];
    return switch (code) {
      'en' => (widget.vocab['english_word'] as String?) ?? '',
      'ms' => (widget.vocab['malay_word'] as String?) ?? '',
      'zh' => (widget.vocab['chinese_word'] as String?) ?? '',
      _ => '',
    };
  }

  /// Switches which language the child is practising.
  ///
  /// Each language keeps its own result, so moving between them shows what
  /// was already achieved rather than resetting the screen.
  void _selectLanguage(int index) {
    if (index == _currentIndex || _isListening || _isProcessing) return;
    _listenTimer?.cancel();
    _stopActive();
    _releaseStream();
    setState(() {
      _currentIndex = index;
      _hasResult = _langCorrect.containsKey(index);
      _isCorrect = _langCorrect[index] ?? false;
      _transcript = _langTranscript[index] ?? '';
      _errorMessage = null;
      _isListening = false;
      _isProcessing = false;
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _playLanguageAt(index));
  }

  /// Hands the per-language outcomes to the cycle and moves on to the quiz.
  void _finishGuidedSpeech({bool skipped = false}) {
    final cycle = widget.cycle;
    cycle?.speech = SpeechOutcome(
      attempts: _currentAttempts,
      skipped: skipped,
      // One entry per language actually tried; the backend derives the
      // attempted/succeeded counts from exactly this list.
      languages: [
        for (final index in _langAttempts.keys)
          {
            'language': _languages[index]['code']!,
            'correct': _langCorrect[index] ?? false,
          },
      ],
    );

    _listenTimer?.cancel();
    _stopActive();
    _releaseStream();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QuizPracticeScreen(
          vocab: widget.vocab,
          childId: widget.childId,
          flowMode: widget.flowMode,
          cycle: cycle,
        ),
      ),
    );
  }

  /// Plays one specific language, rather than whichever is current — the
  /// guided step keeps all three listenable while only practising English.
  Future<void> _playLanguageAt(int index) async {
    final lang = _languages[index];
    final audioMap = widget.vocab['audio'] as Map<String, dynamic>?;
    final path = audioMap?[lang['code']] as String?;
    final word = switch (lang['code']) {
      'en' => widget.vocab['english_word'] ?? '',
      'ms' => widget.vocab['malay_word'] ?? '',
      'zh' => widget.vocab['chinese_word'] ?? '',
      _ => '',
    };
    try {
      if (path != null) {
        await _player.play(UrlSource('${AppConfig.baseUrl}$path'));
      } else {
        _speakFallback(word as String, lang['speechLang']!);
      }
    } catch (_) {
      _speakFallback(word as String, lang['speechLang']!);
    }
  }

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
          // Something was actually said — a genuine attempt, right or wrong.
          _recordAttempt();
          _recordLanguageResult(correct, transcript);
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
            // Something was actually said — a genuine attempt, right or wrong.
            _recordAttempt();
            _recordLanguageResult(correct, transcript);
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
            // A failing recogniser still counts as a try — otherwise a child
            // whose mic never works could never reach Continue.
            _recordAttempt();
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
    // The guided flow is a separate, single-step screen. The three-language
    // drill below is left exactly as it was for parent/standalone practice.
    if (_guided) return _buildGuided();

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

  /// The guided speaking step.
  ///
  /// All three languages are offered — trilingual practice is the point of
  /// the app — but only ONE is required, and English is selected by default.
  /// Once any language succeeds the other two become optional bonus practice
  /// worth extra XP, and neither can block the child from continuing.
  Widget _buildGuided() {
    final word = _wordFor(_currentIndex);
    final english = (widget.vocab['english_word'] as String?) ?? '';
    final isEnglish = _currentIndex == 0;
    final done = _anyLanguageSucceeded;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  const SizedBox(height: AppTheme.xl),
                  Text(
                    'Teach $_buddyName the word "$word"!',
                    textAlign: TextAlign.center,
                    style: AppTheme.heading.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppTheme.xs),
                  Text(
                    done
                        ? 'Nice! Try another language for bonus stars ⭐'
                        : 'Say it in any language you like',
                    textAlign: TextAlign.center,
                    style: AppTheme.body.copyWith(
                      color: done ? AppTheme.success : AppTheme.textLight,
                      fontWeight: done ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: AppTheme.lg),

                  // ── Language progress + chooser ──
                  // Doubles as the required status display: each language
                  // reads Completed or Not tried at a glance.
                  Row(
                    children: [
                      for (var i = 0; i < _languages.length; i++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                                right: i < _languages.length - 1
                                    ? AppTheme.sm
                                    : 0),
                            child: _LanguageChip(
                              label: _guidedLabels[i],
                              selected: i == _currentIndex,
                              completed: _langCorrect[i] == true,
                              attempted: (_langAttempts[i] ?? 0) > 0,
                              optional: done && _langCorrect[i] != true,
                              onTap: () => _selectLanguage(i),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.lg),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppTheme.xl),
                    decoration: AppTheme.cardDecoration,
                    child: Column(
                      children: [
                        Text(
                          word,
                          textAlign: TextAlign.center,
                          style: AppTheme.heading.copyWith(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        // English stays visible as the anchor when practising
                        // another language, so the child always knows which
                        // word this is.
                        if (!isEnglish && english.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text('English: $english', style: AppTheme.caption),
                        ],
                        const SizedBox(height: AppTheme.lg),
                        Text('Listen', style: AppTheme.caption),
                        const SizedBox(height: AppTheme.sm),
                        // All three languages remain playable, whichever one
                        // is being practised.
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < _languages.length; i++)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.sm),
                                child: Column(
                                  children: [
                                    IconButton(
                                      onPressed: () => _playLanguageAt(i),
                                      iconSize: 26,
                                      icon: const Icon(Icons.volume_up_rounded),
                                      color: AppTheme.primary,
                                      tooltip: 'Play ${_guidedLabels[i]}',
                                    ),
                                    Text(_guidedLabels[i],
                                        style: AppTheme.caption
                                            .copyWith(fontSize: 11)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        if (_hasResult) ...[
                          const SizedBox(height: AppTheme.md),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: _isCorrect
                                  ? AppTheme.successLight
                                  : AppTheme.warningLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _isCorrect
                                      ? 'Perfect! $_buddyName heard you!'
                                      : 'Good try! $_buddyName is still learning',
                                  textAlign: TextAlign.center,
                                  style: AppTheme.body.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: _isCorrect
                                        ? AppTheme.success
                                        : AppTheme.adventure,
                                  ),
                                ),
                                if (_transcript.isNotEmpty)
                                  Text('You said: "$_transcript"',
                                      style: AppTheme.caption),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.xl),

                  if (_micSupported && !_isProcessing)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isListening
                            ? AppTheme.error.withValues(alpha: 0.15)
                            : AppTheme.primary.withValues(alpha: 0.1),
                      ),
                      child: IconButton(
                        iconSize: 68,
                        onPressed: _isListening ? _stopActive : _startActive,
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          size: 68,
                          color: _isListening
                              ? AppTheme.error
                              : AppTheme.primary,
                        ),
                        tooltip:
                            _isListening ? 'Tap to stop' : 'Tap to speak',
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
                        const SizedBox(height: AppTheme.sm),
                        Text('Listening to you...',
                            style: AppTheme.caption
                                .copyWith(color: AppTheme.primary)),
                      ],
                    ),
                  if (_isListening)
                    Padding(
                      padding: const EdgeInsets.only(top: AppTheme.sm),
                      child: Text('Listening... say it now!',
                          style:
                              AppTheme.caption.copyWith(color: AppTheme.error)),
                    ),
                  if (!_micSupported)
                    Padding(
                      padding: const EdgeInsets.only(top: AppTheme.sm),
                      child: Text(
                        "This browser can't hear you — say it out loud "
                        'anyway, then carry on!',
                        textAlign: TextAlign.center,
                        style: AppTheme.caption,
                      ),
                    ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppTheme.sm),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: AppTheme.caption.copyWith(color: AppTheme.error),
                      ),
                    ),

                  const SizedBox(height: AppTheme.xl),

                  // Never a dead end: Continue appears once any language has
                  // succeeded, after two tries in the current language, or
                  // straight away if the browser can't listen at all.
                  if (_canContinue) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _finishGuidedSpeech(),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                        label: const Text('Continue to Quiz'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: AppTheme.textDark,
                          minimumSize: const Size(double.infinity, 58),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          textStyle: AppTheme.buttonText.copyWith(
                            fontSize: 17,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ),
                    ),
                    // Says plainly that the remaining languages are a bonus,
                    // so a child never feels they're leaving something unfinished.
                    if (done && _langCorrect.length < _languages.length) ...[
                      const SizedBox(height: AppTheme.sm),
                      Text(
                        'Tap another language above for bonus practice — '
                        "it's up to you!",
                        textAlign: TextAlign.center,
                        style: AppTheme.caption,
                      ),
                    ],
                  ] else if (_canSkip)
                    TextButton(
                      onPressed: () => _finishGuidedSpeech(skipped: true),
                      child: Text(
                        'Skip for now →',
                        style: AppTheme.caption
                            .copyWith(color: AppTheme.textLight),
                      ),
                    )
                  else
                    Text('Tap the microphone and say the word',
                        style: AppTheme.caption),
                  const SizedBox(height: AppTheme.xxl),
                ],
              ),
            ),
          ),
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

/// One language in the guided step: both the picker and the progress display.
///
/// Status is spelled out in words rather than colour alone, so "Completed" vs
/// "Not tried" is readable to a child (and to anyone who can't distinguish
/// the tick's colour).
class _LanguageChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool completed;
  final bool attempted;

  /// True once another language has already unlocked progression — this one
  /// is now bonus practice.
  final bool optional;

  final VoidCallback onTap;

  const _LanguageChip({
    required this.label,
    required this.selected,
    required this.completed,
    required this.attempted,
    required this.optional,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = completed
        ? AppTheme.success
        : (selected ? AppTheme.primary : AppTheme.textLight);
    final status = completed
        ? 'Completed'
        : attempted
            ? 'Tried'
            : (optional ? 'Bonus' : 'Not tried');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(
              vertical: AppTheme.sm, horizontal: 6),
          decoration: BoxDecoration(
            color: completed
                ? AppTheme.successLight
                : (selected ? AppTheme.primaryLight : AppTheme.surface),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: selected
                  ? accent
                  : accent.withValues(alpha: 0.3),
              width: selected ? 2.5 : 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                completed
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 18,
                color: accent,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTheme.caption.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
              Text(
                status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.caption.copyWith(fontSize: 10, color: accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
