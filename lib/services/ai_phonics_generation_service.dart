import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:developer' as developer;
import '../models/phonics_game.dart';
import '../models/learner_profile.dart';
import '../utils/prompt_loader.dart';
import '../utils/service_locator.dart';
import 'global_session_manager.dart';

class AIPhonicsGenerationService {
  final Random _random = Random();
  final Map<String, Set<String>> _phonemeWordHistory = {};
  
  static final List<String> _allPhonemes = [
    // Basic consonants
    'b', 'c', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'm', 'n', 'p', 'r', 's', 't', 'v', 'w', 'y', 'z',
    // Vowels
    'a', 'e', 'i', 'o', 'u',
    // Digraphs
    'ch', 'sh', 'th', 'ph', 'wh', 'ng', 'ck',
    // Consonant blends
    'bl', 'br', 'cl', 'cr', 'dr', 'fl', 'fr', 'gl', 'gr', 'pl', 'pr', 'sc', 'sk', 'sl', 'sm', 'sn', 'sp', 'st', 'sw', 'tr', 'tw',
    // Vowel teams
    'ai', 'ay', 'ea', 'ee', 'ie', 'oa', 'oo', 'ou', 'ow'
  ];

  /// Generate dynamic sound sets based on learner profile
  Future<List<SoundSet>> generateGameSounds({
    required LearnerProfile? profile,
    int rounds = 5,
    int difficulty = 1,
  }) async {
    developer.log('🎯 Generating AI phonics content: rounds=$rounds, difficulty=$difficulty', 
        name: 'dyslexic_ai.phonics_ai');

    try {
      // Analyze profile to determine focus areas
      final focusPhonemes = _extractFocusPhonemes(profile);
      final selectedPhonemes = _selectPhonemesForGame(focusPhonemes, rounds, difficulty);
      
      developer.log('📊 Selected phonemes: $selectedPhonemes', name: 'dyslexic_ai.phonics_ai');
      developer.log('🎯 Focus areas from profile: $focusPhonemes', name: 'dyslexic_ai.phonics_ai');

      final soundSets = <SoundSet>[];
      
      // Generate all phonemes in one batch (like sentence fixer)
      try {
        final batchSoundSets = await _generateAllPhonemesInBatch(
          selectedPhonemes,
          difficulty,
          profile,
        );
        soundSets.addAll(batchSoundSets);
        developer.log('✅ Generated ${batchSoundSets.length} sound sets in batch', name: 'dyslexic_ai.phonics_ai');
      } catch (e) {
        developer.log('❌ Batch generation failed: $e', name: 'dyslexic_ai.phonics_ai');
        // Fallback: Generate static sets for all phonemes
        for (int i = 0; i < selectedPhonemes.length; i++) {
          final phoneme = selectedPhonemes[i];
          final fallbackSet = _generateStaticSoundSet(phoneme, difficulty, i);
          soundSets.add(fallbackSet);
          developer.log('🔄 Used static fallback for: $phoneme', name: 'dyslexic_ai.phonics_ai');
        }
      }

      developer.log('🎉 Generated ${soundSets.length} sound sets total', name: 'dyslexic_ai.phonics_ai');
      return soundSets;

    } catch (e) {
      developer.log('❌ Complete generation failure, using static fallback: $e', name: 'dyslexic_ai.phonics_ai');
      return _generateFallbackSoundSets(rounds, difficulty);
    }
  }

  /// Extract focus phonemes from learner profile
  List<String> _extractFocusPhonemes(LearnerProfile? profile) {
    if (profile == null) return [];

    final focusPhonemes = <String>[];
    final focus = profile.focus.toLowerCase();

    // Analyze focus areas
    if (focus.contains('vowel')) {
      focusPhonemes.addAll(['a', 'e', 'i', 'o', 'u', 'ai', 'ay', 'ea', 'ee', 'ie', 'oa', 'oo']);
    }
    
    if (focus.contains('consonant') || focus.contains('blend')) {
      focusPhonemes.addAll(['bl', 'br', 'cl', 'cr', 'dr', 'fl', 'fr', 'gl', 'gr', 'pl', 'pr', 'sp', 'st', 'tr']);
    }
    
    if (focus.contains('digraph')) {
      focusPhonemes.addAll(['ch', 'sh', 'th', 'ph', 'wh', 'ng']);
    }

    // Add specific phonemes mentioned in profile
    for (final phoneme in _allPhonemes) {
      if (focus.contains(phoneme)) {
        focusPhonemes.add(phoneme);
      }
    }

    return focusPhonemes.toSet().toList(); // Remove duplicates
  }

