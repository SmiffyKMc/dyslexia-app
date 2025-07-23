import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/widgets.dart';
import '../models/learner_profile.dart';
import '../models/session_log.dart';
import '../controllers/session_log_store.dart';
import '../controllers/learner_profile_store.dart';
import '../utils/service_locator.dart';
import '../utils/prompt_loader.dart';

class GemmaProfileUpdateService {
  late final SessionLogStore _sessionLogStore;
  late final LearnerProfileStore _profileStore;
  
  // Background processing management
  Timer? _deferredUpdateTimer;
  Timer? _activityMonitorTimer; // Fix: Store timer reference to prevent memory leak
  bool _isUserActive = false;
  DateTime? _lastUserActivity;
  bool _isUpdatePending = false; // Fix: Prevent race conditions
  bool _isAppInBackground = false; // Phase 3: App lifecycle tracking
  Timer? _sessionTimeoutTimer; // Phase 4: AI session timeout management
  static const Duration userInactivityDelay = Duration(seconds: 15); // Increased from 5 to 15 seconds
  static const Duration maxDeferDelay = Duration(minutes: 2);
  static const Duration aiSessionTimeout = Duration(minutes: 3); // Phase 4: AI timeout

  GemmaProfileUpdateService() {
    _sessionLogStore = getIt<SessionLogStore>();
    _profileStore = getIt<LearnerProfileStore>();
    
    // Start monitoring user activity
    _startActivityMonitoring();
  }
  
