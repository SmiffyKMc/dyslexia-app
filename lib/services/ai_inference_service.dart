import 'package:flutter_gemma/flutter_gemma_interface.dart';
import 'package:flutter_gemma/core/message.dart';
import 'dart:developer' as developer;
import 'dart:async';

class AIInferenceService {
  final InferenceModel inferenceModel;
  InferenceModelSession? _cachedSession;
  
  // Token management constants
  static const int maxTokenLimit = 2048;
  static const int safeTokenLimit = 1800; // Leave buffer for response
  static const int emergencyTokenLimit = 400; // Absolute minimum
  
  AIInferenceService(this.inferenceModel);
  
  // Clean AI response by removing special tokens
  String _cleanAIResponse(String response) {
    return response
        .replaceAll('<end_of_turn>', '')
        .replaceAll('<start_of_turn>', '')
        .trim();
  }
  
  Future<InferenceModelSession> _getOrCreateSession() async {
    if (_cachedSession == null) {
      developer.log('Creating new cached inference session...', name: 'dyslexic_ai.inference');
      _cachedSession = await inferenceModel.createSession(
        temperature: 0.3,
        topK: 10,
      );
      developer.log('Cached inference session created successfully', name: 'dyslexic_ai.inference');
    }
    return _cachedSession!;
  }
  
  /// Check if a prompt will exceed token limits
  Future<bool> _isWithinTokenLimit(String prompt) async {
    try {
      final session = await _getOrCreateSession();
      final tokenCount = await session.sizeInTokens(prompt);
      
      developer.log('Token count for prompt: $tokenCount / $maxTokenLimit', name: 'dyslexic_ai.inference');
      
      return tokenCount <= safeTokenLimit;
    } catch (e) {
      developer.log('Error checking token count: $e', name: 'dyslexic_ai.inference');
      // If we can't check, assume it's safe and let the actual generation handle it
      return true;
    }
  }
  
  /// Generate response with token validation and error recovery
  Future<String> generateResponse(String prompt, {String? fallbackPrompt}) async {
    try {
      developer.log('Generating response for prompt: ${prompt.substring(0, prompt.length > 100 ? 100 : prompt.length)}...', name: 'dyslexic_ai.inference');
      
      // Check token limit before processing
      if (!await _isWithinTokenLimit(prompt)) {
        developer.log('Prompt exceeds token limit, using fallback', name: 'dyslexic_ai.inference');
        
        if (fallbackPrompt != null && await _isWithinTokenLimit(fallbackPrompt)) {
          developer.log('Using provided fallback prompt', name: 'dyslexic_ai.inference');
          return await _performGeneration(fallbackPrompt);
        } else {
          developer.log('No suitable fallback, returning error response', name: 'dyslexic_ai.inference');
          return _createFallbackResponse();
        }
      }
      
      return await _performGeneration(prompt);
      
    } catch (e, stackTrace) {
      developer.log('Error in generateResponse: $e', name: 'dyslexic_ai.inference', error: e, stackTrace: stackTrace);
      
      // Check if it's a token limit error
      if (e.toString().contains('token') || e.toString().contains('OUT_OF_RANGE')) {
        developer.log('Token limit error detected, invalidating session', name: 'dyslexic_ai.inference');
        await _invalidateSession();
        
        // Try fallback if available
        if (fallbackPrompt != null) {
          try {
            developer.log('Attempting fallback after token error', name: 'dyslexic_ai.inference');
            return await _performGeneration(fallbackPrompt);
          } catch (fallbackError) {
            developer.log('Fallback also failed: $fallbackError', name: 'dyslexic_ai.inference');
          }
        }
        
        return _createFallbackResponse();
      }
      
      // For other errors, invalidate session and rethrow
      await _invalidateSession();
      rethrow;
    }
  }
  
  /// Perform the actual generation with proper session management
  Future<String> _performGeneration(String prompt) async {
    final session = await _getOrCreateSession();
    
    final completer = Completer<String>();
    final buffer = StringBuffer();
    
    await session.addQueryChunk(Message(text: prompt));
    
    session.getResponseAsync().listen(
      (token) {
        buffer.write(token);
      },
      onDone: () {
        final response = buffer.toString().trim();
        developer.log('Response generated: ${response.substring(0, response.length > 100 ? 100 : response.length)}...', name: 'dyslexic_ai.inference');
        completer.complete(response);
      },
      onError: (error) {
        developer.log('Error generating response: $error', name: 'dyslexic_ai.inference', error: error);
        completer.completeError(error);
      },
    );
    
    final result = await completer.future;
    return _cleanAIResponse(result);
  }
  
  /// Invalidate and recreate session after errors
  Future<void> _invalidateSession() async {
    if (_cachedSession != null) {
      try {
        await _cachedSession!.close();
        developer.log('Closed cached session after error', name: 'dyslexic_ai.inference');
      } catch (closeError) {
        developer.log('Error closing cached session: $closeError', name: 'dyslexic_ai.inference');
      }
      _cachedSession = null;
    }
  }
  
  /// Create a fallback response when token limits are exceeded
  String _createFallbackResponse() {
    return '''
{
  "phonologicalAwareness": "developing",
  "phonemeConfusions": ["unable to analyze"],
  "decodingAccuracy": "developing",
  "workingMemory": "average",
  "fluency": "developing",
  "confidence": "building",
  "preferredStyle": "multimodal",
  "focus": "continue current practice",
  "recommendedTool": "Reading Coach",
  "advice": "Unable to fully analyze due to technical constraints. Continue your current practice routine and check back later for detailed analysis."
}
''';
  }

  Future<String> generateReadingAssistance(String text) async {
    const prompt = '''
You are a dyslexia-friendly reading assistant. Your task is to help make text more accessible and understandable.

Please analyze the following text and provide:
1. A simplified version with shorter sentences and easier vocabulary
2. Key points summarized in bullet format
3. Any difficult words explained simply

Original text: 
''';
    
    return await generateResponse(prompt + text);
  }
  
  Future<String> generateWordPrediction(String partialText) async {
    final prompt = '''
You are helping someone with dyslexia complete words or sentences. Given the partial text below, suggest 3-5 likely completions that are:
- Simple and commonly used
- Contextually appropriate
- Easy to spell and pronounce

Partial text: $partialText

Provide only the suggested completions, one per line, without numbering or additional text.
''';
    
    return await generateResponse(prompt);
  }
  
  Future<String> generateSpellingHelp(String word) async {
    final prompt = '''
You are a dyslexia-friendly spelling helper. For the word "$word", provide:
1. The correct spelling
2. A simple phonetic breakdown
3. A memory trick or pattern to remember the spelling
4. 2-3 similar words that follow the same pattern

Keep explanations simple and encouraging.
''';
    
    return await generateResponse(prompt);
  }
  
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
  
  // Clean up method for proper disposal
  Future<void> dispose() async {
    await _invalidateSession();
  }
} 