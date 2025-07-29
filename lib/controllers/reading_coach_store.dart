import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:mobx/mobx.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:math' as math;

import '../models/reading_session.dart';
import '../models/session_log.dart';
import '../models/learner_profile.dart';
import '../services/speech_recognition_service.dart';
import '../services/text_to_speech_service.dart';
import '../services/ocr_service.dart';
import '../services/preset_stories_service.dart';
import '../services/reading_analysis_service.dart';
import '../services/session_logging_service.dart';
import '../services/story_service.dart';
import '../utils/service_locator.dart';
import '../controllers/learner_profile_store.dart';

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
  bool isGeneratingStory = false;

  @observable
  List<String> liveFeedback = [];

  @observable
  List<String> practiceWords = [];

  @observable
  List<PresetStory> presetStories = [];

  @observable
  List<String> currentTextWords = [];

  @observable
  List<String> recognizedWords = [];

  // Track incremental speech processing to prevent re-highlighting old words
  int _lastProcessedWordCount = 0;

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
  bool get canStartReading =>
      currentText.isNotEmpty &&
      !isListening &&
      !isAnalyzing &&
      _speechService.isInitialized;

  @computed
  bool get hasSession => currentSession != null;

  @computed
  bool get isInInputMode => !isGeneratingStory && currentText.isEmpty;

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

  @computed
  List<bool> get wordHighlightStates {
    if (currentTextWords.isEmpty || recognizedWords.isEmpty) {
      return List.filled(currentTextWords.length, false);
    }

    final result = _calculateWordMatches(currentTextWords, recognizedWords);
    developer.log('🔍 Highlighting: ${currentTextWords.length} text words, ${recognizedWords.length} spoken words', 
        name: 'dyslexic_ai.reading_coach');
    developer.log('📝 Text: ${currentTextWords.take(10).join(", ")}...', 
        name: 'dyslexic_ai.reading_coach');
    developer.log('🎤 Spoken: ${recognizedWords.take(10).join(", ")}...', 
        name: 'dyslexic_ai.reading_coach');
    developer.log('💡 Highlights: ${result.asMap().entries.where((e) => e.value).map((e) => "${e.key}:${currentTextWords[e.key]}").join(", ")}', 
        name: 'dyslexic_ai.reading_coach');
    
    return result;
  }

  // Helper method to calculate which words should be highlighted
  List<bool> _calculateWordMatches(
      List<String> textWords, List<String> spokenWords) {
    final highlightStates = List.filled(textWords.length, false);

    // Simple sequential matching with fuzzy logic and recovery
    int textIndex = 0;
    int spokenIndex = 0;
    int matchCount = 0;

    developer.log('🔄 Starting word matching: textIndex=0, spokenIndex=0', 
        name: 'dyslexic_ai.reading_coach.matching');

    while (textIndex < textWords.length && spokenIndex < spokenWords.length) {
      final textWord =
          textWords[textIndex].toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
      final spokenWord = spokenWords[spokenIndex]
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w]'), '');

      // Exact match
      if (textWord == spokenWord) {
        highlightStates[textIndex] = true;
        matchCount++;
        developer.log('✅ Exact match: "${textWord}" at text[$textIndex] ↔ spoken[$spokenIndex]', 
            name: 'dyslexic_ai.reading_coach.matching');
        textIndex++;
        spokenIndex++;
      }
      // Fuzzy match (80% similarity)
      else if (_calculateSimilarity(textWord, spokenWord) >= 0.8) {
        highlightStates[textIndex] = true;
        matchCount++;
        developer.log('🔸 Fuzzy match: "${textWord}" ↔ "${spokenWord}" at text[$textIndex] ↔ spoken[$spokenIndex]', 
            name: 'dyslexic_ai.reading_coach.matching');
        textIndex++;
        spokenIndex++;
      }
      // Text word is shorter - might be partial recognition
      else if (textWord.length > 3 &&
          spokenWord.startsWith(textWord.substring(0, textWord.length ~/ 2))) {
        highlightStates[textIndex] = true;
        matchCount++;
        developer.log('🔹 Partial match: "${textWord}" ↔ "${spokenWord}" at text[$textIndex] ↔ spoken[$spokenIndex]', 
            name: 'dyslexic_ai.reading_coach.matching');
        textIndex++;
        spokenIndex++;
      }
      // No match - try recovery by looking ahead
      else {
        developer.log('❌ No match: "${textWord}" ↔ "${spokenWord}" at text[$textIndex] ↔ spoken[$spokenIndex]', 
            name: 'dyslexic_ai.reading_coach.matching');
        
        // Try to find the next matching sequence
        final recoveryResult = _findNextMatch(textWords, spokenWords, textIndex, spokenIndex);
        
        if (recoveryResult != null) {
          // Found a recovery point - jump to it
          developer.log('🔄 Recovery found: jumping to text[${recoveryResult.textIndex}] ↔ spoken[${recoveryResult.spokenIndex}]', 
              name: 'dyslexic_ai.reading_coach.matching');
          textIndex = recoveryResult.textIndex;
          spokenIndex = recoveryResult.spokenIndex;
        } else {
          // No recovery possible - skip this spoken word
          developer.log('⏭️ Skip spoken: "${spokenWord}" (no recovery possible)', 
              name: 'dyslexic_ai.reading_coach.matching');
          spokenIndex++;
        }
      }
    }

    developer.log('🏁 Matching complete: ${matchCount} matches, textIndex=${textIndex}, spokenIndex=${spokenIndex}', 
        name: 'dyslexic_ai.reading_coach.matching');

    return highlightStates;
  }

  // Recovery mechanism: look ahead to find next matching sequence
  ({int textIndex, int spokenIndex})? _findNextMatch(
      List<String> textWords, List<String> spokenWords, int currentTextIndex, int currentSpokenIndex) {
    
    // Look ahead in spoken words (up to 3 words)
    for (int spokenOffset = 1; spokenOffset <= 3 && currentSpokenIndex + spokenOffset < spokenWords.length; spokenOffset++) {
      final futureSpokenWord = spokenWords[currentSpokenIndex + spokenOffset]
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w]'), '');
      
      // Look ahead in text words (up to 2 words)  
      for (int textOffset = 0; textOffset <= 2 && currentTextIndex + textOffset < textWords.length; textOffset++) {
        final futureTextWord = textWords[currentTextIndex + textOffset]
            .toLowerCase()
            .replaceAll(RegExp(r'[^\w]'), '');
        
        // Check for exact match or high similarity
        if (futureTextWord == futureSpokenWord || 
            _calculateSimilarity(futureTextWord, futureSpokenWord) >= 0.8) {
          developer.log('🎯 Recovery match found: "${futureTextWord}" ↔ "${futureSpokenWord}" at text[${currentTextIndex + textOffset}] ↔ spoken[${currentSpokenIndex + spokenOffset}]', 
              name: 'dyslexic_ai.reading_coach.matching');
          return (
            textIndex: currentTextIndex + textOffset,
            spokenIndex: currentSpokenIndex + spokenOffset
          );
        }
      }
    }
    
    return null; // No recovery possible
  }

  // Simple similarity calculation (Levenshtein-like)
  double _calculateSimilarity(String word1, String word2) {
    if (word1.isEmpty || word2.isEmpty) return 0.0;
    if (word1 == word2) return 1.0;

    final maxLength = math.max(word1.length, word2.length);
    final commonChars = _countCommonChars(word1, word2);

    return commonChars / maxLength;
  }

  int _countCommonChars(String word1, String word2) {
    final chars1 = word1.split('');
    final chars2 = word2.split('');
    int common = 0;

    for (int i = 0; i < math.min(chars1.length, chars2.length); i++) {
      if (chars1[i] == chars2[i]) common++;
    }

    return common;
  }

  @action
  Future<void> initialize() async {
    isLoading = true;
    errorMessage = null;

    try {
      // Check speech service initialization with proper error handling
      final speechInitialized = await _speechService.initialize();
      if (!speechInitialized) {
        // Speech service failed to initialize - likely permission issue
        errorMessage =
            'Microphone access is required for reading practice. Please allow microphone permissions in your device settings.';
        developer.log(
            'Speech service initialization failed - likely permission denied',
            name: 'dyslexic_ai.reading_coach');
      } else {
        // Set up all listeners for the new recording flow only if speech service is ready
        _speechSubscription =
            _speechService.recognizedWordsStream.listen(_onSpeechRecognized);
        _listeningSubscription =
            _speechService.listeningStream.listen(_onListeningChanged);
        _recordingStatusSubscription = _speechService.recordingStatusStream
            .listen(_onRecordingStatusChanged);
        _silenceSubscription = _speechService.silenceSecondsStream
            .listen(_onSilenceSecondsChanged);

        developer.log('Speech recognition initialized successfully',
            name: 'dyslexic_ai.reading_coach');
      }

      await _ttsService.initialize();
      presetStories = PresetStoriesService.getPresetStories();
    } catch (e) {
      errorMessage = 'Failed to initialize reading coach: $e';
      developer.log('Reading coach initialization error: $e',
          name: 'dyslexic_ai.reading_coach');
    } finally {
      isLoading = false;
    }
  }

  @action
  void setCurrentText(String text) {
    currentText = text;
    errorMessage = null;

    // Split text into words for highlighting
    currentTextWords =
        text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
    
    // Reset incremental word tracking when text changes
    recognizedWords.clear(); // Clear old speech data when text changes
    _lastProcessedWordCount = 0;
  }

  @action
  void clearCurrentText() {
    currentText = '';
    currentTextWords.clear();
    errorMessage = null;
    // Clear any active session when starting fresh
    if (currentSession != null) {
      currentSession = null;
    }
    
    // Reset incremental word tracking
    recognizedWords.clear(); // Clear old speech data
    _lastProcessedWordCount = 0;
  }

  @action
  void selectPresetStory(PresetStory story) {
    setCurrentText(story.content);
  }

  /// Create a safe default profile for users without profiles
  LearnerProfile _createSafeDefaultProfile() {
    return LearnerProfile(
      phonologicalAwareness: 'developing',
      phonemeConfusions: const [],
      decodingAccuracy: 'developing', // Maps to beginner = 2 sentences
      workingMemory: 'average',
      fluency: 'developing',
      confidence: 'building',
      preferredStyle: 'visual',
      focus: 'basic phonemes',
      recommendedTool: 'Reading Coach',
      advice: 'Practice with simple stories to build confidence!',
      lastUpdated: DateTime.now(),
      sessionCount: 0,
      version: 1,
    );
  }

  @action
  Future<void> generateAIStory(Function(String) onTextUpdate) async {
    if (isGeneratingStory) return;

    final profileStore = getIt<LearnerProfileStore>();
    final profile = profileStore.currentProfile ?? _createSafeDefaultProfile();

    // Allow AI generation even without a profile using safe defaults

    isGeneratingStory = true;
    errorMessage = null;
    setCurrentText(''); // Clear current text

    try {
      final storyService = getIt<StoryService>();
      final stream = storyService.generateStoryWithChatStream(profile);

      final buffer = StringBuffer();
      await for (final chunk in stream) {
        buffer.write(chunk);
        final currentText = buffer.toString();

        developer.log(
            '📖 Setting text (${currentText.length} chars): "${currentText.length > 100 ? '${currentText.substring(0, 100)}...' : currentText}"',
            name: 'dyslexic_ai.reading_coach');

        setCurrentText(currentText);
        onTextUpdate(currentText); // Update UI immediately
      }

      developer.log('✅ AI story generation completed',
          name: 'dyslexic_ai.reading_coach');

      final finalText = currentText;
      developer.log(
          '📚 Final story: ${finalText.length} chars, ${finalText.split(RegExp(r'\s+')).length} words',
          name: 'dyslexic_ai.reading_coach');
    } catch (e) {
      developer.log('❌ AI story generation failed: $e',
          name: 'dyslexic_ai.reading_coach');
      errorMessage = 'Failed to generate story: $e';
      setCurrentText(''); // Clear on error
    } finally {
      isGeneratingStory = false;
    }
  }

  @action
  Future<void> pickImageFromGallery() async {
    isLoading = true;
    errorMessage = null;

    try {
      final XFile? image =
          await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final extractedText =
            await _ocrService.processImageForReading(File(image.path));
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
      developer.log('Cannot start reading: canStartReading=false',
          name: 'dyslexic_ai.reading_coach');

      // Provide specific feedback about why reading cannot start
      if (!_speechService.isInitialized) {
        errorMessage =
            'Microphone access is required to start reading practice. Please allow microphone permissions.';
      }
      return;
    }

    developer.log('Starting reading session',
        name: 'dyslexic_ai.reading_coach');

    currentSession = ReadingSession(
      text: currentText,
      status: ReadingSessionStatus.reading,
    );

    liveFeedback.clear();
    practiceWords.clear();
    recognizedSpeech = '';
    recognizedWords.clear(); // Clear old speech data
    isAnalyzing = false;
    
    // Reset incremental word tracking for new session
    _lastProcessedWordCount = 0;

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
    developer.log('Reading session started successfully',
        name: 'dyslexic_ai.reading_coach');
  }

  @action
  Future<void> stopReading() async {
    if (!isListening) {
      developer.log('Cannot stop reading: not currently listening',
          name: 'dyslexic_ai.reading_coach');
      return;
    }

    developer.log('Stopping reading session',
        name: 'dyslexic_ai.reading_coach');

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
      currentSession =
          currentSession!.copyWith(status: ReadingSessionStatus.paused);
    }
  }

  @action
  Future<void> resumeReading() async {
    if (currentSession?.status != ReadingSessionStatus.paused) return;

    currentSession =
        currentSession!.copyWith(status: ReadingSessionStatus.reading);

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
        developer.log('Cannot speak word while recording',
            name: 'dyslexic_ai.reading_coach');
      }
    } catch (e) {
      developer.log('TTS error speaking word: $e',
          name: 'dyslexic_ai.reading_coach');
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
        developer.log('Cannot speak text while recording',
            name: 'dyslexic_ai.reading_coach');
      }
    } catch (e) {
      developer.log('TTS error speaking text: $e',
          name: 'dyslexic_ai.reading_coach');
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
    recognizedWords.clear(); // Clear old speech data
    liveFeedback.clear();
    practiceWords.clear();
    errorMessage = null;
    
    // Reset incremental word tracking
    _lastProcessedWordCount = 0;
  }

  @action
  void clearError() {
    errorMessage = null;
  }

  @action
  void _onSpeechRecognized(String speech) {
    // Only update speech, don't trigger analysis here
    recognizedSpeech = speech;

    // Split recognized speech into words for highlighting
    final allWords = speech.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
    
    // Only process if we have new words (prevents re-processing causing highlight misalignment)
    final newWordCount = allWords.length;
    
    developer.log('📡 Speech received: "${speech}" (${speech.length} chars)', 
        name: 'dyslexic_ai.reading_coach');
    developer.log('🔢 Word count: ${newWordCount} new vs ${_lastProcessedWordCount} last processed', 
        name: 'dyslexic_ai.reading_coach');
    
    if (newWordCount > _lastProcessedWordCount) {
      final previousCount = _lastProcessedWordCount;
      final oldWords = recognizedWords.toList(); // Copy for comparison
      recognizedWords = allWords;
      _lastProcessedWordCount = newWordCount;
      
      developer.log('🎯 New words detected: +${newWordCount - previousCount} new words', 
          name: 'dyslexic_ai.reading_coach');
      developer.log('🔄 Words updated: ${oldWords.length} → ${allWords.length}', 
          name: 'dyslexic_ai.reading_coach');
      developer.log('📋 New words: ${allWords.join(" | ")}', 
          name: 'dyslexic_ai.reading_coach');
    } else if (newWordCount < _lastProcessedWordCount) {
      developer.log('⚠️ Word count decreased! ${_lastProcessedWordCount} → ${newWordCount} (possible speech reset)', 
          name: 'dyslexic_ai.reading_coach');
      // Don't update - this might be speech recognition restarting
    } else {
      developer.log('📍 Same word count (${newWordCount}), no update needed', 
          name: 'dyslexic_ai.reading_coach');
    }
  }

  @action
  void _onListeningChanged(bool listening) {
    isListening = listening;

    // Remove auto-complete logic - now handled by recording status
    if (!listening && currentSession?.status == ReadingSessionStatus.reading) {
      if (recognizedSpeech.isEmpty) {
        errorMessage =
            'Having trouble hearing you. Try speaking louder or moving closer to the microphone.';
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
      // Provide more specific error message for permission issues
      if (!_speechService.isInitialized) {
        errorMessage =
            'Microphone permission is required. Please check your device settings and allow microphone access for this app.';
      } else {
        errorMessage =
            'Recording failed. Please try again or restart the microphone.';
      }
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

      // Check if speech service is properly initialized before restarting
      if (!_speechService.isInitialized) {
        developer.log(
            'Cannot restart listening: speech service not initialized',
            name: 'dyslexic_ai.reading_coach');
        errorMessage =
            'Microphone access is required. Please allow microphone permissions and try again.';
        return;
      }

      // Clear incremental tracking when manually restarting
      recognizedWords.clear();
      _lastProcessedWordCount = 0;
      developer.log('🔄 Manual restart: cleared speech tracking', name: 'dyslexic_ai.reading_coach');

      // Ensure TTS is stopped before restarting
      await _ttsService.prepareForSpeechRecognition();

      await _speechService.restartListening();
    }
  }

  @action
  Future<void> requestMicrophonePermission() async {
    developer.log('Requesting microphone permission...',
        name: 'dyslexic_ai.reading_coach');

    // Clear any existing error message while we try
    errorMessage = null;
    isLoading = true;

    try {
      // Re-initialize speech service to trigger permission request
      final initialized = await _speechService.initialize();

      if (initialized) {
        // Set up listeners if they weren't set up before
        if (_speechSubscription == null) {
          _speechSubscription =
              _speechService.recognizedWordsStream.listen(_onSpeechRecognized);
          _listeningSubscription =
              _speechService.listeningStream.listen(_onListeningChanged);
          _recordingStatusSubscription = _speechService.recordingStatusStream
              .listen(_onRecordingStatusChanged);
          _silenceSubscription = _speechService.silenceSecondsStream
              .listen(_onSilenceSecondsChanged);
        }
        developer.log('Microphone permission granted successfully',
            name: 'dyslexic_ai.reading_coach');
      } else {
        errorMessage =
            'Microphone permission was denied. Please go to your device settings and allow microphone access for this app, then try again.';
        developer.log('Microphone permission denied',
            name: 'dyslexic_ai.reading_coach');
      }
    } catch (e) {
      errorMessage = 'Failed to request microphone permission: $e';
      developer.log('Microphone permission request failed: $e',
          name: 'dyslexic_ai.reading_coach');
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> _handleRecordingComplete() async {
    if (currentSession == null) {
      developer.log('Cannot handle recording completion: missing session',
          name: 'dyslexic_ai.reading_coach');
      return;
    }

    if (recognizedSpeech.isEmpty) {
      developer.log('Cannot handle recording completion: no speech recognized',
          name: 'dyslexic_ai.reading_coach');
      errorMessage = 'No speech was detected. Please try again.';
      return;
    }

    developer.log('Recording completed, starting analysis',
        name: 'dyslexic_ai.reading_coach');

    // Now analyze the complete recording
    await _analyzeCompleteRecording();
  }

  @action
  Future<void> _analyzeCompleteRecording() async {
    if (currentSession == null || recognizedSpeech.isEmpty) {
      developer.log('Cannot analyze recording: missing session or speech data',
          name: 'dyslexic_ai.reading_coach');
      return;
    }

    isAnalyzing = true;
    developer.log('Starting analysis of complete recording',
        name: 'dyslexic_ai.reading_coach');

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
      developer.log('Analysis completed successfully',
          name: 'dyslexic_ai.reading_coach');
    } catch (e) {
      developer.log('Analysis failed: $e', name: 'dyslexic_ai.reading_coach');
      errorMessage = 'Analysis failed: $e';
    } finally {
      isAnalyzing = false;
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
    final wordsRead = currentSession!.wordResults.length;

    _sessionLogging.completeSession(
      finalAccuracy: accuracy,
      completionStatus: 'completed',
      additionalData: {
        'final_status': 'completed',
        'words_read': wordsRead, // Ensure words_read is preserved
        'total_words': wordsRead,
        'correct_words': currentSession!.correctWordsCount,
        'mispronounced_words_count': currentSession!.mispronuncedWords.length,
        'practice_words_suggested': practiceWords.length,
        'feedback_messages_count': liveFeedback.length,
      },
    );
  }

  void dispose() {
    try {
      developer.log('🎤 Disposing ReadingCoachStore',
          name: 'dyslexic_ai.reading_coach');

      // Cancel any active session logging first
      if (_sessionLogging.hasActiveSession) {
        _sessionLogging.cancelSession(reason: 'reading_coach_disposed');
      }

      // Cancel all stream subscriptions
      _speechSubscription?.cancel();
      _speechSubscription = null;

      _listeningSubscription?.cancel();
      _listeningSubscription = null;

      _recordingStatusSubscription?.cancel();
      _recordingStatusSubscription = null;

      _silenceSubscription?.cancel();
      _silenceSubscription = null;

      // Stop services but don't dispose (shared services)
      _ttsService.stop();

      // Stop speech recognition if active
      if (_speechService.isListening) {
        _speechService.stopListening();
      }

      // Clear state
      currentSession = null;
      currentText = '';
      recognizedSpeech = '';
      liveFeedback.clear();
      practiceWords.clear();
      errorMessage = null;
      isListening = false;
      isAnalyzing = false;

      developer.log('🎤 ReadingCoachStore disposed successfully',
          name: 'dyslexic_ai.reading_coach');
    } catch (e) {
      developer.log('Reading coach dispose error: $e',
          name: 'dyslexic_ai.reading_coach');
    }
  }
}
