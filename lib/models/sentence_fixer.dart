import 'package:uuid/uuid.dart';

enum SentenceFixerStatus { playing, completed, paused }

enum ErrorType { spelling, grammar, homophone, punctuation, wordChoice }

class SentenceWithErrors {
  final String id;
  final List<String> words;
  final List<int> errorPositions;
  final List<String> corrections;
  final String difficulty;
  final List<ErrorType> errorTypes;
  final String? hint;
  final String category;

  SentenceWithErrors({
    String? id,
    required this.words,
    required this.errorPositions,
    required this.corrections,
    required this.difficulty,
    required this.errorTypes,
    this.hint,
    this.category = 'general',
  }) : id = id ?? const Uuid().v4();

  String get originalSentence => words.join(' ');
  
  String get correctedSentence {
    final correctedWords = List<String>.from(words);
    for (int i = 0; i < errorPositions.length; i++) {
      final position = errorPositions[i];
      if (position < correctedWords.length && i < corrections.length) {
        correctedWords[position] = corrections[i];
      }
    }
    return correctedWords.join(' ');
  }

  int get errorCount => errorPositions.length;
  
  bool hasErrorAt(int position) => errorPositions.contains(position);
  
  String? getCorrectionFor(int position) {
    final errorIndex = errorPositions.indexOf(position);
    if (errorIndex != -1 && errorIndex < corrections.length) {
      return corrections[errorIndex];
    }
    return null;
  }
}

class WordSelection {
  final int position;
  final String word;
  final bool isSelected;
  final bool isError;
  final String? correction;

  WordSelection({
    required this.position,
    required this.word,
    required this.isSelected,
    required this.isError,
    this.correction,
  });

  WordSelection copyWith({
    int? position,
    String? word,
    bool? isSelected,
    bool? isError,
    String? correction,
  }) {
    return WordSelection(
      position: position ?? this.position,
      word: word ?? this.word,
      isSelected: isSelected ?? this.isSelected,
      isError: isError ?? this.isError,
      correction: correction ?? this.correction,
    );
  }
}

class SentenceFixerFeedback {
  final List<int> correctSelections;
  final List<int> incorrectSelections;
  final List<int> missedErrors;
  final String correctedSentence;
  final double accuracy;
  final int score;
  final String message;
  final bool isSuccess;

  SentenceFixerFeedback({
    required this.correctSelections,
    required this.incorrectSelections,
    required this.missedErrors,
    required this.correctedSentence,
    required this.accuracy,
    required this.score,
    required this.message,
    required this.isSuccess,
  });

  int get totalSelections => correctSelections.length + incorrectSelections.length;
  int get totalErrors => correctSelections.length + missedErrors.length;
  bool get foundAllErrors => missedErrors.isEmpty;
  bool get noIncorrectSelections => incorrectSelections.isEmpty;
  bool get isPerfectScore => foundAllErrors && noIncorrectSelections;
}

class SentenceAttempt {
  final String sentenceId;
  final List<int> selectedPositions;
  final SentenceFixerFeedback feedback;
  final DateTime attemptTime;
  final int timeSpentSeconds;
  final bool isRetry;

  SentenceAttempt({
    required this.sentenceId,
    required this.selectedPositions,
    required this.feedback,
    DateTime? attemptTime,
    required this.timeSpentSeconds,
    this.isRetry = false,
  }) : attemptTime = attemptTime ?? DateTime.now();

  bool get isCorrect => feedback.isPerfectScore;
  int get score => feedback.score;
}

class SentenceFixerSession {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final SentenceFixerStatus status;
  final int totalSentences;
  final int currentSentenceIndex;
  final List<SentenceAttempt> attempts;
  final int totalScore;
  final int streak;
  final String difficulty;
  final List<SentenceWithErrors> sentences;

  SentenceFixerSession({
    String? id,
    DateTime? startTime,
    this.endTime,
    required this.status,
    required this.totalSentences,
    required this.currentSentenceIndex,
    required this.attempts,
    required this.totalScore,
    required this.streak,
    required this.difficulty,
    required this.sentences,
  })  : id = id ?? const Uuid().v4(),
        startTime = startTime ?? DateTime.now();