  /// Select phonemes for game based on focus areas and difficulty
  List<String> _selectPhonemesForGame(List<String> focusPhonemes, int rounds, int difficulty) {
    final selectedPhonemes = <String>[];
    
    if (focusPhonemes.isNotEmpty) {
      // Emphasize focus areas (70% focus, 30% variety)
      final focusCount = (rounds * 0.7).round();
      final varietyCount = rounds - focusCount;
      
      // Add focus phonemes
      focusPhonemes.shuffle(_random);
      for (int i = 0; i < focusCount && i < focusPhonemes.length; i++) {
        selectedPhonemes.add(focusPhonemes[i]);
      }
      
      // Fill remaining with variety based on difficulty
      final varietyPhonemes = _getPhonemesForDifficulty(difficulty)
          .where((p) => !selectedPhonemes.contains(p))
          .toList();
      varietyPhonemes.shuffle(_random);
      
      for (int i = 0; i < varietyCount && i < varietyPhonemes.length; i++) {
        selectedPhonemes.add(varietyPhonemes[i]);
      }
    } else {
      // No specific focus - use difficulty-appropriate phonemes
      final availablePhonemes = _getPhonemesForDifficulty(difficulty);
      availablePhonemes.shuffle(_random);
      selectedPhonemes.addAll(availablePhonemes.take(rounds));
    }

    // Ensure we have enough phonemes
    while (selectedPhonemes.length < rounds) {
      final basicPhonemes = ['b', 'c', 'd', 'f', 'g'];
      selectedPhonemes.add(basicPhonemes[_random.nextInt(basicPhonemes.length)]);
    }

    selectedPhonemes.shuffle(_random); // Final shuffle for variety
    return selectedPhonemes.take(rounds).toList();
  }

  /// Get phonemes appropriate for difficulty level
  List<String> _getPhonemesForDifficulty(int difficulty) {
    switch (difficulty) {
      case 1: // Beginner
        return ['b', 'c', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'm', 'n', 'p', 'r', 's', 't'];
      case 2: // Intermediate  
        return ['b', 'c', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'm', 'n', 'p', 'r', 's', 't', 'v', 'w', 'y', 'z', 'ch', 'sh', 'th'];
      case 3: // Advanced
        return _allPhonemes;
      default:
        return ['b', 'c', 'd', 'f', 'g'];
    }
  }



  /// Generate all phonemes in one batch (like sentence fixer does)
  Future<List<SoundSet>> _generateAllPhonemesInBatch(
    List<String> phonemes,
    int difficulty,
    LearnerProfile? profile,
  ) async {
    final aiService = getAIInferenceService();
    if (aiService == null) {
      developer.log('❌ AI service not available', name: 'dyslexic_ai.phonics_ai');
      throw Exception('AI service not available');
    }

    try {
      // Build prompt for all phonemes at once
      final prompt = _buildBatchPrompt(phonemes, difficulty, profile);
      
      developer.log('📝 Batch AI generation for phonemes: $phonemes', name: 'dyslexic_ai.phonics_ai');

      // Single AI call for all phonemes (like sentence fixer)
      final response = await aiService.generateResponse(
        prompt,
        activity: AIActivity.phonicsGeneration,
      );

      developer.log('✅ Batch AI response received (${response.length} chars)', name: 'dyslexic_ai.phonics_ai');

      // Parse batch response
      final soundSets = _parseBatchResponse(response, phonemes, difficulty);
      
      developer.log('🎯 Parsed ${soundSets.length} sound sets from batch', name: 'dyslexic_ai.phonics_ai');
      
      return soundSets;

    } catch (e) {
      developer.log('❌ Batch generation failed: $e', name: 'dyslexic_ai.phonics_ai');
      rethrow;
    }
  }

  /// Build prompt for batch generation of all phonemes
  String _buildBatchPrompt(List<String> phonemes, int difficulty, LearnerProfile? profile) {
    final difficultyLevel = _getDifficultyName(difficulty);
    final wordCount = _getWordCountForDifficulty(difficulty);
    
    return '''Generate word lists for ${phonemes.length} phonemes at $difficultyLevel level.

For each phoneme, provide:
- 1 correct word starting with that phoneme
- ${wordCount - 1} incorrect words starting with different sounds

Phonemes to generate: ${phonemes.join(', ')}

Example for "b" phoneme:
{
  "phoneme": "b",
  "correct_words": ["ball"],
  "incorrect_words": ["cat", "dog", "fish"],
  "pronunciation_hint": "Make the 'buh' sound like in 'ball'"
}

Generate JSON array with one object per phoneme:
[
  {
    "phoneme": "${phonemes[0]}",
    "correct_words": ["word_starting_with_${phonemes[0]}"],
    "incorrect_words": ["word1", "word2", "word3"],
    "pronunciation_hint": "how to pronounce ${phonemes[0]}"
  },
  ... (continue for all phonemes)
]''';
  }

