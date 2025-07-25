import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_gemma/flutter_gemma.dart';

/// Activity types for session management
enum AIActivity {
  sentenceGeneration,
  ocrProcessing,
  profileAnalysis,
  textSimplification,
  storyGeneration,
  phonicsGeneration,
  wordAnalysis,
  general,
}

/// Activity-specific session policies
class SessionPolicy {
  final bool requiresFreshSession;
  final int maxTokenBudget;
  final String description;
  
  const SessionPolicy({
    required this.requiresFreshSession,
    required this.maxTokenBudget,
    required this.description,
  });
}

/// Simplified global session manager with activity-based lifecycle management
class GlobalSessionManager {
  static final GlobalSessionManager _instance = GlobalSessionManager._internal();
  factory GlobalSessionManager() => _instance;
  GlobalSessionManager._internal();

  InferenceModelSession? _session;
  InferenceModel? _model;
  AIActivity? _currentActivity;
  DateTime? _sessionCreatedAt;
  int _estimatedTokensUsed = 0;
  int _powerUserOperationCount = 0; // Track operations for power user session management
  
  /// Standard session configuration
  static const double temperature = 0.3;
  static const int topK = 10;
  
  /// Session timeout duration (auto-cleanup) - AGGRESSIVE for power users
  static const Duration sessionTimeout = Duration(minutes: 2); // Reduced from 5 to 2
  
  /// Global token ceiling - ensure we never exceed model limits
  static const int globalTokenCeiling = 1800; // Safe margin below 2048
  
  /// Activity-specific session policies - REDUCED budgets for power users
  static const Map<AIActivity, SessionPolicy> _activityPolicies = {
    AIActivity.ocrProcessing: SessionPolicy(
      requiresFreshSession: true,
      maxTokenBudget: 600, // Reduced from 800
      description: 'OCR operations always need fresh sessions due to high image token consumption',
    ),
    AIActivity.profileAnalysis: SessionPolicy(
      requiresFreshSession: true,
      maxTokenBudget: 400, // Reduced from 600
      description: 'Profile analysis needs clean context for accurate assessment',
    ),
    AIActivity.sentenceGeneration: SessionPolicy(
      requiresFreshSession: true, // Changed to true for power users
      maxTokenBudget: 500, // Reduced from 800
      description: 'Sentence generation uses fresh sessions for power users',
    ),
    AIActivity.textSimplification: SessionPolicy(
      requiresFreshSession: true, // Changed to true for power users
      maxTokenBudget: 300, // Reduced from 500
      description: 'Text simplification uses fresh sessions for power users',
    ),
    AIActivity.storyGeneration: SessionPolicy(
      requiresFreshSession: true, // Changed to true for power users
      maxTokenBudget: 600, // Reduced from 1000
      description: 'Story generation uses fresh sessions for power users',
    ),
    AIActivity.phonicsGeneration: SessionPolicy(
      requiresFreshSession: true, // Changed to true for power users
      maxTokenBudget: 800, // Reduced from 1500
      description: 'Phonics generation uses fresh sessions for power users',
    ),
    AIActivity.wordAnalysis: SessionPolicy(
      requiresFreshSession: true, // Changed to true for power users
      maxTokenBudget: 400, // Reduced from 800
      description: 'Word analysis uses fresh sessions for power users',
    ),
    AIActivity.general: SessionPolicy(
      requiresFreshSession: false,
      maxTokenBudget: 300, // Reduced from 500
      description: 'General purpose operations',
    ),
  };
  
  /// Get session with activity-based lifecycle management
  Future<InferenceModelSession> getSession({
    AIActivity? activity,
    bool forceNew = false,
  }) async {
    final targetActivity = activity ?? AIActivity.general;
    final policy = _activityPolicies[targetActivity]!;
    
    // Check if we need a fresh session based on policy or request
    final needsFreshSession = forceNew || 
        policy.requiresFreshSession ||
        _shouldCreateNewSession(targetActivity, policy);
    
    if (needsFreshSession) {
      await invalidateSession();
      developer.log('🔄 Creating fresh session for activity: ${targetActivity.name} (${policy.description})', 
          name: 'dyslexic_ai.session');
    }
    
    if (_session != null) {
      developer.log('♻️ Reusing existing session for activity: ${targetActivity.name}', 
          name: 'dyslexic_ai.session');
      return _session!;
    }
    
    developer.log('🆕 Creating new session for activity: ${targetActivity.name}...', 
        name: 'dyslexic_ai.session');
    
    final model = await _getModel();
    if (model == null) {
      throw Exception('AI model not available - please ensure model is loaded');
    }
    
    _session = await model.createSession(
      temperature: temperature,
      topK: topK,
    );
    
    _currentActivity = targetActivity;
    _sessionCreatedAt = DateTime.now();
    _estimatedTokensUsed = 0;
    
    developer.log('✅ Session created successfully for activity: ${targetActivity.name}', 
        name: 'dyslexic_ai.session');
    return _session!;
  }
  
