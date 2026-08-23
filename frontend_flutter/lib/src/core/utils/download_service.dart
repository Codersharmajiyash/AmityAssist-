import 'package:flutter/foundation.dart';

class DownloadService {
  static void downloadFile(String url, {String? fileName}) {
    // In web/desktop, log and handle download gracefully without failing unit tests
    debugPrint('Downloading: $url (File: $fileName)');
  }
}