  /// Parse batch response into sound sets
  List<SoundSet> _parseBatchResponse(String response, List<String> phonemes, int difficulty) {
    try {
      // Clean response to extract JSON
      String jsonStr = response.trim();
      
      // Remove markdown code blocks
      if (jsonStr.contains('```')) {
        final codeBlockMatch = RegExp(r'```(?:json)?\s*\n(.*?)\n\s*```', dotAll: true).firstMatch(jsonStr);
        if (codeBlockMatch != null) {
          jsonStr = codeBlockMatch.group(1)?.trim() ?? jsonStr;
        }
      }
      
      // Try to find JSON array
      final jsonMatch = RegExp(r'\[.*\]', dotAll: true).firstMatch(jsonStr);
      if (jsonMatch != null) {
        jsonStr = jsonMatch.group(0)!;
      }
      
      final List<dynamic> jsonArray = json.decode(jsonStr);
      final soundSets = <SoundSet>[];
      final allWordsUsed = <String>{};
      
      for (int i = 0; i < jsonArray.length && i < phonemes.length; i++) {
        final item = jsonArray[i];
        if (item is Map<String, dynamic>) {
          final phoneme = phonemes[i]; // Use expected phoneme order
          final soundSet = _createSoundSetFromBatchItem(item, phoneme, difficulty, i);
          if (soundSet != null) {
            // Check for global duplicates across all phonemes
            for (final wordOption in soundSet.words) {
              if (allWordsUsed.contains(wordOption.word.toLowerCase())) {
                developer.log('🚨 GLOBAL DUPLICATE: "${wordOption.word}" appears in multiple phonemes!', name: 'dyslexic_ai.phonics_ai');
              } else {
                allWordsUsed.add(wordOption.word.toLowerCase());
              }
            }
            
            soundSets.add(soundSet);
            developer.log('✅ Created sound set for: $phoneme', name: 'dyslexic_ai.phonics_ai');
          } else {
            developer.log('❌ Failed to create sound set for: $phoneme', name: 'dyslexic_ai.phonics_ai');
          }
        }
      }
      
      // Final summary of all words used
      developer.log('📋 TOTAL WORDS GENERATED: ${allWordsUsed.length} unique words across ${soundSets.length} phonemes', name: 'dyslexic_ai.phonics_ai');
      developer.log('📝 ALL WORDS: ${allWordsUsed.toList().join(', ')}', name: 'dyslexic_ai.phonics_ai');
      
      return soundSets;
      
    } catch (e) {
      developer.log('❌ Failed to parse batch response: $e', name: 'dyslexic_ai.phonics_ai');
      return [];
    }
  }

