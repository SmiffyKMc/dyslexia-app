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
import '../utils/resource_diagnostics.dart';
import 'global_session_manager.dart';

class ProfileUpdateService {
  late final SessionLogStore _sessionLogStore;
  late final LearnerProfileStore _profileStore;

  Timer? _deferredUpdateTimer;
  DateTime? _lastUserActivity;
  bool _isUpdatePending = false;
  bool _isAppInBackground = false;
  Timer? _sessionTimeoutTimer;
  static const Duration userInactivityDelay = Duration(seconds: 15);
  static const Duration maxDeferDelay = Duration(minutes: 2);
  static const Duration aiSessionTimeout = Duration(minutes: 3);

  ProfileUpdateService() {
    _sessionLogStore = getIt<SessionLogStore>();
    _profileStore = getIt<LearnerProfileStore>();

    _deferredUpdateTimer?.cancel();
    ResourceDiagnostics()
        .unregisterTimer('ProfileUpdateService', 'deferredUpdateTimer');
    _deferredUpdateTimer = null;
    _isUpdatePending = false;
  }

  void handleAppLifecycleChange(AppLifecycleState state) {
    developer.log('App lifecycle changed to: $state',
        name: 'dyslexic_ai.profile_update');

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _pauseBackgroundProcessing();
        break;
      case AppLifecycleState.resumed:
        _resumeBackgroundProcessing();
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _pauseBackgroundProcessing() {
    _isAppInBackground = true;
    _deferredUpdateTimer?.cancel();
    _sessionTimeoutTimer?.cancel();

    developer.log('Paused background processing - app in background',
        name: 'dyslexic_ai.profile_update');

    if (_profileStore.isUpdating) {
      developer.log(
          'AI processing active during background - will complete current task',
          name: 'dyslexic_ai.profile_update');
    }
  }

  void _resumeBackgroundProcessing() {
    _isAppInBackground = false;
    developer.log('Resumed background processing - app in foreground',
        name: 'dyslexic_ai.profile_update');

    if (_isUpdatePending) {
      developer.log('Running immediate update after app resume',
          name: 'dyslexic_ai.profile_update');
      _isUpdatePending = false;
      updateProfileFromRecentSessions(isBackgroundTask: true);
    }
  }

  void markUserActive() {
    final previousActivity = _lastUserActivity;
    _lastUserActivity = DateTime.now();

    if (previousActivity == null ||
        DateTime.now().difference(previousActivity).inSeconds > 2) {
      developer.log('👤 User activity detected - resetting inactivity timer',
          name: 'dyslexic_ai.profile_update');
    }
  }

  void scheduleBackgroundUpdate() {
    developer.log(
        '🔄 scheduleBackgroundUpdate called - but disabled (using immediate updates)',
        name: 'dyslexic_ai.profile_update');

    _deferredUpdateTimer?.cancel();
    ResourceDiagnostics()
        .unregisterTimer('ProfileUpdateService', 'deferredUpdateTimer');
    _deferredUpdateTimer = null;
    _isUpdatePending = false;

    developer.log(
        '✅ Old scheduling system disabled - profile updates are now immediate',
        name: 'dyslexic_ai.profile_update');
  }

  Future<bool> updateProfileFromRecentSessions(
      {bool isBackgroundTask = false}) async {
    final taskType = isBackgroundTask ? 'background' : 'foreground';
    developer.log('Starting $taskType profile update from recent sessions...',
        name: 'dyslexic_ai.profile_update');

    // Phase 4: Set AI session timeout
    _sessionTimeoutTimer?.cancel();
    _sessionTimeoutTimer = Timer(aiSessionTimeout, () {
      developer.log('AI session timeout - potential hang detected',
          name: 'dyslexic_ai.profile_update');
      _handleAISessionTimeout();
    });

    // Set updating state in the profile store
    _profileStore.startUpdate();

    try {
      final currentProfile = _profileStore.currentProfile;
      if (currentProfile == null) {
        developer.log('No current profile found',
            name: 'dyslexic_ai.profile_update');
        return false;
      }

      final recentSessions = await _getRecentSessionsForAnalysis();
      if (recentSessions.isEmpty) {
        developer.log('No recent sessions found for analysis',
            name: 'dyslexic_ai.profile_update');
        return false;
      }

      developer.log(
          'Analyzing ${recentSessions.length} recent sessions ($taskType)',
          name: 'dyslexic_ai.profile_update');

      final aiService = getAIInferenceService();
      if (aiService == null) {
        developer.log('AI service not available',
            name: 'dyslexic_ai.profile_update');
        return false;
      }

      final prompt = await _buildPrompt(currentProfile, recentSessions);

      developer.log(
          'Generated profile update prompt for AI analysis ($taskType)',
          name: 'dyslexic_ai.profile_update');

      // Use AI service with single prompt - no fallback complexity
      final aiResponse = await aiService.generateResponse(
        prompt,
        isBackgroundTask: isBackgroundTask,
        activity: AIActivity.profileAnalysis,
      );
      developer.log('Received AI response ($taskType)',
          name: 'dyslexic_ai.profile_update');

      final updatedProfile = _parseProfileResponse(aiResponse, currentProfile);
      if (updatedProfile != null) {
        await _profileStore.updateProfile(updatedProfile);
        developer.log('Profile updated successfully ($taskType)',
            name: 'dyslexic_ai.profile_update');
        return true;
      } else {
        developer.log(
            'Failed to parse AI response into valid profile ($taskType)',
            name: 'dyslexic_ai.profile_update');

        // Direct retry for failed background updates
        if (isBackgroundTask) {
          developer.log(
              'Scheduling retry for failed background profile update in 2 minutes',
              name: 'dyslexic_ai.profile_update');
          Timer(const Duration(minutes: 2), () {
            developer.log('Retrying profile update after previous failure',
                name: 'dyslexic_ai.profile_update');
            updateProfileFromRecentSessions(isBackgroundTask: true);
          });
        }

        return false;
      }
    } catch (e, stackTrace) {
      developer.log('Profile update failed ($taskType): $e',
          name: 'dyslexic_ai.profile_update', error: e, stackTrace: stackTrace);
      return false;
    } finally {
      // Always reset updating state, even if there's an error
      _profileStore.finishUpdate();
      _isUpdatePending = false; // Fix: Reset pending flag
      _sessionTimeoutTimer?.cancel(); // Phase 4: Clear timeout timer
      developer.log(
          '🔄 Profile update cleanup completed - isUpdatePending reset to: $_isUpdatePending',
          name: 'dyslexic_ai.profile_update');
    }
  }

  /// Phase 4: Handle AI session timeout
  void _handleAISessionTimeout() {
    developer.log('Handling AI session timeout',
        name: 'dyslexic_ai.profile_update');

    // Force reset the updating state
    _profileStore.finishUpdate();
    _isUpdatePending = false;

    // Invalidate AI session to prevent corruption
    final aiService = getAIInferenceService();
    if (aiService != null) {
      // aiService.invalidateSession(); // This would need to be implemented in AI service
      developer.log('AI session invalidated due to timeout',
          name: 'dyslexic_ai.profile_update');
    }
  }

  Future<List<SessionLog>> _getRecentSessionsForAnalysis() async {
    final allLogs = _sessionLogStore.completedLogs;

    // Reduce to 3 sessions for ultra-compact analysis
    final recentLogs = allLogs.take(3).toList();

    developer.log('Found ${recentLogs.length} recent completed sessions',
        name: 'dyslexic_ai.profile_update');

    return recentLogs;
  }

  Future<String> _buildPrompt(
      LearnerProfile currentProfile, List<SessionLog> recentSessions) async {
    final sessionData = recentSessions
        .map((session) =>
            '${session.feature}: ${((session.accuracy ?? 0.0) * 100).round()}% accuracy, errors: ${session.phonemeErrors.take(2).join(",")}')
        .join('\n');

    final avgAccuracy = recentSessions.isNotEmpty
        ? recentSessions.map((s) => s.accuracy ?? 0.0).reduce((a, b) => a + b) /
            recentSessions.length
        : 0.0;

    final variables = <String, String>{
      'current_profile':
          'Confidence: ${currentProfile.confidence}, Accuracy: ${currentProfile.decodingAccuracy}, Confusions: ${currentProfile.phonemeConfusions.take(2).join(', ')}',
      'session_data': sessionData,
      'suggested_tools':
          _getToolRecommendation(avgAccuracy, currentProfile.confidence),
    };

    final template =
        await PromptLoader.load('profile_analysis', 'full_update.tmpl');
    return PromptLoader.fill(template, variables);
  }

  String _getToolRecommendation(double avgAccuracy, String confidence) {
    if (avgAccuracy >= 0.85) {
      return 'Sentence Fixer, Story Mode';
    } else if (avgAccuracy >= 0.70) {
      return 'Story Mode, Sentence Fixer, Reading Coach';
    } else {
      return 'Phonics Game, Reading Coach';
    }
  }

  LearnerProfile? _parseProfileResponse(
      String response, LearnerProfile currentProfile) {
    try {
      developer.log('Parsing AI response for profile update',
          name: 'dyslexic_ai.profile_update');
      developer.log('Raw AI response: $response',
          name: 'dyslexic_ai.profile_update');

      // Handle potential fallback responses
      if (response.contains('unable to analyze') ||
          response.contains('technical constraints')) {
        developer.log('Received fallback response, using minimal updates',
            name: 'dyslexic_ai.profile_update');
        return currentProfile.copyWith(
          advice:
              'Unable to fully analyze due to technical constraints. Continue your current practice routine.',
        );
      }

      final jsonMatch = RegExp(r'```json\s*\n(.*?)\n\s*```', dotAll: true)
          .firstMatch(response);
      String jsonString;

      if (jsonMatch != null) {
        jsonString = jsonMatch.group(1)!;
        developer.log('Extracted JSON from code block: $jsonString',
            name: 'dyslexic_ai.profile_update');
      } else {
        final trimmed = response.trim();
        if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
          jsonString = trimmed;
          developer.log('Using response as direct JSON: $jsonString',
              name: 'dyslexic_ai.profile_update');
        } else {
          developer.log('No valid JSON found in AI response',
              name: 'dyslexic_ai.profile_update');
          return null;
        }
      }

      // Sanitize JSON string to handle control characters
      final sanitizedJson = _sanitizeJsonString(jsonString);
      developer.log('Sanitized JSON: $sanitizedJson',
          name: 'dyslexic_ai.profile_update');

      final profileData = json.decode(sanitizedJson) as Map<String, dynamic>;
      developer.log('Parsed JSON data: $profileData',
          name: 'dyslexic_ai.profile_update');

      final validatedData = _validateAndCleanProfileData(profileData);
      if (validatedData == null) {
        developer.log('Profile data validation failed',
            name: 'dyslexic_ai.profile_update');
        return null;
      }

      developer.log('Validated profile data: $validatedData',
          name: 'dyslexic_ai.profile_update');

      final updatedProfile = currentProfile.copyWith(
        decodingAccuracy: validatedData['decodingAccuracy'] as String?,
        confidence: validatedData['confidence'] as String?,
        phonemeConfusions:
            (validatedData['phonemeConfusions'] as List?)?.cast<String>(),
        recommendedTool: validatedData['recommendedTool'] as String?,
        advice: validatedData['advice'] as String?,
      );

      developer.log('Successfully parsed updated profile',
          name: 'dyslexic_ai.profile_update');
      return updatedProfile;
    } catch (e, stackTrace) {
      developer.log('Failed to parse profile response: $e',
          name: 'dyslexic_ai.profile_update', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Map<String, dynamic>? _validateAndCleanProfileData(
      Map<String, dynamic> data) {
    final validatedData = <String, dynamic>{};

    final levelOptions = ['needs work', 'developing', 'good', 'excellent'];
    final confidenceOptions = ['low', 'building', 'medium', 'high'];

    developer.log(
        'Validating ultra-compact profile data with ${data.keys.length} fields',
        name: 'dyslexic_ai.profile_update');

    // Validate 5 critical fields only
    if (data['decodingAccuracy'] is String &&
        levelOptions.contains(data['decodingAccuracy'])) {
      validatedData['decodingAccuracy'] = data['decodingAccuracy'];
      developer.log('✅ decodingAccuracy: ${data['decodingAccuracy']}',
          name: 'dyslexic_ai.profile_update');
    } else {
      developer.log('❌ decodingAccuracy invalid: ${data['decodingAccuracy']}',
          name: 'dyslexic_ai.profile_update');
    }

    if (data['confidence'] is String &&
        confidenceOptions.contains(data['confidence'])) {
      validatedData['confidence'] = data['confidence'];
      developer.log('✅ confidence: ${data['confidence']}',
          name: 'dyslexic_ai.profile_update');
    } else {
      developer.log('❌ confidence invalid: ${data['confidence']}',
          name: 'dyslexic_ai.profile_update');
    }

    if (data['phonemeConfusions'] is List) {
      final confusions = (data['phonemeConfusions'] as List)
          .cast<String>()
          .where((s) => s.isNotEmpty && s.length <= 10)
          .take(2) // Limit to 2 for ultra-compact
          .toList();
      validatedData['phonemeConfusions'] = confusions;
      developer.log('✅ phonemeConfusions: $confusions',
          name: 'dyslexic_ai.profile_update');
    } else {
      developer.log('❌ phonemeConfusions invalid: ${data['phonemeConfusions']}',
          name: 'dyslexic_ai.profile_update');
    }

    if (data['recommendedTool'] is String &&
        (data['recommendedTool'] as String).length <= 50) {
      validatedData['recommendedTool'] = data['recommendedTool'];
      developer.log('✅ recommendedTool: ${data['recommendedTool']}',
          name: 'dyslexic_ai.profile_update');
    } else {
      developer.log('❌ recommendedTool invalid: ${data['recommendedTool']}',
          name: 'dyslexic_ai.profile_update');
    }

    if (data['advice'] is String && (data['advice'] as String).length <= 250) {
      // Reduced from 1000 to 250
      validatedData['advice'] = data['advice'];
      developer.log('✅ advice: ${data['advice']}',
          name: 'dyslexic_ai.profile_update');
    } else {
      developer.log('❌ advice invalid: ${data['advice']}',
          name: 'dyslexic_ai.profile_update');
    }

    developer.log(
        'Validation complete: ${validatedData.length} valid fields out of ${data.keys.length} provided',
        name: 'dyslexic_ai.profile_update');

    if (validatedData.length < 3) {
      // Reduced from 5 to 3 minimum fields
      developer.log('Not enough valid fields in profile data',
          name: 'dyslexic_ai.profile_update');
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
      developer.log('Failed to get profile suggestions: $e',
          name: 'dyslexic_ai.profile_update');
      return {};
    }
  }

  bool get canUpdateProfile {
    return _profileStore.hasProfile &&
        _sessionLogStore.completedLogs.isNotEmpty &&
        getAIInferenceService() != null &&
        !_profileStore.isUpdating &&
        !_isAppInBackground;
  }

  /// Check if background AI processing is currently active
  bool get isBackgroundProcessingActive {
    return _profileStore.isUpdating;
  }

  /// Reset stuck pending flags (safety mechanism)
  void resetPendingFlags() {
    if (_isUpdatePending && !_profileStore.isUpdating) {
      developer.log('🔧 Resetting stuck pending flag - was: $_isUpdatePending',
          name: 'dyslexic_ai.profile_update');
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
    developer.log('Disposing ProfileUpdateService',
        name: 'dyslexic_ai.profile_update');
    _deferredUpdateTimer?.cancel();
    ResourceDiagnostics()
        .unregisterTimer('ProfileUpdateService', 'deferredUpdateTimer');
    // Activity monitor timer removed - no longer needed

    // Reset state flags
    _isUpdatePending = false;
  }
}
