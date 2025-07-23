import 'package:mobx/mobx.dart';
import 'dart:async';
import 'dart:developer' as developer;
import '../models/sentence_fixer.dart';
import '../models/learner_profile.dart';
import '../models/session_log.dart';
import '../services/sentence_fixer_service.dart';
import '../services/session_logging_service.dart';
import '../utils/service_locator.dart';

part 'sentence_fixer_store.g.dart';

class SentenceFixerStore = _SentenceFixerStore with _$SentenceFixerStore;

abstract class _SentenceFixerStore with Store {
  late final SentenceFixerService _sentenceFixerService;
  late final SessionLoggingService _sessionLoggingService;
  
  Timer? _sessionTimer;
  DateTime? _currentSentenceStartTime;

  _SentenceFixerStore() {
    _sentenceFixerService = SentenceFixerService();
    _sessionLoggingService = getIt<SessionLoggingService>();
  }

  @observable
  SentenceFixerSession? currentSession;

  @observable
  List<bool> selectedWords = [];

  @observable
  SentenceFixerFeedback? currentFeedback;

  @observable
  bool showFeedback = false;

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  int timeSpentOnCurrentSentence = 0;

  @observable
  SentenceFixerStats stats = SentenceFixerStats.empty();

  @observable
  bool isGeneratingSentences = false;

  @observable
  int sentencesGenerated = 0;

  @observable
  int totalSentencesToGenerate = 0;

  @observable
  String? detailedFeedback;

  @computed
  bool get hasCurrentSession => currentSession != null;

  @computed
  bool get hasCurrentSentence => currentSession?.currentSentence != null;

  @computed
  SentenceWithErrors? get currentSentence => currentSession?.currentSentence;

  @computed
  bool get isSessionCompleted => currentSession?.isCompleted ?? false;

  @computed
  bool get canSubmit => selectedWords.any((selected) => selected);

  @computed
  int get selectedWordsCount => selectedWords.where((selected) => selected).length;

  @computed
  double get progressPercentage {
    if (currentSession == null) return 0.0;
    return (currentSession!.currentSentenceIndex / currentSession!.totalSentences);
  }

  @computed
  int get currentSentenceNumber => (currentSession?.currentSentenceIndex ?? 0) + 1;

  @computed
  int get totalSentences => currentSession?.totalSentences ?? 0;

  @computed
  int get currentScore => currentSession?.totalScore ?? 0;

  @computed
  int get currentStreak => currentSession?.streak ?? 0;

  @computed
  bool get isStreamingInProgress => isGeneratingSentences && sentencesGenerated < totalSentencesToGenerate;

  @computed
  String get streamingStatusText {
    if (!isGeneratingSentences) return '';
    if (sentencesGenerated == 0) return 'Preparing first sentence...';
    return 'Generating sentence ${sentencesGenerated + 1}/$totalSentencesToGenerate...';
  }

  @computed
  double get streamingProgress {
    if (totalSentencesToGenerate == 0) return 0.0;
    return sentencesGenerated / totalSentencesToGenerate;
  }

  @action
  Future<void> startNewSession({
    required String difficulty,
    int? sentenceCount, // Make optional to use difficulty-based counts
    LearnerProfile? profile,
  }) async {
    // Use streaming version for better UX
    await startNewSessionStreaming(
      difficulty: difficulty,
      sentenceCount: sentenceCount,
      profile: profile,
    );
  }