  /// Create sound set from batch item
  SoundSet? _createSoundSetFromBatchItem(Map<String, dynamic> item, String phoneme, int difficulty, int index) {
    try {
      final correctWords = (item['correct_words'] as List?)?.cast<String>() ?? [];
      final incorrectWords = (item['incorrect_words'] as List?)?.cast<String>() ?? [];
      final pronunciationHint = item['pronunciation_hint'] as String? ?? '';
      
      // Validate word distribution
      if (correctWords.length != 1) {
        developer.log('❌ Invalid correct word count for $phoneme: ${correctWords.length}', name: 'dyslexic_ai.phonics_ai');
        return null;
      }
      
      if (incorrectWords.length < 3) {
        developer.log('❌ Insufficient incorrect words for $phoneme: ${incorrectWords.length}', name: 'dyslexic_ai.phonics_ai');
        return null;
      }
      
      // Create word options
      final wordOptions = <WordOption>[];
      
      // Add correct word
      final correctWord = correctWords[0];
      wordOptions.add(WordOption(
        word: correctWord,
        imageUrl: '',
        isCorrect: true,
        phoneme: phoneme,
      ));
      
      // Add incorrect words
      final selectedIncorrectWords = incorrectWords.take(3).toList();
      for (final word in selectedIncorrectWords) {
        wordOptions.add(WordOption(
          word: word,
          imageUrl: '',
          isCorrect: false,
          phoneme: word.isNotEmpty ? word[0] : 'x',
        ));
      }
      
      // Log detailed word information BEFORE shuffling
      developer.log('🎯 PHONEME "$phoneme" WORDS:', name: 'dyslexic_ai.phonics_ai');
      developer.log('   ✅ CORRECT: "$correctWord" (starts with "$phoneme")', name: 'dyslexic_ai.phonics_ai');
      for (int i = 0; i < selectedIncorrectWords.length; i++) {
        final incorrectWord = selectedIncorrectWords[i];
        final actualStartingSound = incorrectWord.isNotEmpty ? incorrectWord[0].toLowerCase() : '?';
        developer.log('   ❌ INCORRECT ${i+1}: "$incorrectWord" (starts with "$actualStartingSound")', name: 'dyslexic_ai.phonics_ai');
      }
      
      // Validate no duplicates
      final allWords = [correctWord, ...selectedIncorrectWords];
      final uniqueWords = allWords.toSet();
      if (uniqueWords.length != allWords.length) {
        developer.log('⚠️ DUPLICATE WORDS DETECTED for phoneme "$phoneme": $allWords', name: 'dyslexic_ai.phonics_ai');
      }
      
      // Validate correct word starts with phoneme
      if (!correctWord.toLowerCase().startsWith(phoneme.toLowerCase())) {
        developer.log('❌ WRONG CORRECT WORD: "$correctWord" does not start with "$phoneme"', name: 'dyslexic_ai.phonics_ai');
      }
      
      // Shuffle word options to randomize answer position
      wordOptions.shuffle(_random);
      
      // Log final shuffled order
      developer.log('🔀 SHUFFLED ORDER for "$phoneme": ${wordOptions.map((w) => '${w.word}${w.isCorrect ? " (CORRECT)" : ""}').join(', ')}', name: 'dyslexic_ai.phonics_ai');
      
      return SoundSet(
        id: 'ai_batch_${phoneme}_$index',
        name: '${phoneme.toUpperCase()} Sounds',
        sound: _getPhonemeSound(phoneme),
        phoneme: phoneme,
        type: _getPhonemeType(phoneme),
        difficulty: difficulty,
        words: wordOptions,
        description: pronunciationHint.isNotEmpty ? pronunciationHint : _getStaticPronunciationHint(phoneme),
      );
      
    } catch (e) {
      developer.log('❌ Error creating sound set from batch item for $phoneme: $e', name: 'dyslexic_ai.phonics_ai');
      return null;
    }
  }

  /// Build AI prompt for phonics word generation
  Future<String> _buildPhonicsPrompt(String phoneme, int difficulty, LearnerProfile? profile) async {
    try {
      // Determine template based on phoneme type
      final templateName = _getTemplateForPhoneme(phoneme);
      final tmpl = await PromptLoader.load('phonics_generation', templateName);
      
      // Build context from profile
      final difficultyLevel = _getDifficultyName(difficulty);
      final wordCount = _getWordCountForDifficulty(difficulty);
      final confidenceLevel = profile?.confidence ?? 'medium';
      
      final variables = {
        'phoneme': phoneme,
        'difficulty_level': difficultyLevel,
        'word_count': wordCount.toString(),
        'confidence_level': confidenceLevel,
        'pronunciation_guide': _getPhonemeGuide(phoneme),
      };
      
      return PromptLoader.fill(tmpl, variables);
      
    } catch (e) {
      developer.log('❌ Failed to build phonics prompt: $e', name: 'dyslexic_ai.phonics_ai');
      return _buildFallbackPrompt(phoneme, difficulty);
    }
  }

  /// Get template name based on phoneme type
  String _getTemplateForPhoneme(String phoneme) {
    if (phoneme.length == 1 && 'aeiou'.contains(phoneme)) {
      return 'vowel_generation.tmpl';
    } else if (phoneme.length > 1) {
      // Consonant digraphs
      if (['ch', 'sh', 'th', 'ph', 'wh', 'ng', 'ck'].contains(phoneme)) {
        return 'digraph_generation.tmpl';
      }
      // Vowel digraphs (two letters making one vowel sound)
      else if (['ai', 'ay', 'ea', 'ee', 'ie', 'oa', 'ow', 'oo', 'ou', 'ue', 'ui'].contains(phoneme)) {
        return 'digraph_generation.tmpl';
      }
      // Consonant blends (two consonants pronounced separately)
      else {
        return 'blend_generation.tmpl';
      }
    } else {
      return 'consonant_generation.tmpl';
    }
  }

