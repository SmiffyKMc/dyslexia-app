import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/phonics_game.dart';
import '../models/session_log.dart';
import '../services/phonics_sounds_service.dart';
import '../services/ai_phonics_generation_service.dart';
import '../services/session_logging_service.dart';
import '../controllers/learner_profile_store.dart';
import '../utils/service_locator.dart';

class PhonicsGameStore with ChangeNotifier {
  final PhonicsSoundsService _soundsService = PhonicsSoundsService();
  late final AIPhonicsGenerationService _aiPhonicsService;
  late final SessionLoggingService _sessionLogging;

  PhonicsGameSession? _currentSession;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isPlayingSound = false;
  String? _selectedAnswer;
  bool _showFeedback = false;
  String _feedbackMessage = '';
  bool _feedbackIsCorrect = false;
  int _sessionDuration = 5;

  Timer? _gameTimer;
  DateTime? _roundStartTime;

  // Getters
  PhonicsGameSession? get currentSession => _currentSession;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isPlayingSound => _isPlayingSound;
  String? get selectedAnswer => _selectedAnswer;
  bool get showFeedback => _showFeedback;
  String get feedbackMessage => _feedbackMessage;
  bool get feedbackIsCorrect => _feedbackIsCorrect;
  int get sessionDuration => _sessionDuration;

  GameRound? get currentRound => _currentSession?.currentRound;
  bool get hasCurrentSession => _currentSession != null;
  bool get isGameActive => hasCurrentSession && !_currentSession!.isCompleted;
  int get currentRoundNumber => (_currentSession?.currentRoundIndex ?? 0) + 1;
  int get totalRounds => _currentSession?.totalRounds ?? 0;
  double get progressPercentage => totalRounds > 0 ? (currentRoundNumber / totalRounds) : 0;
  int get currentScore => _currentSession?.score ?? 0;
  int get correctAnswers => _currentSession?.correctAnswers ?? 0;
  double get accuracyPercentage => _currentSession?.accuracyPercentage ?? 0;

  Future<void> startNewGame({int rounds = 5, int difficulty = 1}) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Initialize services
      _sessionLogging = getIt<SessionLoggingService>();
      _aiPhonicsService = getIt<AIPhonicsGenerationService>();

      await _soundsService.initialize();

      // Get learner profile for AI generation
      final learnerProfileStore = getIt<LearnerProfileStore>();
      final profile = learnerProfileStore.currentProfile;

      // Generate sound sets using AI (with fallback)
      List<SoundSet> soundSets = await _aiPhonicsService.generateGameSounds(
        profile: profile,
        rounds: rounds,
        difficulty: difficulty,
      );
      
      if (soundSets.isEmpty) {
        throw Exception('No sound sets available for difficulty $difficulty');
      }

      List<GameRound> gameRounds = [];
      for (int i = 0; i < soundSets.length; i++) {
        SoundSet soundSet = soundSets[i];
        
        // Use AI-generated word options directly, fallback to original generation if needed
        List<WordOption> options = soundSet.words.isNotEmpty 
            ? soundSet.words 
            : _soundsService.generateGameOptions(soundSet);
        
        gameRounds.add(GameRound(
          roundNumber: i + 1,
          soundSet: soundSet,
          options: options,
        ));
      }

