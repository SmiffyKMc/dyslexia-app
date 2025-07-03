enum GameStatus { playing, completed, paused }

enum SoundType { consonant, vowel, blend, digraph }

class SoundSet {
  final String id;
  final String name;
  final String sound;
  final String phoneme;
  final SoundType type;
  final int difficulty;
  final List<WordOption> words;
  final String description;

  SoundSet({
    required this.id,
    required this.name,
    required this.sound,
    required this.phoneme,
    required this.type,
    required this.difficulty,
    required this.words,
    required this.description,
  });
}

class WordOption {
  final String word;
  final String imageUrl;
  final bool isCorrect;
  final String phoneme;

  WordOption({
    required this.word,
    required this.imageUrl,
    required this.isCorrect,
    required this.phoneme,
  });
}

class GameRound {
  final int roundNumber;
  final SoundSet soundSet;
  final List<WordOption> options;
  final String? selectedWord;
  final bool? isCorrect;
  final DateTime? answeredAt;
  final int timeSpent;

  GameRound({
    required this.roundNumber,
    required this.soundSet,
    required this.options,
    this.selectedWord,
    this.isCorrect,
    this.answeredAt,
    this.timeSpent = 0,
  });

  GameRound copyWith({
    int? roundNumber,
    SoundSet? soundSet,
    List<WordOption>? options,
    String? selectedWord,
    bool? isCorrect,
    DateTime? answeredAt,
    int? timeSpent,
  }) {
    return GameRound(
      roundNumber: roundNumber ?? this.roundNumber,
      soundSet: soundSet ?? this.soundSet,
      options: options ?? this.options,
      selectedWord: selectedWord ?? this.selectedWord,
      isCorrect: isCorrect ?? this.isCorrect,
      answeredAt: answeredAt ?? this.answeredAt,
      timeSpent: timeSpent ?? this.timeSpent,
    );
  }

  bool get isAnswered => selectedWord != null;
}

class PhonicsGameSession {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final GameStatus status;
  final int totalRounds;
  final int currentRoundIndex;
  final List<GameRound> rounds;
  final int score;
  final int totalTimeSpent;
  final String difficulty;

  PhonicsGameSession({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.status,
    required this.totalRounds,
    required this.currentRoundIndex,
    required this.rounds,
    required this.score,
    required this.totalTimeSpent,
    required this.difficulty,
  });

  PhonicsGameSession copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    GameStatus? status,
    int? totalRounds,
    int? currentRoundIndex,
    List<GameRound>? rounds,
    int? score,
    int? totalTimeSpent,
    String? difficulty,
  }) {
    return PhonicsGameSession(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      totalRounds: totalRounds ?? this.totalRounds,
      currentRoundIndex: currentRoundIndex ?? this.currentRoundIndex,
      rounds: rounds ?? this.rounds,
      score: score ?? this.score,
      totalTimeSpent: totalTimeSpent ?? this.totalTimeSpent,
      difficulty: difficulty ?? this.difficulty,
    );
  }

  bool get isCompleted => status == GameStatus.completed;
  bool get hasCurrentRound => currentRoundIndex < rounds.length;
  GameRound? get currentRound => hasCurrentRound ? rounds[currentRoundIndex] : null;
  int get correctAnswers => rounds.where((r) => r.isCorrect == true).length;
  int get answeredRounds => rounds.where((r) => r.isAnswered).length;
  double get accuracyPercentage => answeredRounds > 0 ? (correctAnswers / answeredRounds) * 100 : 0;
}

class GameStats {
  final int totalGamesPlayed;
  final int totalRoundsCompleted;
  final int totalCorrectAnswers;
  final double averageAccuracy;
  final int totalTimeSpent;
  final List<String> masteredSounds;
  final Map<String, int> soundProgress;

  GameStats({
    required this.totalGamesPlayed,
    required this.totalRoundsCompleted,
    required this.totalCorrectAnswers,
    required this.averageAccuracy,
    required this.totalTimeSpent,
    required this.masteredSounds,
    required this.soundProgress,
  });
} 