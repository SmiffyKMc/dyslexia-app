import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../controllers/text_simplifier_store.dart';
import '../services/text_simplifier_service.dart';
import '../services/text_to_speech_service.dart';
import '../services/ocr_service.dart';
import '../utils/service_locator.dart';
import '../utils/theme.dart';

class TextSimplifierScreen extends StatefulWidget {
  const TextSimplifierScreen({super.key});

  @override
  State<TextSimplifierScreen> createState() => _TextSimplifierScreenState();
}

class _TextSimplifierScreenState extends State<TextSimplifierScreen> {
  late TextSimplifierStore _store;
  late TextSimplifierService _service;
  late TextToSpeechService _ttsService;
  late OcrService _ocrService;
  final ImagePicker _imagePicker = ImagePicker();
  
  final TextEditingController _textController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _store = getIt<TextSimplifierStore>();
    _service = getIt<TextSimplifierService>();
    _ttsService = getIt<TextToSpeechService>();
    _ocrService = getIt<OcrService>();
  }

  @override
  void dispose() {
    _textController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text Simplifier'),
        actions: [
          IconButton(
            onPressed: _showInfoDialog,
            icon: const Icon(Icons.info),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Input section - no Observer wrapper needed
            _buildInputSection(),
            
            // Results section - separate Observer for simplification results
            Expanded(
              child: Observer(
                builder: (context) => SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_store.errorMessage != null) _buildErrorMessage(),
                      if (_store.isSimplifying) _buildLoadingIndicator(),
                      if (_store.hasSimplifiedText) _buildSimplifiedTextSection(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      color: DyslexiaTheme.primaryBackground,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste complex text below and I\'ll rewrite it in '
              'simpler language that\'s easier to understand.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Complex Text',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: TextField(
                controller: _textController,
                focusNode: _inputFocusNode,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Paste or type complex text here...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildInputControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputControls() {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: _handlePasteText,
                icon: const Icon(Icons.paste),
                label: const Text('Paste'),
              ),
              const SizedBox(width: 8),
              Observer(
                builder: (context) => ElevatedButton.icon(
                  onPressed: _store.isProcessingOCR ? null : _handleCameraCapture,
                  icon: _store.isProcessingOCR 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt),
                  label: Text(_store.isProcessingOCR ? 'Processing...' : 'Camera'),
                ),
              ),
              const SizedBox(width: 8),
              Observer(
                builder: (context) => ElevatedButton.icon(
                  onPressed: _store.isProcessingOCR ? null : _handleGalleryPick,
                  icon: _store.isProcessingOCR 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_library),
                  label: Text(_store.isProcessingOCR ? 'Processing...' : 'Gallery'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSimplificationControls(),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: Observer(
            builder: (context) => ElevatedButton(
              onPressed: (_textController.text.trim().isNotEmpty && !_store.isSimplifying && !_store.isProcessingOCR) 
                  ? _handleSimplify : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: DyslexiaTheme.primaryAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Simplify Text',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSimplify() async {
    // Sync text to store only when button is pressed
    final textToSimplify = _textController.text.trim();
    if (textToSimplify.isEmpty) return;
    
    _store.setOriginalText(textToSimplify);
    _inputFocusNode.unfocus();
    
    if (!_store.canSimplify) return;
    
    _store.setIsSimplifying(true);
    
    try {
      final simplifiedText = await _service.simplifyText(
        originalText: _store.originalText,
        readingLevel: _store.selectedReadingLevel,
        explainChanges: _store.explainChanges,
        defineKeyTerms: _store.defineKeyTerms,
        addVisuals: _store.addVisuals,
        isRegenerateRequest: false,
      );
      
      _store.setSimplifiedText(simplifiedText);
      
      // Clear cached data for memory optimization
      _store.clearCachedData();
    } catch (e) {
      _store.setErrorMessage('Failed to simplify text: $e');
    } finally {
      _store.setIsSimplifying(false);
    }
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Text Simplifier'),
        content: const Text(
          'This tool helps you understand complex text by:\n\n'
          '• Rewriting text in simpler language\n'
          '• Adjusting reading level to your needs\n'
          '• Providing definitions for difficult words\n'
          '• Reading text aloud for better comprehension\n\n'
          'Choose your reading level and options, then tap "Simplify Text" to get started.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePasteText() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null) {
        _textController.text = clipboardData!.text!;
        _store.pasteFromClipboard(clipboardData.text!);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to paste text: $e');
    }
  }

  Future<void> _handleCameraCapture() async {
    try {
      _store.setIsProcessingOCR(true);
      final pickedFile = await _imagePicker.pickImage(source: ImageSource.camera);
      
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final ocrResult = await _ocrService.scanImage(file);
        
        if (ocrResult.isSuccess && ocrResult.text.isNotEmpty) {
          _textController.text = ocrResult.text;
          _store.setOCRText(ocrResult.text);
        } else {
          _showErrorSnackBar('No text found in image');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to process image: $e');
    } finally {
      _store.setIsProcessingOCR(false);
    }
  }

  Future<void> _handleGalleryPick() async {
    try {
      _store.setIsProcessingOCR(true);
      final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery);
      
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final ocrResult = await _ocrService.scanImage(file);
        
        if (ocrResult.isSuccess && ocrResult.text.isNotEmpty) {
          _textController.text = ocrResult.text;
          _store.setOCRText(ocrResult.text);
        } else {
          _showErrorSnackBar('No text found in image');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to process image: $e');
    } finally {
      _store.setIsProcessingOCR(false);
    }
  }

  Future<void> _handleSimplifyAgain() async {
    if (!_store.canSimplifyAgain) return;
    
    _store.setIsSimplifying(true);
    
    try {
      final simplifiedText = await _service.simplifyText(
        originalText: _store.originalText,
        readingLevel: _store.selectedReadingLevel,
        explainChanges: _store.explainChanges,
        defineKeyTerms: _store.defineKeyTerms,
        addVisuals: _store.addVisuals,
        isRegenerateRequest: true,
      );
      
      _store.setSimplifiedText(simplifiedText);
      
      // Clear cached data for memory optimization
      _store.clearCachedData();
    } catch (e) {
      _store.setErrorMessage('Failed to regenerate text: $e');
    } finally {
      _store.setIsSimplifying(false);
    }
  }

  Future<void> _handleReadAloud() async {
    if (!_store.hasSimplifiedText) return;
    
    try {
      _store.setIsSpeaking(true);
      await _ttsService.speak(_store.simplifiedText);
    } catch (e) {
      _showErrorSnackBar('Failed to read text aloud: $e');
    } finally {
      _store.setIsSpeaking(false);
    }
  }

  Future<void> _handleCopyText() async {
    if (!_store.hasSimplifiedText) return;
    
    try {
      await Clipboard.setData(ClipboardData(text: _store.simplifiedText));
      _showSuccessSnackBar('Text copied to clipboard');
    } catch (e) {
      _showErrorSnackBar('Failed to copy text: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showReadingLevelSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Reading Level'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _store.getReadingLevels().length,
            itemBuilder: (context, index) {
              final level = _store.getReadingLevels()[index];
              return RadioListTile<String>(
                title: Text(level),
                value: level,
                groupValue: _store.selectedReadingLevel,
                onChanged: (value) {
                  if (value != null) {
                    _store.setSelectedReadingLevel(value);
                    Navigator.of(context).pop();
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      width: double.infinity,
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error,
                color: Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Error',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                _store.errorMessage!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.red.shade700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      width: double.infinity,
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DyslexiaTheme.primaryBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DyslexiaTheme.primaryAccent.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: DyslexiaTheme.primaryAccent,
              strokeWidth: 2,
            ),
            const SizedBox(height: 16),
            Text(
              'Simplifying text...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimplifiedTextSection() {
    if (_store.sideBySideView && _store.hasOriginalText) {
      return _buildSideBySideView();
    } else {
      return _buildSimplifiedTextView();
    }
  }

  Widget _buildSideBySideView() {
    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Original text side
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Original',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        _store.originalText,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Divider
          Container(
            width: 1,
            color: Colors.grey[300],
          ),
          // Simplified text side
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Simplified',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInteractiveText(_store.simplifiedText),
                          const SizedBox(height: 16),
                          if (_store.canSimplifyAgain) ...[
                            Center(
                              child: ElevatedButton.icon(
                                onPressed: _store.canSimplifyAgain ? _handleSimplifyAgain : null,
                                icon: _store.isSimplifying 
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.refresh),
                                label: Text(_store.isSimplifying ? 'Simplifying...' : 'Simplify Again'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                  foregroundColor: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimplifiedTextView() {
    return Container(
      width: double.infinity,
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInteractiveText(_store.simplifiedText),
            const SizedBox(height: 16),
            if (_store.canSimplifyAgain) ...[
              Center(
                child: ElevatedButton.icon(
                  onPressed: _store.canSimplifyAgain ? _handleSimplifyAgain : null,
                  icon: _store.isSimplifying 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(_store.isSimplifying ? 'Simplifying...' : 'Simplify Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    foregroundColor: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveText(String text) {
    // Split text into words for interactive functionality
    final words = text.split(RegExp(r'\s+'));
    
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: words.map((word) {
        // Clean word of punctuation for processing
        final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '');
        
        return GestureDetector(
          onTap: () => _handleWordTap(cleanWord),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: _store.wordDefinitions.containsKey(cleanWord)
                  ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                  : Colors.transparent,
            ),
            child: Text(
              word,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _store.wordDefinitions.containsKey(cleanWord)
                    ? Theme.of(context).primaryColor
                    : null,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_fix_high,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Your simplified text will appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleWordTap(String word) async {
    if (word.isEmpty) return;
    
    try {
      // Check if definition already exists
      if (_store.wordDefinitions.containsKey(word)) {
        _showWordDefinition(word, _store.wordDefinitions[word]!);
        return;
      }
      
      // Get definition from AI service
      final definition = await _service.defineWord(word);
      _store.addWordDefinition(word, definition);
      
      _showWordDefinition(word, definition);
    } catch (e) {
      _showErrorSnackBar('Failed to get definition for "$word": $e');
    }
  }

  void _showWordDefinition(String word, String definition) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(word),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(definition),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await _ttsService.speakWord(word);
                    } catch (e) {
                      _showErrorSnackBar('Failed to speak word: $e');
                    }
                  },
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Say Word'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await _ttsService.speak(definition);
                    } catch (e) {
                      _showErrorSnackBar('Failed to speak definition: $e');
                    }
                  },
                  icon: const Icon(Icons.record_voice_over),
                  label: const Text('Say Definition'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSimplificationControls() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Primary controls - always visible
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Reading Level',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _buildReadingLevelDropdown(),
              ],
            ),
            const SizedBox(height: 16),
            
            // Smart defaults with clear labels
            Row(
              children: [
                Expanded(
                  child: _buildExplainChangesCheckbox(),
                ),
              ],
            ),
            
            Row(
              children: [
                Expanded(
                  child: _buildDefineKeyTermsCheckbox(),
                ),
              ],
            ),
            
            // Advanced options (collapsible)
            _buildAdvancedOptionsExpansion(),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingLevelDropdown() {
    return Observer(
      builder: (context) => GestureDetector(
        onTap: _showReadingLevelSelector,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _store.selectedReadingLevel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_drop_down,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExplainChangesCheckbox() {
    return Observer(
      builder: (context) => CheckboxListTile(
        title: Text(
          'Explain changes',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'Show what was changed',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        value: _store.explainChanges,
        onChanged: (value) {
          if (value != null) {
            _store.setExplainChanges(value);
          }
        },
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildDefineKeyTermsCheckbox() {
    return Observer(
      builder: (context) => CheckboxListTile(
        title: Text(
          'Define difficult words',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'Tap words for definitions',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        value: _store.defineKeyTerms,
        onChanged: (value) {
          if (value != null) {
            _store.setDefineKeyTerms(value);
          }
        },
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildAdvancedOptionsExpansion() {
    return ExpansionTile(
      title: Text(
        'Advanced Options',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        'Display and feature options',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.grey[600],
        ),
      ),
      initiallyExpanded: false,
      children: [
        Observer(
          builder: (context) => CheckboxListTile(
            title: Text(
              'Side-by-side view',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            subtitle: Text(
              'Show original and simplified text together',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            value: _store.sideBySideView,
            onChanged: (value) {
              if (value != null) {
                _store.setSideBySideView(value);
              }
            },
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
        Observer(
          builder: (context) => CheckboxListTile(
            title: Text(
              'Add visual elements',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            subtitle: Text(
              'Include emoji and visual cues (experimental)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            value: _store.addVisuals,
            onChanged: (value) {
              if (value != null) {
                _store.setAddVisuals(value);
              }
            },
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
      ],
    );
  }

} 