      _currentSession = PhonicsGameSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: DateTime.now(),
        status: GameStatus.playing,
        totalRounds: gameRounds.length,
        currentRoundIndex: 0,
        rounds: gameRounds,
        score: 0,
        totalTimeSpent: 0,
        difficulty: difficulty.toString(),
      );

      _sessionDuration = rounds;
      
      // Start session logging
      await _sessionLogging.startSession(
        sessionType: SessionType.phonicsGame,
        featureName: 'Phonics Game',
        initialData: {
          'session_id': _currentSession!.id,
          'difficulty': difficulty,
          'total_rounds': rounds,
          'game_started': DateTime.now().toIso8601String(),
        },
      );
      
      _startRoundTimer();
      
    } catch (e) {
      _errorMessage = 'Failed to start game: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
      
      // Play sound after loading is complete
      if (_errorMessage?.isEmpty ?? true) {
        await _playCurrentSound();
      }
    }
  }

  Future<void> selectAnswer(String word) async {
    if (!isGameActive || currentRound == null || _showFeedback) return;

    _selectedAnswer = word;
    
    WordOption selectedOption = currentRound!.options.firstWhere((o) => o.word == word);
    bool isCorrect = selectedOption.isCorrect;
    
    GameRound updatedRound = currentRound!.copyWith(
      selectedWord: word,
      isCorrect: isCorrect,
      answeredAt: DateTime.now(),
      timeSpent: _getRoundTimeSpent(),
    );

    List<GameRound> updatedRounds = List.from(_currentSession!.rounds);
    updatedRounds[_currentSession!.currentRoundIndex] = updatedRound;

    int newScore = _currentSession!.score + (isCorrect ? 10 : 0);

    _currentSession = _currentSession!.copyWith(
      rounds: updatedRounds,
      score: newScore,
    );

    _feedbackIsCorrect = isCorrect;
    _feedbackMessage = isCorrect 
        ? 'Correct! "$word" starts with /${currentRound!.soundSet.phoneme}/'
        : 'Not quite. "$word" doesn\'t start with /${currentRound!.soundSet.phoneme}/';
    
    _showFeedback = true;
    _stopRoundTimer();
    
    // Log game results
    _sessionLogging.logGameResults(
      score: newScore,
      roundsCompleted: _currentSession!.currentRoundIndex + 1,
      totalRounds: _currentSession!.totalRounds,
      difficultSounds: !isCorrect ? [currentRound!.soundSet.phoneme] : null,
    );
    
    // Log phoneme if incorrect
    if (!isCorrect) {
      _sessionLogging.logPhonemeError(currentRound!.soundSet.phoneme);
    }
    
    // Log confidence based on recent performance
    final recentAccuracy = _currentSession!.accuracyPercentage;
    final confidenceLevel = recentAccuracy > 0.8 ? 'high' : 
                          recentAccuracy > 0.6 ? 'medium' : 
                          recentAccuracy > 0.4 ? 'building' : 'low';
    _sessionLogging.logConfidenceLevel(confidenceLevel, reason: 'phonics_game_performance');
    
    notifyListeners();
  }

  Future<void> nextRound() async {
    if (!hasCurrentSession) return;

    _showFeedback = false;
    _selectedAnswer = null;

    if (_currentSession!.currentRoundIndex < _currentSession!.totalRounds - 1) {
      _currentSession = _currentSession!.copyWith(
        currentRoundIndex: _currentSession!.currentRoundIndex + 1,
      );
      _startRoundTimer();
      await _playCurrentSound();
    } else {
      await _completeGame();
    }
    notifyListeners();
  }

  Future<void> replaySound() async {
    if (currentRound == null) return;
    
    _isPlayingSound = true;
    notifyListeners();
    
    try {
      await _soundsService.playPhoneme(currentRound!.soundSet.phoneme);
    } catch (e) {
      _errorMessage = 'Failed to play sound: $e';
    } finally {
      _isPlayingSound = false;
      notifyListeners();
    }
  }

  Future<void> playWordPronunciation(String word) async {
    try {
      await _soundsService.playWord(word);
    } catch (e) {
      _errorMessage = 'Failed to play word pronunciation: $e';
      notifyListeners();
    }
  }

  Future<void> retryGame() async {
    if (!hasCurrentSession) return;
    
    int difficulty = int.parse(_currentSession!.difficulty);
    int rounds = _currentSession!.totalRounds;
    await startNewGame(rounds: rounds, difficulty: difficulty);
  }

  Future<void> startNextSoundSet() async {
    if (!hasCurrentSession) return;
    
    int currentDifficulty = int.parse(_currentSession!.difficulty);
    int nextDifficulty = currentDifficulty < 2 ? currentDifficulty + 1 : 1;
    
    await startNewGame(rounds: _sessionDuration, difficulty: nextDifficulty);
  }

  void setSessionDuration(int rounds) {
    _sessionDuration = rounds.clamp(5, 10);
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void pauseGame() {
    if (hasCurrentSession && !_currentSession!.isCompleted) {
      _currentSession = _currentSession!.copyWith(status: GameStatus.paused);
      _stopRoundTimer();
      notifyListeners();
    }
  }

  void resumeGame() {
    if (hasCurrentSession && _currentSession!.status == GameStatus.paused) {
      _currentSession = _currentSession!.copyWith(status: GameStatus.playing);
      _startRoundTimer();
      notifyListeners();
    }
  }

  Future<void> _playCurrentSound() async {
    if (currentRound == null) return;
    
    _isPlayingSound = true;
    notifyListeners();
    
    try {
      await _soundsService.playPhoneme(currentRound!.soundSet.phoneme);
    } catch (e) {
      _errorMessage = 'Failed to play sound: $e';
    } finally {
      _isPlayingSound = false;
      notifyListeners();
    }
  }

  Future<void> _completeGame() async {
    if (!hasCurrentSession) return;

    _currentSession = _currentSession!.copyWith(
      status: GameStatus.completed,
      endTime: DateTime.now(),
      totalTimeSpent: _getTotalGameTime(),
    );

    _stopRoundTimer();
    
    // Complete session logging
    await _sessionLogging.completeSession(
      finalAccuracy: _currentSession!.accuracyPercentage / 100,
      finalScore: _currentSession!.score.toDouble(),
      completionStatus: 'completed',
      additionalData: {
        'final_status': 'completed',
        'total_rounds': _currentSession!.totalRounds,
        'rounds_completed': _currentSession!.totalRounds,
        'correct_answers': _currentSession!.correctAnswers,
        'accuracy_percentage': _currentSession!.accuracyPercentage,
        'time_spent_seconds': _currentSession!.totalTimeSpent,
        'difficulty_level': _currentSession!.difficulty,
      },
    );
    
    notifyListeners();
  }

  void _startRoundTimer() {
    _roundStartTime = DateTime.now();
  }

  void _stopRoundTimer() {
    _gameTimer?.cancel();
    _roundStartTime = null;
  }

  int _getRoundTimeSpent() {
    if (_roundStartTime == null) return 0;
    return DateTime.now().difference(_roundStartTime!).inSeconds;
  }

  int _getTotalGameTime() {
    if (_currentSession == null) return 0;
    return DateTime.now().difference(_currentSession!.startTime).inSeconds;
  }

  @override
  void dispose() {
    // Cancel any active session logging
    if (_sessionLogging.hasActiveSession) {
      _sessionLogging.cancelSession(reason: 'phonics_game_disposed');
    }
    
    _gameTimer?.cancel();
    _soundsService.dispose();
    super.dispose();
  }
} 