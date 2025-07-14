import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;
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

class ReadingCoachStore extends _ReadingCoachStore with _$ReadingCoachStore {
  ReadingCoachStore();
}

abstract class _ReadingCoachStore with Store {
  late final SpeechRecognitionService _speechService;
  late final TextToSpeechService _ttsService;
  late final OcrService _ocrService;
  late final ReadingAnalysisService _analysisService;
  late final SessionLoggingService _sessionLogging;
  late final ImagePicker _imagePicker;
  
  StreamSubscription<String>? _speechSubscription;
  StreamSubscription<bool>? _listeningSubscription;
  StreamSubscription<RecordingStatus>? _recordingStatusSubscription;
  StreamSubscription<int>? _silenceSubscription;

  _ReadingCoachStore() {
    _speechService = getIt<SpeechRecognitionService>();
    _ttsService = getIt<TextToSpeechService>();
    _ocrService = getIt<OcrService>();
    _analysisService = getIt<ReadingAnalysisService>();
    _sessionLogging = getIt<SessionLoggingService>();
    _imagePicker = ImagePicker();
  }

  @observable
  String currentText = '';

  @observable
  ReadingSession? currentSession;

  @observable
  String recognizedSpeech = '';

  @observable
  bool isListening = false;

  @observable
  RecordingStatus recordingStatus = RecordingStatus.idle;

  @observable
  int silenceSeconds = 0;

  @observable
  bool isAnalyzing = false;



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
  bool get canStartReading => currentText.isNotEmpty && !isListening && !isAnalyzing;

  @computed
  bool get hasSession => currentSession != null;

  @computed
  String get recordingStatusText {
    switch (recordingStatus) {
      case RecordingStatus.idle:
        return 'Ready to record';
      case RecordingStatus.recording:
        return 'Recording...';
      case RecordingStatus.detectingSilence:
        return 'Finishing up... (${silenceSeconds}s)';
      case RecordingStatus.completed:
        return 'Recording complete';
      case RecordingStatus.error:
        return 'Recording error';
    }
  }