  @action
  Future<void> startNewSessionStreaming({
    required String difficulty,
    int? sentenceCount, // Make optional so we can set based on difficulty
    LearnerProfile? profile,
  }) async {
    try {
      // Set sentence count based on difficulty
      final count = sentenceCount ?? _getSentenceCountForDifficulty(difficulty);
      
      isLoading = true;
      isGeneratingSentences = true;
      sentencesGenerated = 0;
      totalSentencesToGenerate = count;
      errorMessage = null;
      
      developer.log('🎯 Starting reliable AI-powered Sentence Fixer session: $difficulty ($count sentences)', 
          name: 'dyslexic_ai.sentence_fixer');

      final sentencesList = <SentenceWithErrors>[];
      
      // Stream sentences one by one
      final stream = _sentenceFixerService.generateSentencePackStream(
        difficulty: difficulty,
        count: count,
        profile: profile,
      );

      bool isFirstSentence = true;
      
      await for (final sentence in stream) {
        sentencesList.add(sentence);
        sentencesGenerated = sentencesList.length;
        
        developer.log('📥 Received sentence $sentencesGenerated/$count: "${sentence.words.join(' ')}"', 
            name: 'dyslexic_ai.sentence_fixer');

        if (isFirstSentence) {
          // Create session with first sentence immediately
          currentSession = SentenceFixerSession(
            status: SentenceFixerStatus.playing,
            totalSentences: count, // Expected total
            currentSentenceIndex: 0,
            attempts: [],
            totalScore: 0,
            streak: 0,
            difficulty: difficulty,
            sentences: [sentence], // Start with just the first sentence
          );

          // Initialize UI state for first sentence
          _initializeWordSelection();
          _startSentenceTimer();
          
          // Log session start
          _sessionLoggingService.startSession(
            sessionType: SessionType.sentenceFixer,
            featureName: 'Sentence Fixer',
            initialData: {
              'difficulty': difficulty,
              'total_sentences': count,
              'streaming_mode': true,
            },
          );

          isLoading = false; // User can start playing immediately
          isFirstSentence = false;
          
          developer.log('⚡ First sentence ready - user can start playing!', 
              name: 'dyslexic_ai.sentence_fixer');
        } else {
          // Add subsequent sentences to the session
          if (currentSession != null) {
            currentSession = currentSession!.copyWith(
              sentences: [...sentencesList],
            );
            
            developer.log('📝 Added sentence $sentencesGenerated to session queue', 
                name: 'dyslexic_ai.sentence_fixer');
          }
        }
      }

      // All sentences generated
      isGeneratingSentences = false;
      
      if (currentSession != null && sentencesList.isNotEmpty) {
        // Update session with final sentence list
        currentSession = currentSession!.copyWith(
          sentences: sentencesList,
        );
        
        developer.log('✅ All ${sentencesList.length} sentences generated and ready', 
            name: 'dyslexic_ai.sentence_fixer');
      } else {
        throw Exception('No sentences could be generated for this difficulty level');
      }
      
    } catch (e) {
      isLoading = false;
      isGeneratingSentences = false;
      errorMessage = 'Failed to start session: $e';
      developer.log('❌ Failed to start streaming Sentence Fixer session: $e', 
          name: 'dyslexic_ai.sentence_fixer');
    }
  }

  /// Legacy method for compatibility - now redirects to streaming version
  @action
  Future<void> startNewSessionLegacy({
    required String difficulty,
    int sentenceCount = 8,
    LearnerProfile? profile,
  }) async {
    try {
      isLoading = true;
      errorMessage = null;
      
      developer.log('Starting new Sentence Fixer session: $difficulty', 
          name: 'dyslexic_ai.sentence_fixer');

      // Generate sentences for the session
      final sentences = await _sentenceFixerService.generateSentencePack(
        difficulty: difficulty,
        count: sentenceCount,
        profile: profile,
      );

      if (sentences.isEmpty) {
        throw Exception('No sentences could be generated for this difficulty level');
      }

      // Create new session
      currentSession = SentenceFixerSession(
        status: SentenceFixerStatus.playing,
        totalSentences: sentences.length,
        currentSentenceIndex: 0,
        attempts: [],
        totalScore: 0,
        streak: 0,
        difficulty: difficulty,
        sentences: sentences,
      );

      // Initialize UI state
      _initializeWordSelection();
      _startSentenceTimer();

      // Log session start
      _sessionLoggingService.startSession(
        sessionType: SessionType.sentenceFixer,
        featureName: 'Sentence Fixer',
        initialData: {
          'difficulty': difficulty,
          'total_sentences': sentences.length,
        },
      );

      developer.log('Sentence Fixer session started with ${sentences.length} sentences', 
          name: 'dyslexic_ai.sentence_fixer');
      
    } catch (e) {
      errorMessage = 'Failed to start session: $e';
      developer.log('Failed to start Sentence Fixer session: $e', 
          name: 'dyslexic_ai.sentence_fixer');
    } finally {
      isLoading = false;
    }
  }

