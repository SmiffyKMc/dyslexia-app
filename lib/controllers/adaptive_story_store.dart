import 'package:mobx/mobx.dart';
import '../models/story.dart';
import '../models/session_log.dart';
import '../services/story_service.dart';
import '../services/text_to_speech_service.dart';
import '../services/session_logging_service.dart';
import '../services/gemma_profile_update_service.dart';
import '../utils/service_locator.dart';

part 'adaptive_story_store.g.dart';

class AdaptiveStoryStore = _AdaptiveStoryStore with _$AdaptiveStoryStore;

abstract class _AdaptiveStoryStore with Store {
  final StoryService _storyService;
  final TextToSpeechService _ttsService;
  late final SessionLoggingService _sessionLogging;
  late final GemmaProfileUpdateService _profileUpdateService;
  DateTime? _sessionStartTime;

  _AdaptiveStoryStore({
    required StoryService storyService,
    required TextToSpeechService ttsService,
  })  : _storyService = storyService,
        _ttsService = ttsService {
    _sessionLogging = getIt<SessionLoggingService>();
    _profileUpdateService = getIt<GemmaProfileUpdateService>();
  }

  @observable
  Story? currentStory;

  @observable
  StoryProgress? progress;

  @observable
  int currentPartIndex = 0;

  @observable
  int currentQuestionIndex = 0;

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  bool showingFeedback = false;

  @observable
  bool storyCompleted = false;

  @observable
  UserAnswer? lastAnswer;

  @observable
  ObservableList<String> practicedWords = ObservableList<String>();

  @observable
  ObservableMap<String, int> patternPracticeCount = ObservableMap<String, int>();

  @observable
  ObservableList<LearningPattern> discoveredPatterns = ObservableList<LearningPattern>();

  @computed
  StoryPart? get currentPart {
    if (currentStory == null) return null;
    return currentStory!.getPartByIndex(currentPartIndex);
  }

  @computed
  Question? get currentQuestion {
    if (currentPart == null) return null;
    if (currentQuestionIndex >= currentPart!.questions.length) return null;
    return currentPart!.questions[currentQuestionIndex];
  }

  @computed
  String get currentPartContentWithMasking {
    if (currentPart == null || currentQuestion == null) {
      return currentPart?.content ?? '';
    }
    
    final wordsToMask = currentQuestion!.getWordsToMask(currentPart!);
    return currentPart!.getContentWithMaskedWords(wordsToMask);
  }

  @computed
  bool get hasCurrentStory => currentStory != null;

  @computed
  bool get hasCurrentQuestion => currentQuestion != null;

  @computed
  bool get isOnLastPart => currentStory != null && currentPartIndex >= currentStory!.parts.length - 1;

  @computed
  bool get isOnLastQuestion => currentPart != null && currentQuestionIndex >= currentPart!.questions.length - 1;

  @computed
  bool get canGoNext => hasCurrentStory && (!isOnLastPart || !isOnLastQuestion);

  @computed
  bool get canGoPrevious => currentPartIndex > 0 || currentQuestionIndex > 0;

  @computed
  double get progressPercentage {
    if (currentStory == null) return 0.0;
    
    final totalParts = currentStory!.totalParts;
    final completedParts = currentPartIndex;
    final currentPartProgress = currentPart != null && currentPart!.hasQuestions
        ? (currentQuestionIndex + 1) / currentPart!.questionCount
        : 1.0;
    
    return ((completedParts + currentPartProgress) / totalParts) * 100;
  }

  @computed
  int get totalQuestionsAnswered => practicedWords.length;

  @computed
  List<String> get uniquePracticedWords => practicedWords.toSet().toList();

  @computed
  List<String> get practicedPatterns => patternPracticeCount.keys.toList();

  @action
  List<Story> getAllStories() {
    return _storyService.getAllStories();
  }

