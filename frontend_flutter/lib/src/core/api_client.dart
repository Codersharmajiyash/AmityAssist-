import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/offline_cache_service.dart';

/// Key used to persist the JWT token in SharedPreferences.
const kJwtTokenKey = 'jwt_token';

/// Provides a global singleton instance of Dio for API requests.
final apiClientProvider = Provider<Dio>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);

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

  // ── JWT auth interceptor ──────────────────────────────────
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = prefs.getString(kJwtTokenKey);
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        // On 401 Unauthorized, clear the stored token so the UI
        // can redirect to login.
        if (error.response?.statusCode == 401) {
          prefs.remove(kJwtTokenKey);
        }
        return handler.next(error);
      },
    ),
  );

  return dio;
});
