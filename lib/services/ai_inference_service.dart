import 'package:flutter_gemma/flutter_gemma_interface.dart';
import 'package:flutter_gemma/core/message.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'global_session_manager.dart';

/// Simplified AI inference service following flutter_gemma best practices
class AIInferenceService {
  final InferenceModel inferenceModel;
  final GlobalSessionManager _sessionManager;
  
  AIInferenceService(this.inferenceModel) : _sessionManager = GlobalSessionManager();

  /// Generate response with simple error handling
  Future<String> generateResponse(String prompt, {String? fallbackPrompt, bool isBackgroundTask = false}) async {
    try {
      developer.log('Generating response for prompt: ${prompt.substring(0, prompt.length > 100 ? 100 : prompt.length)}...', name: 'dyslexic_ai.inference');
      
      final session = await _sessionManager.getSession();
      await session.addQueryChunk(Message(text: prompt));
      
      // This naturally runs in background - flutter_gemma handles threading
      final response = await session.getResponse();
      
      developer.log('Response generated: ${response.substring(0, response.length > 100 ? 100 : response.length)}...', name: 'dyslexic_ai.inference');
      return _cleanAIResponse(response);
      
    } catch (e) {
      developer.log('Error in generateResponse: $e', name: 'dyslexic_ai.inference');
      
      // Simple fallback handling
        if (fallbackPrompt != null) {
          try {
          developer.log('Attempting fallback prompt', name: 'dyslexic_ai.inference');
          final session = await _sessionManager.getSession();
          await session.addQueryChunk(Message(text: fallbackPrompt));
          final response = await session.getResponse();
          return _cleanAIResponse(response);
          } catch (fallbackError) {
            developer.log('Fallback also failed: $fallbackError', name: 'dyslexic_ai.inference');
          }
        }
        
      // Simple error handling - invalidate session and rethrow
      await _sessionManager.invalidateSession();
      rethrow;
    }
  }
  
  /// Generate streaming response for real-time UI updates
  Future<Stream<String>> generateResponseStream(String prompt) async {
    try {
      developer.log('Generating stream response for prompt: ${prompt.substring(0, prompt.length > 100 ? 100 : prompt.length)}...', name: 'dyslexic_ai.inference');
      
    final session = await _sessionManager.getSession();
    await session.addQueryChunk(Message(text: prompt));
    
      // Return the stream directly - flutter_gemma handles background processing
      return session.getResponseAsync().map((token) => _cleanAIResponse(token));
      
    } catch (e) {
      developer.log('Error in generateResponseStream: $e', name: 'dyslexic_ai.inference');
      
      // Simple error handling - invalidate session and rethrow
    await _sessionManager.invalidateSession();
      rethrow;
  }
  }

  /// Legacy compatibility method
  Future<String> generateSentenceSimplification(String sentence) async {
    final prompt = '''
You are helping someone with dyslexia understand complex sentences. Please rewrite the following sentence to be:
- Shorter and clearer
- Using simpler vocabulary
- Maintaining the original meaning
- More accessible for someone with reading difficulties

Original sentence: $sentence

Provide only the simplified version.
''';
    
    return await generateResponse(prompt);
  }
  
  /// Clean AI response by removing special tokens
  String _cleanAIResponse(String response) {
    return response
        .replaceAll('<end_of_turn>', '')
        .replaceAll('<start_of_turn>', '')
        .trim();
  }

  /// Dispose of the service
  Future<void> dispose() async {
    await _sessionManager.dispose();
  }
} 