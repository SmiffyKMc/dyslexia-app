import 'package:uuid/uuid.dart';

enum SessionType {
  readingCoach,
  wordDoctor,
  adaptiveStory,
  phonicsGame,
  textSimplifier,
  soundItOut,
  buildSentence,
  readAloud,
  soundFocusGame,
  visualDictionary,
  wordConfusion,
  thoughtToWord,
}

class SessionLog {
  final String id;
  final SessionType sessionType;
  final String feature;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final Duration duration;
  final double? accuracy;
  final int? score;
  final Map<String, dynamic> metadata;

  SessionLog({
    String? id,
    required this.sessionType,
    required this.feature,
    required this.data,
    DateTime? timestamp,
    required this.duration,
    this.accuracy,
    this.score,
    Map<String, dynamic>? metadata,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now(),
        metadata = metadata ?? {};

  SessionLog copyWith({
    String? id,
    SessionType? sessionType,
    String? feature,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    Duration? duration,
    double? accuracy,
    int? score,
    Map<String, dynamic>? metadata,
  }) {
    return SessionLog(
      id: id ?? this.id,
      sessionType: sessionType ?? this.sessionType,
      feature: feature ?? this.feature,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      duration: duration ?? this.duration,
      accuracy: accuracy ?? this.accuracy,
      score: score ?? this.score,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionType': sessionType.name,
      'feature': feature,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'duration': duration.inMilliseconds,
      'accuracy': accuracy,
      'score': score,
      'metadata': metadata,
    };
  }

  factory SessionLog.fromJson(Map<String, dynamic> json) {
    return SessionLog(
      id: json['id'] as String,
      sessionType: SessionType.values.byName(json['sessionType'] as String),
      feature: json['feature'] as String,
      data: Map<String, dynamic>.from(json['data'] as Map),
      timestamp: DateTime.parse(json['timestamp'] as String),
      duration: Duration(milliseconds: json['duration'] as int),
      accuracy: json['accuracy'] as double?,
      score: json['score'] as int?,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }

  List<String> get phonemeErrors {
    final errors = <String>[];
    
    switch (sessionType) {
      case SessionType.readingCoach:
        final mispronounced = data['mispronounced_phonemes'] as List<dynamic>? ?? [];
        errors.addAll(mispronounced.cast<String>());
        break;
      case SessionType.wordDoctor:
        final phonemeErrors = data['phoneme_errors'] as List<dynamic>? ?? [];
        errors.addAll(phonemeErrors.cast<String>());
        break;
      case SessionType.phonicsGame:
        final difficult = data['difficult_sounds'] as List<dynamic>? ?? [];
        errors.addAll(difficult.cast<String>());
        break;
      case SessionType.adaptiveStory:
        final mistakes = data['phoneme_mistakes'] as List<dynamic>? ?? [];
        errors.addAll(mistakes.cast<String>());
        break;
      default:
        break;
    }
    
    return errors;
  }

  String get confidenceIndicator {
    switch (sessionType) {
      case SessionType.readingCoach:
        final confidence = data['confidence_level'] as String? ?? 'medium';
        return confidence;
      case SessionType.wordDoctor:
        final completionRate = data['completion_rate'] as double? ?? 0.5;
        if (completionRate > 0.8) return 'high';
        if (completionRate > 0.6) return 'medium';
        return 'low';
      case SessionType.adaptiveStory:
        final comprehension = data['comprehension_score'] as double? ?? 0.5;
        if (comprehension > 0.8) return 'high';
        if (comprehension > 0.6) return 'medium';
        return 'low';
      case SessionType.phonicsGame:
        final gameAccuracy = accuracy ?? 0.5;
        if (gameAccuracy > 0.8) return 'high';
        if (gameAccuracy > 0.6) return 'medium';
        return 'low';
      default:
        return 'medium';
    }
  }

  double get fluencyScore {
    switch (sessionType) {
      case SessionType.readingCoach:
        final wordsPerMinute = data['words_per_minute'] as double? ?? 100.0;
        return (wordsPerMinute / 150.0).clamp(0.0, 1.0);
      case SessionType.adaptiveStory:
        final readingSpeed = data['reading_speed'] as double? ?? 100.0;
        return (readingSpeed / 150.0).clamp(0.0, 1.0);
      case SessionType.readAloud:
        final speed = data['reading_speed'] as double? ?? 100.0;
        return (speed / 150.0).clamp(0.0, 1.0);
      default:
        return 0.5;
    }
  }

  String get preferredStyleIndicator {
    if (sessionType == SessionType.visualDictionary) return 'visual';
    if (sessionType == SessionType.soundItOut || sessionType == SessionType.phonicsGame) {
      return 'auditory';
    }
    if (sessionType == SessionType.readingCoach || sessionType == SessionType.readAloud) {
      return 'kinesthetic';
    }
    
    final visualElements = data['used_visual_aids'] as bool? ?? false;
    final audioElements = data['used_audio_support'] as bool? ?? false;
    
    if (visualElements && audioElements) return 'multimodal';
    if (visualElements) return 'visual';
    if (audioElements) return 'auditory';
    return 'visual';
  }

  bool get isCompleted {
    return data['status'] == 'completed' || 
           data['completion_rate'] != null ||
           accuracy != null;
  }

  String get sessionDescription {
    switch (sessionType) {
      case SessionType.readingCoach:
        final wordsRead = data['words_read'] as int? ?? 0;
        final accuracyPercent = ((accuracy ?? 0.0) * 100).round();
        
        // Debug logging for session description
        if (wordsRead == 0 || accuracyPercent == 0) {
          print('🐛 SessionDescription Debug: words_read=$wordsRead, accuracy=$accuracy, data keys=${data.keys}');
        }
        
        return 'Read $wordsRead words with $accuracyPercent% accuracy';
      case SessionType.wordDoctor:
        final wordsAnalyzed = data['words_analyzed'] as int? ?? 0;
        return 'Analyzed $wordsAnalyzed words';
      case SessionType.adaptiveStory:
        final questionsAnswered = data['questions_answered'] as int? ?? 0;
        return 'Answered $questionsAnswered story questions';
      case SessionType.phonicsGame:
        final roundsCompleted = data['rounds_completed'] as int? ?? 0;
        return 'Completed $roundsCompleted phonics rounds';
      default:
        return 'Completed ${feature.toLowerCase()} session';
    }
  }

  @override
  String toString() {
    return 'SessionLog(type: $sessionType, accuracy: $accuracy, '
           'duration: ${duration.inMinutes}min, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionLog && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class SessionLogSummary {
  final List<SessionLog> logs;
  final DateTime startDate;
  final DateTime endDate;

  SessionLogSummary({
    required this.logs,
    required this.startDate,
    required this.endDate,
  });

  double get averageAccuracy {
    final accuracies = logs
        .where((log) => log.accuracy != null)
        .map((log) => log.accuracy!)
        .toList();
    
    if (accuracies.isEmpty) return 0.0;
    return accuracies.reduce((a, b) => a + b) / accuracies.length;
  }

  Duration get totalDuration {
    return logs.fold(Duration.zero, (total, log) => total + log.duration);
  }

  List<String> get allPhonemeErrors {
    final errors = <String>{};
    for (final log in logs) {
      errors.addAll(log.phonemeErrors);
    }
    return errors.toList();
  }

  Map<String, int> get phonemeErrorFrequency {
    final frequency = <String, int>{};
    for (final log in logs) {
      for (final error in log.phonemeErrors) {
        frequency[error] = (frequency[error] ?? 0) + 1;
      }
    }
    return frequency;
  }

  String get dominantConfidenceLevel {
    final confidenceCounts = <String, int>{};
    for (final log in logs) {
      final confidence = log.confidenceIndicator;
      confidenceCounts[confidence] = (confidenceCounts[confidence] ?? 0) + 1;
    }
    
    if (confidenceCounts.isEmpty) return 'medium';
    
    return confidenceCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  double get averageFluencyScore {
    final fluencyScores = logs.map((log) => log.fluencyScore).toList();
    if (fluencyScores.isEmpty) return 0.5;
    return fluencyScores.reduce((a, b) => a + b) / fluencyScores.length;
  }

  String get preferredLearningStyle {
    final styleCounts = <String, int>{};
    for (final log in logs) {
      final style = log.preferredStyleIndicator;
      styleCounts[style] = (styleCounts[style] ?? 0) + 1;
    }
    
    if (styleCounts.isEmpty) return 'visual';
    
    return styleCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  List<SessionType> get mostUsedTools {
    final toolCounts = <SessionType, int>{};
    for (final log in logs) {
      toolCounts[log.sessionType] = (toolCounts[log.sessionType] ?? 0) + 1;
    }
    
    final sortedTools = toolCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedTools.map((entry) => entry.key).take(3).toList();
  }

  @override
  String toString() {
    return 'SessionLogSummary(logs: ${logs.length}, accuracy: ${(averageAccuracy * 100).round()}%, '
           'duration: ${totalDuration.inMinutes}min)';
  }
} 