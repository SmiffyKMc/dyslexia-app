import 'dart:convert';
import 'dart:math';
import 'dart:developer' as developer;
import '../models/sentence_fixer.dart';
import '../models/learner_profile.dart';
import '../utils/prompt_loader.dart';
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

  /// Streaming version that yields sentences one by one for immediate UI feedback
  Stream<SentenceWithErrors> generateSentencePackStream({
    required String difficulty,
    required int count,
    LearnerProfile? profile,
  }) async* {
    developer.log('🎯 Starting reliable streaming sentence generation: $difficulty, count=$count', 
        name: 'dyslexic_ai.sentence_fixer');
    
    // Phase 1: Yield first sentence immediately (from predefined for speed)
    final firstSentence = _getFirstSentenceForDifficulty(difficulty);
    developer.log('⚡ Yielding first sentence immediately: "${firstSentence.words.join(' ')}"', 
        name: 'dyslexic_ai.sentence_fixer');
    yield firstSentence;
    
    // Phase 2: Generate remaining sentences using reliable AI batch
    final remainingCount = count - 1;
    if (remainingCount <= 0) return;
    
    try {
      developer.log('🤖 Generating ${remainingCount} sentences with reliable AI batch', 
          name: 'dyslexic_ai.sentence_fixer');
      
      // Use reliable batch generation for consistent quality
      final aiSentences = await generateReliableBatch(
        difficulty: difficulty,
        profile: profile,
      );
      
      // Yield AI sentences one by one
      int yieldedCount = 0;
      for (final sentence in aiSentences) {
        if (yieldedCount >= remainingCount) break;
        
        developer.log('✅ Yielding reliable AI sentence ${yieldedCount + 1}: "${sentence.words.join(' ')}"', 
            name: 'dyslexic_ai.sentence_fixer');
        yield sentence;
        yieldedCount++;
      }
      
      // Fill any remaining slots with predefined sentences
      final predefinedNeeded = remainingCount - yieldedCount;
      if (predefinedNeeded > 0) {
        final predefinedSentences = _getFallbackSentences(difficulty);
        for (int i = 0; i < predefinedNeeded && i < predefinedSentences.length; i++) {
          developer.log('📝 Yielding fallback sentence: "${predefinedSentences[i].words.join(' ')}"', 
              name: 'dyslexic_ai.sentence_fixer');
          yield predefinedSentences[i];
        }
      }
      
    } catch (e) {
      developer.log('❌ Reliable generation failed, using fallback sentences: $e', 
          name: 'dyslexic_ai.sentence_fixer');
      
      // Fallback to predefined sentences
      final fallbackSentences = _getFallbackSentences(difficulty);
      for (int i = 0; i < remainingCount && i < fallbackSentences.length; i++) {
        developer.log('📝 Yielding fallback sentence: "${fallbackSentences[i].words.join(' ')}"', 
            name: 'dyslexic_ai.sentence_fixer');
        yield fallbackSentences[i];
      }
    }
    
    developer.log('🎉 Reliable streaming sentence generation complete', 
        name: 'dyslexic_ai.sentence_fixer');
  }

  /// Get the best first sentence for immediate display
  SentenceWithErrors _getFirstSentenceForDifficulty(String difficulty) {
    final predefined = _getPredefinedSentencesForDifficulty(difficulty);
    if (predefined.isNotEmpty) {
      return predefined.first; // Use first predefined for consistency
    }
    
    // Fallback to any predefined sentence
    return _predefinedSentences.first;
  }

  /// Generate a single AI sentence
  Future<SentenceWithErrors?> _generateSingleAISentence({
    required String difficulty,
    LearnerProfile? profile,
  }) async {
    final aiService = getAIInferenceService();
    if (aiService == null) {
      return null;
    }
    
    try {
      final tmpl = await PromptLoader.load('sentence_fixer.tmpl');
      final prompt = PromptLoader.fill(tmpl, {
        'count': '1', // Generate only one sentence
        'difficulty': difficulty,
      });
      
      final response = await aiService.generateResponse(prompt);
      final sentences = _parseAISentenceResponse(response, difficulty);
      
      return sentences.isNotEmpty ? sentences.first : null;
    } catch (e) {
      developer.log('❌ Single AI sentence generation failed: $e', 
          name: 'dyslexic_ai.sentence_fixer');
      return null;
    }
  }

  /// Generate a single AI sentence using simple prompt (much faster)
  Future<SentenceWithErrors?> _generateFastAISentence({
    required String difficulty,
    LearnerProfile? profile,
  }) async {
    final aiService = getAIInferenceService();
    if (aiService == null) {
      return null;
    }
    
    try {
      final tmpl = await PromptLoader.load('sentence_simple.tmpl');
      final prompt = tmpl; // No variable substitution needed for simple template
      
      final response = await aiService.generateResponse(prompt);
      final cleanSentence = response.trim().replaceAll('"', '');
      
      if (cleanSentence.isEmpty) {
        return null;
      }
      
      // Split into words and detect error position using spell check
      final words = cleanSentence.split(' ');
      final errorPosition = _detectErrorPosition(words);
      
      developer.log('🔍 AI generated: "$cleanSentence"', name: 'dyslexic_ai.sentence_fixer');
      developer.log('🔍 Error position detected: $errorPosition', name: 'dyslexic_ai.sentence_fixer');
      
      if (errorPosition == -1) {
        // No error detected, manually create one by misspelling a word
        developer.log('🔧 No error detected, creating manual error', name: 'dyslexic_ai.sentence_fixer');
        return _createErrorInSentence(words, difficulty);
      }
      
      return SentenceWithErrors(
        words: words,
        errorPositions: [errorPosition],
        corrections: [_suggestCorrection(words[errorPosition])],
        difficulty: difficulty,
        errorTypes: [ErrorType.spelling],
        hint: _generateHint(words[errorPosition]),
        category: 'spelling',
      );
      
    } catch (e) {
      developer.log('❌ Fast AI sentence generation failed: $e', 
          name: 'dyslexic_ai.sentence_fixer');
      return null;
    }
  }
  
  /// Detect which word position has a spelling error
  int _detectErrorPosition(List<String> words) {
    final commonMisspellings = {
      'runing': 'running',
      'comming': 'coming', 
      'geting': 'getting',
      'siting': 'sitting',
      'wriet': 'write',
      'freind': 'friend',
      'becaus': 'because',
      'beleive': 'believe',
      'tommorrow': 'tomorrow',
      'thier': 'their',
      'hapy': 'happy',
      'alot': 'a lot',
    };
    
    for (int i = 0; i < words.length; i++) {
      final word = words[i].toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
      if (commonMisspellings.containsKey(word)) {
        return i;
      }
    }
    
    return -1; // No error detected
  }
  
  /// Suggest correction for a misspelled word
  String _suggestCorrection(String misspelledWord) {
    final commonMisspellings = {
      'runing': 'running',
      'comming': 'coming',
      'geting': 'getting', 
      'siting': 'sitting',
      'wriet': 'write',
      'freind': 'friend',
      'becaus': 'because',
      'beleive': 'believe',
      'tommorrow': 'tomorrow',
      'thier': 'their',
      'hapy': 'happy',
      'alot': 'a lot',
    };
    
    final cleanWord = misspelledWord.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
    return commonMisspellings[cleanWord] ?? misspelledWord;
  }
  
  /// Generate a helpful hint for the error
  String _generateHint(String misspelledWord) {
    final word = misspelledWord.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
    
    final hints = {
      'runing': 'This word needs a double letter before adding -ing',
      'comming': 'This word needs a double letter in the middle',
      'geting': 'This word needs a double letter before adding -ing',
      'siting': 'This word needs a double letter',
      'wriet': 'The vowels in this word are in the wrong order',
      'freind': 'Remember the rule: "i before e except after c"',
      'becaus': 'This word is missing a letter at the end',
      'beleive': 'Remember the rule: "i before e except after c"',
      'tommorrow': 'This word has too many of one letter',
      'thier': 'This word starts like "the" but with different letters',
      'hapy': 'This word needs a double letter',
      'alot': 'This should be written as two separate words',
    };
    
    return hints[word] ?? 'Check the spelling of this word carefully';
  }
  
  /// Create an error in a clean sentence by misspelling one word
  SentenceWithErrors _createErrorInSentence(List<String> words, String difficulty) {
    // Pick a word to misspell (avoid first/last words, prefer middle)
    int targetIndex = words.length > 3 ? 1 + Random().nextInt(words.length - 2) : 0;
    String targetWord = words[targetIndex].toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
    
    // Apply common misspelling patterns
    String misspelled = _applyMisspellingPattern(targetWord);
    
    // Replace the word in the sentence
    List<String> modifiedWords = List.from(words);
    modifiedWords[targetIndex] = misspelled;
    
    return SentenceWithErrors(
      words: modifiedWords,
      errorPositions: [targetIndex],
      corrections: [targetWord],
      difficulty: difficulty,
      errorTypes: [ErrorType.spelling],
      hint: _generateHint(misspelled),
      category: 'spelling',
    );
  }
  
  /// Apply common misspelling patterns to create realistic errors
  String _applyMisspellingPattern(String word) {
    final patterns = [
      (String w) => w.replaceAll('ing', 'ing').replaceAll('nning', 'ning'), // running -> runing
      (String w) => w.replaceAll('ie', 'ei'), // friend -> freind  
      (String w) => w.replaceAll('pp', 'p'), // happy -> hapy
      (String w) => w.replaceAll('tt', 't'), // sitting -> siting
      (String w) => w.replaceAll('mm', 'm'), // tomorrow -> tommorow (reverse)
    ];
    
    // Try each pattern and return first that creates a change
    for (final pattern in patterns) {
      String result = pattern(word);
      if (result != word) {
        return result;
      }
    }
    
    // Fallback: remove last letter if word is long enough
    return word.length > 4 ? word.substring(0, word.length - 1) : word;
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
        final tmpl = await PromptLoader.load('sentence_fixer.tmpl');
        final prompt = PromptLoader.fill(tmpl, {
          'count': '$count',
          'difficulty': difficulty,
        });
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
      
      final tmpl = await PromptLoader.load('sentence_batch.tmpl');
      final prompt = PromptLoader.fill(tmpl, {'count': count.toString()});
      
      final response = await aiService.generateResponse(prompt);
      final sentences = _parseStructuredResponse(response, difficulty);
      
      if (sentences.length >= count) {
        developer.log('✅ Generated ${sentences.length} reliable sentences', 
            name: 'dyslexic_ai.sentence_fixer');
        return sentences.take(count).toList();
      } else {
        developer.log('⚠️ Only got ${sentences.length} sentences, using fallback', 
            name: 'dyslexic_ai.sentence_fixer');
        return _getFallbackSentences(difficulty);
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
      
      developer.log('🔍 Parsing JSON response: ${jsonStr.substring(0, min(200, jsonStr.length))}...', 
          name: 'dyslexic_ai.sentence_fixer');
      
      final List<dynamic> jsonArray = json.decode(jsonStr);
      final List<SentenceWithErrors> sentences = [];
      
      for (final item in jsonArray) {
        if (item is Map<String, dynamic>) {
          final sentence = item['sentence']?.toString() ?? '';
          final errorWord = item['error_word']?.toString() ?? '';
          final correctWord = item['correct_word']?.toString() ?? '';
          
          if (sentence.isNotEmpty && errorWord.isNotEmpty && correctWord.isNotEmpty) {
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
                hint: _generateHint(errorWord),
                category: 'spelling',
              ));
              
              developer.log('✅ Created sentence: "$sentence" (error: $errorWord → $correctWord)', 
                  name: 'dyslexic_ai.sentence_fixer');
            }
          }
        }
      }
      
      return sentences;
      
    } catch (e) {
      developer.log('❌ JSON parsing failed: $e', name: 'dyslexic_ai.sentence_fixer');
      return [];
    }
  }
  
  /// Get reliable fallback sentences for when AI fails
  List<SentenceWithErrors> _getFallbackSentences(String difficulty) {
    final fallbackSentences = [
      {
        'words': ['The', 'dog', 'is', 'runing', 'in', 'the', 'park'],
        'errorPos': 3,
        'correction': 'running',
        'errorWord': 'runing'
      },
      {
        'words': ['My', 'freind', 'is', 'coming', 'over'],
        'errorPos': 1,
        'correction': 'friend',
        'errorWord': 'freind'
      },
      {
        'words': ['She', 'is', 'very', 'hapy', 'today'],
        'errorPos': 3,
        'correction': 'happy',
        'errorWord': 'hapy'
      },
      {
        'words': ['I', 'like', 'to', 'wriet', 'stories'],
        'errorPos': 3,
        'correction': 'write',
        'errorWord': 'wriet'
      },
      {
        'words': ['The', 'cat', 'is', 'siting', 'on', 'the', 'chair'],
        'errorPos': 3,
        'correction': 'sitting',
        'errorWord': 'siting'
      },
    ];
    
    return fallbackSentences.map((data) => SentenceWithErrors(
      words: data['words'] as List<String>,
      errorPositions: [data['errorPos'] as int],
      corrections: [data['correction'] as String],
      difficulty: difficulty,
      errorTypes: [ErrorType.spelling],
      hint: _generateHint(data['errorWord'] as String),
      category: 'spelling',
    )).toList();
  }
} 