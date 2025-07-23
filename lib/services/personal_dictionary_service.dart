import 'package:hive/hive.dart';
import 'dart:developer' as developer;
import '../models/word_analysis.dart';

class PersonalDictionaryService {
  static const String _savedWordsBoxName = 'saved_words';
  static const String _recentWordsBoxName = 'recent_words';
  
  Box<Map>? _savedWordsBox;
  Box<Map>? _recentWordsBox;

  Future<void> initialize() async {
    _savedWordsBox = await Hive.openBox<Map>(_savedWordsBoxName);
    _recentWordsBox = await Hive.openBox<Map>(_recentWordsBoxName);
  }

  Future<bool> saveWord(WordAnalysis analysis) async {
    try {
      if (_savedWordsBox == null) await initialize();
      
      final savedAnalysis = analysis.copyWith(isSaved: true);
      await _savedWordsBox!.put(analysis.word, savedAnalysis.toJson());
      
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeWord(String word) async {
    try {
      if (_savedWordsBox == null) await initialize();
      
      await _savedWordsBox!.delete(word);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<WordAnalysis>> getSavedWords() async {
    try {
      if (_savedWordsBox == null) await initialize();
      
      final savedWords = <WordAnalysis>[];
      for (final entry in _savedWordsBox!.values) {
        try {
          final analysis = WordAnalysis.fromJson(Map<String, dynamic>.from(entry));
          savedWords.add(analysis);
        } catch (e) {
          developer.log('Error parsing saved word: $e', name: 'dyslexic_ai.dictionary');
        }
      }
      
      savedWords.sort((a, b) => b.analyzedAt.compareTo(a.analyzedAt));
      return savedWords;
    } catch (e) {
      return [];
    }
  }

  Future<bool> isWordSaved(String word) async {
    try {
      if (_savedWordsBox == null) await initialize();
      return _savedWordsBox!.containsKey(word);
    } catch (e) {
      return false;
    }
  }

  Future<void> addToRecentWords(WordAnalysis analysis) async {
    try {
      if (_recentWordsBox == null) await initialize();
      
      await _recentWordsBox!.put(analysis.word, analysis.toJson());
      
      final recentWordsCount = _recentWordsBox!.length;
      if (recentWordsCount > 20) {
        final oldestKeys = _recentWordsBox!.keys.take(recentWordsCount - 20).toList();
        for (final key in oldestKeys) {
          await _recentWordsBox!.delete(key);
        }
      }
      
    } catch (e) {
      developer.log('Error saving word: $e', name: 'dyslexic_ai.dictionary');
    }
  }

  Future<List<WordAnalysis>> getRecentWords() async {
    try {
      if (_recentWordsBox == null) await initialize();
      
      final recentWords = <WordAnalysis>[];
      for (final entry in _recentWordsBox!.values) {
        try {
          final analysis = WordAnalysis.fromJson(Map<String, dynamic>.from(entry));
          recentWords.add(analysis);
        } catch (e) {
          developer.log('Error parsing recent word: $e', name: 'dyslexic_ai.dictionary');
        }
      }
      
      recentWords.sort((a, b) => b.analyzedAt.compareTo(a.analyzedAt));
      return recentWords;
    } catch (e) {
      return [];
    }
  }

  Future<void> clearRecentWords() async {
    try {
      if (_recentWordsBox == null) await initialize();
      await _recentWordsBox!.clear();
    } catch (e) {
      developer.log('Error clearing recent words: $e', name: 'dyslexic_ai.dictionary');
    }
  }

  Future<WordAnalysis?> getSavedWord(String word) async {
    try {
      if (_savedWordsBox == null) await initialize();
      
      final data = _savedWordsBox!.get(word);
      if (data != null) {
        return WordAnalysis.fromJson(Map<String, dynamic>.from(data));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<int> getSavedWordsCount() async {
    try {
      if (_savedWordsBox == null) await initialize();
      return _savedWordsBox!.length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> getRecentWordsCount() async {
    try {
      if (_recentWordsBox == null) await initialize();
      return _recentWordsBox!.length;
    } catch (e) {
      return 0;
    }
  }
} 