import 'dart:async';
import 'package:flutter/foundation.dart';

/// Non-web fallback stub for SttService.
class SttService {
  static final SttService _instance = SttService._internal();
  factory SttService() => _instance;
  SttService._internal();

  bool get isListening => false;

  final _textController = StreamController<String>.broadcast();
  Stream<String> get onTranscriptChanged => _textController.stream;

  final _listeningStateController = StreamController<bool>.broadcast();
  Stream<bool> get onListeningStateChanged => _listeningStateController.stream;

  void startListening({
    String lang = 'en-IN',
    void Function(String text)? onResult,
    VoidCallback? onError,
  }) {}

  void stopListening() {}
}
