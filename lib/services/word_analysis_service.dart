import 'dart:math';
import '../models/word_analysis.dart';

class WordAnalysisService {
  final Random _random = Random();

  Future<WordAnalysis> analyzeWord(String word) async {
    await Future.delayed(const Duration(milliseconds: 800));
    
    
    final normalizedWord = word.toLowerCase().trim();
    final syllables = _generateSyllables(normalizedWord);
    final phonemes = _generatePhonemes(normalizedWord);
    final mnemonic = _generateMnemonic(normalizedWord);
    final exampleSentence = _generateExampleSentence(normalizedWord);
    
    final analysis = WordAnalysis(
      word: normalizedWord,
      syllables: syllables,
      phonemes: phonemes,
      mnemonic: mnemonic,
      exampleSentence: exampleSentence,
      analyzedAt: DateTime.now(),
    );
    
    
    return analysis;
  }

  List<String> _generateSyllables(String word) {
    final mockedSyllables = {
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