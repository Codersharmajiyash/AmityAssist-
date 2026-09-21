// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:js' as js;
import 'package:flutter/foundation.dart';

/// Service providing real audible speech synthesis via Web SpeechSynthesis API.
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;

  final _speakStateController = StreamController<bool>.broadcast();
  Stream<bool> get onSpeakingStateChanged => _speakStateController.stream;

  /// Speaks the provided [text] out loud through the device audio.
  void speak(String text, {String lang = 'en-IN', double rate = 1.0, double pitch = 1.0, VoidCallback? onComplete}) {
    if (!kIsWeb) {
      debugPrint('[TtsService] Non-web platform: $text');
      onComplete?.call();
      return;
    }

    try {
      // Cancel previous utterances
      stop();

      final cleanText = text
          .replaceAll(RegExp(r'[\*\_#`>]'), '') // strip markdown
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      if (cleanText.isEmpty) return;

      _isSpeaking = true;
      _speakStateController.add(true);

      // Invoke window.speechSynthesis via JS context
      js.context.callMethod('eval', [
        """
        (function(text, lang, rate, pitch) {
          if (!('speechSynthesis' in window)) return;
          window.speechSynthesis.cancel();
          var utterance = new SpeechSynthesisUtterance(text);
          utterance.lang = lang || 'en-IN';
          utterance.rate = rate || 1.0;
          utterance.pitch = pitch || 1.0;
          
          // Select natural English voice if available
          var voices = window.speechSynthesis.getVoices();
          var preferred = voices.find(function(v) { 
            return (v.lang.includes('en-IN') || v.lang.includes('en-US') || v.lang.includes('en-GB')) && !v.name.includes('Google') === false;
          }) || voices.find(function(v) { return v.lang.startsWith('en'); });
          if (preferred) utterance.voice = preferred;

          utterance.onend = function() {
            if (window._onUniAssistTtsEnd) window._onUniAssistTtsEnd();
          };
          utterance.onerror = function(e) {
            console.warn('TTS error:', e);
            if (window._onUniAssistTtsEnd) window._onUniAssistTtsEnd();
          };

          window.speechSynthesis.speak(utterance);
        })(${_escapeJsString(cleanText)}, '$lang', $rate, $pitch)
        """
      ]);

      // Attach JS callback handler
      js.context['_onUniAssistTtsEnd'] = () {
        _isSpeaking = false;
        _speakStateController.add(false);
        onComplete?.call();
      };
    } catch (e) {
      debugPrint('[TtsService] Error speaking: $e');
      _isSpeaking = false;
      _speakStateController.add(false);
      onComplete?.call();
    }
  }

  /// Immediately stop any speaking audio.
  void stop() {
    if (!kIsWeb) return;
    try {
      js.context.callMethod('eval', [
        "if ('speechSynthesis' in window) window.speechSynthesis.cancel();"
      ]);
      _isSpeaking = false;
      _speakStateController.add(false);
    } catch (e) {
      debugPrint('[TtsService] Error stopping speech: $e');
    }
  }

  static String _escapeJsString(String s) {
    final escaped = s
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('"', r'\"')
        .replaceAll('\n', ' ')
        .replaceAll('\r', '');
    return "'$escaped'";
  }
}