  @action
  void toggleWordSelection(int position) {
    if (showFeedback || currentSentence == null) return;
    
    if (position >= 0 && position < selectedWords.length) {
      // Create a new list to ensure MobX reactivity
      final newSelectedWords = List<bool>.from(selectedWords);
      newSelectedWords[position] = !newSelectedWords[position];
      selectedWords = newSelectedWords.asObservable();
      
      // Only log selection changes, not every click (removed excessive session logging)
    }
  }

  @action
  void submitAnswer() {
    if (currentSentence == null || showFeedback) return;

    final selectedPositions = <int>[];
    for (int i = 0; i < selectedWords.length; i++) {
      if (selectedWords[i]) {
        selectedPositions.add(i);
      }
    }

    developer.log('Submitting answer with ${selectedPositions.length} selections', 
        name: 'dyslexic_ai.sentence_fixer');

    // Validate selections and get feedback
    currentFeedback = _sentenceFixerService.validateSelections(
      currentSentence!,
      selectedPositions,
    );

    // Generate detailed feedback with correct answers
    detailedFeedback = _sentenceFixerService.generateDetailedFeedback(
      currentSentence!,
      currentFeedback!,
    );

    // Create attempt record
    final attempt = SentenceAttempt(
      sentenceId: currentSentence!.id,
      selectedPositions: selectedPositions,
      feedback: currentFeedback!,
      timeSpentSeconds: timeSpentOnCurrentSentence,
    );

    // Update session with attempt
    final updatedAttempts = [...currentSession!.attempts, attempt];
    final newScore = currentSession!.totalScore + currentFeedback!.score;
    final newStreak = currentFeedback!.isSuccess 
        ? currentSession!.streak + 1 
        : 0;

    currentSession = currentSession!.copyWith(
      attempts: updatedAttempts,
      totalScore: newScore,
      streak: newStreak,
    );

    // Log the attempt
    _sessionLoggingService.logUserAction(
      action: 'sentence_submitted',
      metadata: {
        'sentence_id': currentSentence!.id,
        'selected_positions': selectedPositions,
        'correct_selections': currentFeedback!.correctSelections,
        'incorrect_selections': currentFeedback!.incorrectSelections,
        'missed_errors': currentFeedback!.missedErrors,
        'accuracy': currentFeedback!.accuracy,
        'score': currentFeedback!.score,
        'time_spent': timeSpentOnCurrentSentence,
      },
    );

    showFeedback = true;
    _stopSentenceTimer();
  }

  @action
  void nextSentence() {
    if (currentSession == null) return;

    final nextIndex = currentSession!.currentSentenceIndex + 1;
    
    if (nextIndex < currentSession!.totalSentences) {
      // Move to next sentence
      currentSession = currentSession!.copyWith(
        currentSentenceIndex: nextIndex,
      );
      
      _initializeWordSelection();
      _startSentenceTimer();
      showFeedback = false;
      currentFeedback = null;
      detailedFeedback = null;
      
      developer.log('Moved to sentence ${nextIndex + 1}/${currentSession!.totalSentences}', 
          name: 'dyslexic_ai.sentence_fixer');
    } else {
      // Session completed
      _completeSession();
    }
  }

  @action
  void retryCurrentSentence() {
    if (currentSession == null || currentSentence == null) return;

    _initializeWordSelection();
    showFeedback = false;
    currentFeedback = null;
    detailedFeedback = null;
    _startSentenceTimer();
    
    developer.log('Retrying current sentence', name: 'dyslexic_ai.sentence_fixer');
  }