  @action
  Future<void> startStory(String storyId) async {
    print('📖 Starting story: $storyId');
    isLoading = true;
    errorMessage = null;

    try {
      final story = _storyService.getStoryById(storyId);
      if (story == null) {
        throw Exception('Story not found');
      }

      currentStory = story;
      currentPartIndex = 0;
      currentQuestionIndex = 0;
      lastAnswer = null;
      showingFeedback = false;
      
      practicedWords.clear();
      patternPracticeCount.clear();
      discoveredPatterns.clear();

      progress = StoryProgress(
        storyId: storyId,
        startedAt: DateTime.now(),
      );

      // Start session logging
      _sessionStartTime = DateTime.now();
      await _sessionLogging.startSession(
        sessionType: SessionType.adaptiveStory,
        featureName: 'Adaptive Story',
        initialData: {
          'story_id': storyId,
          'story_title': story.title,
          'story_difficulty': story.difficulty.toString(),
          'total_parts': story.totalParts,
          'total_questions': story.parts.fold(0, (sum, part) => sum + part.questions.length),
          'story_started': _sessionStartTime!.toIso8601String(),
        },
      );

      print('📖 Story started: ${story.title}');
    } catch (e) {
      print('❌ Failed to start story: $e');
      errorMessage = 'Failed to start story: $e';
      
      // Complete session with error if logging was started
      if (_sessionLogging.hasActiveSession) {
        await _sessionLogging.completeSession(
          finalAccuracy: 0.0,
          completionStatus: 'failed',
          additionalData: {
            'error_message': e.toString(),
            'story_status': 'failed_to_start',
          },
        );
      }
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> answerQuestion(String answer) async {
    if (currentQuestion == null) return;

    print('💭 Answering question: $answer');
    
    final question = currentQuestion!;
    final isCorrect = question.isCorrect(answer);
    
    final userAnswer = UserAnswer(
      questionId: question.id,
      userAnswer: answer,
      correctAnswer: question.correctAnswer,
      isCorrect: isCorrect,
      answeredAt: DateTime.now(),
    );

    lastAnswer = userAnswer;
    showingFeedback = true;

    // Track practiced word
    practicedWords.add(question.correctAnswer);
    
    // Track pattern practice
    if (question.pattern.isNotEmpty) {
      final currentCount = patternPracticeCount[question.pattern] ?? 0;
      patternPracticeCount[question.pattern] = currentCount + 1;
      
      _updateDiscoveredPatterns(question.pattern);
    }

    // Update progress
    if (progress != null) {
      final updatedAnswers = List<UserAnswer>.from(progress!.answers)..add(userAnswer);
      final updatedPracticedWords = List<String>.from(progress!.practicedWords)..add(question.correctAnswer);
      final updatedPatternCount = Map<String, int>.from(progress!.patternPracticeCount);
      if (question.pattern.isNotEmpty) {
        updatedPatternCount[question.pattern] = (updatedPatternCount[question.pattern] ?? 0) + 1;
      }

      progress = progress!.copyWith(
        answers: updatedAnswers,
        practicedWords: updatedPracticedWords,
        patternPracticeCount: updatedPatternCount,
      );
    }

    // Session logging
    if (_sessionLogging.hasActiveSession) {
      // Log individual question data
      _sessionLogging.updateSessionData({
        'last_question_id': question.id,
        'last_question_pattern': question.pattern,
        'last_question_correct': isCorrect,
        'part_number': currentPartIndex + 1,
        'question_number': currentQuestionIndex + 1,
        'last_question_time': DateTime.now().toIso8601String(),
      });

      // Update confidence based on accuracy
      final currentAccuracy = progress?.accuracyPercentage ?? 0.0;
      if (currentAccuracy >= 80) {
        _sessionLogging.logConfidenceIndicator(
          'high',
          reason: 'High accuracy in story comprehension (${currentAccuracy.toStringAsFixed(1)}%)',
        );
      } else if (currentAccuracy >= 60) {
        _sessionLogging.logConfidenceIndicator(
          'medium',
          reason: 'Moderate accuracy in story comprehension (${currentAccuracy.toStringAsFixed(1)}%)',
        );
      } else {
        _sessionLogging.logConfidenceIndicator(
          'low',
          reason: 'Lower accuracy in story comprehension (${currentAccuracy.toStringAsFixed(1)}%)',
        );
      }

      // Track learning patterns
      if (question.pattern.isNotEmpty) {
        _sessionLogging.logLearningStyleUsage(
          usedVisualAids: true,
          preferredMode: 'visual',
        );
      }
    }

    print('💭 Answer recorded: ${isCorrect ? "✓ Correct" : "✗ Incorrect"}');
  }

  @action
  void _updateDiscoveredPatterns(String pattern) {
    final existingIndex = discoveredPatterns.indexWhere((p) => p.pattern == pattern);
    final examples = _storyService.getPatternExamples()[pattern] ?? [];
    final description = _storyService.getPatternDescription(pattern);
    
    if (existingIndex >= 0) {
      // Update existing pattern
      final existing = discoveredPatterns[existingIndex];
      discoveredPatterns[existingIndex] = existing.copyWith(
        practiceCount: existing.practiceCount + 1,
      );
    } else {
      // Add new pattern
      discoveredPatterns.add(LearningPattern(
        pattern: pattern,
        description: description,
        examples: examples,
        practiceCount: 1,
      ));
    }
  }

  @action
  Future<void> nextQuestion() async {
    if (!hasCurrentQuestion) return;

    showingFeedback = false;
    lastAnswer = null;

    print('🔍 nextQuestion: currentQuestionIndex=$currentQuestionIndex, isOnLastQuestion=$isOnLastQuestion');
    print('🔍 nextQuestion: currentPartIndex=$currentPartIndex, isOnLastPart=$isOnLastPart');

    if (isOnLastQuestion) {
      // Move to next part
      print('🔍 Moving to next part...');
      await nextPart();
    } else {
      // Move to next question in current part
      currentQuestionIndex++;
      print('➡️ Next question: ${currentQuestionIndex + 1}');
    }
  }

  @action
  Future<void> nextPart() async {
    print('🔍 nextPart: currentPartIndex=$currentPartIndex, isOnLastPart=$isOnLastPart');
    print('🔍 nextPart: story parts length=${currentStory?.parts.length}');
    
    if (isOnLastPart) {
      // Story completed
      print('🔍 Story should be completed, calling completeStory...');
      await completeStory();
      return;
    }

    currentPartIndex++;
    currentQuestionIndex = 0;
    showingFeedback = false;
    lastAnswer = null;

    print('📄 Next part: ${currentPartIndex + 1}');
  }

  @action
  Future<void> completeStory() async {
    print('🔍 completeStory called - progress: ${progress != null}');
    
    if (progress != null) {
      progress = progress!.copyWith(completedAt: DateTime.now());
      storyCompleted = true;
      print('🎉 Story completed! Accuracy: ${progress!.accuracyPercentage.toStringAsFixed(1)}%');
      print('🔍 storyCompleted set to: $storyCompleted');
      
      // Complete session logging
      if (_sessionLogging.hasActiveSession) {
        final completionData = {
          'story_completed': true,
          'completion_time': DateTime.now().toIso8601String(),
          'total_questions': progress!.totalAnswersCount,
          'correct_answers': progress!.correctAnswersCount,
          'final_accuracy': progress!.accuracyPercentage,
          'unique_words_practiced': progress!.uniquePracticedWords.length,
          'patterns_practiced': progress!.practicedPatterns.length,
          'parts_completed': currentPartIndex + 1,
          'story_title': currentStory?.title ?? 'Unknown',
          'story_difficulty': currentStory?.difficulty.toString() ?? 'unknown',
          'session_duration': _sessionStartTime != null 
            ? DateTime.now().difference(_sessionStartTime!).inSeconds 
            : 0,
          // Add comprehension data directly to completion data
          'questions_total': progress!.totalAnswersCount,
          'questions_correct': progress!.correctAnswersCount,
          'questions_answered': progress!.totalAnswersCount,
          'comprehension_score': progress!.accuracyPercentage / 100,
          'incorrect_answers': progress!.answers
            .where((answer) => !answer.isCorrect)
            .map((answer) => answer.userAnswer)
            .toList(),
          'comprehension_updated': DateTime.now().toIso8601String(),
        };

        // Log final comprehension results to ensure session data is updated
        _sessionLogging.logComprehensionResults(
          questionsTotal: progress!.totalAnswersCount,
          questionsCorrect: progress!.correctAnswersCount,
          comprehensionScore: progress!.accuracyPercentage / 100,
          incorrectAnswers: progress!.answers
            .where((answer) => !answer.isCorrect)
            .map((answer) => answer.userAnswer)
            .toList(),
        );

        // Add a small delay to ensure the comprehension data is processed
        await Future.delayed(const Duration(milliseconds: 100));

        await _sessionLogging.completeSession(
          finalAccuracy: progress!.accuracyPercentage / 100,
          completionStatus: 'completed',
          additionalData: completionData,
        );
        
        // Schedule intelligent background profile update after story completion
        print('🧠 Scheduling background profile update after story completion');
        _profileUpdateService.scheduleBackgroundUpdate();
      }
    }
  }

  @action
  void finishStory() {
    // Reset all state and navigate back to story selection
    currentStory = null;
    progress = null;
    currentPartIndex = 0;
    currentQuestionIndex = 0;
    lastAnswer = null;
    showingFeedback = false;
    storyCompleted = false;
    practicedWords.clear();
    patternPracticeCount.clear();
    discoveredPatterns.clear();
    errorMessage = null;
    _sessionStartTime = null;
  }

  @action
  Future<void> skipCurrentQuestion() async {
    print('⏭️ Skipping question');
    await nextQuestion();
  }

  @action
  Future<void> restartStory() async {
    if (currentStory == null) return;
    
    print('🔄 Restarting story');
    await startStory(currentStory!.id);
  }

  @action
  Future<void> goToPreviousPart() async {
    if (currentPartIndex > 0) {
      currentPartIndex--;
      currentQuestionIndex = 0;
      showingFeedback = false;
      lastAnswer = null;
      print('⬅️ Previous part: ${currentPartIndex + 1}');
    }
  }

  @action
  Future<void> speakCurrentContent() async {
    if (currentPart == null) return;
    
    print('🔊 Speaking current part content');
    try {
      await _ttsService.speak(currentPart!.content);
    } catch (e) {
      print('❌ Failed to speak content: $e');
      errorMessage = 'Failed to speak content';
    }
  }

  @action
  Future<void> speakQuestion() async {
    if (currentQuestion == null) return;
    
    print('🔊 Speaking current question');
    try {
      await _ttsService.speak(currentQuestion!.sentenceWithBlank);
    } catch (e) {
      print('❌ Failed to speak question: $e');
      errorMessage = 'Failed to speak question';
    }
  }

  @action
  Future<void> speakCorrectAnswer() async {
    if (currentQuestion == null) return;
    
    print('🔊 Speaking correct answer');
    try {
      await _ttsService.speak(currentQuestion!.sentence);
    } catch (e) {
      print('❌ Failed to speak answer: $e');
      errorMessage = 'Failed to speak answer';
    }
  }

  @action
  void clearError() {
    errorMessage = null;
  }

  @action
  void hideFeedback() {
    showingFeedback = false;
    lastAnswer = null;
  }

  @action
  void clearCurrentStory() {
    // Complete session with cancellation if active
    if (_sessionLogging.hasActiveSession) {
      final currentAccuracy = progress?.accuracyPercentage ?? 0.0;
      _sessionLogging.completeSession(
        finalAccuracy: currentAccuracy / 100,
        completionStatus: 'cancelled',
        additionalData: {
          'story_cancelled': true,
          'parts_completed': currentPartIndex,
          'questions_answered': progress?.totalAnswersCount ?? 0,
          'cancellation_time': DateTime.now().toIso8601String(),
        },
      );
    }
    
    currentStory = null;
    progress = null;
    currentPartIndex = 0;
    currentQuestionIndex = 0;
    lastAnswer = null;
    showingFeedback = false;
    storyCompleted = false;
    practicedWords.clear();
    patternPracticeCount.clear();
    discoveredPatterns.clear();
    errorMessage = null;
    _sessionStartTime = null;
  }

  List<Story> getStoriesByDifficulty(StoryDifficulty difficulty) {
    return _storyService.getStoriesByDifficulty(difficulty);
  }

  void dispose() {
    _ttsService.dispose();
  }
} 