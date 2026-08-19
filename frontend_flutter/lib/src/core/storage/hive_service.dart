import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

class HiveService {
  static const String noticesBox = 'noticesBox';
  static const String profileBox = 'profileBox';

  static Future<void> init() async {
    final appDocumentDirectory = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocumentDirectory.path);

    // Open boxes for caching
    await Hive.openBox(noticesBox);
    await Hive.openBox(profileBox);
  }

  static Future<void> clearAll() async {
    await Hive.box(noticesBox).clear();
    await Hive.box(profileBox).clear();
  }

  // Generic read/write methods
  static Future<void> saveData(String boxName, String key, dynamic data) async {
    final box = Hive.box(boxName);
    await box.put(key, data);
  }

  static dynamic getData(String boxName, String key) {
    final box = Hive.box(boxName);
    return box.get(key);
  }
}
