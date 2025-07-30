import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'dart:async';
import '../controllers/text_simplifier_store.dart';
import '../services/text_simplifier_service.dart';
import '../services/text_to_speech_service.dart';
import '../utils/service_locator.dart';
import '../utils/theme.dart';
import 'dart:developer' as developer;

class TextSimplifierScreen extends StatefulWidget {
  const TextSimplifierScreen({super.key});

  @override
  State<TextSimplifierScreen> createState() => _TextSimplifierScreenState();
}

class _TextSimplifierScreenState extends State<TextSimplifierScreen> {
  late TextSimplifierStore _store;
  late TextSimplifierService _service;
  late TextToSpeechService _ttsService;
  
  final TextEditingController _textController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final StringBuffer _partialBuffer = StringBuffer();
  StreamSubscription<String>? _simplifySub;

  @override
  void initState() {
    super.initState();
    _store = getIt<TextSimplifierStore>();
    _service = getIt<TextSimplifierService>();
    _ttsService = getIt<TextToSpeechService>();
    
    // Add listener to sync text controller with store for reactive button
    _textController.addListener(() {
      // Only update store if text is different to prevent circular updates
      if (_store.originalText != _textController.text) {
        _store.setOriginalText(_textController.text);
      }
    });
  }

  @override
  void dispose() {
    try {
      developer.log('📝 Disposing TextSimplifierScreen', name: 'dyslexic_ai.text_simplifier');
      
      // Cancel stream subscriptions
      _simplifySub?.cancel();
      _simplifySub = null;
      
      // Dispose controllers and focus nodes
      _textController.dispose();
      _inputFocusNode.dispose();
      
      // Stop TTS if speaking
      _ttsService.stop();
      
      // Clear any partial buffer
      _partialBuffer.clear();
      
      developer.log('📝 TextSimplifierScreen disposed successfully', name: 'dyslexic_ai.text_simplifier');
    } catch (e) {
      developer.log('Text simplifier dispose error: $e', name: 'dyslexic_ai.text_simplifier');
    }
    
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
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Input section - no Observer wrapper needed
              _buildInputSection(),
              
              // Results section - separate Observer for simplification results
              Observer(
                builder: (context) => Padding(
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      color: DyslexiaTheme.primaryBackground,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Paste text to simplify',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              focusNode: _inputFocusNode,
              maxLines: 4,
              minLines: 3,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: 'Paste or type complex text here...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 12),
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
              const SizedBox(width: 12),
              Observer(
                builder: (context) => ElevatedButton.icon(
                  onPressed: _store.isProcessingOCR ? null : _handleScanImage,
                  icon: _store.isProcessingOCR 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_library),
                  label: Text(_store.isProcessingOCR ? 'Processing...' : 'Scan Image'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: Observer(
            builder: (context) {              
              return ElevatedButton(
                onPressed: _store.canSimplify ? _handleSimplify : null,
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
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Observer(
          builder: (context) {
            if (_store.wordBeingDefined != null) {
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Generating AI Definition for \"${_store.wordBeingDefined}\"...',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Future<void> _handleSimplify() async {
    final textToSimplify = _textController.text.trim();
    if (textToSimplify.isEmpty) return;

    _store.setOriginalText(textToSimplify);
    _inputFocusNode.unfocus();

    if (!_store.canSimplify) return;

    _store.clearSimplifiedText();
    _partialBuffer.clear();
    _simplifySub?.cancel();
    _store.setIsSimplifying(true);

    try {
      final stream = _service.simplifyTextStream(
        originalText: _store.originalText,
        readingLevel: 'Grade 3', // Default reading level
        explainChanges: false, // Default: don't explain changes
        defineKeyTerms: true, // Default: define difficult words
        addVisuals: false, // Default: no visual elements
      );

      _simplifySub = stream.listen((chunk) {
        _partialBuffer.write(chunk);
        setState(() {});
      }, onError: (e) {
        _store.setErrorMessage('Failed to simplify text: $e');
        _store.setIsSimplifying(false);
      }, onDone: () {
        _store.setSimplifiedText(_partialBuffer.toString());
        _store.setIsSimplifying(false);
        _partialBuffer.clear();
      });
    } catch (e) {
      _store.setErrorMessage('Failed to simplify text: $e');
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
          '• Adjusting reading level for easier understanding\n'
          '• Providing definitions for difficult words\n'
          '• Reading text aloud for better comprehension\n\n'
          'Paste or type complex text, then tap "Simplify Text" to get started.',
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

  Future<void> _handleScanImage() async {
    try {
      developer.log('🖼️ Starting OCR image processing...', name: 'dyslexic_ai.text_simplifier');
      await _store.pickImageFromGallery();
      
      developer.log('📷 OCR completed. Store originalText length: ${_store.originalText.length}', name: 'dyslexic_ai.text_simplifier');
      developer.log('🔍 Store canSimplify: ${_store.canSimplify}', name: 'dyslexic_ai.text_simplifier');
      
      if (_store.originalText.isNotEmpty) {
        _textController.text = _store.originalText;
        developer.log('✅ Set text controller with ${_store.originalText.length} characters', name: 'dyslexic_ai.text_simplifier');
      } else {
        developer.log('⚠️ No text extracted from OCR', name: 'dyslexic_ai.text_simplifier');
      }
    } catch (e) {
      developer.log('❌ OCR processing failed: $e', name: 'dyslexic_ai.text_simplifier');
      _showErrorSnackBar('Failed to process image: $e');
    }
  }

  Future<void> _handleSimplifyAgain() async {
    if (!_store.canSimplifyAgain) return;
    
    _store.setIsSimplifying(true);
    
    try {
      final simplifiedText = await _service.simplifyText(
        originalText: _store.originalText,
        readingLevel: 'Grade 3', // Default reading level
        explainChanges: false, // Default: don't explain changes
        defineKeyTerms: true, // Default: define difficult words
        addVisuals: false, // Default: no visual elements
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



  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DyslexiaTheme.primaryBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DyslexiaTheme.primaryAccent.withValues(alpha: 0.3)),
      ),
      child: _partialBuffer.isEmpty
          ? Column(
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
            )
          : _buildInteractiveText(_partialBuffer.toString()),
    );
  }

  Widget _buildSimplifiedTextSection() {
    if (_store.sideBySideView && _store.hasOriginalText) {
      return _buildSideBySideView();
    } else {
      return _buildSimplifiedTextView();
    }
  }

  Widget _buildInstructionalText() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(
        'Tap a word to see its definition.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
        textAlign: TextAlign.center,
      ),
    );
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
                          const SizedBox(height: 8),
                          if (_store.hasSimplifiedText) _buildInstructionalText(),
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
            const SizedBox(height: 8),
            if (_store.hasSimplifiedText) _buildInstructionalText(),
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
          onTap: _store.wordBeingDefined == null ? () => _handleWordTap(cleanWord) : null,
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



  Future<void> _handleWordTap(String word) async {
    if (word.isEmpty) return;

    try {
      _store.setWordBeingDefined(word);

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
    } finally {
      _store.setWordBeingDefined(null);
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
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8.0,
              runSpacing: 8.0,
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

} 