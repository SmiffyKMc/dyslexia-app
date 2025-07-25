import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../../utils/theme.dart';

class NameEntryScreen extends StatefulWidget {
  final String initialName;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const NameEntryScreen({
    super.key,
    required this.initialName,
    required this.onNameChanged,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<NameEntryScreen> createState() => _NameEntryScreenState();
}

class _NameEntryScreenState extends State<NameEntryScreen> {
  late TextEditingController _nameController;
  bool _isNameValid = false;

  @override
  void initState() {
    super.initState();
    try {
      developer.log('🧠 Initializing NameEntryScreen...', name: 'dyslexic_ai.questionnaire');
      _nameController = TextEditingController(text: widget.initialName);
      _isNameValid = widget.initialName.trim().isNotEmpty;
      _nameController.addListener(_onNameChanged);
      developer.log('🧠 NameEntryScreen initialized successfully', name: 'dyslexic_ai.questionnaire');
    } catch (e, stackTrace) {
      developer.log('❌ Failed to initialize NameEntryScreen: $e', name: 'dyslexic_ai.questionnaire', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    final name = _nameController.text.trim();
    setState(() {
      _isNameValid = name.isNotEmpty;
    });
    widget.onNameChanged(name);
  }

  @override
  Widget build(BuildContext context) {
    try {
      return Scaffold(
        backgroundColor: DyslexiaTheme.primaryBackground,
        appBar: AppBar(
          backgroundColor: DyslexiaTheme.primaryBackground,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: DyslexiaTheme.textPrimary),
            onPressed: widget.onBack,
          ),
          title: const Text(
            'Tell us your name',
            style: TextStyle(
              color: DyslexiaTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress indicator
                _buildProgressIndicator(),
                const SizedBox(height: 40),
                
                // Main content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon and title
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: DyslexiaTheme.primaryAccent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 32,
                          color: DyslexiaTheme.primaryAccent,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      const Text(
                        'What should we call you?',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: DyslexiaTheme.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      const Text(
                        'This helps us personalize your learning experience and create a profile just for you.',
                        style: TextStyle(
                          fontSize: 16,
                          color: DyslexiaTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Name input field
                      _buildNameField(),
                      
                      const Spacer(),
                    ],
                  ),
                ),
                
                // Navigation buttons
                _buildNavigationButtons(),
              ],
            ),
          ),
        ),
      );
    } catch (e, stackTrace) {
      developer.log('❌ Error building NameEntryScreen: $e', name: 'dyslexic_ai.questionnaire', error: e, stackTrace: stackTrace);
      return Scaffold(
        backgroundColor: DyslexiaTheme.primaryBackground,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: DyslexiaTheme.errorColor,
              ),
              const SizedBox(height: 16),
              const Text(
                'Name Entry Error',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: DyslexiaTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'There was a problem loading the name entry screen. Please restart the app.',
                style: TextStyle(
                  fontSize: 16,
                  color: DyslexiaTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: [
        // Step indicators
        for (int i = 0; i < 4; i++)
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= 1 
                          ? DyslexiaTheme.primaryAccent 
                          : DyslexiaTheme.primaryAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (i < 3) const SizedBox(width: 8),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Name',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: DyslexiaTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: 'Enter your first name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: DyslexiaTheme.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: DyslexiaTheme.primaryAccent, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          style: const TextStyle(fontSize: 16),
          textInputAction: TextInputAction.next,
          onSubmitted: (_) {
            if (_isNameValid) {
              widget.onNext();
            }
          },
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: widget.onBack,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: DyslexiaTheme.borderColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'Back',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: DyslexiaTheme.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isNameValid ? widget.onNext : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isNameValid ? DyslexiaTheme.primaryAccent : DyslexiaTheme.borderColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
            ),
            child: const Text(
              'Continue',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
} 