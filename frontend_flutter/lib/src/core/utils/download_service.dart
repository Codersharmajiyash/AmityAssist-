import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class DownloadService {
  /// Downloads a file by opening it in a new browser tab.
  /// On Flutter Web, this triggers the browser's built-in download behavior
  /// for file types like .docx, .pdf, etc.
  static Future<void> downloadFile(String url, {String? fileName}) async {
    debugPrint('Downloading: $url (File: $fileName)');

    final uri = Uri.parse(url);

    // Use platformDefault mode on web — this opens in a new browser tab
    // which triggers a native download for file types like .docx/.pdf
    try {
      final launched = await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
      if (!launched) {
        debugPrint('Could not launch $url');
      }
    } catch (e) {
      debugPrint('Error launching $url: $e');
    }
  }
}
