import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

class SpeechRecognitionService {
  final SpeechToText _speechToText = SpeechToText();
  StreamController<String>? _recognizedWordsController;
  StreamController<bool>? _listeningController;
  
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isDisposed = false;

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

    final hasPermission = await _requestMicrophonePermission();
    if (!hasPermission) return false;

    _isInitialized = await _speechToText.initialize(
      onError: _onError,
      onStatus: _onStatus,
    );

    return _isInitialized;
  }

  Future<bool> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }

  Future<void> startListening() async {
    if (!_isInitialized || _isListening || _isDisposed) return;

    await _speechToText.listen(
      onResult: _onResult,
      listenFor: const Duration(minutes: 10),
      pauseFor: const Duration(seconds: 30),
      partialResults: true,
      cancelOnError: false,
      listenMode: ListenMode.dictation,
    );

    _isListening = true;
    _ensureListeningController();
    _listeningController?.add(true);
  }

  Future<void> stopListening() async {
    if (!_isListening || _isDisposed) return;

    await _speechToText.stop();
    _isListening = false;
    _ensureListeningController();
    _listeningController?.add(false);
  }

  Future<void> restartListening() async {
    if (_isDisposed) return;
    
    if (_isListening) {
      await stopListening();
      await Future.delayed(const Duration(milliseconds: 500));
    }
    await startListening();
  }

  void _onResult(result) {
    if (_isDisposed) return;
    
    print('🎤 Speech Result: "${result.recognizedWords}"');
    print('🎤 Is Final: ${result.finalResult}');
    print('🎤 Confidence: ${result.confidence}');
    
    if (result.recognizedWords.isNotEmpty) {
      _ensureRecognizedWordsController();
      _recognizedWordsController?.add(result.recognizedWords);
    }
    
    if (result.finalResult && result.recognizedWords.isNotEmpty) {
      print('🎤 Got final result, stopping listening automatically');
      _isListening = false;
      _ensureListeningController();
      _listeningController?.add(false);
    }
  }

  void _onError(error) {
    if (_isDisposed) return;
    
    print('Speech recognition error: $error');
    
    // Check for common recoverable errors using toString() since errorType doesn't exist
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('no match') || errorString.contains('error_no_match')) {
      print('No speech detected, continuing to listen...');
      return;
    }
    
    _isListening = false;
    _ensureListeningController();
    _listeningController?.add(false);
  }

  void _onStatus(status) {
    if (_isDisposed) return;
    
    print('Speech recognition status: $status');
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
    
    _isDisposed = true;
    _isListening = false;
    
    _recognizedWordsController?.close();
    _listeningController?.close();
    
    _recognizedWordsController = null;
    _listeningController = null;
  }
} 