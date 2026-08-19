import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/uniassist_app.dart';
import 'src/core/storage/hive_service.dart';
import 'src/core/services/notification_service.dart';
import 'src/core/services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await HiveService.init();
  await NotificationService.init();
  SyncService.init();

  runApp(const ProviderScope(child: UniAssistApp()));
}
