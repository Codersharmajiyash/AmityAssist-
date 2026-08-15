import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides a global singleton instance of Dio for API requests.
final apiClientProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    // Localhost IP address for Android emulator is 10.0.2.2.
    // For desktop/web, it is 127.0.0.1.
    // We default to 127.0.0.1 for desktop testing.
    baseUrl: 'http://127.0.0.1:8000/api',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  // Add a simple interceptor for logging/error handling if needed.
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        // Optionally attach token here in Phase 6
        return handler.next(options);
      },
    ),
  );

  return dio;
});
