import 'dart:math';
import 'dart:convert';
import 'dart:developer' as developer;
import '../models/word_analysis.dart';
import '../utils/service_locator.dart';
import 'global_session_manager.dart';

class WordAnalysisService {
  final Random _random = Random();

  Future<WordAnalysis> analyzeWord(String word) async {
    final normalizedWord = word.toLowerCase().trim();
    
    developer.log('🔍 Starting AI word analysis for: "$normalizedWord"', name: 'dyslexic_ai.word_doctor');
    
    try {
      // Try AI analysis first
      final aiAnalysis = await _analyzeWordWithAI(normalizedWord);
      if (aiAnalysis != null) {
        developer.log('✅ AI analysis successful for: "$normalizedWord"', name: 'dyslexic_ai.word_doctor');
        return aiAnalysis;
      }
      
      developer.log('⚠️ AI analysis failed, using fallback for: "$normalizedWord"', name: 'dyslexic_ai.word_doctor');
      
    } catch (e) {
      developer.log('❌ AI analysis error for "$normalizedWord": $e', name: 'dyslexic_ai.word_doctor');
    }
    
    // Fallback to static analysis
    return _generateStaticAnalysis(normalizedWord);
  }

  Future<WordAnalysis?> _analyzeWordWithAI(String word) async {
    final aiService = getAIInferenceService();
    if (aiService == null) {
      developer.log('❌ AI service not available for word analysis', name: 'dyslexic_ai.word_doctor');
      return null;
    }

    try {
      final prompt = _buildWordAnalysisPrompt(word);
      
      developer.log('📝 AI word analysis prompt for "$word"', name: 'dyslexic_ai.word_doctor');

      final response = await aiService.generateResponse(
        prompt,
        activity: AIActivity.wordAnalysis,
      );

      developer.log('🤖 AI response for "$word" (${response.length} chars)', name: 'dyslexic_ai.word_doctor');

      return _parseAIWordAnalysis(response, word);

    } catch (e) {
      developer.log('❌ AI word analysis failed for "$word": $e', name: 'dyslexic_ai.word_doctor');
      return null;
    }
  }

  String _buildWordAnalysisPrompt(String word) {
    return '''Analyze the word "$word" for a dyslexic learner. Provide comprehensive linguistic breakdown to help with reading and spelling.

REQUIREMENTS:
1. Break into proper syllables following English phonetic rules
2. Provide simple pronunciation guide (not complex IPA)
3. Create a memorable mnemonic or spelling trick
4. Write a simple example sentence appropriate for the word's difficulty
5. Add helpful learning tips

Example for "elephant":
{
  "syllables": ["el", "e", "phant"],
  "phonemes": ["EL", "uh", "FANT"],
  "mnemonic": "An ELephant has a giant trunk - EL-E-PHANT!",
  "example_sentence": "The big elephant walked slowly through the zoo.",
  "difficulty": "beginner",
  "tips": ["Remember: EL-E-PHANT has three parts", "Think of the trunk when you say PHANT"]
}

Analyze "$word" and return ONLY valid JSON:''';
  }

