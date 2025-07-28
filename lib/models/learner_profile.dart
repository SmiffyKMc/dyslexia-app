class LearnerProfile {
  final String phonologicalAwareness;
  final List<String> phonemeConfusions;
  final String decodingAccuracy;
  final String workingMemory;
  final String fluency;
  final String confidence;
  final String preferredStyle;
  final String focus;
  final String recommendedTool;
  final String advice;
  final DateTime lastUpdated;
  final int sessionCount;
  final int version;

  // Questionnaire fields
  final String? userName;
  final bool hasCompletedQuestionnaire;
  final List<String> selectedChallenges;
  final DateTime? questionnaireCompletedAt;

  const LearnerProfile({
    required this.phonologicalAwareness,
    required this.phonemeConfusions,
    required this.decodingAccuracy,
    required this.workingMemory,
    required this.fluency,
    required this.confidence,
    required this.preferredStyle,
    required this.focus,
    required this.recommendedTool,
    required this.advice,
    required this.lastUpdated,
    required this.sessionCount,
    this.version = 1,
    // Questionnaire fields
    this.userName,
    this.hasCompletedQuestionnaire = false,
    this.selectedChallenges = const [],
    this.questionnaireCompletedAt,
  });

  factory LearnerProfile.initial() {
    return LearnerProfile(
      phonologicalAwareness: 'developing',
      phonemeConfusions: const [],
      decodingAccuracy: 'developing',
      workingMemory: 'average',
      fluency: 'developing',
      confidence: 'building',
      preferredStyle: 'visual',
      focus: 'basic phonemes',
      recommendedTool: 'Reading Coach',
      advice: 'Complete a few sessions to get personalized recommendations!',
      lastUpdated: DateTime.now(),
      sessionCount: 0,
      version: 1,
      // Questionnaire fields
      userName: null,
      hasCompletedQuestionnaire: false,
      selectedChallenges: const [],
      questionnaireCompletedAt: null,
    );
  }

  LearnerProfile copyWith({
    String? phonologicalAwareness,
    List<String>? phonemeConfusions,
    String? decodingAccuracy,
    String? workingMemory,
    String? fluency,
    String? confidence,
    String? preferredStyle,
    String? focus,
    String? recommendedTool,
    String? advice,
    DateTime? lastUpdated,
    int? sessionCount,
    int? version,
    // Questionnaire fields
    String? userName,
    bool? hasCompletedQuestionnaire,
    List<String>? selectedChallenges,
    DateTime? questionnaireCompletedAt,
  }) {
    return LearnerProfile(
      phonologicalAwareness:
          phonologicalAwareness ?? this.phonologicalAwareness,
      phonemeConfusions: phonemeConfusions ?? this.phonemeConfusions,
      decodingAccuracy: decodingAccuracy ?? this.decodingAccuracy,
      workingMemory: workingMemory ?? this.workingMemory,
      fluency: fluency ?? this.fluency,
      confidence: confidence ?? this.confidence,
      preferredStyle: preferredStyle ?? this.preferredStyle,
      focus: focus ?? this.focus,
      recommendedTool: recommendedTool ?? this.recommendedTool,
      advice: advice ?? this.advice,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      sessionCount: sessionCount ?? this.sessionCount,
      version: version ?? this.version,
      // Questionnaire fields
      userName: userName ?? this.userName,
      hasCompletedQuestionnaire:
          hasCompletedQuestionnaire ?? this.hasCompletedQuestionnaire,
      selectedChallenges: selectedChallenges ?? this.selectedChallenges,
      questionnaireCompletedAt:
          questionnaireCompletedAt ?? this.questionnaireCompletedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phonologicalAwareness': phonologicalAwareness,
      'phonemeConfusions': phonemeConfusions,
      'decodingAccuracy': decodingAccuracy,
      'workingMemory': workingMemory,
      'fluency': fluency,
      'confidence': confidence,
      'preferredStyle': preferredStyle,
      'focus': focus,
      'recommendedTool': recommendedTool,
      'advice': advice,
      'lastUpdated': lastUpdated.toIso8601String(),
      'sessionCount': sessionCount,
      'version': version,
      // Questionnaire fields
      'userName': userName,
      'hasCompletedQuestionnaire': hasCompletedQuestionnaire,
      'selectedChallenges': selectedChallenges,
      'questionnaireCompletedAt': questionnaireCompletedAt?.toIso8601String(),
    };
  }

  factory LearnerProfile.fromJson(Map<String, dynamic> json) {
    return LearnerProfile(
      phonologicalAwareness: json['phonologicalAwareness'] as String,
      phonemeConfusions: List<String>.from(json['phonemeConfusions'] as List),
      decodingAccuracy: json['decodingAccuracy'] as String,
      workingMemory: json['workingMemory'] as String,
      fluency: json['fluency'] as String,
      confidence: json['confidence'] as String,
      preferredStyle: json['preferredStyle'] as String,
      focus: json['focus'] as String,
      recommendedTool: json['recommendedTool'] as String,
      advice: json['advice'] as String,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      sessionCount: json['sessionCount'] as int,
      version: json['version'] as int? ?? 1,
      // Questionnaire fields
      userName: json['userName'] as String?,
      hasCompletedQuestionnaire:
          json['hasCompletedQuestionnaire'] as bool? ?? false,
      selectedChallenges: json['selectedChallenges'] != null
          ? List<String>.from(json['selectedChallenges'] as List)
          : const [],
      questionnaireCompletedAt: json['questionnaireCompletedAt'] != null
          ? DateTime.parse(json['questionnaireCompletedAt'] as String)
          : null,
    );
  }

  bool get isInitial => sessionCount == 0;

  bool get needsUpdate =>
      sessionCount > 0 && DateTime.now().difference(lastUpdated).inDays > 7;

  String get confidenceLevel {
    switch (confidence.toLowerCase()) {
      case 'high':
        return '🔥 High';
      case 'medium':
        return '⚡ Medium';
      case 'building':
        return '🌱 Building';
      case 'low':
        return '💪 Growing';
      default:
        return '🌟 $confidence';
    }
  }

  String get accuracyLevel {
    switch (decodingAccuracy.toLowerCase()) {
      case 'excellent':
        return '🎯 Excellent';
      case 'good':
        return '✅ Good';
      case 'developing':
        return '📈 Developing';
      case 'needs work':
        return '🎯 Needs Work';
      default:
        return '📊 $decodingAccuracy';
    }
  }

  List<String> get strengthAreas {
    final strengths = <String>[];
    if (confidence == 'high') strengths.add('High Confidence');
    if (decodingAccuracy == 'excellent' || decodingAccuracy == 'good') {
      strengths.add('Strong Decoding');
    }
    if (fluency == 'excellent' || fluency == 'good') {
      strengths.add('Good Fluency');
    }
    if (workingMemory == 'above average' || workingMemory == 'excellent') {
      strengths.add('Strong Memory');
    }
    if (phonologicalAwareness == 'excellent' ||
        phonologicalAwareness == 'good') {
      strengths.add('Phonics Skills');
    }
    return strengths;
  }

  List<String> get improvementAreas {
    final improvements = <String>[];
    if (confidence == 'low' || confidence == 'building') {
      improvements.add('Building Confidence');
    }
    if (decodingAccuracy == 'developing' || decodingAccuracy == 'needs work') {
      improvements.add('Decoding Practice');
    }
    if (fluency == 'developing' || fluency == 'needs work') {
      improvements.add('Reading Fluency');
    }
    if (phonemeConfusions.isNotEmpty) {
      improvements.add('Phoneme Recognition');
    }
    return improvements;
  }

  @override
  String toString() {
    return 'LearnerProfile(confidence: $confidence, accuracy: $decodingAccuracy, '
        'focus: $focus, tool: $recommendedTool, sessions: $sessionCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LearnerProfile &&
        other.version == version &&
        other.sessionCount == sessionCount &&
        other.lastUpdated == lastUpdated;
  }

  @override
  int get hashCode =>
      version.hashCode ^ sessionCount.hashCode ^ lastUpdated.hashCode;
}
