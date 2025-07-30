import 'package:mobx/mobx.dart';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/ocr_service.dart';
import '../utils/service_locator.dart';

part 'text_simplifier_store.g.dart';

class TextSimplifierStore = _TextSimplifierStore with _$TextSimplifierStore;

abstract class _TextSimplifierStore with Store {
  late final OcrService _ocrService;
  late final ImagePicker _imagePicker;

  _TextSimplifierStore() {
    _ocrService = getIt<OcrService>();
    _imagePicker = ImagePicker();
  }

  @observable
  String originalText = '';

  @observable
  String simplifiedText = '';

  @observable
  bool isSimplifying = false;

  @observable
  String? errorMessage;

  @observable
  String selectedReadingLevel = 'Grade 3';

  @observable
  bool explainChanges = true;

  @observable
  bool sideBySideView = false;

  @observable
  bool defineKeyTerms = true;

  @observable
  bool addVisuals = false;

  @observable
  bool isProcessingOCR = false;

  @observable
  List<String> simplificationHistory = [];

  @observable
  Map<String, String> wordDefinitions = {};

  @observable
  bool isSpeaking = false;

  @observable
  String? wordBeingDefined;

  @computed
  bool get hasOriginalText => originalText.trim().isNotEmpty;

  @computed
  bool get hasSimplifiedText => simplifiedText.trim().isNotEmpty;

  @computed
  bool get canSimplify => hasOriginalText && !isSimplifying && !isProcessingOCR;

  @computed
  bool get canSimplifyAgain => hasSimplifiedText && !isSimplifying;

  @action
  void setOriginalText(String text) {
    originalText = text;
    if (text.trim().isEmpty) {
      clearSimplifiedText();
    }
  }

  @action
  void setSimplifiedText(String text) {
    simplifiedText = text;
    if (text.isNotEmpty) {
      simplificationHistory.add(text);
    }
  }

  @action
  void clearSimplifiedText() {
    simplifiedText = '';
    errorMessage = null;
    simplificationHistory.clear();
    wordDefinitions.clear();
  }

  @action
  void setIsSimplifying(bool value) {
    isSimplifying = value;
    if (value) {
      errorMessage = null;
    }
  }

  @action
  void setErrorMessage(String? message) {
    errorMessage = message;
    isSimplifying = false;
  }

  @action
  void setSelectedReadingLevel(String level) {
    selectedReadingLevel = level;
  }

  @action
  void setExplainChanges(bool value) {
    explainChanges = value;
  }

  @action
  void setSideBySideView(bool value) {
    sideBySideView = value;
  }

  @action
  void setDefineKeyTerms(bool value) {
    defineKeyTerms = value;
  }

  @action
  void setAddVisuals(bool value) {
    addVisuals = value;
  }

  @action
  void setIsProcessingOCR(bool value) {
    isProcessingOCR = value;
    if (value) {
      errorMessage = null;
    }
  }

  @action
  void addWordDefinition(String word, String definition) {
    // Limit cache size to prevent memory issues
    const int maxCacheSize = 20;
    
    if (wordDefinitions.length >= maxCacheSize) {
      // Remove oldest definition (first key)
      final oldestKey = wordDefinitions.keys.first;
      wordDefinitions.remove(oldestKey);
      developer.log('TextSimplifier: Removed oldest word definition for $oldestKey to maintain cache size');
    }
    
    wordDefinitions[word] = definition;
  }

  @action
  void setIsSpeaking(bool value) {
    isSpeaking = value;
  }

  @action
  void setWordBeingDefined(String? word) {
    wordBeingDefined = word;
  }

  @action
  void clearAll() {
    originalText = '';
    simplifiedText = '';
    errorMessage = null;
    simplificationHistory.clear();
    wordDefinitions.clear();
    isSimplifying = false;
    isProcessingOCR = false;
    isSpeaking = false;
    wordBeingDefined = null;
  }

  @action
  void pasteFromClipboard(String clipboardText) {
    setOriginalText(clipboardText);
    developer.log('📋 Pasted text from clipboard: ${clipboardText.length} characters', name: 'dyslexic_ai.text_simplifier');
  }

  @action
  Future<void> pickImageFromGallery() async {
    isProcessingOCR = true;
    errorMessage = null;

    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final extractedText = await _ocrService.processImageForReading(File(image.path));
        setOCRText(extractedText);
      }
    } catch (e) {
      errorMessage = 'Failed to process image: $e';
      developer.log('❌ OCR processing failed: $e', name: 'dyslexic_ai.text_simplifier');
    } finally {
      isProcessingOCR = false;
    }
  }

  @action
  void setOCRText(String ocrText) {
    setOriginalText(ocrText);
    developer.log('📷 Set OCR text: ${ocrText.length} characters', name: 'dyslexic_ai.text_simplifier');
  }

  String getReadingLevelForAI() {
    switch (selectedReadingLevel) {
      case 'Grade 1':
      case 'Grade 2':
        return 'elementary (grades 1-2)';
      case 'Grade 3':
      case 'Grade 4':
        return 'early elementary (grades 3-4)';
      case 'Grade 5':
      case 'Grade 6':
        return 'middle elementary (grades 5-6)';
      case 'Grade 7':
      case 'Grade 8':
        return 'middle school (grades 7-8)';
      default:
        return 'elementary (grades 3-4)';
    }
  }

  List<String> getReadingLevels() {
    return [
      'Grade 1',
      'Grade 2', 
      'Grade 3',
      'Grade 4',
      'Grade 5',
      'Grade 6',
      'Grade 7',
      'Grade 8'
    ];
  }

  @action
  void clearWordDefinitions() {
    wordDefinitions.clear();
  }

  @action
  void clearSimplificationHistory() {
    simplificationHistory.clear();
  }

  @action
  void clearCachedData() {
    clearWordDefinitions();
    clearSimplificationHistory();
    errorMessage = null;
    developer.log('TextSimplifier: Cleared cached data for memory optimization');
  }
} 