  /// Fallback prompt when template loading fails
  String _buildFallbackPrompt(String phoneme, int difficulty) {
    final wordCount = _getWordCountForDifficulty(difficulty);
    final incorrectCount = wordCount - 1;
    
    return '''Generate $wordCount simple words for "$phoneme" sound:

Requirements:
- 1 word starting with "$phoneme" sound (correct answer)
- $incorrectCount words starting with different sounds (incorrect options)

Example for "b" sound:
{
  "correct_words": ["ball"],
  "incorrect_words": ["cat", "dog", "fish"],
  "pronunciation_hint": "Make the 'buh' sound like in 'ball'"
}

Generate actual words for "$phoneme" sound in JSON format:
{
  "correct_words": ["actual_word_starting_with_$phoneme"],
  "incorrect_words": ["word_with_different_sound1", "word_with_different_sound2", "word_with_different_sound3"],
  "pronunciation_hint": "clear guidance for $phoneme sound"
}''';
  }

  /// Parse AI response for phonics content
  Map<String, dynamic>? _parseAIPhonicsResponse(String response, String phoneme) {
    try {
      developer.log('🔍 Parsing AI response for $phoneme: ${response.substring(0, min(200, response.length))}...', name: 'dyslexic_ai.phonics_ai');
      
      // Clean response to extract JSON
      String jsonStr = response.trim();
      
      // Remove markdown code blocks
      if (jsonStr.contains('```')) {
        final codeBlockMatch = RegExp(r'```(?:json)?\s*\n(.*?)\n\s*```', dotAll: true).firstMatch(jsonStr);
        if (codeBlockMatch != null) {
          jsonStr = codeBlockMatch.group(1)?.trim() ?? jsonStr;
          developer.log('📦 Extracted from code block: $jsonStr', name: 'dyslexic_ai.phonics_ai');
        }
      }
      
      // Try to find JSON object
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(jsonStr);
      if (jsonMatch != null) {
        jsonStr = jsonMatch.group(0)!;
        developer.log('📋 Extracted JSON: $jsonStr', name: 'dyslexic_ai.phonics_ai');
      }
      
      final jsonData = json.decode(jsonStr);
      
      if (jsonData is Map<String, dynamic>) {
        developer.log('✅ Successfully parsed AI phonics response for $phoneme: $jsonData', name: 'dyslexic_ai.phonics_ai');
        return jsonData;
      }
      
      developer.log('❌ JSON data is not a Map for $phoneme: ${jsonData.runtimeType}', name: 'dyslexic_ai.phonics_ai');
      return null;
      
    } catch (e) {
      developer.log('❌ Failed to parse AI phonics response for $phoneme: $e', name: 'dyslexic_ai.phonics_ai');
      developer.log('Raw response: $response', name: 'dyslexic_ai.phonics_ai');
      return null;
    }
  }

  /// Create SoundSet from AI-generated data
  SoundSet? _createSoundSetFromAI({
    required String phoneme,
    required Map<String, dynamic> wordData,
    required int difficulty,
    required int index,
  }) {
    try {
      final correctWords = (wordData['correct_words'] as List?)?.cast<String>() ?? [];
      final incorrectWords = (wordData['incorrect_words'] as List?)?.cast<String>() ?? [];
      final pronunciationHint = wordData['pronunciation_hint'] as String? ?? _getStaticPronunciationHint(phoneme);
      
      // Validate we have exactly 1 correct word
      if (correctWords.length != 1) {
        developer.log('❌ Need exactly 1 correct word, got ${correctWords.length} for $phoneme. Correct words: $correctWords', name: 'dyslexic_ai.phonics_ai');
        return null;
      }
      
      // Validate we have enough incorrect words
      if (incorrectWords.length < 3) {
        developer.log('❌ Need at least 3 incorrect words, got ${incorrectWords.length} for $phoneme. Incorrect words: $incorrectWords', name: 'dyslexic_ai.phonics_ai');
        return null;
      }
      
      // Create word options
      final wordOptions = <WordOption>[];
      
      // Add correct words
      for (final word in correctWords) {
        if (_isValidWord(word, phoneme)) {
          wordOptions.add(WordOption(
            word: word,
            imageUrl: '',
            isCorrect: true,
            phoneme: phoneme,
          ));
        }
      }
      
      // Add incorrect words
      for (final word in incorrectWords) {
        if (_isValidWord(word, phoneme, shouldMatch: false)) {
          wordOptions.add(WordOption(
            word: word,
            imageUrl: '',
            isCorrect: false,
            phoneme: word.isNotEmpty ? word[0] : 'x',
          ));
        }
      }
      
      // Ensure we have at least 1 correct + 3 incorrect words (minimum game size)
      final correctCount = wordOptions.where((w) => w.isCorrect).length;
      final incorrectCount = wordOptions.where((w) => !w.isCorrect).length;
      
      if (correctCount != 1 || incorrectCount < 3) {
        developer.log('❌ Invalid word distribution for $phoneme: $correctCount correct, $incorrectCount incorrect', name: 'dyslexic_ai.phonics_ai');
        return null;
      }
      
      // Shuffle word options to randomize answer position
      wordOptions.shuffle(_random);
      developer.log('🔀 Shuffled ${wordOptions.length} word options for $phoneme', name: 'dyslexic_ai.phonics_ai');
      
      return SoundSet(
        id: 'ai_${phoneme}_$index',
        name: '${phoneme.toUpperCase()} Sounds',
        sound: _getPhonemeSound(phoneme),
        phoneme: phoneme,
        type: _getPhonemeType(phoneme),
        difficulty: difficulty,
        words: wordOptions,
        description: pronunciationHint,
      );
      
    } catch (e) {
      developer.log('❌ Failed to create SoundSet from AI data for $phoneme: $e', name: 'dyslexic_ai.phonics_ai');
      return null;
    }
  }

