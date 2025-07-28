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
      final prompt = await _buildBatchPrompt(phonemes, difficulty, profile);
      
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

  Future<String> _buildBatchPrompt(List<String> phonemes, int difficulty, LearnerProfile? profile) async {
    final difficultyLevel = _getDifficultyName(difficulty);
    final wordCount = _getWordCountForDifficulty(difficulty);
    
    final variables = <String, String>{
      'phoneme_count': phonemes.length.toString(),
      'difficulty_level': difficultyLevel,
      'incorrect_count': (wordCount - 1).toString(),
      'phonemes_list': phonemes.join(', '),
      'first_phoneme': phonemes.isNotEmpty ? phonemes[0] : 'b',
    };
    
    final template = await PromptLoader.load('phonics_generation', 'batch_generation.tmpl');
    return PromptLoader.fill(template, variables);
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



  /// Generate fallback sound sets for emergency situations
  List<SoundSet> _generateFallbackSoundSets(int rounds, int difficulty) {
    final basicPhonemes = ['b', 'c', 'd', 'f', 'g'];
    final soundSets = <SoundSet>[];
    
    for (int i = 0; i < rounds && i < basicPhonemes.length; i++) {
      soundSets.add(_generateStaticSoundSet(basicPhonemes[i], difficulty, i));
    }
    
    return soundSets;
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