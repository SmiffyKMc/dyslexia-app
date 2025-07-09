import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import '../models/learner_profile.dart';
import '../models/session_log.dart';
import '../controllers/session_log_store.dart';
import '../controllers/learner_profile_store.dart';
import '../services/ai_inference_service.dart';
import '../utils/service_locator.dart';

class GemmaProfileUpdateService {
  late final SessionLogStore _sessionLogStore;
  late final LearnerProfileStore _profileStore;

  GemmaProfileUpdateService() {
    _sessionLogStore = getIt<SessionLogStore>();
    _profileStore = getIt<LearnerProfileStore>();
  }

  Future<bool> updateProfileFromRecentSessions() async {
    developer.log('🧠 Starting profile update from recent sessions...', name: 'dyslexic_ai.profile_update');
    
    // Set updating state in the profile store
    _profileStore.startUpdate();
    
    try {
      final currentProfile = _profileStore.currentProfile;
      if (currentProfile == null) {
        developer.log('❌ No current profile found', name: 'dyslexic_ai.profile_update');
        return false;
      }

      final recentSessions = await _getRecentSessionsForAnalysis();
      if (recentSessions.isEmpty) {
        developer.log('❌ No recent sessions found for analysis', name: 'dyslexic_ai.profile_update');
        return false;
      }

      developer.log('🧠 Analyzing ${recentSessions.length} recent sessions', name: 'dyslexic_ai.profile_update');

      final aiService = getAIInferenceService();
      if (aiService == null) {
        developer.log('❌ AI service not available', name: 'dyslexic_ai.profile_update');
        return false;
      }

      final prompt = _buildProfileUpdatePrompt(currentProfile, recentSessions);
      developer.log('🧠 Generated prompt for AI analysis', name: 'dyslexic_ai.profile_update');

      final aiResponse = await aiService.generateResponse(prompt);
      developer.log('🧠 Received AI response', name: 'dyslexic_ai.profile_update');

      final updatedProfile = _parseProfileResponse(aiResponse, currentProfile);
      if (updatedProfile != null) {
        await _profileStore.updateProfile(updatedProfile);
        developer.log('✅ Profile updated successfully', name: 'dyslexic_ai.profile_update');
        return true;
      } else {
        developer.log('❌ Failed to parse AI response into valid profile', name: 'dyslexic_ai.profile_update');
        return false;
      }
    } catch (e, stackTrace) {
      developer.log('❌ Profile update failed: $e', name: 'dyslexic_ai.profile_update', error: e, stackTrace: stackTrace);
      return false;
    } finally {
      // Always reset updating state, even if there's an error
      _profileStore.finishUpdate();
    }
  }

  Future<List<SessionLog>> _getRecentSessionsForAnalysis() async {
    final allLogs = _sessionLogStore.completedLogs;
    
    // Get more sessions for better trend analysis (up to 10 recent sessions)
    final recentLogs = allLogs.take(10).toList();
    
    developer.log('🧠 Found ${recentLogs.length} recent completed sessions', name: 'dyslexic_ai.profile_update');
    
    return recentLogs;
  }

  String _buildProfileUpdatePrompt(LearnerProfile currentProfile, List<SessionLog> recentSessions) {
    final sessionSummaries = recentSessions.map((session) => _summarizeSession(session)).join('\n\n');
    
    // Add trend analysis
    final trendAnalysis = _analyzeTrends(recentSessions);
    
    // Add previous profile comparison
    final previousProfile = _profileStore.profileHistory.isNotEmpty 
        ? _profileStore.profileHistory.last 
        : null;
    
    final prompt = '''
You are an expert dyslexia learning assistant AI. Analyze the following user learning data and update their learning profile with specific improvement guidance.

CURRENT PROFILE:
```json
${_profileToJsonString(currentProfile)}
```

${previousProfile != null ? '''
PREVIOUS PROFILE (for comparison):
```json
${_profileToJsonString(previousProfile)}
```
''' : ''}

RECENT SESSION DATA (last ${recentSessions.length} sessions):
$sessionSummaries

PERFORMANCE TRENDS:
$trendAnalysis

INSTRUCTIONS:
1. Analyze the session data to identify patterns in the learner's performance
2. Compare current vs previous performance to detect improvements or regressions
3. Look for tool-specific strengths and weaknesses
4. Identify persistent phoneme confusions from the session logs
5. Determine the learner's preferred learning style based on tool usage and success
6. Assess working memory capacity based on task completion and accuracy patterns
7. **IMPORTANT**: Provide specific, actionable improvement advice based on actual performance data
8. **IMPORTANT**: If accuracy improved significantly (>30%), consider upgrading confidence level
9. **IMPORTANT**: If user shows 90%+ accuracy consistently, upgrade to "good" or "excellent" levels

IMPROVEMENT GUIDANCE RULES:
- If Reading Coach accuracy improved dramatically, suggest "Continue daily reading practice, focus on speed"
- If story comprehension is strong but phonics weak, suggest "Focus on phonics games for foundation"
- If consistency varies between tools, suggest "Practice weaker areas more frequently"
- If phoneme errors are decreasing, suggest "Great progress! Continue current approach"
- If stuck at same level, suggest "Try intermediate difficulty or different learning style"

IMPORTANT RULES:
- Base ALL recommendations on the actual session data provided
- Be encouraging and focus on growth, even for struggling learners
- Keep phoneme confusions list to max 5 most frequent/recent errors
- Recommended tool should be the one that will help most with current challenges
- Focus should be specific and actionable (e.g., "consonant blends", "short vowels")
- Advice should be motivational and specific to the learner's current level
- **UPGRADE CONFIDENCE/ACCURACY LEVELS** when data shows clear improvement

RESPONSE FORMAT:
Return ONLY valid JSON in this exact format:
```json
{
  "phonologicalAwareness": "developing|good|excellent",
  "phonemeConfusions": ["list", "of", "problem", "phonemes"],
  "decodingAccuracy": "needs work|developing|good|excellent", 
  "workingMemory": "below average|average|above average|excellent",
  "fluency": "needs work|developing|good|excellent",
  "confidence": "low|building|medium|high",
  "preferredStyle": "visual|auditory|kinesthetic|multimodal",
  "focus": "specific learning focus area",
  "recommendedTool": "specific tool name",
  "advice": "encouraging, specific advice with improvement steps based on session data"
}
```

Generate the updated profile now:''';

    return prompt;
  }

