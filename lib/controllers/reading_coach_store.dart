import 'dart:async';
import 'dart:io';
import 'package:mobx/mobx.dart';
import 'package:image_picker/image_picker.dart';
import '../models/reading_session.dart';
import '../services/speech_recognition_service.dart';
import '../services/text_to_speech_service.dart';
import '../services/ocr_service.dart';
import '../services/preset_stories_service.dart';
import '../services/reading_analysis_service.dart';

part 'reading_coach_store.g.dart';

class ReadingCoachStore = _ReadingCoachStore with _$ReadingCoachStore;

abstract class _ReadingCoachStore with Store {
  final SpeechRecognitionService _speechService;
  final TextToSpeechService _ttsService;
  final OcrService _ocrService;
  final ReadingAnalysisService _analysisService;
  final ImagePicker _imagePicker = ImagePicker();

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
        _analysisService = analysisService;

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
  }

  void dispose() {
    _speechSubscription?.cancel();
    _listeningSubscription?.cancel();
    _speechService.dispose();
    _ttsService.dispose();
  }
} 