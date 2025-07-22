import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/flutter_gemma_interface.dart';

/// Simplified global session manager following flutter_gemma best practices
class GlobalSessionManager {
  static final GlobalSessionManager _instance = GlobalSessionManager._internal();
  factory GlobalSessionManager() => _instance;
  GlobalSessionManager._internal();

  InferenceModelSession? _session;
  InferenceModel? _model;
  
  /// Standard session configuration
  static const double temperature = 0.3;
  static const int topK = 10;
  
  /// Get the shared session, creating it if necessary
  Future<InferenceModelSession> getSession() async {
    if (_session != null) {
      developer.log('♻️ Reusing existing session', name: 'dyslexic_ai.session');
      return _session!;
    }
    
    developer.log('🆕 Creating new session...', name: 'dyslexic_ai.session');
    
    final model = await _getModel();
    if (model == null) {
      throw Exception('AI model not available - please ensure model is loaded');
    }
    
    _session = await model.createSession(
      temperature: temperature,
      topK: topK,
    );
    
    developer.log('✅ Session created successfully', name: 'dyslexic_ai.session');
    return _session!;
  }
  
  /// Invalidate the current session (call on errors)
  Future<void> invalidateSession() async {
    if (_session != null) {
      try {
        await _session!.close();
        developer.log('Session invalidated', name: 'dyslexic_ai.session');
      } catch (e) {
        developer.log('Error closing session: $e', name: 'dyslexic_ai.session');
      }
      _session = null;
    }
  }
  
  /// Warm up the session (create it proactively) - for compatibility
  Future<void> warmupSession() async {
    if (_session == null) {
      developer.log('Warming up session...', name: 'dyslexic_ai.session');
      final s = await getSession();
      try {
        // Trigger delegate compilation with a tiny prompt
        await s.addQueryChunk(const Message(text: 'hello'));
        final stream = s.getResponseAsync();
        await stream.first.timeout(const Duration(seconds: 5));
        developer.log('Warm-up inference completed', name: 'dyslexic_ai.session');
      } catch (_) {
        // Ignore – this is best-effort
      }
    }
  }
  
  /// Get the model instance
  Future<InferenceModel?> _getModel() async {
    if (_model == null) {
      final plugin = FlutterGemmaPlugin.instance;
      _model = plugin.initializedModel;
      
      if (_model == null) {
        developer.log('No model initialized', name: 'dyslexic_ai.session');
        return null;
      }
    }
    
    return _model;
  }
  
  /// Dispose of the session manager
  Future<void> dispose() async {
    await invalidateSession();
    _model = null;
  }
} 