import 'package:mobx/mobx.dart';
import '../models/story.dart';
import '../services/story_service.dart';
import '../services/text_to_speech_service.dart';

part 'adaptive_story_store.g.dart';

class AdaptiveStoryStore = _AdaptiveStoryStore with _$AdaptiveStoryStore;

abstract class _AdaptiveStoryStore with Store {
  final StoryService _storyService;
  final TextToSpeechService _ttsService;

  _AdaptiveStoryStore({
    required StoryService storyService,
    required TextToSpeechService ttsService,
  })  : _storyService = storyService,
        _ttsService = ttsService;

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
  UserAnswer? lastAnswer;

  @observable
  bool showingFeedback = false;

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

      print('📖 Story started: ${story.title}');
    } catch (e) {
      print('❌ Failed to start story: $e');
      errorMessage = 'Failed to start story: $e';
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

    if (isOnLastQuestion) {
      // Move to next part
      await nextPart();
    } else {
      // Move to next question in current part
      currentQuestionIndex++;
      print('➡️ Next question: ${currentQuestionIndex + 1}');
    }
  }

  @action
  Future<void> nextPart() async {
    if (isOnLastPart) {
      // Story completed
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
    if (progress != null) {
      progress = progress!.copyWith(completedAt: DateTime.now());
      print('🎉 Story completed! Accuracy: ${progress!.accuracyPercentage.toStringAsFixed(1)}%');
    }
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
    currentStory = null;
    progress = null;
    currentPartIndex = 0;
    currentQuestionIndex = 0;
    lastAnswer = null;
    showingFeedback = false;
    practicedWords.clear();
    patternPracticeCount.clear();
    discoveredPatterns.clear();
    errorMessage = null;
  }

  List<Story> getStoriesByDifficulty(StoryDifficulty difficulty) {
    return _storyService.getStoriesByDifficulty(difficulty);
  }

  void dispose() {
    _ttsService.dispose();
  }
} 