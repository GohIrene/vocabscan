/// Centralised API configuration.
/// Change [baseUrl] when switching between local development and phone testing.
class AppConfig {
  /// The base URL for the Flask backend.
  ///
  /// LAPTOP / LOCAL TESTING (current): use 127.0.0.1
  ///   static const String baseUrl = 'http://127.0.0.1:5000';
  ///
  /// PHONE TESTING (do later): comment out the line above and use the
  /// laptop's current Wi-Fi/hotspot IP (find it with `ipconfig`). This same
  /// LAN IP also works on the laptop, so you can leave it on for both.
  ///   static const String baseUrl = 'http://172.20.10.2:5000';  // <- update IP when network changes
  static const String baseUrl = 'http://127.0.0.1:5000';
}
