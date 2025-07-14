import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/flutter_gemma_interface.dart';

/// Global session manager for flutter_gemma sessions
/// Eliminates session duplication across AIInferenceService and OcrService
/// Provides centralized session lifecycle management with advanced features
class GlobalSessionManager {
  static final GlobalSessionManager _instance = GlobalSessionManager._internal();
  factory GlobalSessionManager() => _instance;
  GlobalSessionManager._internal();

  // Core session management
  InferenceModelSession? _sharedSession;
  InferenceModel? _model;
  
  // Session configuration (same parameters used by all services)
  static const double temperature = 0.3;
  static const int topK = 10;
  
  // Advanced session management
  Timer? _sessionTimeoutTimer;
  int _usageCount = 0;
  DateTime? _lastUsed;
  DateTime? _sessionCreatedAt;
  
  // Session timeout configuration
  static const Duration sessionTimeout = Duration(minutes: 3);
  static const Duration maxSessionAge = Duration(minutes: 15);
  
  /// Get the shared session, creating it if necessary
  Future<InferenceModelSession> getSession() async {
    // Defensive programming: Check if current session is still valid with captured reference
    final currentSession = _sharedSession;
    if (currentSession != null && _isSessionHealthy) {
      _recordUsage();
      return currentSession; // Use captured reference to avoid race condition
    }
    
    // Create new session if needed
    developer.log('🆕 Creating new shared session...', name: 'dyslexic_ai.global_session');
    
    // Get model instance
    final model = await _getModel();
    if (model == null) {
      throw Exception('AI model not available - please ensure model is loaded');
    }
    
    // Create session with standard parameters
    final newSession = await model.createSession(
      temperature: temperature,
      topK: topK,
    );
    
    // Atomic assignment to prevent race conditions
    _sharedSession = newSession;
    _sessionCreatedAt = DateTime.now();
    _recordUsage();
    _startSessionTimeout();
    
    developer.log('✅ Shared session created successfully', name: 'dyslexic_ai.global_session');
    return newSession;
  }
  
  /// Invalidate the current session (call on errors)
  Future<void> invalidateSession() async {
    if (_sharedSession != null) {
      try {
        await _sharedSession!.close();
        developer.log('🗑️ Invalidated shared session', name: 'dyslexic_ai.global_session');
      } catch (e) {
        developer.log('⚠️ Error closing shared session: $e', name: 'dyslexic_ai.global_session');
      }
      _sharedSession = null;
    }
    
    _sessionCreatedAt = null;
    _cancelSessionTimeout();
  }
  
  /// Warm up the session (create it proactively)
  Future<void> warmupSession() async {
    if (_sharedSession == null) {
      developer.log('🔥 Warming up shared session...', name: 'dyslexic_ai.global_session');
      await getSession();
    }
  }
  
  /// Get current session statistics
  SessionStats getSessionStats() {
    return SessionStats(
      usageCount: _usageCount,
      lastUsed: _lastUsed,
      sessionCreatedAt: _sessionCreatedAt,
      isActive: _sharedSession != null,
      sessionAge: _sessionCreatedAt != null 
          ? DateTime.now().difference(_sessionCreatedAt!)
          : null,
    );
  }
  
  /// Check if the current session is healthy
  bool get _isSessionHealthy {
    if (_sharedSession == null) return false;
    
    // Check session age
    if (_sessionCreatedAt != null) {
      final age = DateTime.now().difference(_sessionCreatedAt!);
      if (age > maxSessionAge) {
        developer.log('⚠️ Session too old (${age.inMinutes}m), needs refresh', name: 'dyslexic_ai.global_session');
        return false;
      }
    }
    
    return true;
  }
  
  /// Get the model instance
  Future<InferenceModel?> _getModel() async {
    if (_model == null) {
      final plugin = FlutterGemmaPlugin.instance;
      _model = plugin.initializedModel;
      
      if (_model == null) {
        developer.log('❌ No model initialized', name: 'dyslexic_ai.global_session');
        return null;
      }
      
      developer.log('🤖 Model retrieved: ${_model.runtimeType}', name: 'dyslexic_ai.global_session');
    }
    
    return _model;
  }
  
  /// Record session usage
  void _recordUsage() {
    _usageCount++;
    _lastUsed = DateTime.now();
    
    // Reset session timeout on usage
    _startSessionTimeout();
    
    // Log usage periodically
    if (_usageCount % 10 == 0) {
      developer.log('📊 Session usage: $_usageCount operations', name: 'dyslexic_ai.global_session');
    }
  }
  
  /// Start session timeout timer
  void _startSessionTimeout() {
    _cancelSessionTimeout();
    
    _sessionTimeoutTimer = Timer(sessionTimeout, () {
      developer.log('⏰ Session timeout reached, closing session', name: 'dyslexic_ai.global_session');
      // Use fire-and-forget pattern for async operation in timer callback
      // ignore: unawaited_futures
      invalidateSession();
    });
  }
  
  /// Cancel session timeout timer
  void _cancelSessionTimeout() {
    _sessionTimeoutTimer?.cancel();
    _sessionTimeoutTimer = null;
  }
  
  /// Dispose of the session manager
  Future<void> dispose() async {
    developer.log('🗑️ Disposing GlobalSessionManager...', name: 'dyslexic_ai.global_session');
    
    await invalidateSession();
    _model = null;
    _usageCount = 0;
    _lastUsed = null;
    
    developer.log('✅ GlobalSessionManager disposed', name: 'dyslexic_ai.global_session');
  }
}

/// Session statistics data class
class SessionStats {
  final int usageCount;
  final DateTime? lastUsed;
  final DateTime? sessionCreatedAt;
  final bool isActive;
  final Duration? sessionAge;
  
  const SessionStats({
    required this.usageCount,
    required this.lastUsed,
    required this.sessionCreatedAt,
    required this.isActive,
    required this.sessionAge,
  });
  
  @override
  String toString() {
    return 'SessionStats(usage: $usageCount, active: $isActive, age: ${sessionAge?.inMinutes}m)';
  }
} 