  WordAnalysis? _parseAIWordAnalysis(String response, String word) {
    try {
      // Clean response to extract JSON
      String jsonStr = response.trim();
      
      developer.log('🔍 Raw AI response for "$word": $jsonStr', name: 'dyslexic_ai.word_doctor');
      
      // Remove markdown code blocks
      if (jsonStr.contains('```')) {
        final codeBlockMatch = RegExp(r'```(?:json)?\s*\n(.*?)\n\s*```', dotAll: true).firstMatch(jsonStr);
        if (codeBlockMatch != null) {
          jsonStr = codeBlockMatch.group(1)?.trim() ?? jsonStr;
        }
      }
      
      // Try to find JSON object with better regex
      final jsonMatch = RegExp(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}', dotAll: true).firstMatch(jsonStr);
      if (jsonMatch != null) {
        jsonStr = jsonMatch.group(0)!;
      }
      
      // Clean up common JSON issues
      jsonStr = jsonStr
          .replaceAll(RegExp(r',\s*}'), '}')  // Remove trailing commas
          .replaceAll(RegExp(r',\s*]'), ']')  // Remove trailing commas in arrays
          .replaceAll(RegExp(r'[\u201c\u201d]'), '"')  // Replace smart quotes with regular quotes
          .replaceAll(RegExp(r'[\u2018\u2019]'), "'");  // Replace smart apostrophes
      
      developer.log('🧹 Cleaned JSON for "$word": $jsonStr', name: 'dyslexic_ai.word_doctor');
      
      final Map<String, dynamic> data = json.decode(jsonStr);
      
      // Extract and validate data
      final syllables = (data['syllables'] as List?)?.cast<String>() ?? [];
      final phonemes = (data['phonemes'] as List?)?.cast<String>() ?? [];
      final mnemonic = data['mnemonic'] as String? ?? '';
      final exampleSentence = data['example_sentence'] as String? ?? '';
      final tips = (data['tips'] as List?)?.cast<String>() ?? [];
      
      // Basic validation
      if (syllables.isEmpty || phonemes.isEmpty || mnemonic.isEmpty) {
        developer.log('❌ AI response missing required fields for "$word"', name: 'dyslexic_ai.word_doctor');
        return null;
      }
      
      // Log detailed analysis
      developer.log('🎯 AI ANALYSIS for "$word":', name: 'dyslexic_ai.word_doctor');
      developer.log('   📝 Syllables: ${syllables.join("-")}', name: 'dyslexic_ai.word_doctor');
      developer.log('   🔊 Phonemes: ${phonemes.join(" ")}', name: 'dyslexic_ai.word_doctor');
      developer.log('   💡 Mnemonic: $mnemonic', name: 'dyslexic_ai.word_doctor');
      developer.log('   📚 Example: $exampleSentence', name: 'dyslexic_ai.word_doctor');
      if (tips.isNotEmpty) {
        developer.log('   💭 Tips: ${tips.join("; ")}', name: 'dyslexic_ai.word_doctor');
      }
      
      return WordAnalysis(
        word: word,
        syllables: syllables,
        phonemes: phonemes,
        mnemonic: mnemonic,
        exampleSentence: exampleSentence,
        analyzedAt: DateTime.now(),
      );
      
    } catch (e) {
      developer.log('❌ Failed to parse AI word analysis for "$word": $e', name: 'dyslexic_ai.word_doctor');
      return null;
    }
  }

  WordAnalysis _generateStaticAnalysis(String word) {
    developer.log('🔄 Generating static fallback analysis for: "$word"', name: 'dyslexic_ai.word_doctor');
    
    final syllables = _generateSyllables(word);
    final phonemes = _generatePhonemes(word);
    final mnemonic = _generateMnemonic(word);
    final exampleSentence = _generateExampleSentence(word);
    
    return WordAnalysis(
      word: word,
      syllables: syllables,
      phonemes: phonemes,
      mnemonic: mnemonic,
      exampleSentence: exampleSentence,
      analyzedAt: DateTime.now(),
    );
  }

  List<String> _generateSyllables(String word) {
    final mockedSyllables = {
      'invaders': ['in', 'va', 'ders'],
      'beautiful': ['beau', 'ti', 'ful'],
      'elephant': ['el', 'e', 'phant'],
      'computer': ['com', 'pu', 'ter'],
      'wonderful': ['won', 'der', 'ful'],
      'restaurant': ['res', 'tau', 'rant'],
      'chocolate': ['choc', 'o', 'late'],
      'butterfly': ['but', 'ter', 'fly'],
      'telephone': ['tel', 'e', 'phone'],
      'magazine': ['mag', 'a', 'zine'],
      'umbrella': ['um', 'brel', 'la'],
      'vocabulary': ['vo', 'cab', 'u', 'lar', 'y'],
      'extraordinary': ['ex', 'tra', 'or', 'di', 'nar', 'y'],
      'mississippi': ['mis', 'sis', 'sip', 'pi'],
      'definitely': ['def', 'i', 'nite', 'ly'],
      'necessary': ['nec', 'es', 'sar', 'y'],
    };

    if (mockedSyllables.containsKey(word)) {
      return mockedSyllables[word]!;
    }

    return _generateGenericSyllables(word);
  }

  List<String> _generateGenericSyllables(String word) {
    if (word.length <= 3) return [word];
    if (word.length <= 6) {
      final mid = word.length ~/ 2;
      return [word.substring(0, mid), word.substring(mid)];
    }
    
    final third = word.length ~/ 3;
    return [
      word.substring(0, third),
      word.substring(third, third * 2),
      word.substring(third * 2),
    ];
  }

