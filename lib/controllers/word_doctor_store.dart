import 'package:mobx/mobx.dart';
import '../models/word_analysis.dart';
import '../services/word_analysis_service.dart';
import '../services/personal_dictionary_service.dart';
import '../services/text_to_speech_service.dart';

part 'word_doctor_store.g.dart';

class WordDoctorStore = _WordDoctorStore with _$WordDoctorStore;

abstract class _WordDoctorStore with Store {
  final WordAnalysisService _analysisService;
  final PersonalDictionaryService _dictionaryService;
  final TextToSpeechService _ttsService;

  _WordDoctorStore({
    required WordAnalysisService analysisService,
    required PersonalDictionaryService dictionaryService,
    required TextToSpeechService ttsService,
  })  : _analysisService = analysisService,
        _dictionaryService = dictionaryService,
        _ttsService = ttsService {
    _initialize();
  }

  @observable
  WordAnalysis? currentAnalysis;

  @observable
  ObservableList<WordAnalysis> savedWords = ObservableList<WordAnalysis>();

  @observable
  ObservableList<WordAnalysis> recentWords = ObservableList<WordAnalysis>();

  @observable
  bool isAnalyzing = false;

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  String inputWord = '';

  @computed
  bool get canAnalyze => inputWord.trim().isNotEmpty && !isAnalyzing;

  @computed
  bool get hasCurrentAnalysis => currentAnalysis != null;

  @computed
  bool get isCurrentWordSaved => currentAnalysis?.isSaved ?? false;

  @computed
  int get savedWordsCount => savedWords.length;

  @computed
  int get recentWordsCount => recentWords.length;

  Future<void> _initialize() async {
    await _loadSavedWords();
    await _loadRecentWords();
  }

  @action
  void setInputWord(String word) {
    inputWord = word;
    errorMessage = null;
  }

  @action
  Future<void> analyzeCurrentWord() async {
    if (!canAnalyze) return;

    final wordToAnalyze = inputWord.trim();
    print('🔍 Starting analysis for: "$wordToAnalyze"');

    isAnalyzing = true;
    errorMessage = null;

    try {
      final analysis = await _analysisService.analyzeWord(wordToAnalyze);
      
      final isSaved = await _dictionaryService.isWordSaved(wordToAnalyze);
      currentAnalysis = analysis.copyWith(isSaved: isSaved);
      
      await _dictionaryService.addToRecentWords(currentAnalysis!);
      await _loadRecentWords();
      
      print('🔍 Analysis completed successfully');
    } catch (e) {
      print('❌ Analysis failed: $e');
      errorMessage = 'Failed to analyze word: $e';
    } finally {
      isAnalyzing = false;
    }
  }

  @action
  Future<void> analyzeWord(String word) async {
    setInputWord(word);
    await analyzeCurrentWord();
  }

  @action
  Future<void> reAnalyzeWord(WordAnalysis analysis) async {
    print('🔄 Re-analyzing word: "${analysis.word}"');
    await analyzeWord(analysis.word);
  }

  @action
  Future<void> speakSyllable(String syllable) async {
    print('🔊 Speaking syllable: "$syllable"');
    try {
      await _ttsService.speakWord(syllable);
    } catch (e) {
      print('❌ Failed to speak syllable: $e');
      errorMessage = 'Failed to speak syllable';
    }
  }

  @action
  Future<void> speakWord(String word) async {
    print('🔊 Speaking word: "$word"');
    try {
      await _ttsService.speakWord(word);
    } catch (e) {
      print('❌ Failed to speak word: $e');
      errorMessage = 'Failed to speak word';
    }
  }

  @action
  Future<void> speakExampleSentence(String sentence) async {
    print('🔊 Speaking sentence');
    try {
      await _ttsService.speak(sentence);
    } catch (e) {
      print('❌ Failed to speak sentence: $e');
      errorMessage = 'Failed to speak sentence';
    }
  }

  @action
  Future<void> saveCurrentWord() async {
    if (currentAnalysis == null) return;

    print('💾 Saving current word: "${currentAnalysis!.word}"');
    isLoading = true;
    errorMessage = null;

    try {
      final success = await _dictionaryService.saveWord(currentAnalysis!);
      if (success) {
        currentAnalysis = currentAnalysis!.copyWith(isSaved: true);
        await _loadSavedWords();
        print('💾 Word saved successfully');
      } else {
        errorMessage = 'Failed to save word';
      }
    } catch (e) {
      print('❌ Save failed: $e');
      errorMessage = 'Failed to save word: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> removeSavedWord(String word) async {
    print('🗑️ Removing saved word: "$word"');
    isLoading = true;
    errorMessage = null;

    try {
      final success = await _dictionaryService.removeWord(word);
      if (success) {
        await _loadSavedWords();
        if (currentAnalysis?.word == word) {
          currentAnalysis = currentAnalysis!.copyWith(isSaved: false);
        }
        print('🗑️ Word removed successfully');
      } else {
        errorMessage = 'Failed to remove word';
      }
    } catch (e) {
      print('❌ Remove failed: $e');
      errorMessage = 'Failed to remove word: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> _loadSavedWords() async {
    try {
      final words = await _dictionaryService.getSavedWords();
      savedWords.clear();
      savedWords.addAll(words);
      print('📚 Loaded ${words.length} saved words');
    } catch (e) {
      print('❌ Failed to load saved words: $e');
    }
  }

  @action
  Future<void> _loadRecentWords() async {
    try {
      final words = await _dictionaryService.getRecentWords();
      recentWords.clear();
      recentWords.addAll(words);
      print('📝 Loaded ${words.length} recent words');
    } catch (e) {
      print('❌ Failed to load recent words: $e');
    }
  }

  @action
  Future<void> clearRecentWords() async {
    print('🗑️ Clearing recent words');
    isLoading = true;
    errorMessage = null;

    try {
      await _dictionaryService.clearRecentWords();
      recentWords.clear();
      print('🗑️ Recent words cleared');
    } catch (e) {
      print('❌ Failed to clear recent words: $e');
      errorMessage = 'Failed to clear recent words: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  void clearCurrentAnalysis() {
    currentAnalysis = null;
    inputWord = '';
    errorMessage = null;
  }

  @action
  void clearError() {
    errorMessage = null;
  }

  Future<void> refreshData() async {
    await _loadSavedWords();
    await _loadRecentWords();
    
    if (currentAnalysis != null) {
      final isSaved = await _dictionaryService.isWordSaved(currentAnalysis!.word);
      currentAnalysis = currentAnalysis!.copyWith(isSaved: isSaved);
    }
  }

  void dispose() {
    _ttsService.dispose();
  }
} 