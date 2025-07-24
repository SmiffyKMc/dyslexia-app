import 'package:flutter_gemma/flutter_gemma_interface.dart';
import 'package:flutter_gemma/core/message.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import '../utils/inference_trace.dart';
import '../utils/prompt_loader.dart';
import 'global_session_manager.dart';
import '../utils/inference_metrics.dart';


// Session/context management constants - now handled by activity-based policies
const int _maxContextTokens = 2048;
const int _outputTokenCap = 128;
const int _rolloverThreshold = _maxContextTokens - _outputTokenCap;

/// Enhanced AI inference service with activity-based session management
class AIInferenceService {
  final InferenceModel inferenceModel;
  final GlobalSessionManager _sessionManager;
  
  AIInferenceService(this.inferenceModel) : _sessionManager = GlobalSessionManager();

  // --- Internal helpers --------------------------------------------------
  int _estimateTokens(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  /// Estimate tokens for multimodal content (images consume significantly more)
  int _estimateMultimodalTokens(String text, {bool hasImage = false}) {
    final textTokens = _estimateTokens(text);
    if (hasImage) {
      // Images typically consume 200-500 tokens depending on size and complexity
      return textTokens + 400; // Conservative estimate
    }
    return textTokens;
  }

  /// Generate response with activity-based session management
  Future<String> generateResponse(
    String prompt, {
    String? fallbackPrompt,
    bool isBackgroundTask = false,
    bool forceFreshSession = false,
    AIActivity? activity,
  }) async {
    final targetActivity = activity ?? AIActivity.general;
    final trace = InferenceTrace(prompt.substring(0, math.min(80, prompt.length)));

    try {
      final session = await _sessionManager.getSession(
        activity: targetActivity,
        forceNew: forceFreshSession,
      );
      
      await session.addQueryChunk(Message(text: prompt));
      final inputTokens = _estimateTokens(prompt);

      // Use streaming to keep UI responsive but buffer until end for JSON integrity
      final stream = session.getResponseAsync();
      final buffer = StringBuffer();
      int outputTokens = 0;
      
      await for (final chunk in stream) {
        if (chunk.trim().isNotEmpty) {
          outputTokens += chunk.split(RegExp(r'\s+')).length;
        }
        buffer.write(chunk);
      }

      final response = buffer.toString();
      trace.done(outputTokens);
      
      // Update session manager with token usage for activity-based management
      final totalTokens = inputTokens + outputTokens;
      _sessionManager.updateTokenUsage(totalTokens);
      InferenceMetrics.contextTokens.value = totalTokens;
      
      developer.log('✅ Response complete for ${targetActivity.name}: $outputTokens output tokens', 
          name: 'dyslexic_ai.inference');
      
      return _cleanAIResponse(response);

    } catch (e) {
      trace.done(0);
      developer.log('Error in generateResponse for ${targetActivity.name}: $e', name: 'dyslexic_ai.inference');

      // Fallback prompt handling with fresh session
      if (fallbackPrompt != null) {
        try {
          developer.log('🔄 Attempting fallback with fresh session', name: 'dyslexic_ai.inference');
          final fbTrace = InferenceTrace(fallbackPrompt.substring(0, math.min(80, fallbackPrompt.length)));
          
          final session = await _sessionManager.getSession(
            activity: targetActivity,
            forceNew: true, // Always use fresh session for fallback
          );
          
          await session.addQueryChunk(Message(text: fallbackPrompt));
          final inputTokens = _estimateTokens(fallbackPrompt);
          
          final stream = session.getResponseAsync();
          final buffer = StringBuffer();
          int outputTokens = 0;
          
          await for (final chunk in stream) {
            if (chunk.trim().isNotEmpty) {
              outputTokens += chunk.split(RegExp(r'\s+')).length;
            }
            buffer.write(chunk);
          }
          
          fbTrace.done(outputTokens);
          _sessionManager.updateTokenUsage(inputTokens + outputTokens);
          
          developer.log('✅ Fallback successful for ${targetActivity.name}', name: 'dyslexic_ai.inference');
          return _cleanAIResponse(buffer.toString());
          
        } catch (fallbackError) {
          developer.log('❌ Fallback also failed for ${targetActivity.name}: $fallbackError', name: 'dyslexic_ai.inference');
        }
      }

      // Complete failure - invalidate session and rethrow
      await _sessionManager.invalidateSession();
      rethrow;
    }
  }
  
  /// Generate streaming response with activity-based session management  
  Future<Stream<String>> generateResponseStream(
    String prompt, {
    bool forceFreshSession = false,
    AIActivity? activity,
  }) async {
    final targetActivity = activity ?? AIActivity.general;
    final trace = InferenceTrace(prompt.substring(0, math.min(80, prompt.length)));
    
    try {
      final session = await _sessionManager.getSession(
        activity: targetActivity,
        forceNew: forceFreshSession,
      );
      
      await session.addQueryChunk(Message(text: prompt));
      final inputTokens = _estimateTokens(prompt);

      int outputTokens = 0;
      final original = session.getResponseAsync();
      final controller = StreamController<String>();
      
      original.listen((token) {
        if (token.trim().isNotEmpty) {
          outputTokens += token.split(RegExp(r'\s+')).length;
        }
        controller.add(_cleanAIResponse(token));
      }, onError: (e) {
        trace.done(outputTokens);
        controller.addError(e);
      }, onDone: () {
        trace.done(outputTokens);
        _sessionManager.updateTokenUsage(inputTokens + outputTokens);
        InferenceMetrics.contextTokens.value = inputTokens + outputTokens;
        controller.close();
      }, cancelOnError: true);

      return controller.stream;

    } catch (e) {
      trace.done(0);
      developer.log('Error in generateResponseStream for ${targetActivity.name}: $e', name: 'dyslexic_ai.inference');
      await _sessionManager.invalidateSession();
      rethrow;
    }
  }

  /// Generate response using multimodal inference (for OCR)
  Future<String> generateMultimodalResponse(
    String prompt,
    Uint8List imageBytes, {
    bool forceFreshSession = true, // OCR always needs fresh session
  }) async {
    const activity = AIActivity.ocrProcessing;
    final trace = InferenceTrace('OCR: ${prompt.substring(0, math.min(40, prompt.length))}');

    try {
      // OCR operations always get fresh sessions due to high token consumption
      final session = await _sessionManager.getSession(
        activity: activity,
        forceNew: forceFreshSession,
      );
      
      final message = Message(
        text: prompt,
        imageBytes: imageBytes,
        isUser: true,
      );
      
      developer.log('🖼️ Processing OCR request (${imageBytes.length} bytes)', name: 'dyslexic_ai.inference');
      
      await session.addQueryChunk(message);
      final estimatedTokens = _estimateMultimodalTokens(prompt, hasImage: true);
      
      // Get response
      final response = await session.getResponse();
      final outputTokens = _estimateTokens(response);
      
      trace.done(outputTokens);
      _sessionManager.updateTokenUsage(estimatedTokens + outputTokens);
      
      developer.log('✅ OCR response complete: ${response.length} chars, ~${outputTokens} tokens', 
          name: 'dyslexic_ai.inference');
      
      return _cleanAIResponse(response);
      
    } catch (e) {
      trace.done(0);
      developer.log('❌ OCR operation failed: $e', name: 'dyslexic_ai.inference');
      
      // OCR failures always invalidate session due to potential corruption from image processing
      await _sessionManager.invalidateSession();
      rethrow;
    }
  }

  /// Generate response using chat-style inference (maintains context)
  Future<String> generateChatResponse(
    String prompt, {
    bool isBackgroundTask = false,
    AIActivity? activity,
  }) async {
    final targetActivity = activity ?? AIActivity.general;
    final trace = InferenceTrace(prompt.substring(0, math.min(80, prompt.length)));

    try {
      final session = await _sessionManager.getSession(activity: targetActivity);      
      await session.addQueryChunk(Message(text: prompt));
      final inputTokens = _estimateTokens(prompt);

      // Use streaming but buffer for complete response
      final stream = session.getResponseAsync();
      final buffer = StringBuffer();
      int outputTokens = 0;
      
      await for (final chunk in stream) {
        if (chunk.trim().isNotEmpty) {
          outputTokens += chunk.split(RegExp(r'\s+')).length;
        }
        buffer.write(chunk);
      }

      final response = buffer.toString();
      trace.done(outputTokens);
      _sessionManager.updateTokenUsage(inputTokens + outputTokens);
      
      developer.log('✅ Chat response complete for ${targetActivity.name}: $outputTokens output tokens', 
          name: 'dyslexic_ai.inference');
      
      return _cleanAIResponse(response);

    } catch (e) {
      developer.log('❌ Chat inference failed for ${targetActivity.name}: $e', name: 'dyslexic_ai.inference');
      throw Exception('Chat inference failed: $e');
    }
  }

  /// Generate streaming chat response with activity-based session management
  Future<Stream<String>> generateChatResponseStream(
    String prompt, {
    AIActivity? activity,
  }) async {
    final targetActivity = activity ?? AIActivity.general;
    
    try {
      final session = await _sessionManager.getSession(activity: targetActivity);
      await session.addQueryChunk(Message(text: prompt));
      final inputTokens = _estimateTokens(prompt);
      
      final controller = StreamController<String>();
      final stream = session.getResponseAsync();
      int outputTokens = 0;
      
      stream.listen((chunk) {
        if (chunk.trim().isNotEmpty) {
          outputTokens += chunk.split(RegExp(r'\s+')).length;
        }
        
        developer.log('📝 Stream chunk: "${chunk.replaceAll('\n', '\\n')}"', name: 'dyslexic_ai.chat_stream');
        controller.add(_cleanAIResponse(chunk));
      }, onError: (e) {
        developer.log('❌ Chat streaming failed for ${targetActivity.name}: $e', name: 'dyslexic_ai.inference');
        controller.addError(Exception('Chat streaming failed: $e'));
      }, onDone: () {
        _sessionManager.updateTokenUsage(inputTokens + outputTokens);
        
        developer.log('✅ Chat stream complete for ${targetActivity.name}: $outputTokens output tokens', 
            name: 'dyslexic_ai.inference');
        
        controller.close();
      });
      
      return controller.stream;
    } catch (e) {
      developer.log('❌ Chat streaming failed for ${targetActivity.name}: $e', name: 'dyslexic_ai.inference');
      throw Exception('Chat streaming failed: $e');
    }
  }

  /// Legacy compatibility method - now uses activity-based sessions
  Future<String> generateCompatibilityResponse(String prompt) async {
    return generateResponse(prompt, activity: AIActivity.general);
  }

  /// Quick sentence simplification for reading assistance
  Future<String> simplifySentence(String sentence) async {
    final prompt = '''
Simplify this sentence for someone with dyslexia:
- Using simpler vocabulary
- Maintaining the original meaning
- More accessible for someone with reading difficulties

Original sentence: $sentence

Provide only the simplified version.
''';
      
    return await generateResponse(prompt, activity: AIActivity.textSimplification);
  }
  
  /// Get session debugging information
  Map<String, dynamic> getSessionDebugInfo() {
    return _sessionManager.getSessionInfo();
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