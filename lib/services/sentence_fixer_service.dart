import 'dart:convert';
import 'dart:math';
import 'dart:developer' as developer;
import '../models/sentence_fixer.dart';
import '../models/learner_profile.dart';
import '../utils/prompt_loader.dart';
import '../utils/service_locator.dart';
import 'global_session_manager.dart';

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

  /// Generate complete sentence pack without immediate yielding
  Stream<SentenceWithErrors> generateSentencePackStream({
    required String difficulty,
    required int count,
    LearnerProfile? profile,
  }) async* {
    developer.log('🎯 Starting complete sentence generation: $difficulty, count=$count', 
        name: 'dyslexic_ai.sentence_fixer');
    
    // Generate ALL sentences first - no immediate yielding
    final allSentences = <SentenceWithErrors>[];
    
    try {
      developer.log('🤖 Generating complete sentence batch with AI...', 
          name: 'dyslexic_ai.sentence_fixer');
      
      // Use reliable batch generation for all sentences
      final aiSentences = await generateReliableBatch(
        difficulty: difficulty,
        profile: profile,
      );
      
      if (aiSentences.length >= count) {
        // AI succeeded - use AI sentences
        aiSentences.shuffle(_random);
        allSentences.addAll(aiSentences.take(count));
        developer.log('✅ Using ${count} AI-generated sentences', 
            name: 'dyslexic_ai.sentence_fixer');
      } else {
        // Hybrid: AI + fallback sentences
        allSentences.addAll(aiSentences);
        
        final fallbackSentences = _getFallbackSentences(difficulty);
        final neededFromFallback = count - aiSentences.length;
        allSentences.addAll(fallbackSentences.take(neededFromFallback));
        
        // Shuffle the final mix
        allSentences.shuffle(_random);
        
        developer.log('🔄 Using hybrid: ${aiSentences.length} AI + ${neededFromFallback} fallback sentences', 
            name: 'dyslexic_ai.sentence_fixer');
      }
      
    } catch (e) {
      developer.log('❌ AI generation failed, using fallback sentences: $e', 
          name: 'dyslexic_ai.sentence_fixer');
      
      // Fallback to predefined sentences only
      final fallbackSentences = _getFallbackSentences(difficulty);
      allSentences.addAll(fallbackSentences.take(count));
    }
    
    // Now yield all sentences at once (after generation is complete)
    for (int i = 0; i < allSentences.length; i++) {
      developer.log('📥 Generated sentence ${i + 1}/$count: "${allSentences[i].words.join(' ')}"', 
          name: 'dyslexic_ai.sentence_fixer');
      yield allSentences[i];
    }
    
    developer.log('🎉 Sentence generation complete - all ${allSentences.length} sentences ready', 
        name: 'dyslexic_ai.sentence_fixer');
  }

  /// Get a random first sentence for immediate display
  SentenceWithErrors _getFirstSentenceForDifficulty(String difficulty) {
    final predefined = _getPredefinedSentencesForDifficulty(difficulty);
    if (predefined.isNotEmpty) {
      return predefined[_random.nextInt(predefined.length)]; // Use random predefined for variety
    }
    
    // Fallback to any random predefined sentence
    return _predefinedSentences[_random.nextInt(_predefinedSentences.length)];
  }


  


  /// Get predefined sentences filtered by difficulty
  List<SentenceWithErrors> _getPredefinedSentencesForDifficulty(String difficulty) {
    return _predefinedSentences
        .where((s) => s.difficulty.toLowerCase() == difficulty.toLowerCase())
        .toList();
  }

  /// Legacy method - now uses streaming internally for consistency
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
        final tmpl = await PromptLoader.load('sentence_fixer', 'single_sentence.tmpl');
        final prompt = PromptLoader.fill(tmpl, {
          'count': '$count',
          'difficulty': difficulty,
        });
        developer.log('📝 AI generation attempt $attempt: $prompt', 
            name: 'dyslexic_ai.sentence_fixer');
        
        final response = await aiService.generateResponse(
          prompt,
          activity: AIActivity.sentenceGeneration,
        );
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

  /// Generate detailed feedback with correct answers
  String generateDetailedFeedback(
    SentenceWithErrors sentence,
    SentenceFixerFeedback feedback,
  ) {
    final List<String> feedbackParts = [];
    
    // Main feedback message
    feedbackParts.add(feedback.message);
    
    // Show what they got right
    if (feedback.correctSelections.isNotEmpty) {
      final correctWords = feedback.correctSelections.map((pos) => 
        '"${sentence.words[pos]}"').join(', ');
      feedbackParts.add('✅ Correctly identified: $correctWords');
    }
    
    // Show what they missed
    if (feedback.missedErrors.isNotEmpty) {
      final missedDetails = feedback.missedErrors.map((pos) {
        final wrongWord = sentence.words[pos];
        final correction = sentence.getCorrectionFor(pos) ?? 'unknown';
        return '"$wrongWord" should be "$correction"';
      }).join(', ');
      feedbackParts.add('❌ Missed errors: $missedDetails');
    }
    
    // Show incorrect selections
    if (feedback.incorrectSelections.isNotEmpty) {
      final incorrectWords = feedback.incorrectSelections.map((pos) => 
        '"${sentence.words[pos]}"').join(', ');
      feedbackParts.add('⚠️ These words were actually correct: $incorrectWords');
    }
    
    return feedbackParts.join('\n');
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

  /// Generate exactly 5 reliable sentences using structured AI prompt
  Future<List<SentenceWithErrors>> generateReliableBatch({
    required String difficulty,
    LearnerProfile? profile,
  }) async {
    final aiService = getAIInferenceService();
    if (aiService == null) {
      developer.log('❌ AI service not available, using fallback sentences', 
          name: 'dyslexic_ai.sentence_fixer');
      return _getFallbackSentences(difficulty);
    }
    
    // Determine sentence count based on difficulty
    final count = _getSentenceCountForDifficulty(difficulty);
    
    try {
      developer.log('🎯 Generating reliable sentence batch for: $difficulty ($count sentences)', 
          name: 'dyslexic_ai.sentence_fixer');
      
      // Use difficulty-specific prompt template
      final templateName = _getTemplateForDifficulty(difficulty);
      final tmpl = await PromptLoader.load('sentence_fixer', templateName);
      
      // Generate extra sentences to ensure we get enough valid ones
      final generateCount = count + 2;
      final prompt = PromptLoader.fill(tmpl, {'count': generateCount.toString()});
      
      final response = await aiService.generateResponse(
        prompt, 
        activity: AIActivity.sentenceGeneration,
      );
      final aiSentences = _parseStructuredResponse(response, difficulty);
      
      developer.log('🔍 AI generated ${aiSentences.length} valid sentences out of $count requested', 
          name: 'dyslexic_ai.sentence_fixer');
      
      if (aiSentences.length >= count) {
        // AI succeeded - shuffle and use random AI sentences
        aiSentences.shuffle(_random);
        developer.log('✅ Using ${count} AI-generated sentences (shuffled from ${aiSentences.length})', 
            name: 'dyslexic_ai.sentence_fixer');
        return aiSentences.take(count).toList();
      } else {
        // Hybrid approach: use valid AI sentences + reliable fallbacks
        final fallbackSentences = _getFallbackSentences(difficulty);
        final neededFromFallback = count - aiSentences.length;
        
        final finalSentences = <SentenceWithErrors>[];
        finalSentences.addAll(aiSentences);
        finalSentences.addAll(fallbackSentences.take(neededFromFallback));
        
        // Shuffle the final mix for variety
        finalSentences.shuffle(_random);
        
        developer.log('🔄 Using hybrid: ${aiSentences.length} AI + ${neededFromFallback} fallback sentences (shuffled)', 
            name: 'dyslexic_ai.sentence_fixer');
        
        return finalSentences.take(count).toList();
      }
      
    } catch (e) {
      developer.log('❌ Reliable batch generation failed: $e, using fallback', 
          name: 'dyslexic_ai.sentence_fixer');
      return _getFallbackSentences(difficulty);
    }
  }

  /// Get sentence count based on difficulty
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
  
  /// Get appropriate template file for difficulty level
  String _getTemplateForDifficulty(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return 'beginner_generation.tmpl';
      case 'intermediate':
        return 'intermediate_generation.tmpl';
      case 'advanced':
        return 'advanced_generation.tmpl';
      default:
        return 'beginner_generation.tmpl'; // Default to beginner
    }
  }
  
  /// Get validation limits based on difficulty level
  /// Returns (minWords, maxWords, maxWordLength, maxLengthDiff, checkComplexWords)
  (int, int, int, int, bool) _getValidationLimits(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return (3, 6, 8, 2, true);   // Short sentences, simple words, strict limits
      case 'intermediate':
        return (4, 8, 12, 3, false); // Medium sentences, moderate words
      case 'advanced':
        return (5, 12, 15, 4, false); // Longer sentences, complex words allowed
      default:
        return (3, 6, 8, 2, true);   // Default to beginner
    }
  }
  
  /// Parse structured JSON response from AI
  List<SentenceWithErrors> _parseStructuredResponse(String response, String difficulty) {
    try {
      // Clean the response to extract JSON
      String jsonStr = response.trim();
      
      // Remove any markdown code blocks
      if (jsonStr.contains('```')) {
        final lines = jsonStr.split('\n');
        final jsonLines = <String>[];
        bool inCodeBlock = false;
        
        for (final line in lines) {
          if (line.trim().startsWith('```')) {
            inCodeBlock = !inCodeBlock;
            continue;
          }
          if (inCodeBlock || line.trim().startsWith('[') || line.trim().startsWith('{') || 
              line.trim().startsWith('}') || line.trim().startsWith(']') || line.contains('"sentence"')) {
            jsonLines.add(line);
          }
        }
        jsonStr = jsonLines.join('\n');
      }
      
      developer.log('🔍 Parsing JSON response: ${jsonStr.substring(0, min(500, jsonStr.length))}...', 
          name: 'dyslexic_ai.sentence_fixer');
      
      // Log the raw response for debugging
      developer.log('🔍 Raw AI response: ${response.substring(0, min(300, response.length))}...', 
          name: 'dyslexic_ai.sentence_fixer');
      
      final List<dynamic> jsonArray = json.decode(jsonStr);
      final List<SentenceWithErrors> sentences = [];
      
      for (final item in jsonArray) {
        if (item is Map<String, dynamic>) {
          final sentence = item['sentence']?.toString() ?? '';
          final errorWord = item['error_word']?.toString() ?? '';
          final correctWord = item['correct_word']?.toString() ?? '';
          
          // Validate AI response quality based on difficulty
          if (_validateAISentence(sentence, errorWord, correctWord, difficulty)) {
            final words = sentence.split(' ');
            final errorIndex = words.indexWhere((word) => 
                word.toLowerCase().replaceAll(RegExp(r'[^\w]'), '') == 
                errorWord.toLowerCase().replaceAll(RegExp(r'[^\w]'), ''));
            
            if (errorIndex != -1) {
              sentences.add(SentenceWithErrors(
                words: words,
                errorPositions: [errorIndex],
                corrections: [correctWord],
                difficulty: difficulty,
                errorTypes: [ErrorType.spelling],
                hint: 'Check the spelling of this word',
                category: 'spelling',
              ));
              
              developer.log('✅ Created valid sentence: "$sentence" (error: $errorWord → $correctWord)', 
                  name: 'dyslexic_ai.sentence_fixer');
            } else {
              developer.log('❌ Error word "$errorWord" not found in sentence: "$sentence"', 
                  name: 'dyslexic_ai.sentence_fixer');
            }
          } else {
            developer.log('❌ Invalid AI sentence rejected: "$sentence" (error: $errorWord → $correctWord)', 
                name: 'dyslexic_ai.sentence_fixer');
          }
        }
      }
      
      return sentences;
      
    } catch (e) {
      developer.log('❌ JSON parsing failed: $e', name: 'dyslexic_ai.sentence_fixer');
      return [];
    }
  }
  
  /// Validate AI-generated sentence based on difficulty level
  bool _validateAISentence(String sentence, String errorWord, String correctWord, String difficulty) {
    // Basic checks
    if (sentence.isEmpty || errorWord.isEmpty || correctWord.isEmpty) {
      return false;
    }
    
    // Error word and correction must be different (strict check)
    if (errorWord.toLowerCase().trim() == correctWord.toLowerCase().trim()) {
      developer.log('❌ Error and correction are identical: "$errorWord"', 
          name: 'dyslexic_ai.sentence_fixer');
      return false;
    }
    
    // Clean up words for comparison
    final cleanErrorWord = errorWord.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
    final cleanCorrectWord = correctWord.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
    
    // Ensure it's actually a spelling mistake, not a grammar change
    if (_isGrammarChange(cleanErrorWord, cleanCorrectWord)) {
      developer.log('❌ Grammar change detected, not spelling error: "$errorWord" → "$correctWord"', 
          name: 'dyslexic_ai.sentence_fixer');
      return false;
    }
    
    // Sentence must contain the error word
    final words = sentence.split(' ');
    final containsError = words.any((word) => 
        word.toLowerCase().replaceAll(RegExp(r'[^\w]'), '') == cleanErrorWord);
    
    if (!containsError) {
      developer.log('❌ Sentence does not contain error word: "$errorWord" in "$sentence"', 
          name: 'dyslexic_ai.sentence_fixer');
      return false;
    }
    
    // Difficulty-specific validation
    final (minWords, maxWords, maxWordLength, maxLengthDiff, checkComplexWords) = _getValidationLimits(difficulty);
    
    // Check sentence length based on difficulty
    if (words.length < minWords || words.length > maxWords) {
      developer.log('❌ Sentence length not appropriate for $difficulty: ${words.length} words', 
          name: 'dyslexic_ai.sentence_fixer');
      return false;
    }
    
    // Check word complexity based on difficulty
    if (cleanErrorWord.length < 2 || cleanErrorWord.length > maxWordLength) {
      developer.log('❌ Error word too complex for $difficulty: "$cleanErrorWord" (${cleanErrorWord.length} chars)', 
          name: 'dyslexic_ai.sentence_fixer');
      return false;
    }
    
    // Check for complex vocabulary (only for beginner level)
    if (checkComplexWords && _hasComplexWords(sentence)) {
      developer.log('❌ Sentence contains complex words not suitable for $difficulty: "$sentence"', 
          name: 'dyslexic_ai.sentence_fixer');
      return false;
    }
    
    // Check length difference based on difficulty
    final lengthDiff = (cleanErrorWord.length - cleanCorrectWord.length).abs();
    if (lengthDiff > maxLengthDiff) {
      developer.log('❌ Error and correction too different for $difficulty: "$cleanErrorWord" vs "$cleanCorrectWord"', 
          name: 'dyslexic_ai.sentence_fixer');
      return false;
    }
    
    developer.log('✅ Sentence validation passed: "$sentence" (error: $errorWord → $correctWord)', 
        name: 'dyslexic_ai.sentence_fixer');
    return true;
  }
  
  /// Check if this is a grammar change rather than spelling error
  bool _isGrammarChange(String errorWord, String correctWord) {
    // Plural changes: cat → cats, dog → dogs, box → boxes, lady → ladies
    if (correctWord == '${errorWord}s' || errorWord == '${correctWord}s') {
      return true;
    }
    if (correctWord == '${errorWord}es' || errorWord == '${correctWord}es') {
      return true;
    }
    
    // Y to IES changes: lady → ladies, baby → babies
    if (errorWord.endsWith('y') && correctWord == '${errorWord.substring(0, errorWord.length - 1)}ies') {
      return true;
    }
    if (correctWord.endsWith('y') && errorWord == '${correctWord.substring(0, correctWord.length - 1)}ies') {
      return true;
    }
    
    // Irregular plurals: child → children, mouse → mice, etc.
    final irregularPlurals = {
      'child': 'children', 'mouse': 'mice', 'foot': 'feet', 'tooth': 'teeth',
      'man': 'men', 'woman': 'women', 'goose': 'geese', 'person': 'people',
      'leaf': 'leaves', 'wolf': 'wolves', 'half': 'halves', 'knife': 'knives'
    };
    if (irregularPlurals[errorWord] == correctWord || irregularPlurals[correctWord] == errorWord) {
      return true;
    }
    
    // Past tense changes: run → ran, play → played, go → went, try → tried
    if (correctWord.endsWith('ed') && !errorWord.endsWith('ed')) {
      return true;
    }
    if (correctWord.endsWith('ied') && errorWord.endsWith('y')) {
      return true; // try → tried, cry → cried
    }
    
    // -ing changes: run → running, play → playing, swim → swimming
    if (correctWord.endsWith('ing') && !errorWord.endsWith('ing')) {
      return true;
    }
    
    // Double consonant + ing: run → running, swim → swimming, stop → stopping
    if (correctWord.endsWith('ing') && correctWord.length > errorWord.length + 3) {
      final baseLength = errorWord.length;
      if (baseLength > 0 && correctWord.substring(baseLength, baseLength + 1) == errorWord.substring(baseLength - 1)) {
        return true; // doubled consonant
      }
    }
    
    // Common tense changes: go → went, run → ran, see → saw, think → thought
    final tenseChanges = {
      'go': 'went', 'run': 'ran', 'see': 'saw', 'come': 'came', 
      'get': 'got', 'have': 'had', 'is': 'was', 'are': 'were',
      'think': 'thought', 'buy': 'bought', 'bring': 'brought',
      'catch': 'caught', 'teach': 'taught', 'make': 'made',
      'take': 'took', 'give': 'gave', 'eat': 'ate', 'drink': 'drank'
    };
    if (tenseChanges[errorWord] == correctWord || tenseChanges[correctWord] == errorWord) {
      return true;
    }
    
    // Comparative/superlative: big → bigger → biggest, good → better → best
    final comparatives = {
      'big': ['bigger', 'biggest'], 'good': ['better', 'best'], 'bad': ['worse', 'worst'],
      'tall': ['taller', 'tallest'], 'small': ['smaller', 'smallest'],
      'fast': ['faster', 'fastest'], 'slow': ['slower', 'slowest']
    };
    for (final entry in comparatives.entries) {
      if ((entry.key == errorWord && entry.value.contains(correctWord)) ||
          (entry.key == correctWord && entry.value.contains(errorWord))) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Check if sentence contains complex words unsuitable for beginners
  bool _hasComplexWords(String sentence) {
    final complexWords = [
      'agile', 'cheetah', 'savanna', 'gazelle', 'torrential', 'majestic', 
      'gracefully', 'chocolate', 'celebrate', 'birthdays', 'vibrant', 
      'wildflowers', 'meadows', 'springtime', 'rewarding', 'scenic', 
      'cottage', 'peaceful', 'retreat', 'bustle', 'throughout', 'entire'
    ];
    
    final words = sentence.toLowerCase().split(' ');
    return words.any((word) => 
        complexWords.contains(word.replaceAll(RegExp(r'[^\w]'), '')));
  }
  
  /// Get fallback sentences appropriate for the difficulty level
  List<SentenceWithErrors> _getFallbackSentences(String difficulty) {
    List<Map<String, dynamic>> fallbackPool;
    
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        // Very simple 1st grade sentences
                 fallbackPool = [
           {'words': ['I', 'can', 'se', 'mom'], 'errorPos': 2, 'correction': 'see', 'errorWord': 'se'},
           {'words': ['The', 'cat', 'ran', 'hom'], 'errorPos': 3, 'correction': 'home', 'errorWord': 'hom'},
           {'words': ['My', 'dog', 'is', 'bigg'], 'errorPos': 3, 'correction': 'big', 'errorWord': 'bigg'},
           {'words': ['Dad', 'haz', 'a', 'hat'], 'errorPos': 1, 'correction': 'has', 'errorWord': 'haz'},
           {'words': ['I', 'liek', 'to', 'play'], 'errorPos': 1, 'correction': 'like', 'errorWord': 'liek'},
           {'words': ['The', 'sunn', 'is', 'hot'], 'errorPos': 1, 'correction': 'sun', 'errorWord': 'sunn'},
           {'words': ['We', 'go', 'to', 'scool'], 'errorPos': 3, 'correction': 'school', 'errorWord': 'scool'},
           {'words': ['My', 'carr', 'is', 'red'], 'errorPos': 1, 'correction': 'car', 'errorWord': 'carr'},
         ];
        break;
        
      case 'intermediate':
        // 3rd-4th grade sentences
        fallbackPool = [
          {'words': ['I', 'ate', 'a', 'sandwhich', 'for', 'lunch'], 'errorPos': 3, 'correction': 'sandwich', 'errorWord': 'sandwhich'},
          {'words': ['The', 'techer', 'helped', 'me', 'today'], 'errorPos': 1, 'correction': 'teacher', 'errorWord': 'techer'},
          {'words': ['My', 'sisiter', 'likes', 'to', 'sing'], 'errorPos': 1, 'correction': 'sister', 'errorWord': 'sisiter'},
          {'words': ['It', 'was', 'raning', 'all', 'day'], 'errorPos': 2, 'correction': 'raining', 'errorWord': 'raning'},
          {'words': ['She', 'drank', 'choclate', 'milk', 'yesterday'], 'errorPos': 2, 'correction': 'chocolate', 'errorWord': 'choclate'},
        ];
        break;
        
      case 'advanced':
        // 5th-6th grade sentences  
        fallbackPool = [
          {'words': ['The', 'elefant', 'ate', 'peanuts', 'at', 'the', 'zoo'], 'errorPos': 1, 'correction': 'elephant', 'errorWord': 'elefant'},
          {'words': ['His', 'brothr', 'plays', 'football', 'well'], 'errorPos': 1, 'correction': 'brother', 'errorWord': 'brothr'},
          {'words': ['We', 'viseted', 'grandma', 'last', 'weekend'], 'errorPos': 1, 'correction': 'visited', 'errorWord': 'viseted'},
          {'words': ['The', 'buterfly', 'landed', 'on', 'the', 'flower'], 'errorPos': 1, 'correction': 'butterfly', 'errorWord': 'buterfly'},
        ];
        break;
        
      default:
        // Default to beginner
        fallbackPool = [
          {'words': ['I', 'can', 'se', 'mom'], 'errorPos': 2, 'correction': 'see', 'errorWord': 'se'},
          {'words': ['The', 'cat', 'ran', 'hom'], 'errorPos': 3, 'correction': 'home', 'errorWord': 'hom'},
          {'words': ['My', 'dog', 'is', 'bigg'], 'errorPos': 3, 'correction': 'big', 'errorWord': 'bigg'},
        ];
    }
    
    // Randomly select sentences to provide variety
    final shuffled = List.from(fallbackPool)..shuffle(_random);
    final selectedSentences = shuffled.take(5).toList();
    
    return selectedSentences.map((data) => SentenceWithErrors(
      words: data['words'] as List<String>,
      errorPositions: [data['errorPos'] as int],
      corrections: [data['correction'] as String],
      difficulty: difficulty,
      errorTypes: [ErrorType.spelling],
      hint: 'Check the spelling of this word',
      category: 'spelling',
    )).toList();
  }
}