  @action
  Future<void> initialize() async {
    isLoading = true;
    errorMessage = null;

    try {
      await _speechService.initialize();
      await _ttsService.initialize();
      
      // Set up all listeners for the new recording flow
      _speechSubscription = _speechService.recognizedWordsStream.listen(_onSpeechRecognized);
      _listeningSubscription = _speechService.listeningStream.listen(_onListeningChanged);
      _recordingStatusSubscription = _speechService.recordingStatusStream.listen(_onRecordingStatusChanged);
      _silenceSubscription = _speechService.silenceSecondsStream.listen(_onSilenceSecondsChanged);
      
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
    isAnalyzing = false;

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

    // Ensure TTS is stopped before starting speech recognition
    await _ttsService.prepareForSpeechRecognition();

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
    
    // Stop TTS first to prevent conflicts
    await _ttsService.stop();
    
    await _speechService.stopListening();
    
    // Note: Analysis will be triggered by recording status change
  }

  @action
  Future<void> pauseReading() async {
    if (!isListening) return;

    // Stop TTS and speech recognition
    await _ttsService.stop();
    await _speechService.stopListening();
    
    if (currentSession != null) {
      currentSession = currentSession!.copyWith(status: ReadingSessionStatus.paused);
    }
  }

  @action
  Future<void> resumeReading() async {
    if (currentSession?.status != ReadingSessionStatus.paused) return;

    currentSession = currentSession!.copyWith(status: ReadingSessionStatus.reading);
    
    // Ensure TTS is ready before starting speech recognition
    await _ttsService.prepareForSpeechRecognition();
    
    await _speechService.startListening();
  }

  @action
  Future<void> restartSession() async {
    // Cancel current session logging before restarting
    if (_sessionLogging.hasActiveSession) {
      _sessionLogging.cancelSession(reason: 'session_restarted');
    }
    
    // Stop both services
    await _ttsService.stop();
    await _speechService.stopListening();
    
    await Future.delayed(const Duration(milliseconds: 300)); // Brief pause
    
    await startReading();
  }

  @action
  Future<void> speakWord(String word) async {
    try {
      // Only speak if not currently recording
      if (!isListening) {
        await _ttsService.speakWord(word);
      } else {
        developer.log('Cannot speak word while recording', name: 'dyslexic_ai.reading_coach');
      }
    } catch (e) {
      developer.log('TTS error speaking word: $e', name: 'dyslexic_ai.reading_coach');
      errorMessage = 'Unable to speak word. Please try again.';
    }
  }

  @action
  Future<void> speakText(String text) async {
    try {
      // Only speak if not currently recording
      if (!isListening) {
        await _ttsService.speak(text);
      } else {
        developer.log('Cannot speak text while recording', name: 'dyslexic_ai.reading_coach');
      }
    } catch (e) {
      developer.log('TTS error speaking text: $e', name: 'dyslexic_ai.reading_coach');
      errorMessage = 'Unable to speak text. Please try again.';
    }
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
    // Only update speech, don't trigger analysis here
    recognizedSpeech = speech;
  }

  @action
  void _onListeningChanged(bool listening) {
    isListening = listening;
    
    // Remove auto-complete logic - now handled by recording status
    if (!listening && currentSession?.status == ReadingSessionStatus.reading) {
      if (recognizedSpeech.isEmpty) {
        errorMessage = 'Having trouble hearing you. Try speaking louder or moving closer to the microphone.';
      }
    }
  }

  @action
  void _onRecordingStatusChanged(RecordingStatus status) {
    recordingStatus = status;
    
    // Handle recording completion - this is where we trigger analysis
    if (status == RecordingStatus.completed && currentSession != null) {
      _handleRecordingComplete();
    } else if (status == RecordingStatus.error) {
      errorMessage = 'Recording failed. Please try again.';
    }
  }

  @action
  void _onSilenceSecondsChanged(int seconds) {
    silenceSeconds = seconds;
  }

  @action
  Future<void> restartListening() async {
    if (currentSession?.status == ReadingSessionStatus.reading) {
      errorMessage = null;
      
      // Ensure TTS is stopped before restarting
      await _ttsService.prepareForSpeechRecognition();
      
      await _speechService.restartListening();
    }
  }

  @action
  Future<void> _handleRecordingComplete() async {
    if (currentSession == null) {
      developer.log('Cannot handle recording completion: missing session', name: 'dyslexic_ai.reading_coach');
      return;
    }

    if (recognizedSpeech.isEmpty) {
      developer.log('Cannot handle recording completion: no speech recognized', name: 'dyslexic_ai.reading_coach');
      errorMessage = 'No speech was detected. Please try again.';
      return;
    }

    developer.log('Recording completed, starting analysis', name: 'dyslexic_ai.reading_coach');
    
    // Now analyze the complete recording
    await _analyzeCompleteRecording();
  }

  @action
  Future<void> _analyzeCompleteRecording() async {
    if (currentSession == null || recognizedSpeech.isEmpty) {
      developer.log('Cannot analyze recording: missing session or speech data', name: 'dyslexic_ai.reading_coach');
      return;
    }

    isAnalyzing = true;
    developer.log('Starting analysis of complete recording', name: 'dyslexic_ai.reading_coach');

    try {
      final results = await _analysisService.analyzeReading(
        expectedText: currentSession!.text,
        spokenText: recognizedSpeech,
      );

      currentSession = currentSession!.copyWith(
        wordResults: results,
        status: ReadingSessionStatus.completed,
      );

      _completeSession();
      developer.log('Analysis completed successfully', name: 'dyslexic_ai.reading_coach');
    } catch (e) {
      developer.log('Analysis failed: $e', name: 'dyslexic_ai.reading_coach');
      errorMessage = 'Analysis failed: $e';
    } finally {
      isAnalyzing = false;
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
      completionStatus: 'completed',
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



  void dispose() {
    // Cancel any active session logging
    if (_sessionLogging.hasActiveSession) {
      _sessionLogging.cancelSession(reason: 'app_disposed');
    }
    
    _speechSubscription?.cancel();
    _listeningSubscription?.cancel();
    _recordingStatusSubscription?.cancel();
    _silenceSubscription?.cancel();
    
    // Stop TTS service before disposing
    _ttsService.stop();
    
    _speechService.dispose();
    _ttsService.dispose();
  }
} 