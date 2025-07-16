import 'package:mobx/mobx.dart';
import 'dart:io';
import 'dart:async';
import 'package:image_picker/image_picker.dart';

import '../models/word_analysis.dart';
import '../services/word_analysis_service.dart';
import '../services/personal_dictionary_service.dart';
import '../services/text_to_speech_service.dart';
import '../services/ocr_service.dart';

part 'word_doctor_store.g.dart';

class WordDoctorStore = _WordDoctorStore with _$WordDoctorStore;

abstract class _WordDoctorStore with Store {
  final WordAnalysisService _analysisService;
  final PersonalDictionaryService _dictionaryService;
  final TextToSpeechService _ttsService;
  final OcrService _ocrService;
  final ImagePicker _imagePicker = ImagePicker();

  _WordDoctorStore({
    required WordAnalysisService analysisService,
    required PersonalDictionaryService dictionaryService,
    required TextToSpeechService ttsService,
    required OcrService ocrService,
  })  : _analysisService = analysisService,
        _dictionaryService = dictionaryService,
        _ttsService = ttsService,
        _ocrService = ocrService {
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

  @observable
  bool isScanning = false;

  // Debouncing for TTS calls
  Timer? _ttsDebounceTimer;
  String? _lastTtsRequest;

  @computed
  bool get canAnalyze => inputWord.trim().isNotEmpty && !isAnalyzing && !isScanning;

  @computed
  bool get canScanImage => !isAnalyzing && !isScanning;

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
      // Just do the basic word analysis - no session logging or complex async operations
      final analysis = await _analysisService.analyzeWord(wordToAnalyze);
      
      // Simple dictionary check
      final isSaved = await _dictionaryService.isWordSaved(wordToAnalyze);
      currentAnalysis = analysis.copyWith(isSaved: isSaved);
      
      // Simple recent words update
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
    }
  }

  @action
  Future<void> speakWord(String word) async {
    print('🔊 Speaking word: "$word"');
    
    try {
      await _ttsService.speakWord(word);
    } catch (e) {
      print('❌ Failed to speak word: $e');
    }
  }

  @action
  Future<void> speakExampleSentence(String sentence) async {
    print('🔊 Speaking example sentence');
    
    try {
      await _ttsService.speak(sentence);
    } catch (e) {
      print('❌ Failed to speak sentence: $e');
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

  String _getConfidenceLevel(WordAnalysis analysis) {
    final wordLength = analysis.word.length;
    final syllableCount = analysis.syllables.length;
    final phonemeCount = analysis.phonemes.length;
    
    // Simple confidence scoring based on word complexity
    if (wordLength <= 4 && syllableCount <= 2) {
      return 'high';
    } else if (wordLength <= 8 && syllableCount <= 3) {
      return 'medium';
    } else if (phonemeCount > 8 || syllableCount > 4) {
      return 'low';
    } else {
      return 'building';
    }
  }
  
  String _calculateDifficultyLevel(WordAnalysis analysis) {
    final wordLength = analysis.word.length;
    final syllableCount = analysis.syllables.length;
    final phonemeCount = analysis.phonemes.length;
    
    // Calculate difficulty based on word structure
    if (wordLength <= 4 && syllableCount <= 2) {
      return 'easy';
    } else if (wordLength <= 8 && syllableCount <= 3) {
      return 'medium';
    } else if (phonemeCount > 8 || syllableCount > 4) {
      return 'hard';
    } else {
      return 'medium';
    }
  }



  @action
  Future<void> scanWordFromGallery() async {
    if (!canScanImage) return;
    
    print('🖼️ Starting word scan from gallery');
    isScanning = true;
    errorMessage = null;

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      
      if (image != null) {
        await _processScannedImage(File(image.path));
      }
    } catch (e) {
      print('❌ Gallery scan failed: $e');
      errorMessage = 'Failed to select image: $e';
    } finally {
      isScanning = false;
    }
  }

  Future<void> _processScannedImage(File imageFile) async {
    print('🔍 Processing scanned image for OCR');
    
    try {
      final result = await _ocrService.scanImage(imageFile);
      
      if (result.isSuccess && result.hasText) {
        // Extract the first meaningful word from the OCR result
        final words = result.text
            .split(RegExp(r'\s+'))
            .where((word) => word.trim().isNotEmpty)
            .map((word) => word.replaceAll(RegExp(r'[^\w]'), ''))
            .where((word) => word.length > 1)
            .toList();
        
        if (words.isNotEmpty) {
          final extractedWord = words.first;
          print('✅ OCR extracted word: "$extractedWord"');
          
          // Set the input word and trigger analysis
          setInputWord(extractedWord);
          
          // Auto-analyze the scanned word
          await analyzeCurrentWord();
        } else {
          errorMessage = 'No readable words found in the image. Please try again with clearer text.';
          print('⚠️ No valid words extracted from OCR result');
        }
      } else {
        errorMessage = result.error ?? 'Unable to read text from image. Please ensure the text is clear and well-lit.';
        print('❌ OCR failed: ${result.error}');
      }
    } catch (e) {
      print('❌ OCR processing failed: $e');
      errorMessage = 'Failed to process image: $e';
    }
  }

  @action
  Future<String> getOCRStatus() async {
    try {
      return await _ocrService.getOCRStatus();
    } catch (e) {
      return 'OCR Status Unknown';
    }
  }



  void dispose() {
    _ttsDebounceTimer?.cancel();
    _ttsService.dispose();
  }
} 