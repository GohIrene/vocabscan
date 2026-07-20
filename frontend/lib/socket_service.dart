import 'package:socket_io_client/socket_io_client.dart' as io;
import 'config.dart';

/// Carries an active teacher session into the scan/result flow so the result
/// screen can push a quiz. Null everywhere in normal Home mode.
class ClassSessionContext {
  final String sessionId;
  final SocketService socket;

  const ClassSessionContext({required this.sessionId, required this.socket});
}

/// Thin real-time connection manager around the Flask-SocketIO backend.
///
/// One instance manages a single socket for a Class Code session. The server
/// is Socket.IO (protocol v5), so we use socket_io_client — raw WebSocket
/// would fail the handshake. MongoDB is the source of truth on the server;
/// this class is transport only.
class SocketService {
  io.Socket? _socket;

  // ── Session identity (re-sent on every (re)connect) ──
  String? _code;
  String? _role;
  String? _nickname;

  // ── Callback registration (all optional) ──
  void Function(Map<String, dynamic> data)? onNewQuiz;
  void Function(Map<String, dynamic> data)? onAnswerResult;
  void Function(Map<String, dynamic> data)? onAnswerReceived;
  void Function(Map<String, dynamic> data)? onStudentJoined;
  void Function(Map<String, dynamic> data)? onStudentLeft;
  void Function(Map<String, dynamic> data)? onSessionEnded;
  void Function(Map<String, dynamic> data)? onAnswerRejected;
  void Function(Map<String, dynamic> data)? onSessionError;
  void Function(bool connected)? onConnectionChange;

  bool get isConnected => _socket?.connected ?? false;

  /// Opens the socket and joins the given session room.
  /// [role] is 'teacher' or 'student'; [nickname] is required for students.
  void connect({
    required String code,
    required String role,
    String? nickname,
  }) {
    _code = code;
    _role = role;
    _nickname = nickname;

    // Reuse the same socket if already connected to this session.
    _socket?.dispose();

    final socket = io.io(
      AppConfig.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableReconnection()
          .setReconnectionAttempts(9999)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .build(),
    );
    _socket = socket;

    // 'connect' fires on the first connection AND on every auto-reconnect,
    // so re-emitting connect_session here keeps the server state in sync.
    socket.onConnect((_) {
      onConnectionChange?.call(true);
      _emitConnectSession();
    });
    socket.onDisconnect((_) => onConnectionChange?.call(false));
    socket.onConnectError((_) => onConnectionChange?.call(false));

    socket.on('new_quiz', (d) => onNewQuiz?.call(_asMap(d)));
    socket.on('answer_result', (d) => onAnswerResult?.call(_asMap(d)));
    socket.on('answer_received', (d) => onAnswerReceived?.call(_asMap(d)));
    socket.on('student_joined', (d) => onStudentJoined?.call(_asMap(d)));
    socket.on('student_left', (d) => onStudentLeft?.call(_asMap(d)));
    socket.on('session_ended', (d) => onSessionEnded?.call(_asMap(d)));
    socket.on('answer_rejected', (d) => onAnswerRejected?.call(_asMap(d)));
    socket.on('session_error', (d) => onSessionError?.call(_asMap(d)));

    socket.connect();
  }

  void _emitConnectSession() {
    final payload = <String, dynamic>{'code': _code, 'role': _role};
    if (_nickname != null) payload['nickname'] = _nickname;
    _socket?.emit('connect_session', payload);
  }

  // ── Emitters ──

  void pushQuiz(String sessionId, String englishKey) {
    _socket?.emit('push_quiz', {
      'session_id': sessionId,
      'english_key': englishKey,
    });
  }

  void submitAnswer(
    String sessionId,
    String nickname,
    String quizId,
    String chosen,
  ) {
    _socket?.emit('submit_answer', {
      'session_id': sessionId,
      'nickname': nickname,
      'quiz_id': quizId,
      'chosen': chosen,
    });
  }

  void endSession(String sessionId) {
    _socket?.emit('end_session', {'session_id': sessionId});
  }

  /// Closes the socket. MUST be called from every screen's dispose().
  void dispose() {
    _socket?.dispose();
    _socket = null;
  }

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }
}
