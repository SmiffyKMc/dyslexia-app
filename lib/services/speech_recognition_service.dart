import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as developer;

enum RecordingStatus {
  idle,
  recording,
  detectingSilence,
  completed,
  error
}

class SpeechRecognitionService {
  final SpeechToText _speechToText = SpeechToText();
  StreamController<String>? _recognizedWordsController;
  StreamController<bool>? _listeningController;
  StreamController<int>? _silenceController;
  StreamController<RecordingStatus>? _statusController;
  
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isDisposed = false;
  bool _permissionGranted = false;
  
  // Silence detection
  Timer? _silenceTimer;
  int _silenceSeconds = 0;
  final int _maxSilenceSeconds = 5; // 5 seconds of silence triggers auto-stop
  bool _hasDetectedSpeech = false;

  Stream<String> get recognizedWordsStream {
    _ensureRecognizedWordsController();
    return _recognizedWordsController!.stream;
  }
  
  Stream<bool> get listeningStream {
    _ensureListeningController();
    return _listeningController!.stream;
  }
  
  Stream<int> get silenceSecondsStream {
    _ensureSilenceController();
    return _silenceController!.stream;
  }
  
  Stream<RecordingStatus> get recordingStatusStream {
    _ensureStatusController();
    return _statusController!.stream;
  }
  
  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
  bool get hasDetectedSpeech => _hasDetectedSpeech;

  void _ensureRecognizedWordsController() {
    if (_isDisposed) return;
    _recognizedWordsController ??= StreamController<String>.broadcast();
  }

  void _ensureListeningController() {
    if (_isDisposed) return;
    _listeningController ??= StreamController<bool>.broadcast();
  }

  void _ensureSilenceController() {
    if (_isDisposed) return;
    _silenceController ??= StreamController<int>.broadcast();
  }

  void _ensureStatusController() {
    if (_isDisposed) return;
    _statusController ??= StreamController<RecordingStatus>.broadcast();
  }

  Future<bool> initialize() async {
    if (_isInitialized || _isDisposed) return _isInitialized;

    try {
      developer.log('🎤 Initializing speech recognition...', name: 'dyslexic_ai.speech');
      
      // Check and request permission first
      final hasPermission = await _requestMicrophonePermission();
      if (!hasPermission) {
        developer.log('🎤 Microphone permission denied', name: 'dyslexic_ai.speech');
        _ensureStatusController();
        _statusController?.add(RecordingStatus.error);
        return false;
      }

      _permissionGranted = true;
      
      // Initialize speech recognition with simplified error handling
      _isInitialized = await _speechToText.initialize(
        onError: _onError,
        onStatus: _onStatus,
        debugLogging: false, // Disable debug logging for performance
      );

      if (_isInitialized) {
        _ensureStatusController();
        _statusController?.add(RecordingStatus.idle);
      }

      developer.log('🎤 Speech recognition initialized: $_isInitialized', name: 'dyslexic_ai.speech');
      return _isInitialized;
    } catch (e) {
      developer.log('🎤 Speech recognition initialization failed: $e', name: 'dyslexic_ai.speech');
      _ensureStatusController();
      _statusController?.add(RecordingStatus.error);
      return false;
    }
  }

  Future<bool> _requestMicrophonePermission() async {
    if (_permissionGranted) return true;
    
    try {
      final status = await Permission.microphone.request();
      _permissionGranted = status == PermissionStatus.granted;
      return _permissionGranted;
    } catch (e) {
      developer.log('🎤 Permission request failed: $e', name: 'dyslexic_ai.speech');
      return false;
    }
  }