  /// Check if a new session should be created based on activity and policy
  bool _shouldCreateNewSession(AIActivity activity, SessionPolicy policy) {
    // Different activity than current session - ALWAYS invalidate for power users
    if (_currentActivity != null && _currentActivity != activity) {
      developer.log('🔄 Activity changed from ${_currentActivity!.name} to ${activity.name} - forcing fresh session', 
          name: 'dyslexic_ai.session');
      return true;
    }
    
    // Global token ceiling check - CRITICAL for power users
    if (_estimatedTokensUsed > globalTokenCeiling) {
      developer.log('🚨 GLOBAL token ceiling exceeded: $_estimatedTokensUsed > $globalTokenCeiling - forcing fresh session', 
          name: 'dyslexic_ai.session');
      return true;
    }
    
    // Session timeout check - more aggressive for power users
    if (_sessionCreatedAt != null && 
        DateTime.now().difference(_sessionCreatedAt!).compareTo(sessionTimeout) > 0) {
      developer.log('⏰ Session timeout exceeded (${sessionTimeout.inMinutes}m) - forcing fresh session', 
          name: 'dyslexic_ai.session');
      return true;
    }
    
    // Activity-specific token budget exceeded
    if (_estimatedTokensUsed > policy.maxTokenBudget) {
      developer.log('🪙 Activity token budget exceeded for ${activity.name}: $_estimatedTokensUsed > ${policy.maxTokenBudget} - forcing fresh session', 
          name: 'dyslexic_ai.session');
      return true;
    }
    
    // For power users: invalidate session every 3 operations to prevent accumulation
    _powerUserOperationCount++;
    if (_powerUserOperationCount >= 3) {
      _powerUserOperationCount = 0;
      developer.log('🔄 Power user: 3 operations completed - forcing fresh session for reliability', 
          name: 'dyslexic_ai.session');
      return true;
    }
    
    return false;
  }
  
  /// Update estimated token usage (called by AIInferenceService)
  void updateTokenUsage(int tokensDelta) {
    _estimatedTokensUsed += tokensDelta;
    
    // Log with warning if approaching limits
    if (_estimatedTokensUsed > globalTokenCeiling * 0.8) {
      developer.log('⚠️ Session approaching token limit: $_estimatedTokensUsed tokens (${((_estimatedTokensUsed / globalTokenCeiling) * 100).round()}%)', 
          name: 'dyslexic_ai.session');
    } else {
      developer.log('🪙 Session token usage updated: $_estimatedTokensUsed tokens', 
          name: 'dyslexic_ai.session');
    }
    
    // Force invalidation if we exceed global ceiling
    if (_estimatedTokensUsed > globalTokenCeiling) {
      developer.log('🚨 CRITICAL: Token usage exceeded global ceiling, invalidating session immediately', 
          name: 'dyslexic_ai.session');
      invalidateSession();
    }
  }
  
  /// Reset token counter (for new sessions)
  void resetTokenUsage() {
    _estimatedTokensUsed = 0;
  }
  
  /// Invalidate the current session (call on errors or activity boundaries)
  Future<void> invalidateSession() async {
    if (_session != null) {
      try {
        await _session!.close();
        developer.log('Session invalidated (was: ${_currentActivity?.name ?? "unknown"})', 
            name: 'dyslexic_ai.session');
      } catch (e) {
        developer.log('Error closing session: $e', name: 'dyslexic_ai.session');
      }
      _session = null;
      _currentActivity = null;
      _sessionCreatedAt = null;
      _estimatedTokensUsed = 0;
      _powerUserOperationCount = 0; // Reset operation counter
    }
  }
  
  /// Force invalidation for high-risk operations (OCR, profile updates)
  Future<void> invalidateSessionForHighRiskOperation(String operationName) async {
    developer.log('🚨 Forcing session invalidation before high-risk operation: $operationName', 
        name: 'dyslexic_ai.session');
    await invalidateSession();
  }
  
  /// Get session info for debugging
  Map<String, dynamic> getSessionInfo() {
    return {
      'hasActiveSession': _session != null,
      'currentActivity': _currentActivity?.name,
      'estimatedTokens': _estimatedTokensUsed,
      'sessionAge': _sessionCreatedAt != null 
          ? DateTime.now().difference(_sessionCreatedAt!).inMinutes
          : null,
    };
  }
  
  /// Warm up the session (create it proactively) - for compatibility
  Future<void> warmupSession() async {
    if (_session == null) {
      developer.log('Warming up session...', name: 'dyslexic_ai.session');
      try {
        // Trigger delegate compilation with a tiny prompt
        final s = await getSession(activity: AIActivity.general);
        await s.addQueryChunk(const Message(text: 'hello'));
        final stream = s.getResponseAsync();
        await stream.first.timeout(const Duration(seconds: 5));
        developer.log('Warm-up inference completed', name: 'dyslexic_ai.session');
      } catch (_) {
        // Ignore – this is best-effort
      }
    }
  }
  
  /// Legacy compatibility - get session without activity context
  Future<InferenceModelSession> getLegacySession() async {
    return getSession(activity: AIActivity.general);
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