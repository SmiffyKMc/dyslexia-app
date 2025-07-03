import 'package:uuid/uuid.dart';

class ReadingSession {
  final String id;
  final String text;
  final DateTime startTime;
  final DateTime? endTime;
  final List<WordResult> wordResults;
  final ReadingSessionStatus status;
  final double? accuracyScore;

  ReadingSession({
    String? id,
    required this.text,
    DateTime? startTime,
    this.endTime,
    List<WordResult>? wordResults,
    this.status = ReadingSessionStatus.preparing,
    this.accuracyScore,
  })  : id = id ?? const Uuid().v4(),
        startTime = startTime ?? DateTime.now(),
        wordResults = wordResults ?? [];

  ReadingSession copyWith({
    String? text,
    DateTime? endTime,
    List<WordResult>? wordResults,
    ReadingSessionStatus? status,
    double? accuracyScore,
  }) {
    return ReadingSession(
      id: id,
      text: text ?? this.text,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      wordResults: wordResults ?? this.wordResults,
      status: status ?? this.status,
      accuracyScore: accuracyScore ?? this.accuracyScore,
    );
  }

  Duration? get duration {
    if (endTime != null) {
      return endTime!.difference(startTime);
    }
    return null;
  }

  List<String> get words => text.split(RegExp(r'\s+'));

  List<String> get mispronuncedWords {
    return wordResults
        .where((result) => !result.isCorrect)
        .map((result) => result.expectedWord)
        .toList();
  }

  int get correctWordsCount {
    return wordResults.where((result) => result.isCorrect).length;
  }

  double calculateAccuracy() {
    if (wordResults.isEmpty) return 0.0;
    return correctWordsCount / wordResults.length;
  }
}

class WordResult {
  final String expectedWord;
  final String? spokenWord;
  final bool isCorrect;
  final double confidence;
  final DateTime timestamp;

  WordResult({
    required this.expectedWord,
    this.spokenWord,
    required this.isCorrect,
    this.confidence = 0.0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

enum ReadingSessionStatus {
  preparing,
  reading,
  paused,
  completed,
  cancelled,
}

class PresetStory {
  final String id;
  final String title;
  final String content;
  final String difficulty;
  final List<String> tags;

  PresetStory({
    required this.id,
    required this.title,
    required this.content,
    required this.difficulty,
    this.tags = const [],
  });
} 