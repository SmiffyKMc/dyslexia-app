enum StoryDifficulty { beginner, intermediate, advanced }

enum QuestionType { fillInBlank, multipleChoice }

class Story {
  final String id;
  final String title;
  final String description;
  final StoryDifficulty difficulty;
  final List<StoryPart> parts;
  final List<String> learningPatterns;
  final String coverImage;

  const Story({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.parts,
    required this.learningPatterns,
    this.coverImage = '',
  });

  int get totalParts => parts.length;
  
  StoryPart? getPartByIndex(int index) {
    if (index >= 0 && index < parts.length) {
      return parts[index];
    }
    return null;
  }
}

class StoryPart {
  final String id;
  final int partNumber;
  final String content;
  final List<Question> questions;
  final String? illustration;

  const StoryPart({
    required this.id,
    required this.partNumber,
    required this.content,
    required this.questions,
    this.illustration,
  });

  bool get hasQuestions => questions.isNotEmpty;
  int get questionCount => questions.length;
  
  String getContentWithMaskedWords(Set<String> wordsToMask) {
    String maskedContent = content;
    
    for (final word in wordsToMask) {
      final wordPattern = RegExp(r'\b' + RegExp.escape(word) + r'\b', caseSensitive: false);
      maskedContent = maskedContent.replaceAll(wordPattern, '____');
    }
    
    return maskedContent;
  }
  
  List<String> getAllWordsInContent() {
    return content
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word.toLowerCase())
        .toList();
  }
}

class Question {
  final String id;
  final String sentence;
  final int blankPosition; // Position of the blank word in sentence
  final String correctAnswer;
  final List<String> options;
  final QuestionType type;
  final String? hint;
  final String pattern; // Learning pattern (e.g., "-ox", "ph", etc.)

  const Question({
    required this.id,
    required this.sentence,
    required this.blankPosition,
    required this.correctAnswer,
    required this.options,
    this.type = QuestionType.fillInBlank,
    this.hint,
    this.pattern = '',
  });

  List<String> get sentenceWords => sentence.split(' ');
  
  String get sentenceWithBlank {
    final words = sentenceWords;
    if (blankPosition >= 0 && blankPosition < words.length) {
      words[blankPosition] = '____';
    }
    return words.join(' ');
  }

  bool isCorrect(String answer) {
    return answer.toLowerCase().trim() == correctAnswer.toLowerCase().trim();
  }
  
  bool hasContextBleeding(StoryPart storyPart) {
    final contentWords = storyPart.getAllWordsInContent();
    
    for (final option in options) {
      if (option.toLowerCase() != correctAnswer.toLowerCase() && 
          contentWords.contains(option.toLowerCase())) {
        return true;
      }
    }
    
    return contentWords.contains(correctAnswer.toLowerCase());
  }
  
  Set<String> getWordsToMask(StoryPart storyPart) {
    final wordsToMask = <String>{};
    final contentWords = storyPart.getAllWordsInContent();
    
    // Only mask the correct answer if it appears in the story content
    if (contentWords.contains(correctAnswer.toLowerCase())) {
      wordsToMask.add(correctAnswer);
    }
    
    return wordsToMask;
  }
  
  QuestionQuality validateQuality(StoryPart storyPart) {
    final issues = <String>[];
    
    if (hasContextBleeding(storyPart)) {
      issues.add('Answer visible in story content');
    }
    
    if (options.length < 3) {
      issues.add('Too few answer options');
    }
    
    if (options.toSet().length != options.length) {
      issues.add('Duplicate answer options');
    }
    
    final similarOptions = <String>[];
    for (int i = 0; i < options.length; i++) {
      for (int j = i + 1; j < options.length; j++) {
        if (_areWordsSimilar(options[i], options[j])) {
          similarOptions.add('${options[i]} vs ${options[j]}');
        }
      }
    }
    
    if (similarOptions.isNotEmpty) {
      issues.add('Similar options: ${similarOptions.join(', ')}');
    }
    
    final difficulty = _assessDifficulty();
    
    return QuestionQuality(
      hasIssues: issues.isNotEmpty,
      issues: issues,
      difficulty: difficulty,
      educationalValue: issues.isEmpty ? 'Good' : 'Poor',
    );
  }
  
