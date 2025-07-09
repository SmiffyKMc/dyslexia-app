import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as developer;

class SpeechRecognitionService {
  final SpeechToText _speechToText = SpeechToText();
  StreamController<String>? _recognizedWordsController;
  StreamController<bool>? _listeningController;
  
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isDisposed = false;
  bool _permissionGranted = false;

  Stream<String> get recognizedWordsStream {
    _ensureRecognizedWordsController();
    return _recognizedWordsController!.stream;
  }
  
  Stream<bool> get listeningStream {
    _ensureListeningController();
    return _listeningController!.stream;
  }
  
  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;

  void _ensureRecognizedWordsController() {
    if (_isDisposed) return;
    _recognizedWordsController ??= StreamController<String>.broadcast();
  }

  void _ensureListeningController() {
    if (_isDisposed) return;
    _listeningController ??= StreamController<bool>.broadcast();
  }

  Future<bool> initialize() async {
    if (_isInitialized || _isDisposed) return _isInitialized;

    try {
      developer.log('🎤 Initializing speech recognition...', name: 'dyslexic_ai.speech');
      
      // Check and request permission first
      final hasPermission = await _requestMicrophonePermission();
      if (!hasPermission) {
        developer.log('🎤 Microphone permission denied', name: 'dyslexic_ai.speech');
        return false;
      }

      _permissionGranted = true;
      
      // Initialize speech recognition with simplified error handling
      _isInitialized = await _speechToText.initialize(
        onError: _onError,
        onStatus: _onStatus,
        debugLogging: false, // Disable debug logging for performance
      );

      developer.log('🎤 Speech recognition initialized: $_isInitialized', name: 'dyslexic_ai.speech');
      return _isInitialized;
    } catch (e) {
      developer.log('🎤 Speech recognition initialization failed: $e', name: 'dyslexic_ai.speech');
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
      
      await _speechToText.listen(
        onResult: _onResult,
        listenFor: const Duration(minutes: 5), // Reduced from 10 minutes
        pauseFor: const Duration(seconds: 3), // Reduced from 30 seconds
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
      );

      _isListening = true;
      _ensureListeningController();
      _listeningController?.add(true);
      
      developer.log('🎤 Speech recognition started', name: 'dyslexic_ai.speech');
    } catch (e) {
      developer.log('🎤 Failed to start listening: $e', name: 'dyslexic_ai.speech');
      _isListening = false;
      _ensureListeningController();
      _listeningController?.add(false);
    }
  }

  Future<void> stopListening() async {
    if (!_isListening || _isDisposed) return;

    try {
      developer.log('🎤 Stopping speech recognition...', name: 'dyslexic_ai.speech');
      
      await _speechToText.stop();
      _isListening = false;
      _ensureListeningController();
      _listeningController?.add(false);
      
      developer.log('🎤 Speech recognition stopped', name: 'dyslexic_ai.speech');
    } catch (e) {
      developer.log('🎤 Failed to stop listening: $e', name: 'dyslexic_ai.speech');
    }
  }

  Future<void> restartListening() async {
    if (_isDisposed) return;
    
    developer.log('🎤 Restarting speech recognition...', name: 'dyslexic_ai.speech');
    
    if (_isListening) {
      await stopListening();
      await Future.delayed(const Duration(milliseconds: 300)); // Reduced delay
    }
    await startListening();
  }

  void _onResult(result) {
    if (_isDisposed) return;
    
    developer.log('🎤 Speech Result: "${result.recognizedWords}" (final: ${result.finalResult})', name: 'dyslexic_ai.speech');
    
    if (result.recognizedWords.isNotEmpty) {
      _ensureRecognizedWordsController();
      _recognizedWordsController?.add(result.recognizedWords);
    }
    
    // Auto-stop on final result to prevent hanging
    if (result.finalResult && result.recognizedWords.isNotEmpty) {
      developer.log('🎤 Final result received, auto-stopping', name: 'dyslexic_ai.speech');
      _isListening = false;
      _ensureListeningController();
      _listeningController?.add(false);
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
    _isListening = false;
    _ensureListeningController();
    _listeningController?.add(false);
  }

  void _onStatus(status) {
    if (_isDisposed) return;
    
    developer.log('🎤 Speech status: $status', name: 'dyslexic_ai.speech');
    _ensureListeningController();
    
    if (status == 'notListening') {
      _isListening = false;
      _listeningController?.add(false);
    } else if (status == 'listening') {
      _isListening = true;
      _listeningController?.add(true);
    }
  }

  void dispose() {
    if (_isDisposed) return;
    
    developer.log('🎤 Disposing speech recognition service', name: 'dyslexic_ai.speech');
    
    _isDisposed = true;
    _isListening = false;
    
    _recognizedWordsController?.close();
    _listeningController?.close();
    
    _recognizedWordsController = null;
    _listeningController = null;
  }
} 