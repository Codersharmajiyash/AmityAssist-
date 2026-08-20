import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../auth/application/auth_provider.dart';

/// Notification model matching backend schema.
class AppNotification {
  final int id;
  final String studentId;
  final String type;
  final String title;
  final String message;
  final String priority;
  final bool isRead;
  final String createdAt;

  AppNotification({
    required this.id,
    required this.studentId,
    required this.type,
    required this.title,
    required this.message,
    required this.priority,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? 0,
      studentId: json['student_id'] ?? '',
      type: json['type'] ?? 'alert',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      priority: json['priority'] ?? 'normal',
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] ?? '',
    );
  }
}

/// Fetch all notifications for the logged-in student.
final notificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final dio = ref.watch(apiClientProvider);
  final studentId = ref.watch(authProvider).studentId;
  final cache = ref.watch(offlineCacheProvider);

  if (studentId == null) return [];

  try {
    final response =
        await dio.get('/notifications', queryParameters: {'student_id': studentId});

    final items = (response.data as List? ?? [])
        .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    // Cache for offline
    await cache.put('notifications_$studentId', response.data);
    return items;
  } catch (e) {
    final cached = cache.get('notifications_$studentId');
    if (cached != null) {
      return (cached as List)
          .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }
});

/// Count of unread notifications for dashboard badge.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifs = ref.watch(notificationsProvider);
  return notifs.when(
    data: (list) => list.where((n) => !n.isRead).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});