  SentenceFixerSession copyWith({
    DateTime? endTime,
    SentenceFixerStatus? status,
    int? currentSentenceIndex,
    List<SentenceAttempt>? attempts,
    int? totalScore,
    int? streak,
    List<SentenceWithErrors>? sentences,
  }) {
    return SentenceFixerSession(
      id: id,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      totalSentences: totalSentences,
      currentSentenceIndex: currentSentenceIndex ?? this.currentSentenceIndex,
      attempts: attempts ?? this.attempts,
      totalScore: totalScore ?? this.totalScore,
      streak: streak ?? this.streak,
      difficulty: difficulty,
      sentences: sentences ?? this.sentences,
    );
  }

  bool get isCompleted => status == SentenceFixerStatus.completed;
  bool get hasCurrentSentence => currentSentenceIndex < sentences.length;
  SentenceWithErrors? get currentSentence => hasCurrentSentence ? sentences[currentSentenceIndex] : null;
  
  int get completedSentences => attempts.length;
  int get correctSentences => attempts.where((a) => a.isCorrect).length;
  double get accuracyPercentage => attempts.isNotEmpty ? (correctSentences / attempts.length) * 100 : 0;
  
  Duration? get duration {
    if (endTime != null) {
      return endTime!.difference(startTime);
    }
    return null;
  }

  List<String> get errorPatterns {
    final patterns = <String>[];
    for (final sentence in sentences) {
      for (final errorType in sentence.errorTypes) {
        patterns.add(errorType.name);
      }
    }
    return patterns.toSet().toList();
  }

  Map<String, int> get errorTypeFrequency {
    final frequency = <String, int>{};
    for (final sentence in sentences) {
      for (final errorType in sentence.errorTypes) {
        frequency[errorType.name] = (frequency[errorType.name] ?? 0) + 1;
      }
    }
    return frequency;
  }

  List<String> get strugglingAreas {
    final areas = <String>[];
    final errorFreq = errorTypeFrequency;
    
    for (final entry in errorFreq.entries) {
      if (entry.value >= 2) {
        areas.add(entry.key);
      }
    }
    
    return areas;
  }
}

class SentenceFixerStats {
  final int totalSessionsPlayed;
  final int totalSentencesAttempted;
  final int totalSentencesCorrect;
  final double averageAccuracy;
  final int totalScore;
  final int bestStreak;
  final int totalTimeSpent;
  final Map<String, int> errorTypeStats;
  final List<String> masteredErrorTypes;

  SentenceFixerStats({
    required this.totalSessionsPlayed,
    required this.totalSentencesAttempted,
    required this.totalSentencesCorrect,
    required this.averageAccuracy,
    required this.totalScore,
    required this.bestStreak,
    required this.totalTimeSpent,
    required this.errorTypeStats,
    required this.masteredErrorTypes,
  });

  factory SentenceFixerStats.empty() {
    return SentenceFixerStats(
      totalSessionsPlayed: 0,
      totalSentencesAttempted: 0,
      totalSentencesCorrect: 0,
      averageAccuracy: 0.0,
      totalScore: 0,
      bestStreak: 0,
      totalTimeSpent: 0,
      errorTypeStats: {},
      masteredErrorTypes: [],
    );
  }

  SentenceFixerStats copyWith({
    int? totalSessionsPlayed,
    int? totalSentencesAttempted,
    int? totalSentencesCorrect,
    double? averageAccuracy,
    int? totalScore,
    int? bestStreak,
    int? totalTimeSpent,
    Map<String, int>? errorTypeStats,
    List<String>? masteredErrorTypes,
  }) {
    return SentenceFixerStats(
      totalSessionsPlayed: totalSessionsPlayed ?? this.totalSessionsPlayed,
      totalSentencesAttempted: totalSentencesAttempted ?? this.totalSentencesAttempted,
      totalSentencesCorrect: totalSentencesCorrect ?? this.totalSentencesCorrect,
      averageAccuracy: averageAccuracy ?? this.averageAccuracy,
      totalScore: totalScore ?? this.totalScore,
      bestStreak: bestStreak ?? this.bestStreak,
      totalTimeSpent: totalTimeSpent ?? this.totalTimeSpent,
      errorTypeStats: errorTypeStats ?? this.errorTypeStats,
      masteredErrorTypes: masteredErrorTypes ?? this.masteredErrorTypes,
    );
  }
} 