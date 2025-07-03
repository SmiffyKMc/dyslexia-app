import 'package:hive/hive.dart';
import '../models/word_analysis.dart';

class PersonalDictionaryService {
  static const String _savedWordsBoxName = 'saved_words';
  static const String _recentWordsBoxName = 'recent_words';
  
  Box<Map>? _savedWordsBox;
  Box<Map>? _recentWordsBox;

  Future<void> initialize() async {
    _savedWordsBox = await Hive.openBox<Map>(_savedWordsBoxName);
    _recentWordsBox = await Hive.openBox<Map>(_recentWordsBoxName);
    print('📚 Personal Dictionary Service initialized');
  }

  Future<bool> saveWord(WordAnalysis analysis) async {
    try {
      if (_savedWordsBox == null) await initialize();
      
      final savedAnalysis = analysis.copyWith(isSaved: true);
      await _savedWordsBox!.put(analysis.word, savedAnalysis.toJson());
      
      print('💾 Saved word to personal dictionary: "${analysis.word}"');
      return true;
    } catch (e) {
      print('❌ Failed to save word: $e');
      return false;
    }
  }

  Future<bool> removeWord(String word) async {
    try {
      if (_savedWordsBox == null) await initialize();
      
      await _savedWordsBox!.delete(word);
      print('🗑️ Removed word from personal dictionary: "$word"');
      return true;
    } catch (e) {
      print('❌ Failed to remove word: $e');
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
          print('⚠️ Failed to parse saved word: $e');
        }
      }
      
      savedWords.sort((a, b) => b.analyzedAt.compareTo(a.analyzedAt));
      print('📚 Retrieved ${savedWords.length} saved words');
      return savedWords;
    } catch (e) {
      print('❌ Failed to get saved words: $e');
      return [];
    }
  }

  Future<bool> isWordSaved(String word) async {
    try {
      if (_savedWordsBox == null) await initialize();
      return _savedWordsBox!.containsKey(word);
    } catch (e) {
      print('❌ Failed to check if word is saved: $e');
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
      
      print('📝 Added to recent words: "${analysis.word}"');
    } catch (e) {
      print('❌ Failed to add to recent words: $e');
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
          print('⚠️ Failed to parse recent word: $e');
        }
      }
      
      recentWords.sort((a, b) => b.analyzedAt.compareTo(a.analyzedAt));
      print('📝 Retrieved ${recentWords.length} recent words');
      return recentWords;
    } catch (e) {
      print('❌ Failed to get recent words: $e');
      return [];
    }
  }

  Future<void> clearRecentWords() async {
    try {
      if (_recentWordsBox == null) await initialize();
      await _recentWordsBox!.clear();
      print('🗑️ Cleared recent words');
    } catch (e) {
      print('❌ Failed to clear recent words: $e');
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
      print('❌ Failed to get saved word: $e');
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