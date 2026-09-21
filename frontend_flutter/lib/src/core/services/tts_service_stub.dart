import 'dart:async';
import 'package:flutter/foundation.dart';

/// Non-web fallback stub for TtsService.
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  bool get isSpeaking => false;

  final _speakStateController = StreamController<bool>.broadcast();
  Stream<bool> get onSpeakingStateChanged => _speakStateController.stream;

  void speak(
    String text, {
    String lang = 'en-IN',
    double rate = 1.0,
    double pitch = 1.0,
    VoidCallback? onComplete,
  }) {
    onComplete?.call();
  }

  void stop() {}
}
