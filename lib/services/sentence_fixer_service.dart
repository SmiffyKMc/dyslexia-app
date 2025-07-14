import 'dart:convert';
import 'dart:math';
import 'dart:developer' as developer;
import '../models/sentence_fixer.dart';
import '../models/learner_profile.dart';
import '../utils/service_locator.dart';

class SentenceFixerService {
  final Random _random = Random();
  
  static final List<SentenceWithErrors> _predefinedSentences = [
    // Beginner - Spelling errors
    SentenceWithErrors(
      words: ['The', 'dog', 'is', 'runing', 'in', 'the', 'park'],
      errorPositions: [3],
      corrections: ['running'],
      difficulty: 'beginner',
      errorTypes: [ErrorType.spelling],
      hint: 'Double the consonant before adding -ing',
      category: 'spelling_rules',
    ),
    SentenceWithErrors(
      words: ['She', 'is', 'very', 'hapy', 'today'],
      errorPositions: [3],
      corrections: ['happy'],
      difficulty: 'beginner',
      errorTypes: [ErrorType.spelling],
      hint: 'Double the consonant before adding -y',
      category: 'spelling_rules',
    ),
    SentenceWithErrors(
      words: ['Alot', 'of', 'people', 'make', 'this', 'mistake'],
      errorPositions: [0],
      corrections: ['A lot'],
      difficulty: 'beginner',
      errorTypes: [ErrorType.spelling],
      hint: 'Two separate words',
      category: 'common_mistakes',
    ),
    SentenceWithErrors(
      words: ['I', 'like', 'to', 'wriet', 'stories'],
      errorPositions: [3],
      corrections: ['write'],
      difficulty: 'beginner',
      errorTypes: [ErrorType.spelling],
      hint: 'I before E',
      category: 'spelling_rules',
    ),
    SentenceWithErrors(
      words: ['The', 'cat', 'is', 'siting', 'on', 'the', 'chair'],
      errorPositions: [3],
      corrections: ['sitting'],
      difficulty: 'beginner',
      errorTypes: [ErrorType.spelling],
      hint: 'Double the T',
      category: 'spelling_rules',
    ),
    SentenceWithErrors(
      words: ['My', 'freind', 'is', 'coming', 'over'],
      errorPositions: [1],
      corrections: ['friend'],
      difficulty: 'beginner',
      errorTypes: [ErrorType.spelling],
      hint: 'I before E except after C',
      category: 'spelling_rules',
    ),
    
    // Intermediate - Mixed errors
    SentenceWithErrors(
      words: ['I', 'recieved', 'a', 'letter', 'yesterday'],
      errorPositions: [1],
      corrections: ['received'],
      difficulty: 'intermediate',
      errorTypes: [ErrorType.spelling],
      hint: 'I before E except after C',
      category: 'spelling_rules',
    ),
    SentenceWithErrors(
      words: ['He', 'dont', 'like', 'vegetables'],
      errorPositions: [1],
      corrections: ['doesn\'t'],
      difficulty: 'intermediate',
      errorTypes: [ErrorType.grammar],
      hint: 'Use proper contraction',
      category: 'contractions',
    ),
    SentenceWithErrors(
      words: ['I', 'loose', 'my', 'keys', 'to', 'often'],
      errorPositions: [1, 5],
      corrections: ['lose', 'too'],
      difficulty: 'intermediate',
      errorTypes: [ErrorType.homophone, ErrorType.homophone],
      hint: 'Check loose/lose and to/too',
      category: 'homophones',
    ),
    SentenceWithErrors(
      words: ['I', 'could', 'of', 'done', 'better'],
      errorPositions: [2],
      corrections: ['have'],
      difficulty: 'intermediate',
      errorTypes: [ErrorType.wordChoice],
      hint: 'Could have, not could of',
      category: 'common_mistakes',
    ),
    SentenceWithErrors(
      words: ['Its', 'raining', 'and', 'I', 'forgot', 'my', 'umbrela'],
      errorPositions: [0, 6],
      corrections: ['It\'s', 'umbrella'],
      difficulty: 'intermediate',
      errorTypes: [ErrorType.grammar, ErrorType.spelling],
      hint: 'Contraction and double letter',
      category: 'mixed_errors',
    ),
    SentenceWithErrors(
      words: ['Their', 'going', 'to', 'the', 'store'],
      errorPositions: [0],
      corrections: ['They\'re'],
      difficulty: 'intermediate',
      errorTypes: [ErrorType.homophone],
      hint: 'They are going = They\'re',
      category: 'homophones',
    ),
    SentenceWithErrors(
      words: ['I', 'seen', 'that', 'movie', 'yesterday'],
      errorPositions: [1],
      corrections: ['saw'],
      difficulty: 'intermediate',
      errorTypes: [ErrorType.grammar],
      hint: 'Past tense of see is saw',
      category: 'verb_tenses',
    ),
    
    // Advanced - Complex errors
    SentenceWithErrors(
      words: ['Me', 'and', 'my', 'friend', 'went', 'shopping'],
      errorPositions: [0, 1],
      corrections: ['My', 'friend'],
      difficulty: 'advanced',
      errorTypes: [ErrorType.grammar],
      hint: 'Use proper subject pronouns',
      category: 'pronouns',
    ),
    SentenceWithErrors(
      words: ['Their', 'going', 'to', 'there', 'house', 'over', 'their'],
      errorPositions: [0, 2, 6],
      corrections: ['They\'re', 'too', 'there'],
      difficulty: 'advanced',
      errorTypes: [ErrorType.homophone, ErrorType.homophone, ErrorType.homophone],
      hint: 'Three different there/their/they\'re uses',
      category: 'homophones',
    ),
    SentenceWithErrors(
      words: ['Who\'s', 'car', 'is', 'parked', 'outside'],
      errorPositions: [0],
      corrections: ['Whose'],
      difficulty: 'advanced',
      errorTypes: [ErrorType.homophone],
      hint: 'Whose shows possession',
      category: 'homophones',
    ),
  ];