  /// Validate if word is appropriate for phoneme
  bool _isValidWord(String word, String phoneme, {bool shouldMatch = true}) {
    if (word.trim().isEmpty || word.length > 12) return false;
    
    final cleanWord = word.toLowerCase().trim();
    final cleanPhoneme = phoneme.toLowerCase();
    final startsWithPhoneme = cleanWord.startsWith(cleanPhoneme);
    
    if (shouldMatch) {
      // For correct words: must start with phoneme
      return startsWithPhoneme;
    } else {
      // For incorrect words: more strict validation
      
      // Must not start with phoneme
      if (startsWithPhoneme) return false;
      
      // Must not contain phoneme anywhere (to avoid confusion)
      if (cleanWord.contains(cleanPhoneme)) return false;
      
      // Check for similar-sounding phonemes that could confuse learners
      if (_hasPhoneticConflict(cleanWord, cleanPhoneme)) return false;
      
      return true;
    }
  }
  
  /// Check if word has phonetic conflicts that could confuse learners
  bool _hasPhoneticConflict(String word, String targetPhoneme) {
    // Map of phonemes that sound similar and could confuse learners
    final phoneticSimilarities = {
      'b': ['p', 'd'], 'p': ['b'], 'd': ['b', 't'], 't': ['d'],
      'f': ['v', 'th'], 'v': ['f'], 's': ['z', 'sh', 'th'], 'z': ['s'],
      'ch': ['sh', 'j'], 'sh': ['ch', 's'], 'th': ['f', 's'],
      'ie': ['ee', 'ea', 'ai', 'ay'], 'ee': ['ie', 'ea'], 'ea': ['ee', 'ie'],
      'ai': ['ay', 'ie'], 'ay': ['ai', 'ie'], 'oa': ['ow', 'oo'], 'ow': ['oa'],
      'pl': ['bl', 'pr', 'br'], 'bl': ['pl', 'br'], 'br': ['pr', 'bl'],
      'fl': ['fr', 'bl'], 'fr': ['fl', 'pr'], 'cr': ['gr', 'br'], 'gr': ['cr'],
    };
    
    final similarPhonemes = phoneticSimilarities[targetPhoneme] ?? [];
    
    // Check if word starts with any similar-sounding phoneme
    for (final similar in similarPhonemes) {
      if (word.startsWith(similar)) return true;
    }
    
    return false;
  }

  /// Generate static fallback sound set
  SoundSet _generateStaticSoundSet(String phoneme, int difficulty, int index) {
    final staticWords = _getStaticWordsForPhoneme(phoneme);
    final wordCount = _getWordCountForDifficulty(difficulty);
    
    // Ensure we have 1 correct word
    final correctWords = staticWords.where((w) => w.isCorrect).toList();
    final incorrectWords = staticWords.where((w) => !w.isCorrect).toList();
    
    final gameWords = <WordOption>[];
    
    // Add 1 correct word
    if (correctWords.isNotEmpty) {
      gameWords.add(correctWords.first);
    }
    
    // Add remaining incorrect words, shuffled
    incorrectWords.shuffle(_random);
    gameWords.addAll(incorrectWords.take(wordCount - 1));
    
    // Final shuffle for game presentation
    gameWords.shuffle(_random);
    
    return SoundSet(
      id: 'static_${phoneme}_$index',
      name: '${phoneme.toUpperCase()} Sounds',
      sound: _getPhonemeSound(phoneme),
      phoneme: phoneme,
      type: _getPhonemeType(phoneme),
      difficulty: difficulty,
      words: gameWords,
      description: _getStaticPronunciationHint(phoneme),
    );
  }

