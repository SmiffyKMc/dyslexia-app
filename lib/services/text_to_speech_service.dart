import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;

enum TTSStatus {
  idle,
  speaking,
  paused,
  stopped,
  error
}

enum PhonemeType {
  vowel,
  consonant,
  digraph,
  blend,
  other
}

class TTSRequest {
  final String text;
  final double? speechRate;
  final Completer<void> completer;
  final DateTime createdAt;
  
  TTSRequest({
    required this.text,
    this.speechRate,
    required this.completer,
    required this.createdAt,
  });
}

class TextToSpeechService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  TTSStatus _status = TTSStatus.idle;
  double _defaultSpeechRate = 0.5;
  
  // Queue system to prevent conflicts
  final Queue<TTSRequest> _speechQueue = Queue<TTSRequest>();
  bool _isProcessingQueue = false;
  
  // State management
  StreamController<TTSStatus>? _statusController;
  Timer? _timeoutTimer;
  
  // Current request tracking
  TTSRequest? _currentRequest;
  
  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _status == TTSStatus.speaking;
  TTSStatus get status => _status;
  
  Stream<TTSStatus> get statusStream {
    _statusController ??= StreamController<TTSStatus>.broadcast();
    return _statusController!.stream;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      developer.log('🔊 Initializing TTS service', name: 'dyslexic_ai.tts');
      
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(_defaultSpeechRate);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      // Set up completion handlers
      _flutterTts.setCompletionHandler(() {
        developer.log('🔊 TTS completion handler called', name: 'dyslexic_ai.tts');
        _onSpeechComplete();
      });

      _flutterTts.setErrorHandler((message) {
        developer.log('🔊 TTS error: $message', name: 'dyslexic_ai.tts');
        _onSpeechError(message);
      });

      _flutterTts.setStartHandler(() {
        developer.log('🔊 TTS started speaking', name: 'dyslexic_ai.tts');
        _updateStatus(TTSStatus.speaking);
      });

      _flutterTts.setPauseHandler(() {
        developer.log('🔊 TTS paused', name: 'dyslexic_ai.tts');
        _updateStatus(TTSStatus.paused);
      });

      _flutterTts.setContinueHandler(() {
        developer.log('🔊 TTS continued', name: 'dyslexic_ai.tts');
        _updateStatus(TTSStatus.speaking);
      });

      _isInitialized = true;
      _updateStatus(TTSStatus.idle);
      
      developer.log('🔊 TTS service initialized successfully', name: 'dyslexic_ai.tts');
    } catch (e) {
      developer.log('🔊 TTS initialization failed: $e', name: 'dyslexic_ai.tts');
      _updateStatus(TTSStatus.error);
      rethrow;
    }
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (text.trim().isEmpty) {
      developer.log('🔊 Empty text provided to speak()', name: 'dyslexic_ai.tts');
      return;
    }

    return _queueSpeechRequest(TTSRequest(
      text: text,
      speechRate: _defaultSpeechRate,
      completer: Completer<void>(),
      createdAt: DateTime.now(),
    ));
  }

  Future<void> speakWord(String word) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (word.trim().isEmpty) {
      developer.log('🔊 Empty word provided to speakWord()', name: 'dyslexic_ai.tts');
      return;
    }

    return _queueSpeechRequest(TTSRequest(
      text: word,
      speechRate: 0.3, // Slower rate for individual words
      completer: Completer<void>(),
      createdAt: DateTime.now(),
    ));
  }

  /// Speak a phoneme with enhanced pronunciation using SSML
  Future<void> speakPhoneme(String phoneme, {bool useSSML = true}) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (phoneme.trim().isEmpty) {
      developer.log('🔊 Empty phoneme provided to speakPhoneme()', name: 'dyslexic_ai.tts');
      return;
    }

    String textToSpeak;
    double speechRate;
    
    if (useSSML) {
      textToSpeak = _buildPhonemeSSML(phoneme);
      speechRate = _getOptimalSpeechRate(phoneme);
    } else {
      textToSpeak = phoneme;
      speechRate = 0.4; // Slower for phonemes
    }

    return _queueSpeechRequest(TTSRequest(
      text: textToSpeak,
      speechRate: speechRate,
      completer: Completer<void>(),
      createdAt: DateTime.now(),
    ));
  }

  /// Speak a phoneme with enhanced clarity and emphasis
  Future<void> speakPhonemeWithEmphasis(String phoneme) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (phoneme.trim().isEmpty) {
      developer.log('🔊 Empty phoneme provided to speakPhonemeWithEmphasis()', name: 'dyslexic_ai.tts');
      return;
    }

    final ssmlText = _buildPhonemeSSMLWithEmphasis(phoneme);
    final speechRate = _getOptimalSpeechRate(phoneme);

    return _queueSpeechRequest(TTSRequest(
      text: ssmlText,
      speechRate: speechRate,
      completer: Completer<void>(),
      createdAt: DateTime.now(),
    ));
  }

  /// Build SSML markup for enhanced phoneme pronunciation (conservative approach)
  String _buildPhonemeSSML(String phoneme) {
    final phonemeType = _getPhonemeType(phoneme);
    
    switch (phonemeType) {
      case PhonemeType.vowel:
        return '<speak><prosody rate="slow" pitch="medium">$phoneme</prosody></speak>';
      
      case PhonemeType.consonant:
        return '<speak><prosody rate="x-slow" pitch="low">$phoneme</prosody></speak>';
      
      case PhonemeType.digraph:
        return '<speak><prosody rate="slow" pitch="medium">$phoneme</prosody><break time="200ms"/></speak>';
      
      case PhonemeType.blend:
        return '<speak><prosody rate="slow">$phoneme</prosody></speak>';
      
      default:
        return '<speak><prosody rate="slow">$phoneme</prosody></speak>';
    }
  }

  /// Build SSML markup with emphasis for difficult phonemes (conservative approach)
  String _buildPhonemeSSMLWithEmphasis(String phoneme) {
    return '<speak>'
           '<prosody rate="x-slow" pitch="medium" volume="loud">'
           '<emphasis level="strong">$phoneme</emphasis>'
           '</prosody>'
           '<break time="300ms"/>'
           '</speak>';
  }

  /// Get optimal speech rate for different phoneme types
  double _getOptimalSpeechRate(String phoneme) {
    final phonemeType = _getPhonemeType(phoneme);
    
    switch (phonemeType) {
      case PhonemeType.vowel:
        return 0.3; // Very slow for vowels
      case PhonemeType.consonant:
        return 0.4; // Slow for consonants
      case PhonemeType.digraph:
        return 0.35; // Extra slow for digraphs
      case PhonemeType.blend:
        return 0.45; // Moderate slow for blends
      default:
        return 0.4; // Default slow rate
    }
  }

  /// Determine phoneme type for appropriate SSML treatment
  PhonemeType _getPhonemeType(String phoneme) {
    final p = phoneme.toLowerCase();
    
    // Vowels
    if (['a', 'e', 'i', 'o', 'u', 'aa', 'ee', 'ii', 'oo', 'uu', 'a_e', 'e_e', 'i_e', 'o_e', 'u_e'].contains(p)) {
      return PhonemeType.vowel;
    }
    
    // Digraphs
    if (['ch', 'sh', 'th', 'ph', 'wh', 'ck', 'ng'].contains(p)) {
      return PhonemeType.digraph;
    }
    
    // Consonant blends
    if (['bl', 'br', 'cl', 'cr', 'dr', 'fl', 'fr', 'gl', 'gr', 'pl', 'pr', 'sc', 'sk', 'sl', 'sm', 'sn', 'sp', 'st', 'sw', 'tr', 'tw', 'scr', 'spl', 'spr', 'str', 'thr'].contains(p)) {
      return PhonemeType.blend;
    }
    
    // Single consonants
    if (['b', 'c', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'm', 'n', 'p', 'q', 'r', 's', 't', 'v', 'w', 'x', 'y', 'z'].contains(p)) {
      return PhonemeType.consonant;
    }
    
    return PhonemeType.other;
  }



  Future<void> _queueSpeechRequest(TTSRequest request) async {
    try {
      developer.log('🔊 Queueing speech request: "${request.text}"', name: 'dyslexic_ai.tts');
      
      _speechQueue.add(request);
      _processQueueIfNeeded();
      
      return request.completer.future;
    } catch (e) {
      developer.log('🔊 Failed to queue speech request: $e', name: 'dyslexic_ai.tts');
      request.completer.completeError(e);
      rethrow;
    }
  }

  Future<void> _processQueueIfNeeded() async {
    if (_isProcessingQueue || _speechQueue.isEmpty) return;
    
    _isProcessingQueue = true;
    
    try {
      while (_speechQueue.isNotEmpty && _status != TTSStatus.error) {
        final request = _speechQueue.removeFirst();
        await _processSpeechRequest(request);
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  Future<void> _processSpeechRequest(TTSRequest request) async {
    try {
      developer.log('🔊 Processing speech request: "${request.text}"', name: 'dyslexic_ai.tts');
      
      // Safety check - don't process if not initialized or in error state
      if (!_isInitialized || _status == TTSStatus.error) {
        developer.log('🔊 Skipping TTS request - service not ready', name: 'dyslexic_ai.tts');
        if (!request.completer.isCompleted) {
          request.completer.completeError(Exception('TTS service not ready'));
        }
        return;
      }
      
      _currentRequest = request;
      
      // Set speech rate if specified
      if (request.speechRate != null) {
        await _flutterTts.setSpeechRate(request.speechRate!);
      }
      
      // Set timeout for speech completion
      _startTimeoutTimer();
      
      // Start speaking
      await _flutterTts.speak(request.text);
      
      // Note: completion will be handled by the completion handler
    } catch (e) {
      developer.log('🔊 Speech request failed: $e', name: 'dyslexic_ai.tts');
      _onSpeechError(e.toString());
    }
  }

  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 10), () {  // Reduced from 30 to 10 seconds
      developer.log('🔊 Speech timeout - forcing completion', name: 'dyslexic_ai.tts');
      _onSpeechComplete();
    });
  }

  void _onSpeechComplete() {
    _timeoutTimer?.cancel();
    
    if (_currentRequest != null && !_currentRequest!.completer.isCompleted) {
      try {
        _currentRequest!.completer.complete();
      } catch (e) {
        developer.log('🔊 Error completing TTS request: $e', name: 'dyslexic_ai.tts');
      }
    }
    
    _currentRequest = null;
    _updateStatus(TTSStatus.idle);
    
    // Reset speech rate to default after word pronunciation
    try {
      if (_defaultSpeechRate != 0.5) {
        _flutterTts.setSpeechRate(_defaultSpeechRate);
      }
    } catch (e) {
      developer.log('🔊 Error resetting speech rate: $e', name: 'dyslexic_ai.tts');
    }
    
    // Process next item in queue with error handling
    try {
      _processQueueIfNeeded();
    } catch (e) {
      developer.log('🔊 Error processing next TTS item: $e', name: 'dyslexic_ai.tts');
    }
  }

  void _onSpeechError(String error) {
    _timeoutTimer?.cancel();
    
    if (_currentRequest != null && !_currentRequest!.completer.isCompleted) {
      try {
        _currentRequest!.completer.completeError(Exception('TTS Error: $error'));
      } catch (e) {
        developer.log('🔊 Error completing TTS request with error: $e', name: 'dyslexic_ai.tts');
      }
    }
    
    _currentRequest = null;
    _updateStatus(TTSStatus.error);
    
    // Clear queue on error
    while (_speechQueue.isNotEmpty) {
      final request = _speechQueue.removeFirst();
      if (!request.completer.isCompleted) {
        try {
          request.completer.completeError(Exception('TTS Error: $error'));
        } catch (e) {
          developer.log('🔊 Error completing queued TTS request: $e', name: 'dyslexic_ai.tts');
        }
      }
    }
    
    // Reset to idle after error
    Timer(const Duration(seconds: 1), () {
      _updateStatus(TTSStatus.idle);
    });
  }

  Future<void> stop() async {
    try {
      developer.log('🔊 Stopping TTS', name: 'dyslexic_ai.tts');
      
      _timeoutTimer?.cancel();
      
      // Complete current request
      if (_currentRequest != null && !_currentRequest!.completer.isCompleted) {
        _currentRequest!.completer.complete();
      }
      _currentRequest = null;
      
      // Clear queue
      while (_speechQueue.isNotEmpty) {
        final request = _speechQueue.removeFirst();
        if (!request.completer.isCompleted) {
          request.completer.complete();
        }
      }
      
      await _flutterTts.stop();
      _updateStatus(TTSStatus.stopped);
      
      // Reset to idle
      Timer(const Duration(milliseconds: 100), () {
        _updateStatus(TTSStatus.idle);
      });
      
    } catch (e) {
      developer.log('🔊 Stop failed: $e', name: 'dyslexic_ai.tts');
      _updateStatus(TTSStatus.error);
    }
  }

  Future<void> pause() async {
    try {
      await _flutterTts.pause();
      _updateStatus(TTSStatus.paused);
    } catch (e) {
      developer.log('🔊 Pause failed: $e', name: 'dyslexic_ai.tts');
      _updateStatus(TTSStatus.error);
    }
  }

  Future<void> setSpeechRate(double rate) async {
    try {
      _defaultSpeechRate = rate;
      await _flutterTts.setSpeechRate(rate);
    } catch (e) {
      developer.log('🔊 Set speech rate failed: $e', name: 'dyslexic_ai.tts');
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      await _flutterTts.setVolume(volume);
    } catch (e) {
      developer.log('🔊 Set volume failed: $e', name: 'dyslexic_ai.tts');
    }
  }

  Future<void> waitForCompletion() async {
    while (_status == TTSStatus.speaking || _speechQueue.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Clear the TTS queue and stop current speech (for Word Doctor new analysis)
  Future<void> clearQueue() async {
    developer.log('🔊 Clearing TTS queue', name: 'dyslexic_ai.tts');
    
    _timeoutTimer?.cancel();
    
    // Complete current request
    if (_currentRequest != null && !_currentRequest!.completer.isCompleted) {
      _currentRequest!.completer.complete();
    }
    _currentRequest = null;
    
    // Clear all queued requests
    while (_speechQueue.isNotEmpty) {
      final request = _speechQueue.removeFirst();
      if (!request.completer.isCompleted) {
        request.completer.complete();
      }
    }
    
    // Stop any current speech
    try {
      await _flutterTts.stop();
    } catch (e) {
      developer.log('🔊 Error stopping TTS during clearQueue: $e', name: 'dyslexic_ai.tts');
    }
    
    _updateStatus(TTSStatus.idle);
    _isProcessingQueue = false;
  }

  /// Ensure TTS is stopped before starting speech recognition
  Future<void> prepareForSpeechRecognition() async {
    developer.log('🔊 Preparing for speech recognition', name: 'dyslexic_ai.tts');
    
    await stop();
    
    // Wait for complete silence
    await Future.delayed(const Duration(milliseconds: 500));
    
    developer.log('🔊 Ready for speech recognition', name: 'dyslexic_ai.tts');
  }

  void _updateStatus(TTSStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController?.add(newStatus);
      developer.log('🔊 TTS status changed to: $newStatus', name: 'dyslexic_ai.tts');
    }
  }

  void dispose() {
    developer.log('🔊 Disposing TTS service', name: 'dyslexic_ai.tts');
    
    _timeoutTimer?.cancel();
    
    // Complete any pending requests
    if (_currentRequest != null && !_currentRequest!.completer.isCompleted) {
      _currentRequest!.completer.complete();
    }
    
    while (_speechQueue.isNotEmpty) {
      final request = _speechQueue.removeFirst();
      if (!request.completer.isCompleted) {
        request.completer.complete();
      }
    }
    
    _statusController?.close();
    _statusController = null;
    
    try {
      _flutterTts.stop();
    } catch (e) {
      developer.log('🔊 Error stopping TTS during dispose: $e', name: 'dyslexic_ai.tts');
    }
    
    _isInitialized = false;
    _updateStatus(TTSStatus.idle);
  }
} 