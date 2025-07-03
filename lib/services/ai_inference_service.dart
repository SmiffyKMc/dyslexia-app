import 'package:flutter_gemma/flutter_gemma_interface.dart';
import 'package:flutter_gemma/core/message.dart';
import 'dart:developer' as developer;
import 'dart:async';

class AIInferenceService {
  final InferenceModel inferenceModel;
  
  AIInferenceService(this.inferenceModel);
  
  // Clean AI response by removing special tokens
  String _cleanAIResponse(String response) {
    return response
        .replaceAll('<end_of_turn>', '')
        .replaceAll('<start_of_turn>', '')
        .trim();
  }
  
  Future<InferenceModelSession> _createFreshSession() async {
    developer.log('Creating fresh inference session...', name: 'dyslexic_ai.inference');
    final session = await inferenceModel.createSession(
      temperature: 0.3,
      topK: 10,
    );
    developer.log('Fresh inference session created successfully', name: 'dyslexic_ai.inference');
    return session;
  }
  
  Future<String> generateResponse(String prompt) async {
    InferenceModelSession? session;
    try {
      developer.log('Generating response for prompt: ${prompt.substring(0, prompt.length > 100 ? 100 : prompt.length)}...', name: 'dyslexic_ai.inference');
      
      session = await _createFreshSession();
      
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
      
      // Clean up session after use
      await session.close();
      developer.log('Session closed after successful generation', name: 'dyslexic_ai.inference');
      
      // Clean the response before returning
      return _cleanAIResponse(result);
    } catch (e, stackTrace) {
      developer.log('Error in generateResponse: $e', name: 'dyslexic_ai.inference', error: e, stackTrace: stackTrace);
      
      // Clean up session on error
      if (session != null) {
        try {
          await session.close();
          developer.log('Session closed after error', name: 'dyslexic_ai.inference');
        } catch (closeError) {
          developer.log('Error closing session: $closeError', name: 'dyslexic_ai.inference');
        }
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
  
  // Sessions are now created fresh for each request and closed automatically
  // No need for manual session management
} 