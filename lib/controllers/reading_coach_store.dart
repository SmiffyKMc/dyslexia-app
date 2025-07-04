import 'dart:async';
import 'dart:io';
import 'package:mobx/mobx.dart';
import 'package:image_picker/image_picker.dart';
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
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.camera);
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
      print('❌ Cannot start reading: canStartReading=false');
      return;
    }

    print('🎯 Starting reading session...');
    print('🎯 Text to read: "${currentText}"');

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

    print('🎯 Session created, starting speech recognition...');
    await _speechService.startListening();
    print('🎯 Speech recognition started');
  }

  @action
  Future<void> stopReading() async {
    if (!isListening) {
      print('❌ Cannot stop reading: not currently listening');
      return;
    }

    print('🛑 Stopping reading session...');
    await _speechService.stopListening();
    print('🛑 Speech recognition stopped');
    
    // Wait a bit for any final speech results to come through
    print('🛑 Waiting for final speech results...');
    await Future.delayed(const Duration(milliseconds: 1000));
    print('🛑 Final recognized speech: "$recognizedSpeech"');
    
    if (currentSession != null && recognizedSpeech.isNotEmpty) {
      print('🛑 Have session and speech data, starting analysis...');
      await _analyzeReading();
      _completeSession();
      print('🛑 Session completed');
    } else {
      print('🛑 No analysis needed: session=${currentSession != null}, speech="${recognizedSpeech}"');
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
    print('🗣️ Speech Recognized: "$speech"');
    recognizedSpeech = speech;
  }

  @action
  void _onListeningChanged(bool listening) {
    print('🎧 Listening state changed: $listening');
    isListening = listening;
    
    // If listening stopped during a reading session
    if (!listening && currentSession?.status == ReadingSessionStatus.reading) {
      print('⚠️ Listening stopped during session');
      
      if (recognizedSpeech.isEmpty) {
        print('⚠️ No speech recognized yet, showing help message');
        errorMessage = 'Having trouble hearing you. Try speaking louder or moving closer to the microphone.';
      } else {
        // We have speech data, automatically trigger analysis
        print('🎯 Speech recognition completed, auto-triggering analysis...');
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
      print('⚠️ Cannot auto-complete: currentSession=${currentSession != null}, recognizedSpeech.isEmpty=${recognizedSpeech.isEmpty}');
      return;
    }

    print('🎯 Auto-completing session with recognized speech: "$recognizedSpeech"');
    
    // Wait a bit for any final speech results to settle
    await Future.delayed(const Duration(milliseconds: 500));
    
    print('🎯 Starting automatic analysis...');
    await _analyzeReading();
    _completeSession();
    print('🎯 Session auto-completed successfully');
  }

  Future<void> _analyzeReading() async {
    if (currentSession == null || recognizedSpeech.isEmpty) {
      print('⚠️ Cannot analyze: currentSession=${currentSession != null}, recognizedSpeech.isEmpty=${recognizedSpeech.isEmpty}');
      return;
    }

    print('🧠 Starting reading analysis...');
    print('🧠 Current session text: "${currentSession!.text}"');
    print('🧠 Recognized speech: "$recognizedSpeech"');

    try {
      final results = await _analysisService.analyzeReading(
        expectedText: currentSession!.text,
        spokenText: recognizedSpeech,
      );

      print('🧠 Analysis complete, ${results.length} word results received');

      currentSession = currentSession!.copyWith(
        wordResults: results,
        accuracyScore: currentSession!.calculateAccuracy(),
      );

      print('🧠 Session updated with accuracy: ${currentSession!.calculateAccuracy()}');

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
      
      print('🧠 Generated ${liveFeedback.length} feedback messages');
      print('🧠 Suggested ${practiceWords.length} practice words: $practiceWords');
    } catch (e) {
      print('❌ Analysis failed: $e');
      errorMessage = 'Failed to analyze reading: $e';
    }
  }

  Future<void> _generateFeedback(List<WordResult> results) async {
    print('💬 Generating feedback for ${results.length} word results');
    liveFeedback.clear();
    
    for (final result in results.take(5)) {
      final message = await _analysisService.generateFeedbackMessage(result);
      print('💬 Feedback: "${result.expectedWord}" → "$message"');
      liveFeedback.add(message);
    }
    
    print('💬 Total feedback messages: ${liveFeedback.length}');
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
    
    _sessionLogging.completeSession(
      finalAccuracy: accuracy,
      additionalData: {
        'final_status': 'completed',
        'total_words': currentSession!.wordResults.length,
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