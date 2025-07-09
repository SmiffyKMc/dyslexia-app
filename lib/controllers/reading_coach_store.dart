import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:mobx/mobx.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/reading_session.dart';
import '../models/session_log.dart';
import '../services/speech_recognition_service.dart';
import '../services/text_to_speech_service.dart';
import '../services/ocr_service.dart';
import '../services/preset_stories_service.dart';
import '../services/reading_analysis_service.dart';
import '../services/session_logging_service.dart';
import '../utils/service_locator.dart';

part 'reading_coach_store.g.dart';

class ReadingCoachStore = _ReadingCoachStore with _$ReadingCoachStore;

abstract class _ReadingCoachStore with Store {
  final SpeechRecognitionService _speechService;
  final TextToSpeechService _ttsService;
  final OcrService _ocrService;
  final ReadingAnalysisService _analysisService;
  final ImagePicker _imagePicker = ImagePicker();
  late final SessionLoggingService _sessionLogging;

  StreamSubscription<String>? _speechSubscription;
  StreamSubscription<bool>? _listeningSubscription;

  _ReadingCoachStore({
    required SpeechRecognitionService speechService,
    required TextToSpeechService ttsService,
    required OcrService ocrService,
    required ReadingAnalysisService analysisService,
  })  : _speechService = speechService,
        _ttsService = ttsService,
        _ocrService = ocrService,
        _analysisService = analysisService {
    _sessionLogging = getIt<SessionLoggingService>();
  }

  @observable
  ReadingSession? currentSession;

  @observable
  String currentText = '';

  @observable
  String recognizedSpeech = '';

  @observable
  bool isListening = false;

  bool _hasFinalResult = false;

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  List<String> liveFeedback = [];

  @observable
  List<String> practiceWords = [];

  @observable
  List<PresetStory> presetStories = [];

  @computed
  double get currentAccuracy {
    if (currentSession?.wordResults.isEmpty ?? true) return 0.0;
    return currentSession!.calculateAccuracy();
  }

  @computed
  String get formattedAccuracy {
    return '${(currentAccuracy * 100).round()}%';
  }

  @computed
  bool get canStartReading => currentText.isNotEmpty && !isListening;

  @computed
  bool get hasSession => currentSession != null;

