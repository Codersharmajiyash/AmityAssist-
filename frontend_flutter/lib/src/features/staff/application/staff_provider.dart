import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';

// Admin Stats
final adminStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(apiClientProvider);
  final response = await dio.get('/admin/stats');
  return response.data as Map<String, dynamic>;
});

// Admin Requests
final adminRequestsProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ref.watch(apiClientProvider);
  final response = await dio.get('/admin/requests');
  return response.data as List<dynamic>;
});

// Admin Grievances
final adminGrievancesProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ref.watch(apiClientProvider);
  final response = await dio.get('/admin/grievances');
  return response.data as List<dynamic>;
});

// Admin Documents
final adminDocumentsProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ref.watch(apiClientProvider);
  final response = await dio.get('/admin/documents');
  return response.data as List<dynamic>;
});

// Actions
final staffActionsProvider = Provider<StaffActions>((ref) {
  return StaffActions(ref.watch(apiClientProvider), ref);
});

class StaffActions {
  final Dio _dio;
  final Ref _ref;

  StaffActions(this._dio, this._ref);

  Future<void> updateRequestStatus(int id, String status) async {
    await _dio.post('/admin/requests/$id/status', data: {'status': status});
    _ref.invalidate(adminRequestsProvider);
    _ref.invalidate(adminStatsProvider);
  }

  Future<void> resolveGrievance(int id, String resolution) async {
    await _dio.post('/admin/grievances/$id/resolve', data: {'resolution': resolution});
    _ref.invalidate(adminGrievancesProvider);
    _ref.invalidate(adminStatsProvider);
  }

  Future<void> verifyDocument(int id, String status, String notes) async {
    await _dio.post('/admin/documents/$id/verify', data: {
      'status': status,
      'admin_notes': notes
    });
    _ref.invalidate(adminDocumentsProvider);
  }
}
