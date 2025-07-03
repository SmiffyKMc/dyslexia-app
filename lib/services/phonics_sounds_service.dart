import 'dart:async';
import 'dart:math';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/phonics_game.dart';

class PhonicsSoundsService {
  static final PhonicsSoundsService _instance = PhonicsSoundsService._internal();
  factory PhonicsSoundsService() => _instance;
  PhonicsSoundsService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _isTtsReady = false;

  Future<void> initialize() async {
    await _configureTts();
    _isTtsReady = true;
  }

  Future<void> _configureTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> playSound(String sound) async {
    if (!_isTtsReady) {
      await initialize();
    }
    
    await _tts.speak(sound);
  }

  Future<void> playPhoneme(String phoneme) async {
    if (!_isTtsReady) {
      await initialize();
    }
    
    String soundToPlay = _phonemeToSound(phoneme);
    await _tts.speak(soundToPlay);
  }

  Future<void> playWord(String word) async {
    if (!_isTtsReady) {
      await initialize();
    }
    
    await _tts.speak(word);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
  }

  String _phonemeToSound(String phoneme) {
    switch (phoneme.toLowerCase()) {
      case 'b':
        return 'buh';
      case 'c':
        return 'kuh';
      case 'd':
        return 'duh';
      case 'f':
        return 'fuh';
      case 'g':
        return 'guh';
      case 'h':
        return 'huh';
      case 'j':
        return 'juh';
      case 'k':
        return 'kuh';
      case 'l':
        return 'luh';
      case 'm':
        return 'muh';
      case 'n':
        return 'nuh';
      case 'p':
        return 'puh';
      case 'q':
        return 'kwuh';
      case 'r':
        return 'ruh';
      case 's':
        return 'sss';
      case 't':
        return 'tuh';
      case 'v':
        return 'vuh';
      case 'w':
        return 'wuh';
      case 'x':
        return 'ksss';
      case 'y':
        return 'yuh';
      case 'z':
        return 'zzz';
      case 'ch':
        return 'chuh';
      case 'sh':
        return 'shuh';
      case 'th':
        return 'thuh';
      case 'ph':
        return 'fuh';
      case 'wh':
        return 'whuh';
      default:
        return phoneme;
    }
  }

  List<SoundSet> getAllSoundSets() {
    return [
      SoundSet(
        id: 'b_sounds',
        name: 'B Sounds',
        sound: 'buh',
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
        sound: 'kuh',
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
        sound: 'duh',
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
        sound: 'fuh',
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
        sound: 'guh',
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
        sound: 'chuh',
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
        sound: 'shuh',
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
        sound: 'thuh',
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
    
    if (correctOptions.isNotEmpty) {
      gameOptions.add(correctOptions[Random().nextInt(correctOptions.length)]);
    }

    incorrectOptions.shuffle();
    int remainingSlots = optionsCount - gameOptions.length;
    gameOptions.addAll(incorrectOptions.take(remainingSlots));

    gameOptions.shuffle();
    return gameOptions;
  }

  List<SoundSet> generateRandomSoundSets(int count, {int? difficulty}) {
    List<SoundSet> availableSets = difficulty != null 
        ? getSoundSetsByDifficulty(difficulty)
        : getAllSoundSets();
    
    availableSets.shuffle();
    return availableSets.take(count).toList();
  }

  void dispose() {
    _tts.stop();
  }
} 