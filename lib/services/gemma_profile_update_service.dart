import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import '../models/learner_profile.dart';
import '../models/session_log.dart';
import '../controllers/session_log_store.dart';
import '../controllers/learner_profile_store.dart';
import '../utils/service_locator.dart';

class GemmaProfileUpdateService {
  late final SessionLogStore _sessionLogStore;
  late final LearnerProfileStore _profileStore;

  GemmaProfileUpdateService() {
    _sessionLogStore = getIt<SessionLogStore>();
    _profileStore = getIt<LearnerProfileStore>();
  }

  Future<bool> updateProfileFromRecentSessions() async {
    developer.log('Starting profile update from recent sessions...', name: 'dyslexic_ai.profile_update');
    
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

      developer.log('Analyzing ${recentSessions.length} recent sessions', name: 'dyslexic_ai.profile_update');

      final aiService = getAIInferenceService();
      if (aiService == null) {
        developer.log('AI service not available', name: 'dyslexic_ai.profile_update');
        return false;
      }

      // Build main prompt and fallback prompt
      final mainPrompt = _buildTier2ProfileUpdatePrompt(currentProfile, recentSessions);
      final fallbackPrompt = _buildMinimalFallbackPrompt(currentProfile, recentSessions);
      
      developer.log('Generated Tier 2 prompt for AI analysis', name: 'dyslexic_ai.profile_update');

      // Use enhanced AI service with token validation and fallback
      final aiResponse = await aiService.generateResponse(mainPrompt, fallbackPrompt: fallbackPrompt);
      developer.log('Received AI response', name: 'dyslexic_ai.profile_update');

      final updatedProfile = _parseProfileResponse(aiResponse, currentProfile);
      if (updatedProfile != null) {
        await _profileStore.updateProfile(updatedProfile);
        developer.log('Profile updated successfully', name: 'dyslexic_ai.profile_update');
        return true;
      } else {
        developer.log('Failed to parse AI response into valid profile', name: 'dyslexic_ai.profile_update');
        return false;
      }
    } catch (e, stackTrace) {
      developer.log('Profile update failed: $e', name: 'dyslexic_ai.profile_update', error: e, stackTrace: stackTrace);
      return false;
    } finally {
      // Always reset updating state, even if there's an error
      _profileStore.finishUpdate();
    }
  }

  Future<List<SessionLog>> _getRecentSessionsForAnalysis() async {
    final allLogs = _sessionLogStore.completedLogs;
    
    // Get fewer sessions for token efficiency while maintaining quality analysis
    final recentLogs = allLogs.take(5).toList();
    
    developer.log('Found ${recentLogs.length} recent completed sessions', name: 'dyslexic_ai.profile_update');
    
    return recentLogs;
  }

  /// Tier 2: Compressed context with detailed instructions (~1200 tokens)
  String _buildTier2ProfileUpdatePrompt(LearnerProfile currentProfile, List<SessionLog> recentSessions) {
    // Compress session data to ~400 tokens
    final sessionSummaries = recentSessions.map((session) => _compressedSessionSummary(session)).join('\n');
    
    // Compress trend analysis to ~200 tokens
    final trendAnalysis = _compressedTrendAnalysis(recentSessions);
    
    // Calculate key performance metrics
    final avgAccuracy = recentSessions.isNotEmpty 
        ? recentSessions.map((s) => s.accuracy ?? 0.0).reduce((a, b) => a + b) / recentSessions.length
        : 0.0;
    
    final prompt = '''
You are an expert dyslexia learning assistant. Analyze the user's learning data and update their profile with specific improvement guidance.

CURRENT PROFILE:
Confidence: ${currentProfile.confidence}, Decoding: ${currentProfile.decodingAccuracy}, Fluency: ${currentProfile.fluency}
Phonological Awareness: ${currentProfile.phonologicalAwareness}, Working Memory: ${currentProfile.workingMemory}
Preferred Style: ${currentProfile.preferredStyle}, Focus: ${currentProfile.focus}
Current Confusions: ${currentProfile.phonemeConfusions.join(', ')}

RECENT SESSIONS (${recentSessions.length} sessions, avg accuracy: ${(avgAccuracy * 100).round()}%):
$sessionSummaries

PERFORMANCE TRENDS:
$trendAnalysis

DETAILED ANALYSIS INSTRUCTIONS:
1. **Accuracy Assessment**: If accuracy improved >20% from previous sessions, consider upgrading confidence level
2. **Phoneme Analysis**: Focus on the 3 most frequent/recent phoneme errors from session data
3. **Tool Effectiveness**: Identify which tools show best performance for recommendations
4. **Learning Style**: Determine preferred style from tool usage patterns and success rates
5. **Working Memory**: Assess from task completion patterns and accuracy consistency
6. **Confidence Levels**: Upgrade if showing 85%+ accuracy consistently across sessions
7. **Focus Areas**: Be specific (e.g., "consonant blends", "short vowels", "reading fluency")

IMPROVEMENT GUIDANCE RULES:
- Reading Coach accuracy >90%: "Continue daily practice, focus on speed building"
- Story comprehension strong but phonics weak: "Focus on phonics games for foundation"
- Inconsistent performance: "Practice weaker areas more frequently"
- Decreasing phoneme errors: "Excellent progress! Continue current approach"
- Plateau in progress: "Try intermediate difficulty or different learning style"
- High accuracy in multiple tools: "Ready for advanced challenges"

CRITICAL REQUIREMENTS:
- Base ALL recommendations on the actual session data provided
- Be encouraging and growth-focused, even for struggling learners
- Keep phoneme confusions to max 3 most critical errors
- Recommended tool should address current biggest challenge
- Focus should be actionable and specific to learner's level
- Advice should be motivational with concrete next steps
- **UPGRADE levels** when data shows clear improvement patterns

RESPONSE FORMAT - Return ONLY valid JSON:
{
  "phonologicalAwareness": "developing|good|excellent",
  "phonemeConfusions": ["most", "frequent", "errors"],
  "decodingAccuracy": "needs work|developing|good|excellent", 
  "workingMemory": "below average|average|above average|excellent",
  "fluency": "needs work|developing|good|excellent",
  "confidence": "low|building|medium|high",
  "preferredStyle": "visual|auditory|kinesthetic|multimodal",
  "focus": "specific area of focus",
  "recommendedTool": "specific tool name",
  "advice": "encouraging advice with specific improvement steps based on session data"
}''';

    return prompt;
  }
  
  /// Minimal fallback prompt for when token limits are exceeded (~400 tokens)
  String _buildMinimalFallbackPrompt(LearnerProfile currentProfile, List<SessionLog> recentSessions) {
    final latestSession = recentSessions.isNotEmpty ? recentSessions.first : null;
    
    if (latestSession == null) {
      return '''
Update profile with minimal changes. Return JSON:
{
  "phonologicalAwareness": "${currentProfile.phonologicalAwareness}",
  "phonemeConfusions": ${currentProfile.phonemeConfusions},
  "decodingAccuracy": "${currentProfile.decodingAccuracy}",
  "workingMemory": "${currentProfile.workingMemory}",
  "fluency": "${currentProfile.fluency}",
  "confidence": "${currentProfile.confidence}",
  "preferredStyle": "${currentProfile.preferredStyle}",
  "focus": "${currentProfile.focus}",
  "recommendedTool": "${currentProfile.recommendedTool}",
  "advice": "Continue current practice routine. Check back later for detailed analysis."
}''';
    }
    
    final accuracy = latestSession.accuracy ?? 0.0;
    final accuracyPercent = (accuracy * 100).round();
    
    return '''
Update profile based on latest session: ${latestSession.feature} ($accuracyPercent% accuracy).
${latestSession.phonemeErrors.isNotEmpty ? 'Errors: ${latestSession.phonemeErrors.take(3).join(', ')}' : ''}

Return JSON:
{
  "phonologicalAwareness": "${accuracy > 0.8 ? 'good' : 'developing'}",
  "phonemeConfusions": ${latestSession.phonemeErrors.take(3).toList()},
  "decodingAccuracy": "${accuracy > 0.85 ? 'good' : 'developing'}",
  "workingMemory": "${currentProfile.workingMemory}",
  "fluency": "${accuracy > 0.9 ? 'good' : 'developing'}",
  "confidence": "${accuracy > 0.85 ? 'building' : 'low'}",
  "preferredStyle": "${currentProfile.preferredStyle}",
  "focus": "continue ${latestSession.feature.toLowerCase()}",
  "recommendedTool": "${latestSession.feature}",
  "advice": "Based on your $accuracyPercent% accuracy in ${latestSession.feature}, ${accuracy > 0.8 ? 'keep up the excellent work!' : 'focus on consistent practice for improvement.'}"
}''';
  }

  /// Compressed session summary (3-4 lines max, ~80 tokens per session)
  String _compressedSessionSummary(SessionLog session) {
    final accuracy = session.accuracy != null ? "${(session.accuracy! * 100).round()}%" : "N/A";
    final duration = "${session.duration.inMinutes}min";
    final errors = session.phonemeErrors.take(3).join(",");
    
    return '${session.feature}: $accuracy accuracy, $duration, ${session.confidenceIndicator} confidence${errors.isNotEmpty ? ', errors: $errors' : ''}';
  }

  /// Compressed trend analysis (key insights only, ~200 tokens total)
  String _compressedTrendAnalysis(List<SessionLog> sessions) {
    if (sessions.length < 2) return "Insufficient data for trend analysis";
    
    final analysis = StringBuffer();
    
    // Overall accuracy trend
    final recent = sessions.first.accuracy ?? 0.0;
    final older = sessions.last.accuracy ?? 0.0;
    final accuracyChange = recent - older;
    
    if (accuracyChange > 0.2) {
      analysis.writeln('• Significant improvement: +${(accuracyChange * 100).round()}% accuracy');
    } else if (accuracyChange > 0.1) {
      analysis.writeln('• Good progress: +${(accuracyChange * 100).round()}% accuracy');
    } else if (accuracyChange < -0.1) {
      analysis.writeln('• Needs attention: ${(accuracyChange * 100).round()}% accuracy drop');
    } else {
      analysis.writeln('• Stable performance: consistent accuracy');
    }
    
    // Common phoneme errors
    final allErrors = sessions.expand((s) => s.phonemeErrors).toList();
    if (allErrors.isNotEmpty) {
      final errorCounts = <String, int>{};
      for (final error in allErrors) {
        errorCounts[error] = (errorCounts[error] ?? 0) + 1;
      }
      final topErrors = errorCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      analysis.writeln('• Common errors: ${topErrors.take(3).map((e) => e.key).join(', ')}');
    }
    
    // Confidence pattern
    final highConfidence = sessions.where((s) => s.confidenceIndicator == 'high').length;
    final confidenceRatio = highConfidence / sessions.length;
    
    if (confidenceRatio > 0.7) {
      analysis.writeln('• High confidence in ${(confidenceRatio * 100).round()}% of sessions');
    } else if (confidenceRatio < 0.3) {
      analysis.writeln('• Low confidence pattern - needs encouragement');
    }
    
    return analysis.toString();
  }



  LearnerProfile? _parseProfileResponse(String response, LearnerProfile currentProfile) {
    try {
      developer.log('Parsing AI response for profile update', name: 'dyslexic_ai.profile_update');
      
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
      } else {
        final trimmed = response.trim();
        if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
          jsonString = trimmed;
        } else {
          developer.log('No valid JSON found in AI response', name: 'dyslexic_ai.profile_update');
          return null;
        }
      }
      
      final profileData = json.decode(jsonString) as Map<String, dynamic>;
      
      final validatedData = _validateAndCleanProfileData(profileData);
      if (validatedData == null) {
        developer.log('Profile data validation failed', name: 'dyslexic_ai.profile_update');
        return null;
      }
      
      final updatedProfile = currentProfile.copyWith(
        phonologicalAwareness: validatedData['phonologicalAwareness'] as String?,
        phonemeConfusions: (validatedData['phonemeConfusions'] as List?)?.cast<String>(),
        decodingAccuracy: validatedData['decodingAccuracy'] as String?,
        workingMemory: validatedData['workingMemory'] as String?,
        fluency: validatedData['fluency'] as String?,
        confidence: validatedData['confidence'] as String?,
        preferredStyle: validatedData['preferredStyle'] as String?,
        focus: validatedData['focus'] as String?,
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
    final memoryOptions = ['below average', 'average', 'above average', 'excellent'];
    final confidenceOptions = ['low', 'building', 'medium', 'high'];
    final styleOptions = ['visual', 'auditory', 'kinesthetic', 'multimodal'];
    
    if (data['phonologicalAwareness'] is String && 
        levelOptions.contains(data['phonologicalAwareness'])) {
      validatedData['phonologicalAwareness'] = data['phonologicalAwareness'];
    }
    
    if (data['phonemeConfusions'] is List) {
      final confusions = (data['phonemeConfusions'] as List)
          .cast<String>()
          .where((s) => s.isNotEmpty && s.length <= 10)
          .take(3)
          .toList();
      validatedData['phonemeConfusions'] = confusions;
    }
    
    if (data['decodingAccuracy'] is String && 
        levelOptions.contains(data['decodingAccuracy'])) {
      validatedData['decodingAccuracy'] = data['decodingAccuracy'];
    }
    
    if (data['workingMemory'] is String && 
        memoryOptions.contains(data['workingMemory'])) {
      validatedData['workingMemory'] = data['workingMemory'];
    }
    
    if (data['fluency'] is String && 
        levelOptions.contains(data['fluency'])) {
      validatedData['fluency'] = data['fluency'];
    }
    
    if (data['confidence'] is String && 
        confidenceOptions.contains(data['confidence'])) {
      validatedData['confidence'] = data['confidence'];
    }
    
    if (data['preferredStyle'] is String && 
        styleOptions.contains(data['preferredStyle'])) {
      validatedData['preferredStyle'] = data['preferredStyle'];
    }
    
    if (data['focus'] is String && 
        (data['focus'] as String).length <= 100) {
      validatedData['focus'] = data['focus'];
    }
    
    if (data['recommendedTool'] is String && 
        (data['recommendedTool'] as String).length <= 50) {
      validatedData['recommendedTool'] = data['recommendedTool'];
    }
    
    if (data['advice'] is String && 
        (data['advice'] as String).length <= 500) {
      validatedData['advice'] = data['advice'];
    }
    
    if (validatedData.length < 5) {
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

  void dispose() {
    developer.log('Disposing GemmaProfileUpdateService', name: 'dyslexic_ai.profile_update');
  }
} 