  Future<List<SentenceWithErrors>> generateSentencePack({
    required String difficulty,
    required int count,
    LearnerProfile? profile,
  }) async {
    developer.log('🎯 Generating sentence pack: difficulty=$difficulty, count=$count', 
        name: 'dyslexic_ai.sentence_fixer');
    
    // Start with predefined sentences matching difficulty
    final availableSentences = _predefinedSentences
        .where((sentence) => sentence.difficulty == difficulty)
        .toList();
    
    developer.log('📚 Available predefined sentences for $difficulty: ${availableSentences.length}', 
        name: 'dyslexic_ai.sentence_fixer');
    
    final selectedSentences = <SentenceWithErrors>[];
    
    // Add shuffled predefined sentences
    final shuffled = List<SentenceWithErrors>.from(availableSentences);
    shuffled.shuffle(_random);
    
    for (int i = 0; i < count && i < shuffled.length; i++) {
      selectedSentences.add(shuffled[i]);
      developer.log('➕ Added predefined sentence ${i + 1}: "${shuffled[i].words.join(' ')}"', 
          name: 'dyslexic_ai.sentence_fixer');
    }
    
    // If we need more sentences, try AI generation
    if (selectedSentences.length < count && profile != null) {
      developer.log('🤖 Need ${count - selectedSentences.length} more sentences, trying AI generation...', 
          name: 'dyslexic_ai.sentence_fixer');
      try {
        final aiSentences = await _generateAISentences(
          difficulty: difficulty,
          count: count - selectedSentences.length,
          profile: profile,
        );
        developer.log('✅ AI generated ${aiSentences.length} sentences', 
            name: 'dyslexic_ai.sentence_fixer');
        for (int i = 0; i < aiSentences.length; i++) {
          developer.log('🤖 AI sentence ${i + 1}: "${aiSentences[i].words.join(' ')}"', 
              name: 'dyslexic_ai.sentence_fixer');
        }
        selectedSentences.addAll(aiSentences);
      } catch (e) {
        developer.log('❌ AI sentence generation failed: $e', 
            name: 'dyslexic_ai.sentence_fixer');
      }
    }
    
    // Fill with random predefined sentences if still short
    while (selectedSentences.length < count) {
      final randomSentence = _predefinedSentences[_random.nextInt(_predefinedSentences.length)];
      if (!selectedSentences.any((s) => s.id == randomSentence.id)) {
        selectedSentences.add(randomSentence);
        developer.log('🔄 Added random predefined sentence: "${randomSentence.words.join(' ')}"', 
            name: 'dyslexic_ai.sentence_fixer');
      }
    }
    
    developer.log('📋 Final sentence pack: ${selectedSentences.length} sentences total', 
        name: 'dyslexic_ai.sentence_fixer');
    for (int i = 0; i < selectedSentences.length; i++) {
      developer.log('📝 Sentence ${i + 1}: "${selectedSentences[i].words.join(' ')}" (errors at positions: ${selectedSentences[i].errorPositions})', 
          name: 'dyslexic_ai.sentence_fixer');
    }
    
    return selectedSentences.take(count).toList();
  }

