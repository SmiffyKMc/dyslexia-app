import 'package:flutter_gemma/flutter_gemma_interface.dart';
import 'package:flutter_gemma/core/message.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'dart:math' as math;
import '../utils/inference_trace.dart';
import 'global_session_manager.dart';

// Session/context management constants
const int _maxContextTokens = 2048;
const int _outputTokenCap = 256; // we rarely need more than this per request
const int _rolloverThreshold = _maxContextTokens - _outputTokenCap; // 1792 headroom

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
    if (forceFreshSession || (_contextTokens + nextInputTokens + _outputTokenCap >= _rolloverThreshold)) {
      developer.log('💡 Rolling over session (contextTokens=$_contextTokens, nextInput=$nextInputTokens)', name: 'dyslexic_ai.inference');
      await _sessionManager.invalidateSession();
      _contextTokens = 0;
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
          return _cleanAIResponse(buffer.toString());
        } catch (fallbackError) {
          developer.log('Fallback also failed: $fallbackError', name: 'dyslexic_ai.inference');
        }
      }

      await _sessionManager.invalidateSession();
      _contextTokens = 0;
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
        controller.close();
      }, cancelOnError: true);

      return controller.stream;

    } catch (e) {
      trace.done(0);
      developer.log('Error in generateResponseStream: $e', name: 'dyslexic_ai.inference');
      await _sessionManager.invalidateSession();
      _contextTokens = 0;
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