  /// Get static words for phoneme (fallback content)
  List<WordOption> _getStaticWordsForPhoneme(String phoneme) {
    final staticWordMap = {
      'b': [
        WordOption(word: 'ball', imageUrl: '', isCorrect: true, phoneme: 'b'),
        WordOption(word: 'cat', imageUrl: '', isCorrect: false, phoneme: 'c'),
        WordOption(word: 'dog', imageUrl: '', isCorrect: false, phoneme: 'd'),
        WordOption(word: 'fish', imageUrl: '', isCorrect: false, phoneme: 'f'),
        WordOption(word: 'sun', imageUrl: '', isCorrect: false, phoneme: 's'),
      ],
      'c': [
        WordOption(word: 'cat', imageUrl: '', isCorrect: true, phoneme: 'c'),
        WordOption(word: 'ball', imageUrl: '', isCorrect: false, phoneme: 'b'),
        WordOption(word: 'dog', imageUrl: '', isCorrect: false, phoneme: 'd'),
        WordOption(word: 'fish', imageUrl: '', isCorrect: false, phoneme: 'f'),
        WordOption(word: 'hat', imageUrl: '', isCorrect: false, phoneme: 'h'),
      ],
      'd': [
        WordOption(word: 'dog', imageUrl: '', isCorrect: true, phoneme: 'd'),
        WordOption(word: 'ball', imageUrl: '', isCorrect: false, phoneme: 'b'),
        WordOption(word: 'cat', imageUrl: '', isCorrect: false, phoneme: 'c'),
        WordOption(word: 'fish', imageUrl: '', isCorrect: false, phoneme: 'f'),
        WordOption(word: 'sun', imageUrl: '', isCorrect: false, phoneme: 's'),
      ],
      'f': [
        WordOption(word: 'fish', imageUrl: '', isCorrect: true, phoneme: 'f'),
        WordOption(word: 'ball', imageUrl: '', isCorrect: false, phoneme: 'b'),
        WordOption(word: 'cat', imageUrl: '', isCorrect: false, phoneme: 'c'),
        WordOption(word: 'dog', imageUrl: '', isCorrect: false, phoneme: 'd'),
        WordOption(word: 'hat', imageUrl: '', isCorrect: false, phoneme: 'h'),
      ],
      'g': [
        WordOption(word: 'goat', imageUrl: '', isCorrect: true, phoneme: 'g'),
        WordOption(word: 'ball', imageUrl: '', isCorrect: false, phoneme: 'b'),
        WordOption(word: 'cat', imageUrl: '', isCorrect: false, phoneme: 'c'),
        WordOption(word: 'dog', imageUrl: '', isCorrect: false, phoneme: 'd'),
        WordOption(word: 'fish', imageUrl: '', isCorrect: false, phoneme: 'f'),
      ],
      // Add common digraphs and blends
      'ch': [
        WordOption(word: 'chair', imageUrl: '', isCorrect: true, phoneme: 'ch'),
        WordOption(word: 'ship', imageUrl: '', isCorrect: false, phoneme: 'sh'),
        WordOption(word: 'ball', imageUrl: '', isCorrect: false, phoneme: 'b'),
        WordOption(word: 'cat', imageUrl: '', isCorrect: false, phoneme: 'c'),
        WordOption(word: 'dog', imageUrl: '', isCorrect: false, phoneme: 'd'),
      ],
      'sh': [
        WordOption(word: 'ship', imageUrl: '', isCorrect: true, phoneme: 'sh'),
        WordOption(word: 'chair', imageUrl: '', isCorrect: false, phoneme: 'ch'),
        WordOption(word: 'think', imageUrl: '', isCorrect: false, phoneme: 'th'),
        WordOption(word: 'ball', imageUrl: '', isCorrect: false, phoneme: 'b'),
        WordOption(word: 'cat', imageUrl: '', isCorrect: false, phoneme: 'c'),
      ],
      'th': [
        WordOption(word: 'think', imageUrl: '', isCorrect: true, phoneme: 'th'),
        WordOption(word: 'chair', imageUrl: '', isCorrect: false, phoneme: 'ch'),
        WordOption(word: 'ship', imageUrl: '', isCorrect: false, phoneme: 'sh'),
        WordOption(word: 'ball', imageUrl: '', isCorrect: false, phoneme: 'b'),
        WordOption(word: 'cat', imageUrl: '', isCorrect: false, phoneme: 'c'),
      ],
    };
    
    return staticWordMap[phoneme] ?? [
      WordOption(word: 'word', imageUrl: '', isCorrect: true, phoneme: phoneme),
      WordOption(word: 'cat', imageUrl: '', isCorrect: false, phoneme: 'c'),
      WordOption(word: 'dog', imageUrl: '', isCorrect: false, phoneme: 'd'),
      WordOption(word: 'fish', imageUrl: '', isCorrect: false, phoneme: 'f'),
      WordOption(word: 'sun', imageUrl: '', isCorrect: false, phoneme: 's'),
    ];
  }

