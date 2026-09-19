import 'package:flutter/foundation.dart';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Bridge between Flutter Web and browser native Web Speech API.
class WebVoiceBridge {
  static bool get isSupported {
    if (!kIsWeb) return false;
    try {
      final voice = globalContext['uniassistVoice'] as JSObject?;
      if (voice == null) return false;
      final fn = voice['isSpeechSupported'] as JSFunction?;
      if (fn == null) return false;
      final res = fn.callAsFunction(voice);
      return (res as JSBoolean?)?.toDart ?? false;
    } catch (_) {
      return false;
    }
  }

  static void startListening({
    String lang = 'en-IN',
    required void Function(String text) onResult,
    required void Function(String error) onError,
  }) {
    if (!kIsWeb) {
      onError('Speech recognition is only supported in web browser mode.');
      return;
    }
    try {
      final voice = globalContext['uniassistVoice'] as JSObject?;
      if (voice == null) {
        onError('Voice service not loaded in browser.');
        return;
      }
      final fn = voice['startListening'] as JSFunction?;
      if (fn == null) {
        onError('Speech recognition function not available.');
        return;
      }

      final onResultJS = ((JSString text) {
        onResult(text.toDart);
      }).toJS;

      final onErrorJS = ((JSString err) {
        onError(err.toDart);
      }).toJS;

      fn.callAsFunction(voice, lang.toJS, onResultJS, onErrorJS);
    } catch (e) {
      onError(e.toString());
    }
  }

  static void stopListening() {
    if (!kIsWeb) return;
    try {
      final voice = globalContext['uniassistVoice'] as JSObject?;
      final fn = voice?['stopListening'] as JSFunction?;
      fn?.callAsFunction(voice);
    } catch (_) {}
  }

  static void speak(
    String text, {
    String lang = 'en-IN',
    double rate = 0.95,
  }) {
    if (!kIsWeb) return;
    try {
      final voice = globalContext['uniassistVoice'] as JSObject?;
      final fn = voice?['speak'] as JSFunction?;
      if (fn == null) return;
      fn.callAsFunction(voice, text.toJS, lang.toJS, rate.toJS);
    } catch (_) {}
  }

  static void stopSpeaking() {
    if (!kIsWeb) return;
    try {
      final voice = globalContext['uniassistVoice'] as JSObject?;
      final fn = voice?['stopSpeaking'] as JSFunction?;
      fn?.callAsFunction(voice);
    } catch (_) {}
  }
}
