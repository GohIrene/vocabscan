/// Centralised API configuration.
/// Change [baseUrl] when switching between local development and phone testing.
class AppConfig {
  /// The base URL for the Flask backend.
  /// - Local web development: 'http://127.0.0.1:5000'
  /// - Phone on same Wi-Fi :   'http://<YOUR_PC_IP>:5000'
  static const String baseUrl = 'http://127.0.0.1:5000';
}
