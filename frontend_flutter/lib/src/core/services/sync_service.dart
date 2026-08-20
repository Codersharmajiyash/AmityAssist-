import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';
import 'offline_cache_service.dart';

const String _kOfflineQueueKey = 'offline_action_queue';

class SyncAction {
  final String id;
  final String path;
  final String method;
  final Map<String, dynamic> data;

  SyncAction({
    required this.id,
    required this.path,
    required this.method,
    required this.data,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'method': method,
        'data': data,
      };

  factory SyncAction.fromJson(Map<String, dynamic> json) => SyncAction(
        id: json['id'],
        path: json['path'],
        method: json['method'],
        data: json['data'] ?? {},
      );
}

class SyncService {
  final Dio _dio;
  final SharedPreferences _prefs;
  final Connectivity _connectivity;

  SyncService(this._dio, this._prefs) : _connectivity = Connectivity() {
    _initListener();
  }

  void _initListener() {
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.contains(ConnectivityResult.mobile) || results.contains(ConnectivityResult.wifi)) {
        _syncPendingActions();
      }
    });
  }

  Future<void> queueAction(String path, String method, Map<String, dynamic> data) async {
    final queue = _getQueue();
    final action = SyncAction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      path: path,
      method: method,
      data: data,
    );
    queue.add(action);
    await _saveQueue(queue);

    // Try to sync immediately if we have network
    final results = await _connectivity.checkConnectivity();
    if (results.contains(ConnectivityResult.mobile) || results.contains(ConnectivityResult.wifi)) {
      _syncPendingActions();
    }
  }

  List<SyncAction> _getQueue() {
    final str = _prefs.getString(_kOfflineQueueKey);
    if (str == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(str);
      return decoded.map((e) => SyncAction.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveQueue(List<SyncAction> queue) async {
    final encoded = jsonEncode(queue.map((e) => e.toJson()).toList());
    await _prefs.setString(_kOfflineQueueKey, encoded);
  }

  Future<void> _syncPendingActions() async {
    final queue = _getQueue();
    if (queue.isEmpty) return;

    final remainingQueue = <SyncAction>[];

    for (final action in queue) {
      try {
        if (action.method == 'POST') {
          await _dio.post(action.path, data: action.data);
        } else if (action.method == 'PUT') {
          await _dio.put(action.path, data: action.data);
        } else if (action.method == 'DELETE') {
          await _dio.delete(action.path, data: action.data);
        }
      } catch (e) {
        // If it's a 4xx error (e.g. bad request), we probably shouldn't retry it infinitely.
        // But for simplicity in this demo, if it fails, we keep it in the queue.
        remainingQueue.add(action);
      }
    }

    await _saveQueue(remainingQueue);
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  final dio = ref.watch(apiClientProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return SyncService(dio, prefs);
});