  /// Helper methods for phoneme properties
  String _getPhonemeSound(String phoneme) {
    final soundMap = {
      'b': 'buh', 'c': 'kuh', 'd': 'duh', 'f': 'fuh', 'g': 'guh',
      'ch': 'ch', 'sh': 'shh', 'th': 'th',
      // Add more as needed
    };
    return soundMap[phoneme] ?? '${phoneme}uh';
  }

  SoundType _getPhonemeType(String phoneme) {
    if (phoneme.length == 1 && 'aeiou'.contains(phoneme)) {
      return SoundType.vowel;
    } else if (phoneme.length > 1) {
      // Both consonant and vowel digraphs
      if (['ch', 'sh', 'th', 'ph', 'wh', 'ng', 'ck', 'ai', 'ay', 'ea', 'ee', 'ie', 'oa', 'ow', 'oo', 'ou', 'ue', 'ui'].contains(phoneme)) {
        return SoundType.digraph;
      } else {
        return SoundType.blend;
      }
    }
    return SoundType.consonant;
  }

  String _getStaticPronunciationHint(String phoneme) {
    final hintMap = {
      'b': 'Make the "buh" sound like in "ball"',
      'c': 'Make the "kuh" sound like in "cat"',
      'd': 'Make the "duh" sound like in "dog"',
      'ch': 'Put your tongue to the roof of your mouth and say "ch" like in "chair"',
      'sh': 'Put your finger to your lips and say "shh" like in "ship"',
      'th': 'Put your tongue between your teeth and say "th" like in "think"',
    };
    return hintMap[phoneme] ?? 'Practice the $phoneme sound';
  }

  String _getDifficultyName(int difficulty) {
    switch (difficulty) {
      case 1: return 'beginner';
      case 2: return 'intermediate';
      case 3: return 'advanced';
      default: return 'beginner';
    }
  }

  int _getWordCountForDifficulty(int difficulty) {
    switch (difficulty) {
      case 1: return 4; // 1 correct, 3 incorrect
      case 2: return 5; // 1 correct, 4 incorrect  
      case 3: return 6; // 1 correct, 5 incorrect
      default: return 4;
    }
  }

  String _getPhonemeGuide(String phoneme) {
    return 'The $phoneme sound';
  }

  /// Generate fallback sound sets for emergency situations
  List<SoundSet> _generateFallbackSoundSets(int rounds, int difficulty) {
    final basicPhonemes = ['b', 'c', 'd', 'f', 'g'];
    final soundSets = <SoundSet>[];
    
    for (int i = 0; i < rounds && i < basicPhonemes.length; i++) {
      soundSets.add(_generateStaticSoundSet(basicPhonemes[i], difficulty, i));
    }
    
    return soundSets;
  }

  /// Track generated words to avoid immediate repetition
  void _trackGeneratedWords(String phoneme, List<String> words) {
    _phonemeWordHistory[phoneme] ??= <String>{};
    _phonemeWordHistory[phoneme]!.addAll(words.map((w) => w.toLowerCase()));
    
    // Keep history manageable - limit to last 20 words per phoneme
    if (_phonemeWordHistory[phoneme]!.length > 20) {
      final wordsList = _phonemeWordHistory[phoneme]!.toList();
      wordsList.shuffle(_random);
      _phonemeWordHistory[phoneme] = wordsList.take(15).toSet();
    }
  }

  /// Check if words are too similar to recently generated ones
  bool _areWordsRepeated(String phoneme, List<String> words) {
    final history = _phonemeWordHistory[phoneme] ?? <String>{};
    final newWords = words.map((w) => w.toLowerCase()).toSet();
    final overlap = newWords.intersection(history);
    
    // Allow if less than 50% overlap with recent words
    return overlap.length > (newWords.length * 0.5);
  }

  /// Clear word history for a phoneme (useful for testing or reset)
  void clearWordHistory([String? phoneme]) {
    if (phoneme != null) {
      _phonemeWordHistory.remove(phoneme);
    } else {
      _phonemeWordHistory.clear();
    }
  }

  /// Get word generation statistics for debugging
  Map<String, int> getWordHistoryStats() {
    return _phonemeWordHistory.map((phoneme, words) => MapEntry(phoneme, words.length));
  }
} 