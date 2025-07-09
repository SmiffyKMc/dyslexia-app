import 'package:flutter_gemma/flutter_gemma_interface.dart';
import 'package:flutter_gemma/core/message.dart';
import 'dart:developer' as developer;
import 'dart:async';

class AIInferenceService {
  final InferenceModel inferenceModel;
  InferenceModelSession? _cachedSession;
  
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
  
  Future<String> generateResponse(String prompt) async {
    try {
      developer.log('Generating response for prompt: ${prompt.substring(0, prompt.length > 100 ? 100 : prompt.length)}...', name: 'dyslexic_ai.inference');
      
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
      
      // Clean the response before returning (don't close session - reuse it)
      return _cleanAIResponse(result);
    } catch (e, stackTrace) {
      developer.log('Error in generateResponse: $e', name: 'dyslexic_ai.inference', error: e, stackTrace: stackTrace);
      
      // If there's an error, invalidate the cached session
      if (_cachedSession != null) {
        try {
          await _cachedSession!.close();
          developer.log('Closed cached session after error', name: 'dyslexic_ai.inference');
        } catch (closeError) {
          developer.log('Error closing cached session: $closeError', name: 'dyslexic_ai.inference');
        }
        _cachedSession = null;
      }
      
      rethrow;
    }
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
    if (_cachedSession != null) {
      developer.log('Disposing cached inference session', name: 'dyslexic_ai.inference');
      try {
        await _cachedSession!.close();
        developer.log('Cached session disposed successfully', name: 'dyslexic_ai.inference');
      } catch (e) {
        developer.log('Error disposing cached session: $e', name: 'dyslexic_ai.inference');
      }
      _cachedSession = null;
    }
  }
  
  // Session reuse eliminates expensive session creation on every request
  // First request creates session, subsequent requests reuse it
} 