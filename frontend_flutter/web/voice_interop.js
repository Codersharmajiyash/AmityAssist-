// UniAssist Web Speech API Interop
// Provides high-reliability speech-to-text recognition and text-to-speech audio synthesis.

window.uniassistVoice = {
  recognition: null,
  isListening: false,
  isSpeaking: false,

  isSpeechSupported: function() {
    var hasRecognition = ('webkitSpeechRecognition' in window || 'SpeechRecognition' in window);
    var hasSynthesis = ('speechSynthesis' in window);
    return hasRecognition && hasSynthesis;
  },

  startListening: function(lang, onResult, onError) {
    try {
      var SpeechRec = window.SpeechRecognition || window.webkitSpeechRecognition;
      if (!SpeechRec) {
        if (onError) onError("Speech Recognition not supported in this browser.");
        return;
      }

      if (this.recognition) {
        try { this.recognition.abort(); } catch (e) {}
      }

      var rec = new SpeechRec();
      rec.lang = lang || 'en-IN';
      rec.continuous = false;
      rec.interimResults = false;
      rec.maxAlternatives = 1;

      rec.onstart = function() {
        window.uniassistVoice.isListening = true;
      };

      rec.onresult = function(event) {
        window.uniassistVoice.isListening = false;
        if (event.results && event.results.length > 0) {
          var transcript = event.results[0][0].transcript;
          if (onResult) onResult(transcript);
        }
      };

      rec.onerror = function(event) {
        window.uniassistVoice.isListening = false;
        if (onError) onError(event.error || "Speech error");
      };

      rec.onend = function() {
        window.uniassistVoice.isListening = false;
      };

      this.recognition = rec;
      rec.start();
    } catch (err) {
      window.uniassistVoice.isListening = false;
      if (onError) onError(err.message || String(err));
    }
  },

  stopListening: function() {
    if (this.recognition) {
      try { this.recognition.stop(); } catch (e) {}
    }
    this.isListening = false;
  },

  speak: function(text, lang, rate) {
    if (!('speechSynthesis' in window)) return;
    try {
      window.speechSynthesis.cancel();
      var clean = (text || '').replace(/[#*`_]/g, '');
      var utterance = new SpeechSynthesisUtterance(clean);
      utterance.lang = lang || 'en-IN';
      utterance.rate = rate || 0.95;

      window.uniassistVoice.isSpeaking = true;
      utterance.onend = function() {
        window.uniassistVoice.isSpeaking = false;
      };
      utterance.onerror = function() {
        window.uniassistVoice.isSpeaking = false;
      };

      window.speechSynthesis.speak(utterance);
    } catch (e) {
      window.uniassistVoice.isSpeaking = false;
    }
  },

  stopSpeaking: function() {
    if ('speechSynthesis' in window) {
      window.speechSynthesis.cancel();
    }
    this.isSpeaking = false;
  }
};
