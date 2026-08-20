import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A mocked Push Notification service scaffolding.
/// In a real deployment, this would use firebase_messaging and firebase_core.
/// We use this mock to prevent compilation errors without google-services.json.
class PushNotificationService {
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    
    // Simulate Firebase initialization
    debugPrint('PushNotificationService: Initializing FCM (Mock)');
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Request permission (mock)
    await _requestPermission();

    // Get FCM Token (mock)
    final token = await _getMockFcmToken();
    debugPrint('PushNotificationService: FCM Token = $token');

    // Set up foreground message listeners (mock)
    _listenToForegroundMessages();

    _initialized = true;
  }

  Future<void> _requestPermission() async {
    // In real app: FirebaseMessaging.instance.requestPermission(...)
    debugPrint('PushNotificationService: Permission requested & granted.');
  }

  Future<String> _getMockFcmToken() async {
    // In real app: return await FirebaseMessaging.instance.getToken();
    return 'mock_fcm_token_12345';
  }

  void _listenToForegroundMessages() {
    // In real app: FirebaseMessaging.onMessage.listen((RemoteMessage message) { ... })
    debugPrint('PushNotificationService: Listening for foreground messages.');
  }

  /// Simulate receiving a push notification while the app is open
  void simulateIncomingNotification(BuildContext context, String title, String body) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(body),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            debugPrint('User tapped simulated push notification');
          },
        ),
      ),
    );
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService();
});
