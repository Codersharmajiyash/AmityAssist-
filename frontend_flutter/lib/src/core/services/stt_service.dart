// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:js' as js;
import 'package:flutter/foundation.dart';

/// Service providing real microphone speech recognition via WebkitSpeechRecognition API.
class SttService {
  static final SttService _instance = SttService._internal();
  factory SttService() => _instance;
  SttService._internal();

  bool _isListening = false;
  bool get isListening => _isListening;

  final _textController = StreamController<String>.broadcast();
  Stream<String> get onTranscriptChanged => _textController.stream;

  final _listeningStateController = StreamController<bool>.broadcast();
  Stream<bool> get onListeningStateChanged => _listeningStateController.stream;

  /// Starts listening to the user's microphone.
  void startListening({String lang = 'en-IN', void Function(String text)? onResult, VoidCallback? onError}) {
    if (!kIsWeb) {
      debugPrint('[SttService] Speech recognition only supported on Web currently.');
      return;
    }

    try {
      stopListening();
      _isListening = true;
      _listeningStateController.add(true);

      // Register JS callbacks
      js.context['_onUniAssistSttResult'] = (dynamic text, dynamic isFinal) {
        final recognized = text.toString();
        _textController.add(recognized);
        if (isFinal == true) {
          _isListening = false;
          _listeningStateController.add(false);
          onResult?.call(recognized);
        }
      };

      js.context['_onUniAssistSttEnd'] = () {
        _isListening = false;
        _listeningStateController.add(false);
      };

      js.context['_onUniAssistSttError'] = (dynamic err) {
        debugPrint('[SttService] JS Recognition Error: $err');
        _isListening = false;
        _listeningStateController.add(false);
        onError?.call();
      };

      js.context.callMethod('eval', [
        """
        (function(lang) {
          var SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
          if (!SpeechRecognition) {
            console.warn('SpeechRecognition API not available in this browser');
            if (window._onUniAssistSttError) window._onUniAssistSttError('Not supported');
            return;
          }
          if (window._uniAssistRecognition) {
            try { window._uniAssistRecognition.abort(); } catch(e){}
          }
          var recognition = new SpeechRecognition();
          window._uniAssistRecognition = recognition;
          recognition.continuous = false;
          recognition.interimResults = true;
          recognition.lang = lang || 'en-IN';

          recognition.onresult = function(event) {
            var interim = '';
            var finalTranscript = '';
            for (var i = event.resultIndex; i < event.results.length; ++i) {
              if (event.results[i].isFinal) {
                finalTranscript += event.results[i][0].transcript;
              } else {
                interim += event.results[i][0].transcript;
              }
            }
            if (finalTranscript.length > 0) {
              if (window._onUniAssistSttResult) window._onUniAssistSttResult(finalTranscript, true);
            } else if (interim.length > 0) {
              if (window._onUniAssistSttResult) window._onUniAssistSttResult(interim, false);
            }
          };

          recognition.onerror = function(event) {
            console.warn('STT recognition error:', event.error);
            if (window._onUniAssistSttError) window._onUniAssistSttError(event.error);
          };

          recognition.onend = function() {
            if (window._onUniAssistSttEnd) window._onUniAssistSttEnd();
          };

          try {
            recognition.start();
          } catch(e) {
            console.warn('Recognition start exception:', e);
          }
        })('$lang')
        """
      ]);
    } catch (e) {
      debugPrint('[SttService] Error starting recognition: $e');
      _isListening = false;
      _listeningStateController.add(false);
      onError?.call();
    }
  }

  /// Stop listening to microphone.
  void stopListening() {
    if (!kIsWeb) return;
    try {
      js.context.callMethod('eval', [
        """
        if (window._uniAssistRecognition) {
          try { window._uniAssistRecognition.stop(); } catch(e){}
        }
        """
      ]);
      _isListening = false;
      _listeningStateController.add(false);
    } catch (e) {
      debugPrint('[SttService] Error stopping recognition: $e');
    }
  }
}