  Future<List<SentenceWithErrors>> _generateAISentences({
    required String difficulty,
    required int count,
    required LearnerProfile profile,
  }) async {
    final aiService = getAIInferenceService();
    if (aiService == null) {
      developer.log('🚫 AI service not available for sentence generation', 
          name: 'dyslexic_ai.sentence_fixer');
      return [];
    }
    
    // Try up to 3 times to get valid sentences
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final prompt = _buildSentenceGenerationPrompt(difficulty, count, profile, attempt: attempt);
        developer.log('📝 AI generation attempt $attempt: $prompt', 
            name: 'dyslexic_ai.sentence_fixer');
        
        final response = await aiService.generateResponse(prompt);
        developer.log('🤖 AI response received (${response.length} chars): $response', 
            name: 'dyslexic_ai.sentence_fixer');
        
        final sentences = _parseAISentenceResponse(response, difficulty);
        
        if (sentences.isNotEmpty) {
          developer.log('✅ AI generated ${sentences.length} validated sentences on attempt $attempt', 
              name: 'dyslexic_ai.sentence_fixer');
          return sentences;
        }
        
        developer.log('⚠️ AI attempt $attempt generated no valid sentences, retrying...', 
            name: 'dyslexic_ai.sentence_fixer');
        
      } catch (e) {
        developer.log('❌ AI sentence generation error on attempt $attempt: $e', 
            name: 'dyslexic_ai.sentence_fixer');
        
        if (attempt == 3) {
          // Last attempt failed, return empty list
          return [];
        }
      }
    }
    
    return [];
  }

  String _buildSentenceGenerationPrompt(String difficulty, int count, LearnerProfile profile, {int attempt = 1}) {
    final errorFocus = profile.phonemeConfusions.isNotEmpty 
        ? profile.phonemeConfusions.take(2).join(', ')
        : 'common spelling errors';
    
    String attemptInstructions = '';
    if (attempt > 1) {
      attemptInstructions = '''
      
⚠️ RETRY ATTEMPT $attempt: Previous attempts failed validation. Be extra careful with:
- Verifying error positions point to actual mistakes
- Ensuring corrections match the words they're fixing
- Double-checking that marked errors are actually wrong
''';
    }
    
    return '''
Create $count sentences for sentence error detection practice, $difficulty level.

CRITICAL: You must SELF-VALIDATE each sentence before returning it.$attemptInstructions

STEP 1 - Generate sentences with intentional errors:
- Create NORMAL sentences with 1-2 intentional errors
- Each sentence must make sense when read aloud
- Errors should be realistic mistakes people make
- Keep sentences 5-8 words long
- Focus on errors related to: $errorFocus

STEP 2 - SELF-VALIDATE each sentence:
For each sentence, ask yourself:
1. "Does the word at errorPosition actually contain an error?"
2. "Is my correction valid for that specific word?"
3. "Would a human recognize this as a mistake?"

SELF-VALIDATION EXAMPLES:

❌ INVALID: "He didnt finish his work" with errorPositions: [3] and corrections: ["didn't"]
WHY INVALID: Position 3 is "his" - that's correct! The error is at position 1 "didnt"
✅ CORRECTED: "He didnt finish his work" with errorPositions: [1] and corrections: ["didn't"]

❌ INVALID: "Their dog ran fast" with errorPositions: [0] and corrections: ["They're"] 
WHY INVALID: "Their" is correct possessive form here
✅ ALTERNATIVE: "Thier dog ran fast" with errorPositions: [0] and corrections: ["Their"]

❌ INVALID: "I am going to school" with errorPositions: [1] and corrections: ["was"]
WHY INVALID: "am" is grammatically correct here
✅ ALTERNATIVE: "I seen the movie" with errorPositions: [1] and corrections: ["saw"]

VALIDATION PROCESS:
1. Generate sentence
2. Check: Is the word at errorPosition actually wrong?
3. Check: Does the correction fix that specific word?
4. If validation fails, regenerate the sentence
5. Only return sentences that pass validation

RESPONSE FORMAT:
Return a JSON array where each sentence has been self-validated:

[
  {
    "words": ["word1", "word2", "error_word", "word4"],
    "errorPositions": [2],
    "corrections": ["correct_word"],
    "errorTypes": ["spelling"],
    "hint": "explanation of the error",
    "category": "error_type",
    "validation_passed": true
  }
]

Now create $count sentences, self-validate each one, and return only those that pass validation:''';
  }

  List<SentenceWithErrors> _parseAISentenceResponse(String response, String difficulty) {
    try {
      developer.log('🔍 Parsing AI sentence response...', name: 'dyslexic_ai.sentence_fixer');
      
      // Extract JSON from response - try multiple patterns
      String? jsonString;
      
      // Try extracting from markdown code block
      final codeBlockMatch = RegExp(r'```(?:json)?\s*\n(.*?)\n\s*```', dotAll: true).firstMatch(response);
      if (codeBlockMatch != null) {
        jsonString = codeBlockMatch.group(1)?.trim();
        developer.log('📦 Found JSON in code block: $jsonString', name: 'dyslexic_ai.sentence_fixer');
      }
      
      // Try extracting JSON array directly
      if (jsonString == null) {
        final jsonMatch = RegExp(r'\[.*\]', dotAll: true).firstMatch(response);
        if (jsonMatch != null) {
          jsonString = jsonMatch.group(0)?.trim();
          developer.log('📦 Found JSON array: $jsonString', name: 'dyslexic_ai.sentence_fixer');
        }
      }
      
      if (jsonString == null) {
        developer.log('❌ No JSON found in AI response', name: 'dyslexic_ai.sentence_fixer');
        return [];
      }
      
      // Parse JSON
      final jsonData = json.decode(jsonString);
      if (jsonData is! List) {
        developer.log('❌ JSON is not an array: ${jsonData.runtimeType}', name: 'dyslexic_ai.sentence_fixer');
        return [];
      }
      
      developer.log('✅ Parsed JSON array with ${jsonData.length} items', name: 'dyslexic_ai.sentence_fixer');
      
      // Convert to SentenceWithErrors objects
      final sentences = <SentenceWithErrors>[];
      for (int i = 0; i < jsonData.length; i++) {
        final item = jsonData[i];
        developer.log('🔄 Processing item $i: $item', name: 'dyslexic_ai.sentence_fixer');
        
        if (item is! Map<String, dynamic>) {
          developer.log('⚠️ Item $i is not a map, skipping', name: 'dyslexic_ai.sentence_fixer');
          continue;
        }
        
        try {
          final sentence = _createSentenceFromAIData(item, difficulty, i);
          if (sentence != null) {
            sentences.add(sentence);
            developer.log('✅ Created sentence: "${sentence.words.join(' ')}"', name: 'dyslexic_ai.sentence_fixer');
          } else {
            developer.log('⚠️ Failed to create sentence from item $i', name: 'dyslexic_ai.sentence_fixer');
          }
        } catch (e) {
          developer.log('❌ Error creating sentence from item $i: $e', name: 'dyslexic_ai.sentence_fixer');
        }
      }
      
      developer.log('📋 Successfully parsed ${sentences.length} sentences from AI response', name: 'dyslexic_ai.sentence_fixer');
      return sentences;
      
    } catch (e) {
      developer.log('❌ Error parsing AI sentence response: $e', name: 'dyslexic_ai.sentence_fixer');
      return [];
    }
  }
  
  SentenceWithErrors? _createSentenceFromAIData(Map<String, dynamic> data, String difficulty, int index) {
    try {
      // Check if AI marked this as validated
      final validationPassed = data['validation_passed'] as bool? ?? false;
      if (!validationPassed) {
        developer.log('❌ AI marked sentence as failed validation: $data', name: 'dyslexic_ai.sentence_fixer');
        return null;
      }
      
      // Validate required fields
      if (!data.containsKey('words') || !data.containsKey('errorPositions')) {
        developer.log('❌ Missing required fields in AI data: $data', name: 'dyslexic_ai.sentence_fixer');
        return null;
      }
      
      // Extract words
      final wordsData = data['words'];
      if (wordsData is! List) {
        developer.log('❌ Words is not a list: $wordsData', name: 'dyslexic_ai.sentence_fixer');
        return null;
      }
      final words = wordsData.cast<String>();
      
      // Basic validation (keep minimal checks)
      if (words.length < 3 || words.length > 12) {
        developer.log('❌ Invalid sentence length: ${words.length}', name: 'dyslexic_ai.sentence_fixer');
        return null;
      }
      
      // Extract error positions
      final errorPositionsData = data['errorPositions'];
      if (errorPositionsData is! List) {
        developer.log('❌ ErrorPositions is not a list: $errorPositionsData', name: 'dyslexic_ai.sentence_fixer');
        return null;
      }
      final errorPositions = errorPositionsData.cast<int>();
      
      // Basic bounds check
      for (final position in errorPositions) {
        if (position < 0 || position >= words.length) {
          developer.log('❌ Error position out of bounds: $position for ${words.length} words', name: 'dyslexic_ai.sentence_fixer');
          return null;
        }
      }
      
      // Extract corrections (optional)
      final corrections = data['corrections'] is List 
          ? (data['corrections'] as List).cast<String>()
          : <String>[];
      
      // Extract error types (optional)
      final errorTypesData = data['errorTypes'] is List 
          ? (data['errorTypes'] as List).cast<String>()
          : <String>[];
      
      final errorTypes = errorTypesData.map((type) {
        switch (type.toLowerCase()) {
          case 'spelling': return ErrorType.spelling;
          case 'grammar': return ErrorType.grammar;
          case 'homophone': return ErrorType.homophone;
          case 'punctuation': return ErrorType.punctuation;
          case 'word_choice': 
          case 'wordchoice': return ErrorType.wordChoice;
          default: return ErrorType.spelling;
        }
      }).toList();
      
      // Extract optional fields
      final hint = data['hint'] as String?;
      final category = data['category'] as String? ?? 'ai_generated';
      
      // Create sentence - trust AI validation
      final sentence = SentenceWithErrors(
        words: words,
        errorPositions: errorPositions,
        corrections: corrections,
        difficulty: difficulty,
        errorTypes: errorTypes.isNotEmpty ? errorTypes : [ErrorType.spelling],
        hint: hint,
        category: category,
        id: 'ai_${difficulty}_$index',
      );
      
      developer.log('✅ Created AI-validated sentence: "${words.join(' ')}" with errors at $errorPositions', 
          name: 'dyslexic_ai.sentence_fixer');
      
      return sentence;
      
    } catch (e) {
      developer.log('❌ Error creating sentence from AI data: $e', name: 'dyslexic_ai.sentence_fixer');
      return null;
    }
  }
  
  // Static validation methods removed - AI now handles validation

  SentenceFixerFeedback validateSelections(
    SentenceWithErrors sentence,
    List<int> selectedPositions,
  ) {
    final correctSelections = <int>[];
    final incorrectSelections = <int>[];
    final missedErrors = <int>[];
    
    // Check each selection
    for (final position in selectedPositions) {
      if (sentence.hasErrorAt(position)) {
        correctSelections.add(position);
      } else {
        incorrectSelections.add(position);
      }
    }
    
    // Check for missed errors
    for (final errorPosition in sentence.errorPositions) {
      if (!selectedPositions.contains(errorPosition)) {
        missedErrors.add(errorPosition);
      }
    }
    
    // Calculate accuracy and score
    final totalErrors = sentence.errorPositions.length;
    final accuracy = totalErrors > 0 
        ? (correctSelections.length / totalErrors) * 100 
        : 0.0;
    
    final score = _calculateScore(correctSelections.length, incorrectSelections.length, totalErrors);
    
    // Generate feedback message
    final message = _generateFeedbackMessage(
      correctSelections.length, 
      incorrectSelections.length, 
      missedErrors.length,
      totalErrors,
    );
    
    return SentenceFixerFeedback(
      correctSelections: correctSelections,
      incorrectSelections: incorrectSelections,
      missedErrors: missedErrors,
      correctedSentence: sentence.correctedSentence,
      accuracy: accuracy,
      score: score,
      message: message,
      isSuccess: missedErrors.isEmpty && incorrectSelections.isEmpty,
    );
  }

  int _calculateScore(int correctSelections, int incorrectSelections, int totalErrors) {
    // Base score for each correct selection
    int score = correctSelections * 10;
    
    // Penalty for incorrect selections
    score -= incorrectSelections * 5;
    
    // Bonus for perfect score
    if (correctSelections == totalErrors && incorrectSelections == 0) {
      score += 20;
    }
    
    return score.clamp(0, 100);
  }

  String _generateFeedbackMessage(int correct, int incorrect, int missed, int total) {
    if (correct == total && incorrect == 0) {
      return 'Perfect! You found all the errors! 🎉';
    } else if (correct == total && incorrect > 0) {
      return 'Good job finding all errors, but watch out for extra selections.';
    } else if (missed == 0 && incorrect > 0) {
      return 'You found all the errors but selected some correct words too.';
    } else if (correct > 0 && missed > 0) {
      return 'Nice work! You found $correct out of $total errors. Keep looking!';
    } else {
      return 'Keep trying! Look more carefully for spelling and grammar mistakes.';
    }
  }

  List<WordSelection> createWordSelections(
    SentenceWithErrors sentence,
    List<int> selectedPositions,
  ) {
    final selections = <WordSelection>[];
    
    for (int i = 0; i < sentence.words.length; i++) {
      final word = sentence.words[i];
      final isSelected = selectedPositions.contains(i);
      final isError = sentence.hasErrorAt(i);
      final correction = sentence.getCorrectionFor(i);
      
      selections.add(WordSelection(
        position: i,
        word: word,
        isSelected: isSelected,
        isError: isError,
        correction: correction,
      ));
    }
    
    return selections;
  }

  String getDifficultyDescription(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return 'Simple spelling errors and basic grammar mistakes';
      case 'intermediate':
        return 'Mixed spelling, grammar, and homophone errors';
      case 'advanced':
        return 'Complex sentences with multiple error types';
      default:
        return 'Mixed difficulty levels';
    }
  }

  List<String> getErrorTypeExplanations(List<ErrorType> errorTypes) {
    return errorTypes.map((type) {
      switch (type) {
        case ErrorType.spelling:
          return 'Spelling: Word is misspelled';
        case ErrorType.grammar:
          return 'Grammar: Incorrect grammar usage';
        case ErrorType.homophone:
          return 'Homophone: Wrong word that sounds similar';
        case ErrorType.punctuation:
          return 'Punctuation: Missing or incorrect punctuation';
        case ErrorType.wordChoice:
          return 'Word Choice: Wrong word for the context';
      }
    }).toList();
  }

  String getHintForErrorType(ErrorType errorType) {
    switch (errorType) {
      case ErrorType.spelling:
        return 'Look for words that don\'t look right';
      case ErrorType.grammar:
        return 'Check if the sentence structure makes sense';
      case ErrorType.homophone:
        return 'Listen for words that sound the same but mean different things';
      case ErrorType.punctuation:
        return 'Check for missing commas, periods, or apostrophes';
      case ErrorType.wordChoice:
        return 'Think about whether the word fits the meaning';
    }
  }

  Map<String, dynamic> getSessionSummary(SentenceFixerSession session) {
    return {
      'totalSentences': session.totalSentences,
      'completedSentences': session.completedSentences,
      'correctSentences': session.correctSentences,
      'accuracy': session.accuracyPercentage,
      'totalScore': session.totalScore,
      'bestStreak': session.streak,
      'duration': session.duration?.inMinutes ?? 0,
      'errorPatterns': session.errorPatterns,
      'strugglingAreas': session.strugglingAreas,
      'errorTypeFrequency': session.errorTypeFrequency,
    };
  }
} 