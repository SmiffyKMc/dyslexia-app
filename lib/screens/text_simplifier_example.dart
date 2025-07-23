import 'package:flutter/material.dart';
import '../services/ai_inference_service.dart';
import '../utils/service_locator.dart';
import '../utils/input_validation_helper.dart';

class TextSimplifierExample extends StatefulWidget {
  const TextSimplifierExample({super.key});

  @override
  State<TextSimplifierExample> createState() => _TextSimplifierExampleState();
}

class _TextSimplifierExampleState extends State<TextSimplifierExample> {
  final TextEditingController _inputController = TextEditingController();
  String? _simplifiedText;
  bool _isLoading = false;
  String? _error;

  AIInferenceService? get _aiService {
    return getAIInferenceService();
  }

  Future<void> _simplifyText() async {
    if (_inputController.text.trim().isEmpty) {
      InputValidationHelper.showInputError(
        context,
        'Please enter some text to simplify. Type text in the field above.',
      );
      return;
    }

    if (_aiService == null) {
      setState(() {
        _error = 'AI service not available. Please ensure the model is loaded.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _simplifiedText = null;
    });

    try {
      final result = await _aiService!.generateSentenceSimplification(_inputController.text);
      setState(() {
        _simplifiedText = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to simplify text: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Text Simplifier'),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'AI Text Simplification Demo',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This demonstrates how the AI inference service can simplify complex text into easier-to-read language.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              Text(
                'Enter Text to Simplify',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              const SizedBox(height: 12),
              
              TextField(
                controller: _inputController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Enter complex text here...\n\nExample: "The implementation of artificial intelligence facilitates enhanced comprehension for individuals experiencing dyslexic challenges."',
                  border: OutlineInputBorder(),
                ),
              ),
              
              const SizedBox(height: 16),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _simplifyText,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_fix_high),
                  label: Text(_isLoading ? 'Simplifying...' : 'Simplify with AI'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              
              if (_error != null) ...[
                const SizedBox(height: 16),
                Card(
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              if (_simplifiedText != null) ...[
                const SizedBox(height: 24),
                Text(
                  'Simplified Result',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'AI-Generated Simplified Text',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            _simplifiedText!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
} 