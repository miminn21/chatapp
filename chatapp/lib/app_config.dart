class AppConfig {
  // Change this to your machine's IP when testing on Android emulator
  // For emulator: http://10.0.2.2:3000
  // For web/desktop: http://localhost:3000
  static const String _baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  static String get baseUrl {
    // Auto-detect: Android emulator uses 10.0.2.2
    return _baseUrl;
  }

  static String get apiUrl => '$baseUrl/api';
  static String get socketUrl => baseUrl;
}
