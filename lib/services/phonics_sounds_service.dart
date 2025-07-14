import 'dart:async';
import 'dart:math';
import '../models/phonics_game.dart';
import '../services/text_to_speech_service.dart';
import '../utils/service_locator.dart';

enum PhonemeQuality {
  easy,
  moderate,
  difficult,
  vowel
}

class PhonicsSoundsService {
  static final PhonicsSoundsService _instance = PhonicsSoundsService._internal();
  factory PhonicsSoundsService() => _instance;
  PhonicsSoundsService._internal();

  late final TextToSpeechService _ttsService;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _ttsService = getIt<TextToSpeechService>();
    await _ttsService.initialize();
    _isInitialized = true;
  }

  /// Play a basic sound with standard pronunciation
  Future<void> playSound(String sound) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    await _ttsService.speak(sound);
  }

  /// Play a phoneme with phonetic pronunciation
  Future<void> playPhoneme(String phoneme) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    // Use phonetic mapping for reliable TTS pronunciation
    final soundToPlay = _phonemeToSound(phoneme);
    await _ttsService.speakWord(soundToPlay);
  }

  /// Play a phoneme with emphasis for difficult sounds
  Future<void> playPhonemeWithEmphasis(String phoneme) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    // Use phonetic mapping with slower speech rate for emphasis
    final soundToPlay = _phonemeToSound(phoneme);
    await _ttsService.speak(soundToPlay);
  }

  /// Play a word with enhanced pronunciation
  Future<void> playWord(String word) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    await _ttsService.speakWord(word);
  }

  /// Stop all speech
  Future<void> stopSpeaking() async {
    if (_isInitialized) {
      await _ttsService.stop();
    }
  }

  /// Play a sound set's phoneme with enhanced pronunciation
  Future<void> playSoundSetPhoneme(SoundSet soundSet, {bool useEmphasis = false}) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (useEmphasis) {
      await playPhonemeWithEmphasis(soundSet.phoneme);
    } else {
      await playPhoneme(soundSet.phoneme);
    }
  }

  /// Get pronunciation quality rating for a phoneme
  PhonemeQuality getPhonemeQuality(String phoneme) {
    final p = phoneme.toLowerCase();
    
    // Difficult phonemes that benefit from enhanced pronunciation
    if (['th', 'ch', 'sh', 'ph', 'wh', 'ng'].contains(p)) {
      return PhonemeQuality.difficult;
    }
    
    // Moderate phonemes
    if (['f', 'v', 's', 'z', 'r', 'l'].contains(p)) {
      return PhonemeQuality.moderate;
    }
    
    // Easy phonemes
    if (['b', 'p', 'm', 'n', 'd', 't', 'g', 'k'].contains(p)) {
      return PhonemeQuality.easy;
    }
    
    // Vowels need special treatment
    if (['a', 'e', 'i', 'o', 'u'].contains(p)) {
      return PhonemeQuality.vowel;
    }
    
    return PhonemeQuality.moderate;
  }

  /// Check if a phoneme should use emphasis for better clarity
  bool shouldUseEmphasis(String phoneme) {
    return getPhonemeQuality(phoneme) == PhonemeQuality.difficult;
  }

  /// Phonetic mapping with vowel sounds for reliable TTS pronunciation
  String _phonemeToSound(String phoneme) {
    switch (phoneme.toLowerCase()) {
      // Fricatives - shorter vowel sounds for continuous effect
      case 'f':
        return 'fuh';     // "fuh" sound - fricative
      case 's':
        return 'sss';     // "sss" sound - fricative (works well)
      case 'z':
        return 'zuh';     // "zuh" sound - fricative
      case 'v':
        return 'vuh';     // "vuh" sound - fricative
      case 'h':
        return 'huh';     // "huh" sound - fricative
      
      // Stop consonants - minimal vowel sounds
      case 'b':
        return 'buh';     // "buh" sound - stop consonant
      case 'c':
        return 'kuh';     // "kuh" sound (hard c)
      case 'd':
        return 'duh';     // "duh" sound - stop consonant
      case 'g':
        return 'guh';     // "guh" sound - stop consonant
      case 'k':
        return 'kuh';     // "kuh" sound - stop consonant
      case 'p':
        return 'puh';     // "puh" sound - stop consonant
      case 't':
        return 'tuh';     // "tuh" sound - stop consonant
      
      // Liquids and nasals - slight vowel sounds
      case 'l':
        return 'luh';     // "luh" sound - liquid
      case 'r':
        return 'ruh';     // "ruh" sound - liquid
      case 'm':
        return 'muh';     // "muh" sound - nasal
      case 'n':
        return 'nuh';     // "nuh" sound - nasal
      
      // Other consonants
      case 'j':
        return 'juh';     // "juh" sound
      case 'q':
        return 'kwuh';    // "kwuh" sound (qu combination)
      case 'w':
        return 'wuh';     // "wuh" sound - glide
      case 'x':
        return 'ksuh';    // "ksuh" sound (ks combination)
      case 'y':
        return 'yuh';     // "yuh" sound - glide
      
             // Digraphs - pure sounds for phonics education
       case 'ch':
         return 'ch';      // Pure 'ch' sound as in 'chair'
       case 'sh':
         return 'shh';     // Pure 'sh' sound as in 'ship' 
       case 'th':
         return 'th';      // Pure 'th' sound as in 'think'
       case 'ph':
         return 'fff';     // 'ph' makes pure 'f' sound
       case 'wh':
         return 'wh';      // Pure 'wh' sound as in 'where'
       case 'ng':
         return 'ng';      // Pure 'ng' sound as in 'ring'
       case 'ck':
         return 'k';       // 'ck' makes pure 'k' sound
       
       // Vowels - clear vowel sounds
       case 'a':
         return 'ah';      // Short 'a' as in 'cat'
       case 'e':
         return 'eh';      // Short 'e' as in 'bed'
       case 'i':
         return 'ih';      // Short 'i' as in 'sit'
       case 'o':
         return 'oh';      // Short 'o' as in 'hot'
       case 'u':
         return 'uh';      // Short 'u' as in 'cup'
       
       // Long vowels
       case 'aa':
       case 'a_e':
         return 'ay';      // Long 'a' as in 'cake'
       case 'ee':
       case 'e_e':
         return 'ee';      // Long 'e' as in 'feet'
       case 'ii':
       case 'i_e':
         return 'eye';     // Long 'i' as in 'kite'
       case 'oo':
       case 'o_e':
         return 'oh';      // Long 'o' as in 'boat'
       case 'uu':
       case 'u_e':
         return 'yoo';     // Long 'u' as in 'cube'
       
       // Common word patterns
       case 'ing':
         return 'ing';     // '-ing' ending
       case 'tion':
         return 'shun';    // '-tion' ending
       case 'ed':
         return 'ed';      // '-ed' ending
       case 'er':
         return 'er';      // '-er' ending
       case 'ly':
         return 'lee';     // '-ly' ending
       
       // Consonant blends - minimal pronunciation
       case 'bl':
         return 'bl';      // Pure 'bl' blend
       case 'br':
         return 'br';      // Pure 'br' blend
       case 'cl':
         return 'cl';      // Pure 'cl' blend
       case 'cr':
         return 'cr';      // Pure 'cr' blend
       case 'dr':
         return 'dr';      // Pure 'dr' blend
       case 'fl':
         return 'fl';      // Pure 'fl' blend
       case 'fr':
         return 'fr';      // Pure 'fr' blend
       case 'gl':
         return 'gl';      // Pure 'gl' blend
       case 'gr':
         return 'gr';      // Pure 'gr' blend
       case 'pl':
         return 'pl';      // Pure 'pl' blend
       case 'pr':
         return 'pr';      // Pure 'pr' blend
       case 'sc':
       case 'sk':
         return 'sk';      // Pure 'sk' blend
       case 'sl':
         return 'sl';      // Pure 'sl' blend
       case 'sm':
         return 'sm';      // Pure 'sm' blend
       case 'sn':
         return 'sn';      // Pure 'sn' blend
       case 'sp':
         return 'sp';      // Pure 'sp' blend
       case 'st':
         return 'st';      // Pure 'st' blend
       case 'sw':
         return 'sw';      // Pure 'sw' blend
       case 'tr':
         return 'tr';      // Pure 'tr' blend
       case 'tw':
         return 'tw';      // Pure 'tw' blend
       
       // Three-letter blends
       case 'scr':
         return 'scr';     // Pure 'scr' blend
       case 'spl':
         return 'spl';     // Pure 'spl' blend
       case 'spr':
         return 'spr';     // Pure 'spr' blend
       case 'str':
         return 'str';     // Pure 'str' blend
       case 'thr':
         return 'thr';     // Pure 'thr' blend
      
      default:
        return phoneme;   // Return original if not found
    }
  }

  List<SoundSet> getAllSoundSets() {
    return [
      SoundSet(
        id: 'b_sounds',
        name: 'B Sounds',
        sound: 'buh',  // Reliable TTS pronunciation
        phoneme: 'b',
        type: SoundType.consonant,
        difficulty: 1,
        description: 'Words that start with the B sound',
        words: [
          WordOption(word: 'ball', imageUrl: '', isCorrect: true, phoneme: 'b'),
          WordOption(word: 'cat', imageUrl: '', isCorrect: false, phoneme: 'c'),
          WordOption(word: 'dog', imageUrl: '', isCorrect: false, phoneme: 'd'),
          WordOption(word: 'bat', imageUrl: '', isCorrect: true, phoneme: 'b'),
          WordOption(word: 'fish', imageUrl: '', isCorrect: false, phoneme: 'f'),
          WordOption(word: 'book', imageUrl: '', isCorrect: true, phoneme: 'b'),
        ],
      ),
      SoundSet(
        id: 'c_sounds',
        name: 'C Sounds',
        sound: 'kuh',  // Reliable TTS pronunciation
        phoneme: 'c',
        type: SoundType.consonant,
        difficulty: 1,
        description: 'Words that start with the C sound',
        words: [
          WordOption(word: 'cat', imageUrl: '', isCorrect: true, phoneme: 'c'),
          WordOption(word: 'car', imageUrl: '', isCorrect: true, phoneme: 'c'),
          WordOption(word: 'ball', imageUrl: '', isCorrect: false, phoneme: 'b'),
          WordOption(word: 'cup', imageUrl: '', isCorrect: true, phoneme: 'c'),
          WordOption(word: 'dog', imageUrl: '', isCorrect: false, phoneme: 'd'),
          WordOption(word: 'cake', imageUrl: '', isCorrect: true, phoneme: 'c'),
        ],
      ),
      SoundSet(
        id: 'd_sounds',
        name: 'D Sounds',
        sound: 'duh',  // Reliable TTS pronunciation
        phoneme: 'd',
        type: SoundType.consonant,
        difficulty: 1,
        description: 'Words that start with the D sound',
        words: [
          WordOption(word: 'dog', imageUrl: '', isCorrect: true, phoneme: 'd'),
          WordOption(word: 'duck', imageUrl: '', isCorrect: true, phoneme: 'd'),
          WordOption(word: 'cat', imageUrl: '', isCorrect: false, phoneme: 'c'),
          WordOption(word: 'door', imageUrl: '', isCorrect: true, phoneme: 'd'),
          WordOption(word: 'fish', imageUrl: '', isCorrect: false, phoneme: 'f'),
          WordOption(word: 'dance', imageUrl: '', isCorrect: true, phoneme: 'd'),
        ],
      ),
      SoundSet(
        id: 'f_sounds',
        name: 'F Sounds',
        sound: 'fuh',  // Reliable TTS pronunciation
        phoneme: 'f',
        type: SoundType.consonant,
        difficulty: 1,
        description: 'Words that start with the F sound',
        words: [
          WordOption(word: 'fish', imageUrl: '', isCorrect: true, phoneme: 'f'),
          WordOption(word: 'fox', imageUrl: '', isCorrect: true, phoneme: 'f'),
          WordOption(word: 'ball', imageUrl: '', isCorrect: false, phoneme: 'b'),
          WordOption(word: 'fire', imageUrl: '', isCorrect: true, phoneme: 'f'),
          WordOption(word: 'dog', imageUrl: '', isCorrect: false, phoneme: 'd'),
          WordOption(word: 'flag', imageUrl: '', isCorrect: true, phoneme: 'f'),
        ],
      ),
      SoundSet(
        id: 'g_sounds',
        name: 'G Sounds',
        sound: 'guh',  // Reliable TTS pronunciation
        phoneme: 'g',
        type: SoundType.consonant,
        difficulty: 1,
        description: 'Words that start with the G sound',
        words: [
          WordOption(word: 'goat', imageUrl: '', isCorrect: true, phoneme: 'g'),
          WordOption(word: 'game', imageUrl: '', isCorrect: true, phoneme: 'g'),
          WordOption(word: 'cat', imageUrl: '', isCorrect: false, phoneme: 'c'),
          WordOption(word: 'girl', imageUrl: '', isCorrect: true, phoneme: 'g'),
          WordOption(word: 'hat', imageUrl: '', isCorrect: false, phoneme: 'h'),
          WordOption(word: 'green', imageUrl: '', isCorrect: true, phoneme: 'g'),
        ],
      ),
      SoundSet(
        id: 'ch_sounds',
        name: 'CH Sounds',
        sound: 'ch',  // Correct phoneme pronunciation
        phoneme: 'ch',
        type: SoundType.digraph,
        difficulty: 2,
        description: 'Words that start with the CH sound',
        words: [
          WordOption(word: 'chair', imageUrl: '', isCorrect: true, phoneme: 'ch'),
          WordOption(word: 'cheese', imageUrl: '', isCorrect: true, phoneme: 'ch'),
          WordOption(word: 'dog', imageUrl: '', isCorrect: false, phoneme: 'd'),
          WordOption(word: 'chicken', imageUrl: '', isCorrect: true, phoneme: 'ch'),
          WordOption(word: 'sun', imageUrl: '', isCorrect: false, phoneme: 's'),
          WordOption(word: 'child', imageUrl: '', isCorrect: true, phoneme: 'ch'),
        ],
      ),
      SoundSet(
        id: 'sh_sounds',
        name: 'SH Sounds',
        sound: 'shh',  // Correct phoneme pronunciation
        phoneme: 'sh',
        type: SoundType.digraph,
        difficulty: 2,
        description: 'Words that start with the SH sound',
        words: [
          WordOption(word: 'ship', imageUrl: '', isCorrect: true, phoneme: 'sh'),
          WordOption(word: 'shoe', imageUrl: '', isCorrect: true, phoneme: 'sh'),
          WordOption(word: 'cat', imageUrl: '', isCorrect: false, phoneme: 'c'),
          WordOption(word: 'shark', imageUrl: '', isCorrect: true, phoneme: 'sh'),
          WordOption(word: 'tree', imageUrl: '', isCorrect: false, phoneme: 't'),
          WordOption(word: 'shell', imageUrl: '', isCorrect: true, phoneme: 'sh'),
        ],
      ),
      SoundSet(
        id: 'th_sounds',
        name: 'TH Sounds',
        sound: 'th',  // Correct phoneme pronunciation
        phoneme: 'th',
        type: SoundType.digraph,
        difficulty: 2,
        description: 'Words that start with the TH sound',
        words: [
          WordOption(word: 'thumb', imageUrl: '', isCorrect: true, phoneme: 'th'),
          WordOption(word: 'think', imageUrl: '', isCorrect: true, phoneme: 'th'),
          WordOption(word: 'cat', imageUrl: '', isCorrect: false, phoneme: 'c'),
          WordOption(word: 'three', imageUrl: '', isCorrect: true, phoneme: 'th'),
          WordOption(word: 'dog', imageUrl: '', isCorrect: false, phoneme: 'd'),
          WordOption(word: 'throw', imageUrl: '', isCorrect: true, phoneme: 'th'),
        ],
      ),
    ];
  }

  List<SoundSet> getSoundSetsByDifficulty(int difficulty) {
    return getAllSoundSets().where((set) => set.difficulty == difficulty).toList();
  }

  SoundSet? getSoundSetById(String id) {
    try {
      return getAllSoundSets().firstWhere((set) => set.id == id);
    } catch (e) {
      return null;
    }
  }

  List<WordOption> generateGameOptions(SoundSet soundSet, {int optionsCount = 4}) {
    List<WordOption> correctOptions = soundSet.words.where((w) => w.isCorrect).toList();
    List<WordOption> incorrectOptions = soundSet.words.where((w) => !w.isCorrect).toList();

    List<WordOption> gameOptions = [];
    
    // Always add one correct option
    if (correctOptions.isNotEmpty) {
      correctOptions.shuffle();
      gameOptions.add(correctOptions.first);
    }

    // Shuffle incorrect options for better variety
    incorrectOptions.shuffle();
    
    // Fill remaining slots with incorrect options
    int remainingSlots = optionsCount - gameOptions.length;
    
    // If we don't have enough incorrect options, create additional ones from other sound sets
    if (incorrectOptions.length < remainingSlots) {
      final additionalOptions = _generateAdditionalIncorrectOptions(soundSet, remainingSlots - incorrectOptions.length);
      incorrectOptions.addAll(additionalOptions);
    }
    
    gameOptions.addAll(incorrectOptions.take(remainingSlots));

    // Ensure we have exactly the requested number of options
    while (gameOptions.length < optionsCount && correctOptions.length > 1) {
      // Add another correct option if we're still short (rare case)
      for (final option in correctOptions) {
        if (!gameOptions.any((existing) => existing.word == option.word)) {
          gameOptions.add(option);
          break;
        }
      }
    }

    // Final shuffle with improved randomization
    for (int i = gameOptions.length - 1; i > 0; i--) {
      final j = Random().nextInt(i + 1);
      final temp = gameOptions[i];
      gameOptions[i] = gameOptions[j];
      gameOptions[j] = temp;
    }
    
    return gameOptions.take(optionsCount).toList();
  }

  List<WordOption> _generateAdditionalIncorrectOptions(SoundSet currentSoundSet, int needed) {
    final additionalOptions = <WordOption>[];
    final allSoundSets = getAllSoundSets();
    final otherSoundSets = allSoundSets.where((set) => set.id != currentSoundSet.id).toList();
    
    // Pool of additional incorrect words from other sound sets
    final wordPool = <String>[
      'hat', 'bat', 'rat', 'sat', 'mat', 'pat',
      'pig', 'big', 'dig', 'fig', 'wig', 'jig',
      'sun', 'run', 'fun', 'gun', 'bun', 'nun',
      'red', 'bed', 'led', 'fed', 'wed', 'shed',
      'top', 'hop', 'pop', 'mop', 'cop', 'shop',
    ];
    
    // First try to get words from other sound sets
    for (final soundSet in otherSoundSets) {
      for (final word in soundSet.words) {
        if (!word.isCorrect && additionalOptions.length < needed) {
          // Make sure it doesn't start with the current phoneme
          if (!word.word.toLowerCase().startsWith(currentSoundSet.phoneme.toLowerCase())) {
            additionalOptions.add(WordOption(
              word: word.word,
              imageUrl: word.imageUrl,
              isCorrect: false,
              phoneme: word.phoneme,
            ));
          }
        }
      }
      if (additionalOptions.length >= needed) break;
    }
    
    // If still need more, use the word pool
    if (additionalOptions.length < needed) {
      wordPool.shuffle();
      for (final word in wordPool) {
        if (additionalOptions.length >= needed) break;
        if (!word.toLowerCase().startsWith(currentSoundSet.phoneme.toLowerCase()) &&
            !additionalOptions.any((opt) => opt.word == word)) {
          additionalOptions.add(WordOption(
            word: word,
            imageUrl: '',
            isCorrect: false,
            phoneme: word[0], // First letter as phoneme
          ));
        }
      }
    }
    
    return additionalOptions;
  }

  List<SoundSet> generateRandomSoundSets(int count, {int? difficulty}) {
    List<SoundSet> availableSets = difficulty != null 
        ? getSoundSetsByDifficulty(difficulty)
        : getAllSoundSets();
    
    availableSets.shuffle();
    return availableSets.take(count).toList();
  }

  void dispose() {
    if (_isInitialized) {
      _ttsService.stop();
    }
  }
} 