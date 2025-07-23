

import 'package:uuid/uuid.dart';

enum SessionType {
  readingCoach,
  adaptiveStory,
  phonicsGame,
  soundItOut,
  sentenceFixer,
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
      case SessionType.phonicsGame:
        final difficult = data['difficult_sounds'] as List<dynamic>? ?? [];
        errors.addAll(difficult.cast<String>());
        break;
      case SessionType.soundItOut:
        final phonemeErrors = data['phoneme_errors'] as List<dynamic>? ?? [];
        errors.addAll(phonemeErrors.cast<String>());
        break;
      case SessionType.sentenceFixer:
        final grammarErrors = data['grammar_errors'] as List<dynamic>? ?? [];
        errors.addAll(grammarErrors.cast<String>());
        break;
      case SessionType.adaptiveStory:
        final readingErrors = data['reading_errors'] as List<dynamic>? ?? [];
        errors.addAll(readingErrors.cast<String>());
        break;
    }
    
    return errors;
  }

  String get confidenceLevel {
    switch (sessionType) {
      case SessionType.readingCoach:
        final confidence = data['confidence_level'] as String? ?? 'medium';
        return confidence;
      case SessionType.adaptiveStory:
        final comprehension = data['comprehension_score'] as double? ?? 0.5;
        if (comprehension > 0.8) return 'high';
        if (comprehension > 0.6) return 'medium';
        return 'low';
      case SessionType.phonicsGame:
        final score = data['final_score'] as double? ?? 0.5;
        if (score > 0.8) return 'high';
        if (score > 0.6) return 'medium';
        return 'low';
      case SessionType.soundItOut:
        final accuracy = data['phoneme_accuracy'] as double? ?? 0.5;
        if (accuracy > 0.8) return 'high';
        if (accuracy > 0.6) return 'medium';
        return 'low';
      case SessionType.sentenceFixer:
        final accuracy = data['final_accuracy'] as double? ?? 0.5;
        if (accuracy > 0.8) return 'high';
        if (accuracy > 0.6) return 'medium';
        return 'low';
    }
  }

  double get engagementScore {
    switch (sessionType) {
      case SessionType.readingCoach:
        final wordsRead = data['words_read'] as int? ?? 0;
        final targetWords = data['target_words'] as int? ?? 1;
        return (wordsRead / targetWords).clamp(0.0, 1.0);
      case SessionType.adaptiveStory:
        final readingSpeed = data['reading_speed'] as double? ?? 100.0;
        return (readingSpeed / 150.0).clamp(0.0, 1.0);
      default:
        return 0.5;
    }
  }

  String get preferredStyleIndicator {

    if (sessionType == SessionType.soundItOut || sessionType == SessionType.phonicsGame) {
      return 'auditory';
    }
    if (sessionType == SessionType.readingCoach) {
      return 'kinesthetic';
    }
    
    final visualElements = data['used_visual_aids'] as bool? ?? false;
    final audioElements = data['used_audio_support'] as bool? ?? false;
    
    if (visualElements && audioElements) return 'multimodal';
    if (visualElements) return 'visual';
    if (audioElements) return 'auditory';

    return 'neutral';
  }

  String get summaryText {
    switch (sessionType) {
      case SessionType.readingCoach:
        final wordsRead = data['words_read'] as int? ?? 0;
        final accuracy = data['final_accuracy'] as double? ?? 0.0;
        final accuracyPercent = (accuracy * 100).round();
        
        if (wordsRead == 0) {
          return 'No words read';
        }
        
        return 'Read $wordsRead words with $accuracyPercent% accuracy';
      case SessionType.adaptiveStory:
        final questionsTotal = data['questions_total'] as int? ?? 0;
        final questionsCorrect = data['questions_correct'] as int? ?? 0;
        
        if (questionsTotal == 0) {
          return 'No questions answered';
        }
        
        final percentage = ((questionsCorrect / questionsTotal) * 100).round();
        return 'Answered $questionsCorrect/$questionsTotal questions ($percentage%)';
      case SessionType.phonicsGame:
        final score = data['final_score'] as double? ?? 0.0;
        final percentage = (score * 100).round();
        return 'Final score: $percentage%';
      case SessionType.soundItOut:
        final wordsAnalyzed = data['words_analyzed'] as int? ?? 0;
        return 'Analyzed $wordsAnalyzed phonetic patterns';
      case SessionType.sentenceFixer:
        final sentencesCompleted = data['sentences_completed'] as int? ?? 0;
        final accuracy = data['final_accuracy'] as double? ?? 0.0;
        final accuracyPercent = (accuracy * 100).round();
        return 'Fixed $sentencesCompleted sentences with $accuracyPercent% accuracy';
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
      final confidence = log.confidenceLevel;
      confidenceCounts[confidence] = (confidenceCounts[confidence] ?? 0) + 1;
    }
    
    if (confidenceCounts.isEmpty) return 'medium';
    
    return confidenceCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  double get averageEngagementScore {
    final engagementScores = logs.map((log) => log.engagementScore).toList();
    if (engagementScores.isEmpty) return 0.5;
    return engagementScores.reduce((a, b) => a + b) / engagementScores.length;
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