  @action
  void skipCurrentSentence() {
    if (currentSession == null || currentSentence == null) return;

    // Create a skip attempt with no selections
    final skipAttempt = SentenceAttempt(
      sentenceId: currentSentence!.id,
      selectedPositions: [],
      feedback: SentenceFixerFeedback(
        correctSelections: [],
        incorrectSelections: [],
        missedErrors: currentSentence!.errorPositions,
        correctedSentence: currentSentence!.correctedSentence,
        accuracy: 0.0,
        score: 0,
        message: 'Sentence skipped',
        isSuccess: false,
      ),
      timeSpentSeconds: timeSpentOnCurrentSentence,
    );

    // Update session
    final updatedAttempts = [...currentSession!.attempts, skipAttempt];
    currentSession = currentSession!.copyWith(
      attempts: updatedAttempts,
      streak: 0, // Reset streak on skip
    );

    // Log the skip
    _sessionLoggingService.logUserAction(
      action: 'sentence_skipped',
      metadata: {
        'sentence_id': currentSentence!.id,
        'time_spent': timeSpentOnCurrentSentence,
      },
    );

    // Move to next sentence
    nextSentence();
  }

  @action
  void pauseSession() {
    if (currentSession == null) return;
    
    currentSession = currentSession!.copyWith(
      status: SentenceFixerStatus.paused,
    );
    
    _stopSentenceTimer();
    developer.log('Session paused', name: 'dyslexic_ai.sentence_fixer');
  }

  @action
  void resumeSession() {
    if (currentSession == null) return;
    
    currentSession = currentSession!.copyWith(
      status: SentenceFixerStatus.playing,
    );
    
    _startSentenceTimer();
    developer.log('Session resumed', name: 'dyslexic_ai.sentence_fixer');
  }

  @action
  void endSession() {
    if (currentSession == null) return;
    
    _completeSession();
    developer.log('Session ended by user', name: 'dyslexic_ai.sentence_fixer');
  }

  @action
  void clearError() {
    errorMessage = null;
  }

  void _initializeWordSelection() {
    if (currentSentence == null) return;
    
    selectedWords = List<bool>.filled(currentSentence!.words.length, false);
    timeSpentOnCurrentSentence = 0;
  }

  void _startSentenceTimer() {
    _currentSentenceStartTime = DateTime.now();
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      timeSpentOnCurrentSentence++;
    });
  }

  void _stopSentenceTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }

  void _completeSession() {
    if (currentSession == null) return;

    final completedSession = currentSession!.copyWith(
      status: SentenceFixerStatus.completed,
      endTime: DateTime.now(),
    );

    currentSession = completedSession;
    _stopSentenceTimer();

    // Log session completion
    _sessionLoggingService.completeSession(
      finalAccuracy: completedSession.accuracyPercentage / 100,
      finalScore: completedSession.totalScore.toDouble(),
      completionStatus: 'completed',
      additionalData: {
        'sentences_completed': completedSession.completedSentences,
        'sentences_correct': completedSession.correctSentences,
        'total_score': completedSession.totalScore,
        'best_streak': completedSession.streak,
        'duration_minutes': completedSession.duration?.inMinutes ?? 0,
        'error_patterns': completedSession.errorPatterns,
        'struggling_areas': completedSession.strugglingAreas,
      },
    );

    developer.log('Session completed: ${completedSession.correctSentences}/${completedSession.completedSentences} correct', 
        name: 'dyslexic_ai.sentence_fixer');
  }

  Map<String, dynamic> getSessionSummary() {
    if (currentSession == null) return {};
    
    return _sentenceFixerService.getSessionSummary(currentSession!);
  }

  void dispose() {
    _sessionTimer?.cancel();
    developer.log('SentenceFixerStore disposed', name: 'dyslexic_ai.sentence_fixer');
  }

  int _getSentenceCountForDifficulty(String difficulty) {
    switch (difficulty) {
      case 'beginner':
        return 5;
      case 'intermediate':
        return 6;
      case 'advanced':
        return 8;
      default:
        return 5; // Default to beginner
    }
  }
} 