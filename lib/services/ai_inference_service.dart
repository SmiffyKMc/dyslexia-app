import 'package:flutter_gemma/flutter_gemma_interface.dart';
import 'package:flutter_gemma/core/message.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'dart:math' as math;
import '../utils/inference_trace.dart';
import '../utils/prompt_loader.dart';
import 'global_session_manager.dart';
import '../utils/inference_metrics.dart';


// Session/context management constants
const int _maxContextTokens = 2048;
const int _outputTokenCap = 128; // Reduced from 256 - most responses are shorter
const int _rolloverThreshold = _maxContextTokens - _outputTokenCap; // 1920 headroom (increased from 1792)

/// Simplified AI inference service following flutter_gemma best practices
class AIInferenceService {
  final InferenceModel inferenceModel;
  final GlobalSessionManager _sessionManager;
  int _contextTokens = 0;
  
  AIInferenceService(this.inferenceModel) : _sessionManager = GlobalSessionManager();

  // --- Internal helpers --------------------------------------------------
  int _estimateTokens(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  Future<void> _ensureHeadroom(int nextInputTokens, {bool forceFreshSession = false}) async {
    final projectedTotal = _contextTokens + nextInputTokens + _outputTokenCap;
    developer.log('🔢 Token check: current=$_contextTokens, input=$nextInputTokens, projected=$projectedTotal, threshold=$_rolloverThreshold', 
        name: 'dyslexic_ai.inference');
    
    if (forceFreshSession || (projectedTotal >= _rolloverThreshold)) {
      developer.log('💡 Rolling over session (reason: ${forceFreshSession ? 'forced' : 'threshold exceeded'})', 
          name: 'dyslexic_ai.inference');
      await _sessionManager.invalidateSession();
      _contextTokens = 0;
      InferenceMetrics.contextTokens.value = 0;
    }
  }

  /// Generate response with simple error handling
  Future<String> generateResponse(String prompt, {String? fallbackPrompt, bool isBackgroundTask = false, bool forceFreshSession = false}) async {
    final trace = InferenceTrace(prompt.substring(0, math.min(80, prompt.length)));

    final inputTokens = _estimateTokens(prompt);
    await _ensureHeadroom(inputTokens, forceFreshSession: forceFreshSession);
    try {
      final session = await _sessionManager.getSession();
      await session.addQueryChunk(Message(text: prompt));

      // Use streaming to keep UI responsive but buffer until end for JSON integrity
      final stream = session.getResponseAsync();
      final buffer = StringBuffer();
      int tokens = 0;
      await for (final chunk in stream) {
        if (chunk.trim().isNotEmpty) {
          tokens += chunk.split(RegExp(r'\s+')).length;
        }
        buffer.write(chunk);
      }

      final response = buffer.toString();
      trace.done(tokens);
      _contextTokens += inputTokens + tokens;
      InferenceMetrics.contextTokens.value = _contextTokens;
      
      developer.log('✅ Response complete: $tokens output tokens, context now $_contextTokens/$_maxContextTokens', 
          name: 'dyslexic_ai.inference');
      
      return _cleanAIResponse(response);

    } catch (e) {
      trace.done(0);
      developer.log('Error in generateResponse: $e', name: 'dyslexic_ai.inference');

      // Fallback prompt handling
      if (fallbackPrompt != null) {
        try {
          final fbTrace = InferenceTrace(fallbackPrompt.substring(0, math.min(80, fallbackPrompt.length)));
          final fbInput = _estimateTokens(fallbackPrompt);
          await _ensureHeadroom(fbInput, forceFreshSession: forceFreshSession);
          final session = await _sessionManager.getSession();
          await session.addQueryChunk(Message(text: fallbackPrompt));
          final stream = session.getResponseAsync();
          final buffer = StringBuffer();
          int tokens = 0;
          await for (final chunk in stream) {
            if (chunk.trim().isNotEmpty) {
              tokens += chunk.split(RegExp(r'\s+')).length;
            }
            buffer.write(chunk);
          }
          fbTrace.done(tokens);
          _contextTokens += fbInput + tokens;
          InferenceMetrics.contextTokens.value = _contextTokens;
          return _cleanAIResponse(buffer.toString());
        } catch (fallbackError) {
          developer.log('Fallback also failed: $fallbackError', name: 'dyslexic_ai.inference');
        }
      }

      await _sessionManager.invalidateSession();
      _contextTokens = 0;
      InferenceMetrics.contextTokens.value = 0;
      rethrow;
    }
  }
  
  /// Generate streaming response for real-time UI updates
  Future<Stream<String>> generateResponseStream(String prompt, {bool forceFreshSession = false}) async {
    final trace = InferenceTrace(prompt.substring(0, math.min(80, prompt.length)));
    final inputTokens = _estimateTokens(prompt);
    await _ensureHeadroom(inputTokens, forceFreshSession: forceFreshSession);
    try {
      final session = await _sessionManager.getSession();
      await session.addQueryChunk(Message(text: prompt));

      int tokens = 0;
      // Wrap the original stream to count tokens and log on completion
      final original = session.getResponseAsync();
      final controller = StreamController<String>();
      original.listen((token) {
        if (token.trim().isNotEmpty) {
          tokens += token.split(RegExp(r'\s+')).length;
        }
        controller.add(_cleanAIResponse(token));
      }, onError: (e) {
        trace.done(tokens);
        controller.addError(e);
      }, onDone: () {
        trace.done(tokens);
        _contextTokens += inputTokens + tokens;
        InferenceMetrics.contextTokens.value = _contextTokens;
        controller.close();
      }, cancelOnError: true);

      return controller.stream;

    } catch (e) {
      trace.done(0);
      developer.log('Error in generateResponseStream: $e', name: 'dyslexic_ai.inference');
      await _sessionManager.invalidateSession();
      _contextTokens = 0;
      InferenceMetrics.contextTokens.value = 0;
      rethrow;
    }
  }

  /// Generate response using chat-style inference (maintains context)
  Future<String> generateChatResponse(String prompt, {bool isBackgroundTask = false}) async {
    final trace = InferenceTrace(prompt.substring(0, math.min(80, prompt.length)));

    final inputTokens = _estimateTokens(prompt);
    await _ensureHeadroom(inputTokens);
    try {
      final session = await _sessionManager.getSession();
      await session.addQueryChunk(Message(text: prompt));

      // Use streaming but buffer for complete response
      final stream = session.getResponseAsync();
      final buffer = StringBuffer();
      int tokens = 0;
      await for (final chunk in stream) {
        if (chunk.trim().isNotEmpty) {
          tokens += chunk.split(RegExp(r'\s+')).length;
        }
        buffer.write(chunk);
      }

      final response = buffer.toString();
      trace.done(tokens);
      _contextTokens += inputTokens + tokens;
      InferenceMetrics.contextTokens.value = _contextTokens;
      
      developer.log('✅ Chat response complete: $tokens output tokens, context now $_contextTokens/$_maxContextTokens', 
          name: 'dyslexic_ai.inference');
      
      return _cleanAIResponse(response);

    } catch (e) {
      developer.log('Error in generateChatResponse: $e', name: 'dyslexic_ai.inference');
      throw Exception('Chat inference failed: $e');
    }
  }

  /// Generate streaming response using chat-style inference (maintains context)
  Future<Stream<String>> generateChatResponseStream(String prompt) async {
    final inputTokens = _estimateTokens(prompt);
    await _ensureHeadroom(inputTokens);
    
    try {
      final session = await _sessionManager.getSession();
      await session.addQueryChunk(Message(text: prompt));
      
      final controller = StreamController<String>();
      final stream = session.getResponseAsync();
      int tokens = 0;
      
      stream.listen((chunk) {
        if (chunk.trim().isNotEmpty) {
          tokens += chunk.split(RegExp(r'\s+')).length;
        }
        
        // Log streaming chunks for debugging
        developer.log('📝 Stream chunk: "${chunk.replaceAll('\n', '\\n')}"', name: 'dyslexic_ai.chat_stream');
        
        controller.add(_cleanAIResponse(chunk));
      }, onError: (e) {
        developer.log('Error in generateChatResponseStream: $e', name: 'dyslexic_ai.inference');
        controller.addError(Exception('Chat streaming failed: $e'));
      }, onDone: () {
        _contextTokens += inputTokens + tokens;
        InferenceMetrics.contextTokens.value = _contextTokens;
        
        developer.log('✅ Chat stream complete: $tokens output tokens, context now $_contextTokens/$_maxContextTokens', 
            name: 'dyslexic_ai.inference');
        
        controller.close();
      });
      
      return controller.stream;
    } catch (e) {
      developer.log('Error in generateChatResponseStream: $e', name: 'dyslexic_ai.inference');
      throw Exception('Chat streaming failed: $e');
    }
  }

  /// Legacy compatibility method
  Future<String> generateSentenceSimplification(String sentence) async {
    try {
      final variables = <String, String>{
        'target_sentence': sentence,
      };
      
      final template = await PromptLoader.load('shared', 'legacy_sentence_simplification.tmpl');
      final prompt = PromptLoader.fill(template, variables);
      
      return await generateResponse(prompt);
    } catch (e) {
      developer.log('❌ Failed to load sentence simplification template: $e', name: 'dyslexic_ai.inference');
      
      // Fallback to hardcoded prompt
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
  }
  
  /// Clean AI response by removing special tokens
  String _cleanAIResponse(String response) {
    return response
        .replaceAll('<end_of_turn>', '')
        .replaceAll('<start_of_turn>', '');
  }

  /// Dispose of the service
  Future<void> dispose() async {
    await _sessionManager.dispose();
  }
} 