  Future<void> startListening() async {
    if (!_isInitialized || _isListening || _isDisposed) return;

    try {
      developer.log('🎤 Starting speech recognition...', name: 'dyslexic_ai.speech');
      
      // Reset state
      _hasDetectedSpeech = false;
      _silenceSeconds = 0;
      _stopSilenceTimer();
      
      await _speechToText.listen(
        onResult: _onResult,
        listenFor: const Duration(minutes: 10), // Longer duration, we'll handle auto-stop
        pauseFor: const Duration(seconds: 8), // Longer pause tolerance
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        ),
      );

      _isListening = true;
      _ensureListeningController();
      _listeningController?.add(true);
      
      _ensureStatusController();
      _statusController?.add(RecordingStatus.recording);
      
      // Start silence detection after a brief delay
      await Future.delayed(const Duration(milliseconds: 500));
      _startSilenceDetection();
      
      developer.log('🎤 Speech recognition started', name: 'dyslexic_ai.speech');
    } catch (e) {
      developer.log('🎤 Failed to start listening: $e', name: 'dyslexic_ai.speech');
      _isListening = false;
      _ensureListeningController();
      _listeningController?.add(false);
      _ensureStatusController();
      _statusController?.add(RecordingStatus.error);
    }
  }

  Future<void> stopListening() async {
    if (!_isListening || _isDisposed) return;

    try {
      developer.log('🎤 Stopping speech recognition...', name: 'dyslexic_ai.speech');
      
      _stopSilenceTimer();
      
      await _speechToText.stop();
      _isListening = false;
      _ensureListeningController();
      _listeningController?.add(false);
      
      _ensureStatusController();
      _statusController?.add(RecordingStatus.completed);
      
      developer.log('🎤 Speech recognition stopped', name: 'dyslexic_ai.speech');
    } catch (e) {
      developer.log('🎤 Failed to stop listening: $e', name: 'dyslexic_ai.speech');
      _ensureStatusController();
      _statusController?.add(RecordingStatus.error);
    }
  }

  Future<void> restartListening() async {
    if (_isDisposed) return;
    
    developer.log('🎤 Restarting speech recognition...', name: 'dyslexic_ai.speech');
    
    if (_isListening) {
      await stopListening();
      await Future.delayed(const Duration(milliseconds: 300));
    }
    await startListening();
  }

  void _startSilenceDetection() {
    _silenceSeconds = 0;
    _silenceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _silenceSeconds++;
      _ensureSilenceController();
      _silenceController?.add(_silenceSeconds);
      
      // Update status based on silence duration
      if (_silenceSeconds >= 3 && _hasDetectedSpeech) {
        _ensureStatusController();
        _statusController?.add(RecordingStatus.detectingSilence);
      }
      
      // Auto-stop after max silence duration (only if we've detected speech)
      if (_silenceSeconds >= _maxSilenceSeconds && _hasDetectedSpeech) {
        _handleSilenceTimeout();
      }
    });
  }

  void _stopSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
  }

  void _resetSilenceTimer() {
    _silenceSeconds = 0;
    _ensureSilenceController();
    _silenceController?.add(_silenceSeconds);
    
    // Update status back to recording when speech detected
    if (_hasDetectedSpeech) {
      _ensureStatusController();
      _statusController?.add(RecordingStatus.recording);
    }
  }

  void _handleSilenceTimeout() {
    developer.log('🎤 Silence timeout - auto-stopping recording', name: 'dyslexic_ai.speech');
    _stopSilenceTimer();
    
    // Stop listening due to silence
    if (_isListening) {
      stopListening();
    }
  }

  void _onResult(result) {
    if (_isDisposed) return;
    
    developer.log('🎤 Speech Result: "${result.recognizedWords}" (final: ${result.finalResult})', name: 'dyslexic_ai.speech');
    
    if (result.recognizedWords.isNotEmpty) {
      _hasDetectedSpeech = true;
      _resetSilenceTimer();
      
      _ensureRecognizedWordsController();
      _recognizedWordsController?.add(result.recognizedWords);
    }
    
    // Handle final result
    if (result.finalResult && result.recognizedWords.isNotEmpty) {
      developer.log('🎤 Final result received', name: 'dyslexic_ai.speech');
      // Don't auto-stop here - let silence detection handle it
    }
  }

  void _onError(error) {
    if (_isDisposed) return;
    
    developer.log('🎤 Speech error: $error', name: 'dyslexic_ai.speech');
    
    // Handle common recoverable errors
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('no match') || errorString.contains('error_no_match')) {
      developer.log('🎤 No speech detected, continuing...', name: 'dyslexic_ai.speech');
      return;
    }
    
    // For other errors, stop listening
    _stopSilenceTimer();
    _isListening = false;
    _ensureListeningController();
    _listeningController?.add(false);
    _ensureStatusController();
    _statusController?.add(RecordingStatus.error);
  }

  void _onStatus(status) {
    if (_isDisposed) return;
    
    developer.log('🎤 Speech status: $status', name: 'dyslexic_ai.speech');
    _ensureListeningController();
    
    if (status == 'notListening') {
      _stopSilenceTimer();
      _isListening = false;
      _listeningController?.add(false);
      
      // Only mark as completed if we have detected speech
      if (_hasDetectedSpeech) {
        _ensureStatusController();
        _statusController?.add(RecordingStatus.completed);
      }
    } else if (status == 'listening') {
      _isListening = true;
      _listeningController?.add(true);
      
      _ensureStatusController();
      _statusController?.add(RecordingStatus.recording);
    }
  }

  void dispose() {
    if (_isDisposed) return;
    
    developer.log('🎤 Disposing speech recognition service', name: 'dyslexic_ai.speech');
    
    _isDisposed = true;
    _isListening = false;
    _stopSilenceTimer();
    
    _recognizedWordsController?.close();
    _listeningController?.close();
    _silenceController?.close();
    _statusController?.close();
    
    _recognizedWordsController = null;
    _listeningController = null;
    _silenceController = null;
    _statusController = null;
  }
} 