  @action
  Future<void> initialize() async {
    isLoading = true;
    errorMessage = null;

    try {
      await _speechService.initialize();
      await _ttsService.initialize();
      
      _speechSubscription = _speechService.recognizedWordsStream.listen(_onSpeechRecognized);
      _listeningSubscription = _speechService.listeningStream.listen(_onListeningChanged);
      
      presetStories = PresetStoriesService.getPresetStories();
    } catch (e) {
      errorMessage = 'Failed to initialize: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  void setCurrentText(String text) {
    currentText = text.trim();
    errorMessage = null;
  }

  @action
  void selectPresetStory(PresetStory story) {
    setCurrentText(story.content);
  }

  @action
  Future<void> takePhoto() async {
    isLoading = true;
    errorMessage = null;

    try {
      developer.log('📷 Checking camera permissions...', name: 'dyslexic_ai.reading_coach');
      
      // Check camera permission first
      final cameraPermission = await Permission.camera.status;
      if (!cameraPermission.isGranted) {
        developer.log('📷 Camera permission not granted, requesting...', name: 'dyslexic_ai.reading_coach');
        final permissionResult = await Permission.camera.request();
        if (!permissionResult.isGranted) {
          errorMessage = 'Camera permission is required to take photos. Please enable camera access in settings.';
          return;
        }
      }
      
      developer.log('📷 Camera permission granted, preparing for photo capture...', name: 'dyslexic_ai.reading_coach');
      
      // Add memory preparation before camera launch
      await _prepareForCameraLaunch();
      
      developer.log('📷 Launching camera...', name: 'dyslexic_ai.reading_coach');
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,  // Slightly reduced quality for memory efficiency
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1024,    // Limit resolution to reduce memory usage
        maxHeight: 1024,
      );
      
      // Handle return from camera
      await _handleCameraReturn();
      
      if (image != null) {
        developer.log('📷 Photo taken successfully: ${image.path}', name: 'dyslexic_ai.reading_coach');
        
        // Process with additional memory management
        await _processPhotoWithMemoryManagement(image);
        
        developer.log('📷 OCR completed successfully', name: 'dyslexic_ai.reading_coach');
      } else {
        developer.log('📷 No image selected', name: 'dyslexic_ai.reading_coach');
        errorMessage = 'No photo was taken';
      }
    } catch (e) {
      developer.log('❌ Camera error: $e', name: 'dyslexic_ai.reading_coach', error: e);
      await _handleCameraReturn(); // Ensure cleanup on error
      
      if (e.toString().contains('permission')) {
        errorMessage = 'Camera permission denied. Please enable camera access in settings.';
      } else if (e.toString().contains('unavailable')) {
        errorMessage = 'Camera is not available on this device.';
      } else if (e.toString().contains('memory') || e.toString().contains('OutOfMemory')) {
        errorMessage = 'Not enough memory available. Please close other apps and try again.';
      } else {
        errorMessage = 'Failed to take photo: $e';
      }
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> pickImageFromGallery() async {
    isLoading = true;
    errorMessage = null;

    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final extractedText = await _ocrService.processImageForReading(File(image.path));
        setCurrentText(extractedText);
      }
    } catch (e) {
      errorMessage = 'Failed to process image: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> startReading() async {
    if (!canStartReading) {
      developer.log('Cannot start reading: canStartReading=false', name: 'dyslexic_ai.reading_coach');
      return;
    }

    developer.log('Starting reading session', name: 'dyslexic_ai.reading_coach');

    currentSession = ReadingSession(
      text: currentText,
      status: ReadingSessionStatus.reading,
    );

    liveFeedback.clear();
    practiceWords.clear();
    recognizedSpeech = '';
    _hasFinalResult = false;

    // Start session logging
    await _sessionLogging.startSession(
      sessionType: SessionType.readingCoach,
      featureName: 'Reading Coach',
      initialData: {
        'text_length': currentText.length,
        'word_count': currentText.split(RegExp(r'\s+')).length,
        'text_preview': currentText.length > 100 
            ? '${currentText.substring(0, 100)}...' 
            : currentText,
        'session_id': currentSession!.id,
      },
    );

    await _speechService.startListening();
    developer.log('Reading session started successfully', name: 'dyslexic_ai.reading_coach');
  }

  @action
  Future<void> stopReading() async {
    if (!isListening) {
      developer.log('Cannot stop reading: not currently listening', name: 'dyslexic_ai.reading_coach');
      return;
    }

    developer.log('Stopping reading session', name: 'dyslexic_ai.reading_coach');
    await _speechService.stopListening();
    
    // Wait a bit for any final speech results to come through
    await Future.delayed(const Duration(milliseconds: 1000));
    
    if (currentSession != null && recognizedSpeech.isNotEmpty) {
      await _analyzeReading();
      _completeSession();
      developer.log('Reading session completed', name: 'dyslexic_ai.reading_coach');
    }
  }

  @action
  Future<void> pauseReading() async {
    if (!isListening) return;

    await _speechService.stopListening();
    
    if (currentSession != null) {
      currentSession = currentSession!.copyWith(status: ReadingSessionStatus.paused);
    }
  }

  @action
  Future<void> resumeReading() async {
    if (currentSession?.status != ReadingSessionStatus.paused) return;

    currentSession = currentSession!.copyWith(status: ReadingSessionStatus.reading);
    await _speechService.startListening();
  }

  @action
  Future<void> restartSession() async {
    // Cancel current session logging before restarting
    if (_sessionLogging.hasActiveSession) {
      _sessionLogging.cancelSession(reason: 'session_restarted');
    }
    
    await stopReading();
    await startReading();
  }

  @action
  Future<void> speakWord(String word) async {
    await _ttsService.speakWord(word);
  }

  @action
  Future<void> speakText(String text) async {
    await _ttsService.speak(text);
  }

  @action
  void clearSession() {
    // Cancel active session logging if there's an incomplete session
    if (_sessionLogging.hasActiveSession) {
      _sessionLogging.cancelSession(reason: 'user_cleared_session');
    }
    
    currentSession = null;
    currentText = '';
    recognizedSpeech = '';
    liveFeedback.clear();
    practiceWords.clear();
    errorMessage = null;
  }

  @action
  void clearError() {
    errorMessage = null;
  }

  @action
  void _onSpeechRecognized(String speech) {
    recognizedSpeech = speech;
  }

  @action
  void _onListeningChanged(bool listening) {
    isListening = listening;
    
    // If listening stopped during a reading session
    if (!listening && currentSession?.status == ReadingSessionStatus.reading) {
      if (recognizedSpeech.isEmpty) {
        errorMessage = 'Having trouble hearing you. Try speaking louder or moving closer to the microphone.';
      } else {
        // We have speech data, automatically trigger analysis
        _autoCompleteSession();
      }
    }
  }

  @action
  Future<void> restartListening() async {
    if (currentSession?.status == ReadingSessionStatus.reading) {
      errorMessage = null;
      await _speechService.restartListening();
    }
  }

  @action
  Future<void> _autoCompleteSession() async {
    if (currentSession == null || recognizedSpeech.isEmpty) {
      developer.log('Cannot auto-complete session: missing data', name: 'dyslexic_ai.reading_coach');
      return;
    }

    // Wait a bit for any final speech results to settle
    await Future.delayed(const Duration(milliseconds: 500));
    
    await _analyzeReading();
    _completeSession();
    developer.log('Session auto-completed', name: 'dyslexic_ai.reading_coach');
  }

  Future<void> _analyzeReading() async {
    if (currentSession == null || recognizedSpeech.isEmpty) {
      developer.log('Cannot analyze reading: missing session or speech data', name: 'dyslexic_ai.reading_coach');
      return;
    }

    developer.log('Starting reading analysis', name: 'dyslexic_ai.reading_coach');

    try {
      final results = await _analysisService.analyzeReading(
        expectedText: currentSession!.text,
        spokenText: recognizedSpeech,
      );

      currentSession = currentSession!.copyWith(
        wordResults: results,
        accuracyScore: currentSession!.calculateAccuracy(),
      );

      // Log reading metrics
      final accuracy = currentSession!.calculateAccuracy();
      final wordsPerMinute = _calculateWordsPerMinute();
      final mispronuncedPhonemes = _extractPhonemeErrors(results);
      
      _sessionLogging.logReadingMetrics(
        wordsRead: results.length,
        wordsPerMinute: wordsPerMinute,
        accuracy: accuracy,
        difficultWords: currentSession!.mispronuncedWords,
      );
      
      // Log phoneme errors
      for (final phoneme in mispronuncedPhonemes) {
        _sessionLogging.logPhonemeError(phoneme);
      }
      
      // Log confidence based on accuracy
      final confidenceLevel = accuracy > 0.8 ? 'high' : 
                            accuracy > 0.6 ? 'medium' : 
                            accuracy > 0.4 ? 'building' : 'low';
      _sessionLogging.logConfidenceIndicator(confidenceLevel, reason: 'reading_accuracy');

      await _generateFeedback(results);
      practiceWords = await _analysisService.suggestPracticeWords(results);
      
      developer.log('Reading analysis completed successfully', name: 'dyslexic_ai.reading_coach');
    } catch (e) {
      developer.log('Reading analysis failed: $e', name: 'dyslexic_ai.reading_coach', error: e);
      errorMessage = 'Failed to analyze reading: $e';
    }
  }

  Future<void> _generateFeedback(List<WordResult> results) async {
    liveFeedback.clear();
    
    for (final result in results.take(5)) {
      final message = await _analysisService.generateFeedbackMessage(result);
      liveFeedback.add(message);
    }
  }

  void _completeSession() {
    if (currentSession == null) return;

    currentSession = currentSession!.copyWith(
      status: ReadingSessionStatus.completed,
      endTime: DateTime.now(),
    );

    // Complete session logging
    final accuracy = currentSession!.calculateAccuracy();
    final duration = currentSession!.duration ?? const Duration(minutes: 1);
    final wordsRead = currentSession!.wordResults.length;
    
    _sessionLogging.completeSession(
      finalAccuracy: accuracy,
      additionalData: {
        'final_status': 'completed',
        'words_read': wordsRead,  // Ensure words_read is preserved
        'total_words': wordsRead,
        'correct_words': currentSession!.correctWordsCount,
        'mispronounced_words_count': currentSession!.mispronuncedWords.length,
        'practice_words_suggested': practiceWords.length,
        'feedback_messages_count': liveFeedback.length,
      },
    );
  }

  double _calculateWordsPerMinute() {
    if (currentSession == null) return 0.0;
    
    final duration = DateTime.now().difference(currentSession!.startTime);
    final minutes = duration.inMilliseconds / 60000.0;
    
    if (minutes <= 0) return 0.0;
    
    final wordsRead = currentSession!.wordResults.length;
    return wordsRead / minutes;
  }

  List<String> _extractPhonemeErrors(List<WordResult> results) {
    final phonemeErrors = <String>[];
    
    for (final result in results) {
      if (!result.isCorrect && result.expectedWord.isNotEmpty) {
        // Simple phoneme extraction - in a real app this would be more sophisticated
        final word = result.expectedWord.toLowerCase();
        
        // Common phoneme patterns that cause difficulty
        if (word.contains('th')) phonemeErrors.add('th');
        if (word.contains('ch')) phonemeErrors.add('ch');
        if (word.contains('sh')) phonemeErrors.add('sh');
        if (word.contains('ph')) phonemeErrors.add('ph');
        if (word.contains('ough')) phonemeErrors.add('ough');
        if (word.contains('augh')) phonemeErrors.add('augh');
        if (word.contains('tion')) phonemeErrors.add('tion');
        if (word.contains('sion')) phonemeErrors.add('sion');
        
        // Vowel sounds
        if (word.contains('ea')) phonemeErrors.add('ea');
        if (word.contains('oo')) phonemeErrors.add('oo');
        if (word.contains('ou')) phonemeErrors.add('ou');
        if (word.contains('ow')) phonemeErrors.add('ow');
        
        // Common single letter confusions
        if (word.contains('b')) phonemeErrors.add('b');
        if (word.contains('d')) phonemeErrors.add('d');
        if (word.contains('p')) phonemeErrors.add('p');
        if (word.contains('q')) phonemeErrors.add('q');
      }
    }
    
    // Remove duplicates and return
    return phonemeErrors.toSet().toList();
  }

  /// Prepare system for camera launch by managing memory
  Future<void> _prepareForCameraLaunch() async {
    try {
      developer.log('Preparing for camera launch', name: 'dyslexic_ai.reading_coach');
      
      // Give the system a moment to prepare
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Explicitly trigger garbage collection
      // Note: In Dart, we can't force GC, but we can give the system time
      await Future.delayed(const Duration(milliseconds: 100));
      
      developer.log('Camera preparation complete', name: 'dyslexic_ai.reading_coach');
    } catch (e) {
      developer.log('Camera preparation failed: $e', name: 'dyslexic_ai.reading_coach', error: e);
    }
  }
  
  /// Handle return from camera app
  Future<void> _handleCameraReturn() async {
    try {
      developer.log('Handling camera return', name: 'dyslexic_ai.reading_coach');
      
      // Give the system time to stabilize after camera app
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Ensure services are still initialized
      if (!_speechService.isInitialized) {
        developer.log('Reinitializing speech service after camera', name: 'dyslexic_ai.reading_coach');
        await _speechService.initialize();
      }
      
      developer.log('Camera return handled successfully', name: 'dyslexic_ai.reading_coach');
    } catch (e) {
      developer.log('Camera return handling failed: $e', name: 'dyslexic_ai.reading_coach', error: e);
    }
  }
  
  /// Process photo with memory management
  Future<void> _processPhotoWithMemoryManagement(XFile image) async {
    try {
      developer.log('Processing photo with memory management', name: 'dyslexic_ai.reading_coach');
      
      // Add a small delay to allow memory to stabilize
      await Future.delayed(const Duration(milliseconds: 150));
      
      // Process the image
      final extractedText = await _ocrService.processImageForReading(File(image.path));
      setCurrentText(extractedText);
      
      // Clean up the temporary image file if possible
      try {
        await File(image.path).delete();
        developer.log('Temporary image file cleaned up', name: 'dyslexic_ai.reading_coach');
      } catch (e) {
        developer.log('Could not clean up temporary image: $e', name: 'dyslexic_ai.reading_coach');
      }
      
    } catch (e) {
      developer.log('Photo processing failed: $e', name: 'dyslexic_ai.reading_coach', error: e);
      rethrow;
    }
  }

  void dispose() {
    // Cancel any active session logging
    if (_sessionLogging.hasActiveSession) {
      _sessionLogging.cancelSession(reason: 'app_disposed');
    }
    
    _speechSubscription?.cancel();
    _listeningSubscription?.cancel();
    _speechService.dispose();
    _ttsService.dispose();
  }
} 