  String _summarizeSession(SessionLog session) {
    final data = session.data;
    final summary = StringBuffer();
    
    summary.writeln('SESSION: ${session.feature} (${session.sessionType.name})');
    summary.writeln('Duration: ${session.duration.inMinutes} minutes');
    summary.writeln('Accuracy: ${session.accuracy != null ? "${(session.accuracy! * 100).round()}%" : "N/A"}');
    
    final phonemeErrors = session.phonemeErrors;
    if (phonemeErrors.isNotEmpty) {
      summary.writeln('Phoneme Errors: ${phonemeErrors.join(", ")}');
    }
    
    summary.writeln('Confidence Level: ${session.confidenceIndicator}');
    summary.writeln('Learning Style: ${session.preferredStyleIndicator}');
    
    // Validate session data quality for profile analysis
    if (session.sessionType == SessionType.readingCoach) {
      if (data['words_read'] == null || data['words_read'] == 0) {
        developer.log('⚠️ Profile Update: Session missing words_read data', name: 'dyslexic_ai.profile_update');
      }
      if (session.accuracy == null || session.accuracy == 0) {
        developer.log('⚠️ Profile Update: Session missing accuracy data', name: 'dyslexic_ai.profile_update');
      }
    }
    
    switch (session.sessionType) {
      case SessionType.readingCoach:
        if (data['words_per_minute'] != null) {
          summary.writeln('Reading Speed: ${data['words_per_minute']} WPM');
        }
        if (data['words_read'] != null) {
          summary.writeln('Words Read: ${data['words_read']}');
        }
        break;
        
      case SessionType.wordDoctor:
        if (data['words_analyzed'] != null) {
          summary.writeln('Words Analyzed: ${data['words_analyzed']}');
        }
        if (data['completion_rate'] != null) {
          summary.writeln('Completion Rate: ${(data['completion_rate'] * 100).round()}%');
        }
        break;
        
      case SessionType.adaptiveStory:
        if (data['questions_correct'] != null && data['questions_total'] != null) {
          summary.writeln('Questions: ${data['questions_correct']}/${data['questions_total']}');
        }
        if (data['comprehension_score'] != null) {
          summary.writeln('Comprehension: ${(data['comprehension_score'] * 100).round()}%');
        }
        break;
        
      case SessionType.phonicsGame:
        if (data['game_score'] != null) {
          summary.writeln('Game Score: ${data['game_score']}');
        }
        if (data['rounds_completed'] != null) {
          summary.writeln('Rounds Completed: ${data['rounds_completed']}');
        }
        break;
        
      default:
        break;
    }
    
    return summary.toString();
  }

  String _profileToJsonString(LearnerProfile profile) {
    return const JsonEncoder.withIndent('  ').convert(profile.toJson());
  }

  LearnerProfile? _parseProfileResponse(String response, LearnerProfile currentProfile) {
    try {
      developer.log('🧠 Parsing AI response for profile update', name: 'dyslexic_ai.profile_update');
      
      final jsonMatch = RegExp(r'```json\s*\n(.*?)\n\s*```', dotAll: true).firstMatch(response);
      String jsonString;
      
      if (jsonMatch != null) {
        jsonString = jsonMatch.group(1)!;
      } else {
        final trimmed = response.trim();
        if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
          jsonString = trimmed;
        } else {
          developer.log('❌ No valid JSON found in AI response', name: 'dyslexic_ai.profile_update');
          return null;
        }
      }
      
      final profileData = json.decode(jsonString) as Map<String, dynamic>;
      
      final validatedData = _validateAndCleanProfileData(profileData);
      if (validatedData == null) {
        developer.log('❌ Profile data validation failed', name: 'dyslexic_ai.profile_update');
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
      
      developer.log('✅ Successfully parsed updated profile', name: 'dyslexic_ai.profile_update');
      return updatedProfile;
      
    } catch (e, stackTrace) {
      developer.log('❌ Failed to parse profile response: $e', name: 'dyslexic_ai.profile_update', error: e, stackTrace: stackTrace);
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
          .take(5)
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
      developer.log('❌ Not enough valid fields in profile data', name: 'dyslexic_ai.profile_update');
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
      developer.log('❌ Failed to get profile suggestions: $e', name: 'dyslexic_ai.profile_update');
      return {};
    }
  }