  List<String> _generatePhonemes(String word) {
    final mockedPhonemes = {
      'beautiful': ['/bjuː/', '/tɪ/', '/fəl/'],
      'elephant': ['/ˈel/', '/ɪ/', '/fənt/'],
      'computer': ['/kəm/', '/ˈpjuː/', '/tər/'],
      'wonderful': ['/ˈwʌn/', '/dər/', '/fəl/'],
      'restaurant': ['/ˈres/', '/tər/', '/ɒnt/'],
      'chocolate': ['/ˈtʃɒk/', '/ə/', '/lət/'],
      'butterfly': ['/ˈbʌt/', '/ər/', '/flaɪ/'],
      'telephone': ['/ˈtel/', '/ɪ/', '/foʊn/'],
      'magazine': ['/ˌmæg/', '/ə/', '/ziːn/'],
      'umbrella': ['/ʌm/', '/ˈbrel/', '/ə/'],
    };

    if (mockedPhonemes.containsKey(word)) {
      return mockedPhonemes[word]!;
    }

    final syllables = _generateSyllables(word);
    return syllables.map((syllable) => '/$syllable/').toList();
  }

  String _generateMnemonic(String word) {
    final mnemonics = {
      'beautiful': 'Remember: "Be-a-utiful" - You are beautiful!',
      'elephant': 'Think of an ELEphant with a giant PHANT-astic trunk!',
      'computer': 'A COM-puter helps you COM-pute numbers!',
      'wonderful': 'WONDERful things make you WONDER in amazement!',
      'restaurant': 'At a RESTaurant, you REST and eat delicious food!',
      'chocolate': 'CHOColate is so good, you want to CHOC on more!',
      'butterfly': 'A BUTTERfly spreads butter-smooth wings to FLY!',
      'telephone': 'A TELEphone lets you tell someone far away!',
      'magazine': 'A MAGAzine has magical stories like a mage!',
      'umbrella': 'An UMBrella keeps you dry - UM, brilliant!',
      'necessary': 'It\'s NECESSary to wear one Collar and two Sleeves (1 c, 2 s)',
      'definitely': 'DEFINitely has "finite" in it - finite means definite!',
      'mississippi': 'Mrs. M, Mrs. I, Mrs. S-S-I, Mrs. S-S-I, Mrs. P-P-I!',
    };

    if (mnemonics.containsKey(word)) {
      return mnemonics[word]!;
    }

    final templates = [
      'Think of "${word.toUpperCase()}" as breaking into smaller parts!',
      'Remember: Each part of "$word" has its own sound.',
      'Picture the word "$word" written in colorful letters!',
      'The word "$word" can be easier when you say it slowly.',
      'Break "$word" down and build it back up piece by piece!',
    ];

    return templates[_random.nextInt(templates.length)];
  }

  String _generateExampleSentence(String word) {
    final sentences = {
      'beautiful': 'The sunset over the mountains was absolutely beautiful.',
      'elephant': 'The large elephant walked slowly through the jungle.',
      'computer': 'She used her computer to write the important report.',
      'wonderful': 'What a wonderful surprise to see you here today!',
      'restaurant': 'They decided to try the new Italian restaurant downtown.',
      'chocolate': 'The rich chocolate cake was the perfect dessert.',
      'butterfly': 'A colorful butterfly landed gently on the flower.',
      'telephone': 'The telephone rang just as she was leaving the house.',
      'magazine': 'He picked up his favorite magazine to read during lunch.',
      'umbrella': 'Don\'t forget to bring an umbrella since it might rain.',
      'necessary': 'It is necessary to study hard to pass the exam.',
      'definitely': 'I will definitely be there for your birthday party.',
      'mississippi': 'The mighty Mississippi River flows through many states.',
    };

    if (sentences.containsKey(word)) {
      return sentences[word]!;
    }

    final templates = [
      'The word "$word" appears frequently in everyday conversations.',
      'Learning to spell "$word" correctly is very important.',
      'Can you use "$word" in a sentence of your own?',
      'Many people find "$word" challenging to remember.',
      'Practice saying "$word" several times to improve your pronunciation.',
    ];

    return templates[_random.nextInt(templates.length)];
  }
} 