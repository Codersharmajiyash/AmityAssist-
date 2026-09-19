/// Centralized API configuration for UniAssist.
/// Supports compile-time environment overrides via:
/// flutter run --dart-define=API_BASE_URL=http://your-server:8000
class ApiConfig {
  static const String serverUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static String get apiUrl => '$serverUrl/api';

  static String get wsUrl {
    if (serverUrl.startsWith('https://')) {
      return serverUrl.replaceFirst('https://', 'wss://');
    }
    return serverUrl.replaceFirst('http://', 'ws://');
  }

  static String fullUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$serverUrl$cleanPath';
  }
}
