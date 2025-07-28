import 'package:mobx/mobx.dart';
import 'dart:io';
import 'dart:async';
import 'dart:developer' as developer;
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

  @observable
  bool isProcessingOCR = false;

  // Debouncing for TTS calls
  Timer? _ttsDebounceTimer;

  @computed
  bool get canAnalyze =>
      inputWord.trim().isNotEmpty && !isAnalyzing && !isScanning;

  @computed
  bool get canScanImage => !isAnalyzing && !isScanning && !isProcessingOCR;

  @computed
  bool get hasCurrentAnalysis => currentAnalysis != null;

  @computed
  bool get isCurrentWordSaved => currentAnalysis?.isSaved ?? false;

  @computed
  int get savedWordsCount => savedWords.length;

  @computed
  int get recentWordsCount => recentWords.length;

  Future<void> _initialize() async {
    try {
      await _loadSavedWords();
      await _loadRecentWords();
    } catch (e) {
      developer.log('Word Doctor initialization error: $e',
          name: 'dyslexic_ai.word_doctor');
      // Don't crash the app, just log the error
    }
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
    } catch (e) {
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
    await analyzeWord(analysis.word);
  }

  @action
  Future<void> speakSyllable(String syllable) async {
    // Cancel any existing TTS timer
    _ttsDebounceTimer?.cancel();

    try {
      // Clear TTS queue before speaking new content
      await _ttsService.clearQueue();
      await _ttsService.speakWord(syllable);
    } catch (e) {
      developer.log('Error speaking syllable: $e',
          name: 'dyslexic_ai.word_doctor');
      errorMessage = 'Unable to speak syllable. Please try again.';
    }
  }

  @action
  Future<void> speakWord(String word) async {
    // Cancel any existing TTS timer
    _ttsDebounceTimer?.cancel();

    try {
      // Clear TTS queue before speaking new content
      await _ttsService.clearQueue();
      await _ttsService.speakWord(word);
    } catch (e) {
      developer.log('Error speaking word: $e', name: 'dyslexic_ai.word_doctor');
      errorMessage = 'Unable to speak word. Please try again.';
    }
  }

  @action
  Future<void> speakExampleSentence(String sentence) async {
    // Cancel any existing TTS timer
    _ttsDebounceTimer?.cancel();

    try {
      // Clear TTS queue before speaking new content
      await _ttsService.clearQueue();
      await _ttsService.speak(sentence);
    } catch (e) {
      developer.log('Error speaking sentence: $e',
          name: 'dyslexic_ai.word_doctor');
      errorMessage = 'Unable to speak sentence. Please try again.';
    }
  }

  @action
  Future<void> saveCurrentWord() async {
    if (currentAnalysis == null) return;

    isLoading = true;
    errorMessage = null;

    try {
      final success = await _dictionaryService.saveWord(currentAnalysis!);
      if (success) {
        currentAnalysis = currentAnalysis!.copyWith(isSaved: true);
        await _loadSavedWords();
      } else {
        errorMessage = 'Failed to save word';
      }
    } catch (e) {
      errorMessage = 'Failed to save word: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> removeSavedWord(String word) async {
    isLoading = true;
    errorMessage = null;

    try {
      final success = await _dictionaryService.removeWord(word);
      if (success) {
        await _loadSavedWords();
        if (currentAnalysis?.word == word) {
          currentAnalysis = currentAnalysis!.copyWith(isSaved: false);
        }
      } else {
        errorMessage = 'Failed to remove word';
      }
    } catch (e) {
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
    } catch (e) {
      developer.log('Error loading saved words: $e',
          name: 'dyslexic_ai.word_doctor');
    }
  }

  @action
  Future<void> _loadRecentWords() async {
    try {
      final words = await _dictionaryService.getRecentWords();
      recentWords.clear();
      recentWords.addAll(words);
    } catch (e) {
      developer.log('Error loading recent words: $e',
          name: 'dyslexic_ai.word_doctor');
    }
  }

  @action
  Future<void> clearRecentWords() async {
    isLoading = true;
    errorMessage = null;

    try {
      await _dictionaryService.clearRecentWords();
      recentWords.clear();
    } catch (e) {
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
      final isSaved =
          await _dictionaryService.isWordSaved(currentAnalysis!.word);
      currentAnalysis = currentAnalysis!.copyWith(isSaved: isSaved);
    }
  }

  @action
  Future<void> scanWordFromGallery() async {
    if (!canScanImage) return;

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
      errorMessage = 'Failed to select image: $e';
    } finally {
      isScanning = false;
    }
  }

  Future<void> _processScannedImage(File imageFile) async {
    isProcessingOCR = true;

    try {
      developer.log('📷 Starting OCR processing...',
          name: 'dyslexic_ai.word_doctor');
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

          // Set the input word (user will manually press "Analyze Word")
          setInputWord(extractedWord);

          developer.log(
              '📷 OCR extracted word: "$extractedWord" - ready for manual analysis',
              name: 'dyslexic_ai.word_doctor');
        } else {
          errorMessage =
              'No readable words found in the image. Please try again with clearer text.';
        }
      } else {
        errorMessage = result.error ??
            'Unable to read text from image. Please ensure the text is clear and well-lit.';
      }
    } catch (e) {
      errorMessage = 'Failed to process image: $e';
    } finally {
      isProcessingOCR = false;
      developer.log('📷 OCR processing completed',
          name: 'dyslexic_ai.word_doctor');
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
    try {
      developer.log('🩹 Disposing WordDoctorStore',
          name: 'dyslexic_ai.word_doctor');

      // Cancel timers
      _ttsDebounceTimer?.cancel();
      _ttsDebounceTimer = null;

      // Stop TTS but don't dispose (shared service)
      _ttsService.stop();

      // Clear any ongoing analysis
      if (isAnalyzing) {
        errorMessage = 'Analysis cancelled - screen closed';
      }

      // Clear state
      currentAnalysis = null;
      inputWord = '';
      errorMessage = null;
      isScanning = false;

      developer.log('🩹 WordDoctorStore disposed successfully',
          name: 'dyslexic_ai.word_doctor');
    } catch (e) {
      developer.log('Word Doctor dispose error: $e',
          name: 'dyslexic_ai.word_doctor');
      // Continue with disposal even if errors occur
    }
  }
}
