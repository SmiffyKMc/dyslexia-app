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
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      developer.log('🔊 Speech timeout - forcing completion', name: 'dyslexic_ai.tts');
      _onSpeechComplete();
    });
  }

  void _onSpeechComplete() {
    _timeoutTimer?.cancel();
    
    if (_currentRequest != null && !_currentRequest!.completer.isCompleted) {
      _currentRequest!.completer.complete();
    }
    
    _currentRequest = null;
    _updateStatus(TTSStatus.idle);
    
    // Reset speech rate to default after word pronunciation
    if (_defaultSpeechRate != 0.5) {
      _flutterTts.setSpeechRate(_defaultSpeechRate);
    }
    
    // Process next item in queue
    _processQueueIfNeeded();
  }

  void _onSpeechError(String error) {
    _timeoutTimer?.cancel();
    
    if (_currentRequest != null && !_currentRequest!.completer.isCompleted) {
      _currentRequest!.completer.completeError(Exception('TTS Error: $error'));
    }
    
    _currentRequest = null;
    _updateStatus(TTSStatus.error);
    
    // Clear queue on error
    while (_speechQueue.isNotEmpty) {
      final request = _speechQueue.removeFirst();
      if (!request.completer.isCompleted) {
        request.completer.completeError(Exception('TTS Error: $error'));
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