  bool _areWordsSimilar(String word1, String word2) {
    if (word1.length != word2.length) return false;
    
    int differences = 0;
    for (int i = 0; i < word1.length; i++) {
      if (word1[i] != word2[i]) differences++;
    }
    
    return differences <= 1;
  }
  
  String _assessDifficulty() {
    if (options.length >= 4 && pattern.isNotEmpty) return 'Challenging';
    if (options.length >= 3) return 'Moderate';
    return 'Easy';
  }
}

class UserAnswer {
  final String questionId;
  final String userAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final DateTime answeredAt;
  final int attemptsCount;

  const UserAnswer({
    required this.questionId,
    required this.userAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    required this.answeredAt,
    this.attemptsCount = 1,
  });

  UserAnswer copyWith({
    String? questionId,
    String? userAnswer,
    String? correctAnswer,
    bool? isCorrect,
    DateTime? answeredAt,
    int? attemptsCount,
  }) {
    return UserAnswer(
      questionId: questionId ?? this.questionId,
      userAnswer: userAnswer ?? this.userAnswer,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      isCorrect: isCorrect ?? this.isCorrect,
      answeredAt: answeredAt ?? this.answeredAt,
      attemptsCount: attemptsCount ?? this.attemptsCount,
    );
  }
}

class StoryProgress {
  final String storyId;
  final int currentPartIndex;
  final int currentQuestionIndex;
  final List<UserAnswer> answers;
  final DateTime startedAt;
  final DateTime? completedAt;
  final List<String> practicedWords;
  final Map<String, int> patternPracticeCount;

  const StoryProgress({
    required this.storyId,
    this.currentPartIndex = 0,
    this.currentQuestionIndex = 0,
    this.answers = const [],
    required this.startedAt,
    this.completedAt,
    this.practicedWords = const [],
    this.patternPracticeCount = const {},
  });

  StoryProgress copyWith({
    String? storyId,
    int? currentPartIndex,
    int? currentQuestionIndex,
    List<UserAnswer>? answers,
    DateTime? startedAt,
    DateTime? completedAt,
    List<String>? practicedWords,
    Map<String, int>? patternPracticeCount,
  }) {
    return StoryProgress(
      storyId: storyId ?? this.storyId,
      currentPartIndex: currentPartIndex ?? this.currentPartIndex,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      answers: answers ?? this.answers,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      practicedWords: practicedWords ?? this.practicedWords,
      patternPracticeCount: patternPracticeCount ?? this.patternPracticeCount,
    );
  }

  bool get isCompleted => completedAt != null;
  
  int get correctAnswersCount => answers.where((a) => a.isCorrect).length;
  
  int get totalAnswersCount => answers.length;
  
  double get accuracyPercentage {
    if (totalAnswersCount == 0) return 0.0;
    return (correctAnswersCount / totalAnswersCount) * 100;
  }

  List<String> get uniquePracticedWords => practicedWords.toSet().toList();
  
  List<String> get practicedPatterns => patternPracticeCount.keys.toList();
}

class QuestionQuality {
  final bool hasIssues;
  final List<String> issues;
  final String difficulty;
  final String educationalValue;

  const QuestionQuality({
    required this.hasIssues,
    required this.issues,
    required this.difficulty,
    required this.educationalValue,
  });

  @override
  String toString() {
    return 'QuestionQuality(hasIssues: $hasIssues, difficulty: $difficulty, issues: ${issues.join(", ")})';
  }
}

class LearningPattern {
  final String pattern;
  final String description;
  final List<String> examples;
  final int practiceCount;

  const LearningPattern({
    required this.pattern,
    required this.description,
    required this.examples,
    this.practiceCount = 0,
  });

  LearningPattern copyWith({
    String? pattern,
    String? description,
    List<String>? examples,
    int? practiceCount,
  }) {
    return LearningPattern(
      pattern: pattern ?? this.pattern,
      description: description ?? this.description,
      examples: examples ?? this.examples,
      practiceCount: practiceCount ?? this.practiceCount,
    );
  }
} 