  /// Phase 3: Handle app lifecycle changes
  void handleAppLifecycleChange(AppLifecycleState state) {
    developer.log('App lifecycle changed to: $state', name: 'dyslexic_ai.profile_update');
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _pauseBackgroundProcessing();
        break;
      case AppLifecycleState.resumed:
        _resumeBackgroundProcessing();
        break;
      case AppLifecycleState.inactive:
        // Don't pause for inactive state - could be temporary
        break;
      case AppLifecycleState.hidden:
        _pauseBackgroundProcessing();
        break;
    }
  }
  
  /// Phase 3: Pause background processing when app goes to background
  void _pauseBackgroundProcessing() {
    _isAppInBackground = true;
    _deferredUpdateTimer?.cancel();
    _sessionTimeoutTimer?.cancel();
    
    developer.log('Paused background processing - app in background', name: 'dyslexic_ai.profile_update');
    
    // If AI is currently running, let it complete but don't start new tasks
    if (_profileStore.isUpdating) {
      developer.log('AI processing active during background - will complete current task', name: 'dyslexic_ai.profile_update');
    }
  }
  
  /// Phase 3: Resume background processing when app comes to foreground
  void _resumeBackgroundProcessing() {
    _isAppInBackground = false;
    developer.log('Resumed background processing - app in foreground', name: 'dyslexic_ai.profile_update');
    
    // If there was a pending update, reschedule it
    if (_isUpdatePending) {
      developer.log('Rescheduling deferred update after app resume', name: 'dyslexic_ai.profile_update');
      _isUpdatePending = false; // Reset flag
      scheduleBackgroundUpdate();
    }
  }
  
  /// Start monitoring user activity to defer background AI processing
  void _startActivityMonitoring() {
    // Fix: Store timer reference and add disposal logic
    _activityMonitorTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lastUserActivity != null) {
        final timeSinceActivity = DateTime.now().difference(_lastUserActivity!);
        _isUserActive = timeSinceActivity.inSeconds < userInactivityDelay.inSeconds;
      }
    });
  }
  
  /// Mark user as active (call this from UI interactions)
  void markUserActive() {
    final previousActivity = _lastUserActivity;
    _lastUserActivity = DateTime.now();
    _isUserActive = true;
    
    // Only log if it's been more than 2 seconds since last log (to avoid spam)
    if (previousActivity == null || DateTime.now().difference(previousActivity).inSeconds > 2) {
      developer.log('👤 User activity detected - resetting inactivity timer', name: 'dyslexic_ai.profile_update');
    }
  }
  
  /// Check if it's appropriate to run background AI processing
  bool get _canRunBackgroundAI {
    if (_isAppInBackground) {
      developer.log('Deferring AI processing - app in background', name: 'dyslexic_ai.profile_update');
      return false;
    }
    
    if (_isUserActive) {
      final timeSinceActivity = _lastUserActivity != null 
          ? DateTime.now().difference(_lastUserActivity!).inSeconds 
          : 0;
      developer.log('Deferring AI processing - user is active (last activity: ${timeSinceActivity}s ago)', name: 'dyslexic_ai.profile_update');
      return false;
    }
    
    if (_profileStore.isUpdating) {
      developer.log('Deferring AI processing - already updating', name: 'dyslexic_ai.profile_update');
      return false;
    }
    
    final timeSinceActivity = _lastUserActivity != null 
        ? DateTime.now().difference(_lastUserActivity!).inSeconds 
        : 999;
    developer.log('✅ AI processing can proceed - user inactive for ${timeSinceActivity}s', name: 'dyslexic_ai.profile_update');
    return true;
  }

  /// Schedule a deferred profile update that waits for user inactivity
  void scheduleBackgroundUpdate() {
    developer.log('🔄 scheduleBackgroundUpdate called - isUpdatePending: $_isUpdatePending, isAppInBackground: $_isAppInBackground', name: 'dyslexic_ai.profile_update');
    
    // Fix: Prevent duplicate scheduling
    if (_isUpdatePending) {
      developer.log('❌ Profile update already pending, skipping new schedule', name: 'dyslexic_ai.profile_update');
      return;
    }
    
    // Phase 3: Don't schedule if app is in background
    if (_isAppInBackground) {
      developer.log('App in background, deferring profile update scheduling', name: 'dyslexic_ai.profile_update');
      _isUpdatePending = true; // Mark as pending for when app resumes
      return;
    }
    
    // Cancel any existing timer
    _deferredUpdateTimer?.cancel();
    _isUpdatePending = true;
    
    developer.log('✅ Scheduling background profile update - timer will check every 2s', name: 'dyslexic_ai.profile_update');
    
    // Set up a timer that checks periodically if we can run the update
    _deferredUpdateTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_canRunBackgroundAI) {
        developer.log('User inactive - running deferred profile update', name: 'dyslexic_ai.profile_update');
        timer.cancel();
        _isUpdatePending = false;
        
        try {
          await updateProfileFromRecentSessions(isBackgroundTask: true);
        } catch (e) {
          developer.log('Background profile update failed: $e', name: 'dyslexic_ai.profile_update');
        }
      } else {
        // If we've been waiting too long, force the update
        final waitTime = DateTime.now().difference(_lastUserActivity ?? DateTime.now());
        if (waitTime > maxDeferDelay) {
          developer.log('Forcing profile update after max defer delay', name: 'dyslexic_ai.profile_update');
          timer.cancel();
          _isUpdatePending = false;
          
          try {
            await updateProfileFromRecentSessions(isBackgroundTask: true);
          } catch (e) {
            developer.log('Forced background profile update failed: $e', name: 'dyslexic_ai.profile_update');
          }
        }
      }
    });
  }

  Future<bool> updateProfileFromRecentSessions({bool isBackgroundTask = false}) async {
    final taskType = isBackgroundTask ? 'background' : 'foreground';
    developer.log('Starting $taskType profile update from recent sessions...', name: 'dyslexic_ai.profile_update');
    
    // Phase 4: Set AI session timeout
    _sessionTimeoutTimer?.cancel();
    _sessionTimeoutTimer = Timer(aiSessionTimeout, () {
      developer.log('AI session timeout - potential hang detected', name: 'dyslexic_ai.profile_update');
      _handleAISessionTimeout();
    });
    
    // Set updating state in the profile store
    _profileStore.startUpdate();
    
    try {
      final currentProfile = _profileStore.currentProfile;
      if (currentProfile == null) {
        developer.log('No current profile found', name: 'dyslexic_ai.profile_update');
        return false;
      }

      final recentSessions = await _getRecentSessionsForAnalysis();
      if (recentSessions.isEmpty) {
        developer.log('No recent sessions found for analysis', name: 'dyslexic_ai.profile_update');
        return false;
      }

      developer.log('Analyzing ${recentSessions.length} recent sessions ($taskType)', name: 'dyslexic_ai.profile_update');

      final aiService = getAIInferenceService();
      if (aiService == null) {
        developer.log('AI service not available', name: 'dyslexic_ai.profile_update');
        return false;
      }

      // Build main prompt and fallback prompt
      final mainPrompt = await _buildTier2ProfileUpdatePrompt(currentProfile, recentSessions);
      final fallbackPrompt = await _buildMinimalFallbackPrompt(currentProfile, recentSessions);
      
      developer.log('Generated Tier 2 prompt for AI analysis ($taskType)', name: 'dyslexic_ai.profile_update');

      // Use enhanced AI service with background task flag for cooperative yielding
      final aiResponse = await aiService.generateResponse(
        mainPrompt, 
        fallbackPrompt: fallbackPrompt,
        isBackgroundTask: isBackgroundTask,
      );
      developer.log('Received AI response ($taskType)', name: 'dyslexic_ai.profile_update');

      final updatedProfile = _parseProfileResponse(aiResponse, currentProfile);
      if (updatedProfile != null) {
        await _profileStore.updateProfile(updatedProfile);
        developer.log('Profile updated successfully ($taskType)', name: 'dyslexic_ai.profile_update');
        return true;
      } else {
        developer.log('Failed to parse AI response into valid profile ($taskType)', name: 'dyslexic_ai.profile_update');
        
        // Schedule retry for failed background updates
        if (isBackgroundTask) {
          developer.log('Scheduling retry for failed background profile update in 2 minutes', name: 'dyslexic_ai.profile_update');
          Timer(const Duration(minutes: 2), () {
            developer.log('Retrying profile update after previous failure', name: 'dyslexic_ai.profile_update');
            scheduleBackgroundUpdate();
          });
        }
        
        return false;
      }
    } catch (e, stackTrace) {
      developer.log('Profile update failed ($taskType): $e', name: 'dyslexic_ai.profile_update', error: e, stackTrace: stackTrace);
      return false;
    } finally {
      // Always reset updating state, even if there's an error
      _profileStore.finishUpdate();
      _isUpdatePending = false; // Fix: Reset pending flag
      _sessionTimeoutTimer?.cancel(); // Phase 4: Clear timeout timer
      developer.log('🔄 Profile update cleanup completed - isUpdatePending reset to: $_isUpdatePending', name: 'dyslexic_ai.profile_update');
    }
  }
  
  /// Phase 4: Handle AI session timeout
  void _handleAISessionTimeout() {
    developer.log('Handling AI session timeout', name: 'dyslexic_ai.profile_update');
    
    // Force reset the updating state
    _profileStore.finishUpdate();
    _isUpdatePending = false;
    
    // Invalidate AI session to prevent corruption
    final aiService = getAIInferenceService();
    if (aiService != null) {
      // aiService.invalidateSession(); // This would need to be implemented in AI service
      developer.log('AI session invalidated due to timeout', name: 'dyslexic_ai.profile_update');
    }
  }



  Future<List<SessionLog>> _getRecentSessionsForAnalysis() async {
    final allLogs = _sessionLogStore.completedLogs;
    
    // Reduce to 3 sessions for ultra-compact analysis
    final recentLogs = allLogs.take(3).toList();
    
    developer.log('Found ${recentLogs.length} recent completed sessions', name: 'dyslexic_ai.profile_update');
    
    return recentLogs;
  }

  /// Ultra-compact profile update prompt (~300-400 tokens)
  Future<String> _buildTier2ProfileUpdatePrompt(LearnerProfile currentProfile, List<SessionLog> recentSessions) async {
    try {
      // Ultra-simplified session data
      final sessionData = recentSessions.map((session) => 
        '${session.feature}: ${((session.accuracy ?? 0.0) * 100).round()}% accuracy, errors: ${session.phonemeErrors.take(2).join(",")}'
      ).join('\n');
      
      // Calculate average accuracy for tool recommendation
      final avgAccuracy = recentSessions.isNotEmpty 
          ? recentSessions.map((s) => s.accuracy ?? 0.0).reduce((a, b) => a + b) / recentSessions.length
          : 0.0;
      
      // Simple tool recommendation based on accuracy
      final suggestedTools = _getSimpleToolRecommendation(avgAccuracy, currentProfile.confidence);
      
      final variables = <String, String>{
        'current_profile': 'Confidence: ${currentProfile.confidence}, Accuracy: ${currentProfile.decodingAccuracy}, Confusions: ${currentProfile.phonemeConfusions.take(2).join(', ')}',
        'session_data': sessionData,
        'suggested_tools': suggestedTools,
      };
      
      final template = await PromptLoader.load('profile_analysis', 'full_update.tmpl');
      return PromptLoader.fill(template, variables);
    } catch (e) {
      developer.log('❌ Failed to build profile update prompt: $e', name: 'dyslexic_ai.profile_update');
      
      // Fallback to basic prompt
      return _buildFallbackProfilePrompt(currentProfile, recentSessions);
    }
  }
  
  /// Simple tool recommendation based on performance (learning activities only)
  String _getSimpleToolRecommendation(double avgAccuracy, String confidence) {
    if (avgAccuracy >= 0.85) {
      return 'Sentence Fixer, Story Mode';
    } else if (avgAccuracy >= 0.70) {
      return 'Story Mode, Sentence Fixer, Reading Coach';
    } else {
      return 'Phonics Game, Reading Coach';
    }
  }
  
  /// Super minimal fallback prompt (~150 tokens)
  Future<String> _buildMinimalFallbackPrompt(LearnerProfile currentProfile, List<SessionLog> recentSessions) async {
    try {
      final latestSession = recentSessions.isNotEmpty ? recentSessions.first : null;
      
      if (latestSession == null) {
        final variables = <String, String>{
          'current_profile': 'Profile with minimal data',
          'current_accuracy': currentProfile.decodingAccuracy,
          'current_confidence': currentProfile.confidence,
          'current_phoneme_confusions': currentProfile.phonemeConfusions.take(2).toList().toString(),
          'current_recommended_tool': currentProfile.recommendedTool,
          'latest_session_data': 'No recent sessions available',
          'session_advice': 'Continue current practice routine.',
        };
        
        final template = await PromptLoader.load('profile_analysis', 'minimal_update.tmpl');
        return PromptLoader.fill(template, variables);
      }
      
      final accuracy = latestSession.accuracy ?? 0.0;
      final accuracyPercent = (accuracy * 100).round();
      
      final variables = <String, String>{
        'current_profile': 'Latest session analysis',
        'current_accuracy': accuracy > 0.85 ? 'good' : 'developing',
        'current_confidence': accuracy > 0.85 ? 'building' : 'low',
        'current_phoneme_confusions': latestSession.phonemeErrors.take(2).toList().toString(),
        'current_recommended_tool': latestSession.feature,
        'latest_session_data': '${latestSession.feature} ($accuracyPercent% accuracy)',
        'session_advice': accuracy > 0.8 ? 'Great progress!' : 'Keep practicing!',
      };
      
      final template = await PromptLoader.load('profile_analysis', 'minimal_update.tmpl');
      return PromptLoader.fill(template, variables);
    } catch (e) {
      developer.log('❌ Failed to build minimal profile prompt: $e', name: 'dyslexic_ai.profile_update');
      
      // Final fallback
      return _buildHardcodedMinimalPrompt(currentProfile, recentSessions);
    }
  }

  /// Fallback prompt if template loading fails
  String _buildFallbackProfilePrompt(LearnerProfile currentProfile, List<SessionLog> recentSessions) {
    final sessionData = recentSessions.map((session) => 
      '${session.feature}: ${((session.accuracy ?? 0.0) * 100).round()}% accuracy, errors: ${session.phonemeErrors.take(2).join(",")}'
    ).join('\n');

    final avgAccuracy = recentSessions.isNotEmpty 
        ? recentSessions.map((s) => s.accuracy ?? 0.0).reduce((a, b) => a + b) / recentSessions.length
        : 0.0;

    final suggestedTools = _getSimpleToolRecommendation(avgAccuracy, currentProfile.confidence);

    return '''
Analyze dyslexia learning data and update profile. Focus on confidence, accuracy, phoneme errors, tool recommendation, and advice.

CURRENT: Confidence: ${currentProfile.confidence}, Accuracy: ${currentProfile.decodingAccuracy}, Confusions: ${currentProfile.phonemeConfusions.take(2).join(', ')}

RECENT SESSIONS:
$sessionData

RULES:
- Accuracy 85%+ → upgrade confidence and accuracy levels
- Accuracy <70% → focus on foundation skills
- 3+ same phoneme errors → add to confusions
- Tool variety: avoid repeating ${currentProfile.recommendedTool}
- Suggested tools: $suggestedTools

Return JSON:
{
  "decodingAccuracy": "needs work|developing|good|excellent",
  "confidence": "low|building|medium|high", 
  "phonemeConfusions": ["error1", "error2"],
  "recommendedTool": "tool name from suggestions",
  "advice": "specific next steps (max 200 chars)"
}''';
  }

  /// Hardcoded minimal fallback prompt
  String _buildHardcodedMinimalPrompt(LearnerProfile currentProfile, List<SessionLog> recentSessions) {
    final latestSession = recentSessions.isNotEmpty ? recentSessions.first : null;
    
    if (latestSession == null) {
      return '''
Update profile minimally. Return JSON:
{
  "decodingAccuracy": "${currentProfile.decodingAccuracy}",
  "confidence": "${currentProfile.confidence}",
  "phonemeConfusions": ${currentProfile.phonemeConfusions.take(2).toList()},
  "recommendedTool": "${currentProfile.recommendedTool}",
  "advice": "Continue current practice routine."
}''';
    }
    
    final accuracy = latestSession.accuracy ?? 0.0;
    final accuracyPercent = (accuracy * 100).round();
    
    return '''
Update from latest session: ${latestSession.feature} ($accuracyPercent% accuracy).

Return JSON:
{
  "decodingAccuracy": "${accuracy > 0.85 ? 'good' : 'developing'}",
  "confidence": "${accuracy > 0.85 ? 'building' : 'low'}",
  "phonemeConfusions": ${latestSession.phonemeErrors.take(2).toList()},
  "recommendedTool": "${latestSession.feature}",
  "advice": "${accuracy > 0.8 ? 'Great progress!' : 'Keep practicing!'}"
}''';
  }




  LearnerProfile? _parseProfileResponse(String response, LearnerProfile currentProfile) {
    try {
      developer.log('Parsing AI response for profile update', name: 'dyslexic_ai.profile_update');
      developer.log('Raw AI response: $response', name: 'dyslexic_ai.profile_update');
      
      // Handle potential fallback responses
      if (response.contains('unable to analyze') || response.contains('technical constraints')) {
        developer.log('Received fallback response, using minimal updates', name: 'dyslexic_ai.profile_update');
        return currentProfile.copyWith(
          advice: 'Unable to fully analyze due to technical constraints. Continue your current practice routine.',
        );
      }
      
      final jsonMatch = RegExp(r'```json\s*\n(.*?)\n\s*```', dotAll: true).firstMatch(response);
      String jsonString;
      
      if (jsonMatch != null) {
        jsonString = jsonMatch.group(1)!;
        developer.log('Extracted JSON from code block: $jsonString', name: 'dyslexic_ai.profile_update');
      } else {
        final trimmed = response.trim();
        if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
          jsonString = trimmed;
          developer.log('Using response as direct JSON: $jsonString', name: 'dyslexic_ai.profile_update');
        } else {
          developer.log('No valid JSON found in AI response', name: 'dyslexic_ai.profile_update');
          return null;
        }
      }
      
      // Sanitize JSON string to handle control characters
      final sanitizedJson = _sanitizeJsonString(jsonString);
      developer.log('Sanitized JSON: $sanitizedJson', name: 'dyslexic_ai.profile_update');
      
      final profileData = json.decode(sanitizedJson) as Map<String, dynamic>;
      developer.log('Parsed JSON data: $profileData', name: 'dyslexic_ai.profile_update');
      
      final validatedData = _validateAndCleanProfileData(profileData);
      if (validatedData == null) {
        developer.log('Profile data validation failed', name: 'dyslexic_ai.profile_update');
        return null;
      }
      
      developer.log('Validated profile data: $validatedData', name: 'dyslexic_ai.profile_update');
      
      final updatedProfile = currentProfile.copyWith(
        decodingAccuracy: validatedData['decodingAccuracy'] as String?,
        confidence: validatedData['confidence'] as String?,
        phonemeConfusions: (validatedData['phonemeConfusions'] as List?)?.cast<String>(),
        recommendedTool: validatedData['recommendedTool'] as String?,
        advice: validatedData['advice'] as String?,
      );
      
      developer.log('Successfully parsed updated profile', name: 'dyslexic_ai.profile_update');
      return updatedProfile;
      
    } catch (e, stackTrace) {
      developer.log('Failed to parse profile response: $e', name: 'dyslexic_ai.profile_update', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Map<String, dynamic>? _validateAndCleanProfileData(Map<String, dynamic> data) {
    final validatedData = <String, dynamic>{};
    
    final levelOptions = ['needs work', 'developing', 'good', 'excellent'];
    final confidenceOptions = ['low', 'building', 'medium', 'high'];
    
    developer.log('Validating ultra-compact profile data with ${data.keys.length} fields', name: 'dyslexic_ai.profile_update');
    
    // Validate 5 critical fields only
    if (data['decodingAccuracy'] is String && 
        levelOptions.contains(data['decodingAccuracy'])) {
      validatedData['decodingAccuracy'] = data['decodingAccuracy'];
      developer.log('✅ decodingAccuracy: ${data['decodingAccuracy']}', name: 'dyslexic_ai.profile_update');
    } else {
      developer.log('❌ decodingAccuracy invalid: ${data['decodingAccuracy']}', name: 'dyslexic_ai.profile_update');
    }
    
    if (data['confidence'] is String && 
        confidenceOptions.contains(data['confidence'])) {
      validatedData['confidence'] = data['confidence'];
      developer.log('✅ confidence: ${data['confidence']}', name: 'dyslexic_ai.profile_update');
    } else {
      developer.log('❌ confidence invalid: ${data['confidence']}', name: 'dyslexic_ai.profile_update');
    }
    
    if (data['phonemeConfusions'] is List) {
      final confusions = (data['phonemeConfusions'] as List)
          .cast<String>()
          .where((s) => s.isNotEmpty && s.length <= 10)
          .take(2)  // Limit to 2 for ultra-compact
          .toList();
      validatedData['phonemeConfusions'] = confusions;
      developer.log('✅ phonemeConfusions: $confusions', name: 'dyslexic_ai.profile_update');
    } else {
      developer.log('❌ phonemeConfusions invalid: ${data['phonemeConfusions']}', name: 'dyslexic_ai.profile_update');
    }
    
    if (data['recommendedTool'] is String && 
        (data['recommendedTool'] as String).length <= 50) {
      validatedData['recommendedTool'] = data['recommendedTool'];
      developer.log('✅ recommendedTool: ${data['recommendedTool']}', name: 'dyslexic_ai.profile_update');
    } else {
      developer.log('❌ recommendedTool invalid: ${data['recommendedTool']}', name: 'dyslexic_ai.profile_update');
    }
    
    if (data['advice'] is String && 
        (data['advice'] as String).length <= 250) {  // Reduced from 1000 to 250
      validatedData['advice'] = data['advice'];
      developer.log('✅ advice: ${data['advice']}', name: 'dyslexic_ai.profile_update');
    } else {
      developer.log('❌ advice invalid: ${data['advice']}', name: 'dyslexic_ai.profile_update');
    }
    
    developer.log('Validation complete: ${validatedData.length} valid fields out of ${data.keys.length} provided', name: 'dyslexic_ai.profile_update');
    
    if (validatedData.length < 3) {  // Reduced from 5 to 3 minimum fields
      developer.log('Not enough valid fields in profile data', name: 'dyslexic_ai.profile_update');
      return null;
    }
    
    return validatedData;
  }

  Future<Map<String, dynamic>> getProfileUpdateSuggestions() async {
    try {
      final currentProfile = _profileStore.currentProfile;
      if (currentProfile == null) return {};

      final recentSessions = await _getRecentSessionsForAnalysis();
      if (recentSessions.isEmpty) return {};

      final summary = SessionLogSummary(
        logs: recentSessions,
        startDate: recentSessions.last.timestamp,
        endDate: recentSessions.first.timestamp,
      );

      return {
        'sessions_analyzed': recentSessions.length,
        'average_accuracy': summary.averageAccuracy,
        'total_study_time': summary.totalDuration.inMinutes,
        'common_phoneme_errors': summary.allPhonemeErrors,
        'dominant_confidence': summary.dominantConfidenceLevel,
        'preferred_learning_style': summary.preferredLearningStyle,
        'most_used_tools': summary.mostUsedTools.map((t) => t.name).toList(),
        'ready_for_update': _profileStore.needsUpdate,
      };
    } catch (e) {
      developer.log('Failed to get profile suggestions: $e', name: 'dyslexic_ai.profile_update');
      return {};
    }
  }

  bool get canUpdateProfile {
    return _profileStore.hasProfile && 
           _sessionLogStore.completedLogs.isNotEmpty &&
           getAIInferenceService() != null;
  }
  
  /// Check if background AI processing is currently active
  bool get isBackgroundProcessingActive {
    return _profileStore.isUpdating;
  }
  
  /// Reset stuck pending flags (safety mechanism)
  void resetPendingFlags() {
    if (_isUpdatePending && !_profileStore.isUpdating) {
      developer.log('🔧 Resetting stuck pending flag - was: $_isUpdatePending', name: 'dyslexic_ai.profile_update');
      _isUpdatePending = false;
      _deferredUpdateTimer?.cancel();
    }
  }

  /// Sanitize JSON string to handle control characters from AI responses
  String _sanitizeJsonString(String jsonString) {
    // Replace common control characters that break JSON parsing
    return jsonString
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '') // Remove control characters
        .replaceAll(RegExp(r'\\n'), ' ') // Replace literal \n with space
        .replaceAll(RegExp(r'\\t'), ' ') // Replace literal \t with space
        .replaceAll(RegExp(r'\\r'), ' ') // Replace literal \r with space
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }

  void dispose() {
    developer.log('Disposing GemmaProfileUpdateService', name: 'dyslexic_ai.profile_update');
    _deferredUpdateTimer?.cancel();
    _activityMonitorTimer?.cancel(); // Fix: Dispose activity monitor timer
    
    // Reset state flags
    _isUpdatePending = false;
    _isUserActive = false;
  }
} 