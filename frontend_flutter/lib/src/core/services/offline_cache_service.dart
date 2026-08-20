import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences-backed JSON cache for offline operation.
///
/// Stores API responses as JSON strings keyed by a cache key.
/// When the network is unavailable, providers can fall back to cached data.
class OfflineCacheService {
  OfflineCacheService(this._prefs);

  final SharedPreferences _prefs;

  static const _prefix = 'cache_';

  /// Persist a JSON-encodable value under [key].
  Future<void> put(String key, dynamic value) async {
    final json = jsonEncode(value);
    await _prefs.setString('$_prefix$key', json);
  }

  /// Retrieve a cached value for [key], or `null` if none exists.
  dynamic get(String key) {
    final raw = _prefs.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  /// Remove a single cached entry.
  Future<void> remove(String key) async {
    await _prefs.remove('$_prefix$key');
  }

  /// Clear all cached entries (but not non-cache prefs like JWT).
  Future<void> clearAll() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith(_prefix));
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }
}

/// Global SharedPreferences instance — initialised in main.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  // This is overridden in main() with a ProviderScope override.
  throw UnimplementedError('SharedPreferences not initialised');
});

final offlineCacheProvider = Provider<OfflineCacheService>((ref) {
  return OfflineCacheService(ref.watch(sharedPreferencesProvider));
});