  bool get canUpdateProfile {
    return _profileStore.hasProfile && 
           _sessionLogStore.completedLogs.isNotEmpty &&
           getAIInferenceService() != null;
  }

  void dispose() {
    developer.log('🧠 Disposing GemmaProfileUpdateService', name: 'dyslexic_ai.profile_update');
  }

  String _analyzeTrends(List<SessionLog> sessions) {
    if (sessions.length < 2) return "Not enough data for trend analysis.";
    
    final trendAnalysis = StringBuffer();
    
    // Group sessions by tool type
    final readingCoachSessions = sessions.where((s) => s.sessionType == SessionType.readingCoach).toList();
    final storySessions = sessions.where((s) => s.sessionType == SessionType.adaptiveStory).toList();
    final phonicsSessions = sessions.where((s) => s.sessionType == SessionType.phonicsGame).toList();
    
    // Analyze Reading Coach trends
    if (readingCoachSessions.length >= 2) {
      final recent = readingCoachSessions.first;
      final older = readingCoachSessions.last;
      final accuracyChange = (recent.accuracy ?? 0) - (older.accuracy ?? 0);
      
      trendAnalysis.writeln('READING COACH TREND:');
      if (accuracyChange > 0.3) {
        trendAnalysis.writeln('- SIGNIFICANT IMPROVEMENT: Accuracy increased by ${(accuracyChange * 100).round()}%');
      } else if (accuracyChange > 0.1) {
        trendAnalysis.writeln('- GOOD PROGRESS: Accuracy increased by ${(accuracyChange * 100).round()}%');
      } else if (accuracyChange < -0.1) {
        trendAnalysis.writeln('- NEEDS ATTENTION: Accuracy decreased by ${(accuracyChange.abs() * 100).round()}%');
      } else {
        trendAnalysis.writeln('- STABLE: Accuracy relatively consistent');
      }
    }
    
    // Analyze Story comprehension trends
    if (storySessions.length >= 2) {
      final recent = storySessions.first;
      final older = storySessions.last;
      final accuracyChange = (recent.accuracy ?? 0) - (older.accuracy ?? 0);
      
      trendAnalysis.writeln('STORY COMPREHENSION TREND:');
      if (accuracyChange > 0.2) {
        trendAnalysis.writeln('- EXCELLENT PROGRESS: Comprehension improved by ${(accuracyChange * 100).round()}%');
      } else if (accuracyChange > 0.1) {
        trendAnalysis.writeln('- GOOD IMPROVEMENT: Comprehension increased by ${(accuracyChange * 100).round()}%');
      } else {
        trendAnalysis.writeln('- CONSISTENT: Comprehension relatively stable');
      }
    }
    
    // Analyze phoneme error patterns
    final allPhonemeErrors = sessions
        .expand((s) => s.phonemeErrors)
        .toList();
    
    if (allPhonemeErrors.isNotEmpty) {
      final errorFrequency = <String, int>{};
      for (final error in allPhonemeErrors) {
        errorFrequency[error] = (errorFrequency[error] ?? 0) + 1;
      }
      
      final topErrors = errorFrequency.entries
          .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
      
      trendAnalysis.writeln('PHONEME ERROR PATTERNS:');
      trendAnalysis.writeln('- Most frequent errors: ${topErrors.take(3).map((e) => '${e.key}(${e.value}x)').join(', ')}');
    }
    
    // Analyze confidence patterns
    final confidenceLevels = sessions.map((s) => s.confidenceIndicator).toList();
    final highConfidenceCount = confidenceLevels.where((c) => c == 'high').length;
    final confidenceRatio = highConfidenceCount / sessions.length;
    
    trendAnalysis.writeln('CONFIDENCE PATTERN:');
    if (confidenceRatio > 0.7) {
      trendAnalysis.writeln('- HIGH CONFIDENCE: User shows strong confidence in ${(confidenceRatio * 100).round()}% of sessions');
    } else if (confidenceRatio > 0.4) {
      trendAnalysis.writeln('- BUILDING CONFIDENCE: User shows confidence in ${(confidenceRatio * 100).round()}% of sessions');
    } else {
      trendAnalysis.writeln('- NEEDS CONFIDENCE BUILDING: User shows low confidence in most sessions');
    }
    
    return trendAnalysis.toString();
  }
} 