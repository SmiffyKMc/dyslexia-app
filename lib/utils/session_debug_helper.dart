import 'dart:developer' as developer;
import '../models/session_log.dart';
import '../controllers/session_log_store.dart';
import '../controllers/learner_profile_store.dart';
import '../utils/service_locator.dart';

class SessionDebugHelper {
  static final SessionLogStore _sessionLogStore = getIt<SessionLogStore>();
  static final LearnerProfileStore _profileStore = getIt<LearnerProfileStore>();
  
  static void debugSessionData(SessionLog session) {
    developer.log('🐛 === SESSION DEBUG ===', name: 'dyslexic_ai.debug');
    developer.log('🐛 Session ID: ${session.id}', name: 'dyslexic_ai.debug');
    developer.log('🐛 Session Type: ${session.sessionType.name}', name: 'dyslexic_ai.debug');
    developer.log('🐛 Feature: ${session.feature}', name: 'dyslexic_ai.debug');
    developer.log('🐛 Accuracy: ${session.accuracy}', name: 'dyslexic_ai.debug');
    developer.log('🐛 Duration: ${session.duration.inMinutes}min', name: 'dyslexic_ai.debug');
    developer.log('🐛 Data Keys: ${session.data.keys.toList()}', name: 'dyslexic_ai.debug');
    
    // Check specific data fields
    if (session.data.containsKey('words_read')) {
      developer.log('🐛 words_read: ${session.data['words_read']}', name: 'dyslexic_ai.debug');
    }
    if (session.data.containsKey('total_words')) {
      developer.log('🐛 total_words: ${session.data['total_words']}', name: 'dyslexic_ai.debug');
    }
    if (session.data.containsKey('correct_words')) {
      developer.log('🐛 correct_words: ${session.data['correct_words']}', name: 'dyslexic_ai.debug');
    }
    
    developer.log('🐛 Session Description: "${session.summaryText}"', name: 'dyslexic_ai.debug');
    developer.log('🐛 === END SESSION DEBUG ===', name: 'dyslexic_ai.debug');
  }
  
  static void debugAllRecentSessions() {
    developer.log('🐛 === ALL RECENT SESSIONS DEBUG ===', name: 'dyslexic_ai.debug');
    final recentSessions = _sessionLogStore.recentLogs;
    
    if (recentSessions.isEmpty) {
      developer.log('🐛 No recent sessions found', name: 'dyslexic_ai.debug');
      return;
    }
    
    for (int i = 0; i < recentSessions.length; i++) {
      developer.log('🐛 --- Session ${i + 1} ---', name: 'dyslexic_ai.debug');
      debugSessionData(recentSessions[i]);
    }
    
    developer.log('🐛 === END ALL SESSIONS DEBUG ===', name: 'dyslexic_ai.debug');
  }
  

  
  static void debugDataFlow(String context, Map<String, dynamic> data) {
    developer.log('🐛 === DATA FLOW DEBUG: $context ===', name: 'dyslexic_ai.debug');
    developer.log('🐛 Data keys: ${data.keys.toList()}', name: 'dyslexic_ai.debug');
    
    for (final entry in data.entries) {
      developer.log('🐛 ${entry.key}: ${entry.value}', name: 'dyslexic_ai.debug');
    }
    
    developer.log('🐛 === END DATA FLOW DEBUG ===', name: 'dyslexic_ai.debug');
  }
  
  static void validateSessionData(SessionLog session) {
    developer.log('🐛 === SESSION VALIDATION ===', name: 'dyslexic_ai.debug');
    
    final issues = <String>[];
    
    // Check for reading coach specific issues
    if (session.sessionType == SessionType.readingCoach) {
      if (!session.data.containsKey('words_read')) {
        issues.add('Missing words_read field');
      }
      if (session.accuracy == null) {
        issues.add('Missing accuracy field');
      }
      if (session.data['words_read'] == 0) {
        issues.add('words_read is zero');
      }
    }
    
    if (session.duration.inSeconds == 0) {
      issues.add('Duration is zero');
    }
    
    if (issues.isEmpty) {
      developer.log('🐛 ✅ Session validation passed', name: 'dyslexic_ai.debug');
    } else {
      developer.log('🐛 ❌ Session validation failed:', name: 'dyslexic_ai.debug');
      for (final issue in issues) {
        developer.log('🐛     - $issue', name: 'dyslexic_ai.debug');
      }
    }
    
    developer.log('🐛 === END SESSION VALIDATION ===', name: 'dyslexic_ai.debug');
  }

  static void debugCurrentSession() {
    developer.log('🐛 === CURRENT SESSION DEBUG ===', name: 'dyslexic_ai.debug');
    
    final currentSession = _sessionLogStore.currentSession;
    if (currentSession != null) {
      developer.log('🐛 Current Session Type: ${currentSession.sessionType}', name: 'dyslexic_ai.debug');
      developer.log('🐛 Current Session Feature: ${currentSession.feature}', name: 'dyslexic_ai.debug');
      developer.log('🐛 Current Session Data Keys: ${currentSession.data.keys.toList()}', name: 'dyslexic_ai.debug');
      developer.log('🐛 Current Session Accuracy: ${currentSession.accuracy}', name: 'dyslexic_ai.debug');
      
      // Log specific data fields
      final data = currentSession.data;
      developer.log('🐛 questions_answered: ${data['questions_answered']}', name: 'dyslexic_ai.debug');
      developer.log('🐛 questions_total: ${data['questions_total']}', name: 'dyslexic_ai.debug');
      developer.log('🐛 questions_correct: ${data['questions_correct']}', name: 'dyslexic_ai.debug');
      developer.log('🐛 words_read: ${data['words_read']}', name: 'dyslexic_ai.debug');
    } else {
      developer.log('🐛 No current session active', name: 'dyslexic_ai.debug');
    }
    
    developer.log('🐛 === END CURRENT SESSION DEBUG ===', name: 'dyslexic_ai.debug');
  }

  static void debugAllSessions() {
    developer.log('🐛 === ALL SESSIONS DEBUG ===', name: 'dyslexic_ai.debug');
    
    final allSessions = _sessionLogStore.sessionLogs;
    developer.log('🐛 Total Sessions: ${allSessions.length}', name: 'dyslexic_ai.debug');
    
    for (int i = 0; i < allSessions.length && i < 5; i++) {
      final session = allSessions[i];
      developer.log('🐛 Session $i: ${session.feature} - Accuracy: ${session.accuracy}', name: 'dyslexic_ai.debug');
      developer.log('🐛   Data: questions_answered=${session.data['questions_answered']}, questions_total=${session.data['questions_total']}', name: 'dyslexic_ai.debug');
    }
    
    developer.log('🐛 === END ALL SESSIONS DEBUG ===', name: 'dyslexic_ai.debug');
  }

  static void debugTodaysProgress() {
    developer.log('🐛 === TODAYS PROGRESS DEBUG ===', name: 'dyslexic_ai.debug');
    
    final todaysLogs = _sessionLogStore.todaysLogs;
    developer.log('🐛 Today\'s Sessions Count: ${todaysLogs.length}', name: 'dyslexic_ai.debug');
    developer.log('🐛 Today\'s Accuracy: ${(_sessionLogStore.todaysAverageAccuracy * 100).round()}%', name: 'dyslexic_ai.debug');
    developer.log('🐛 Raw Accuracy Value: ${_sessionLogStore.todaysAverageAccuracy}', name: 'dyslexic_ai.debug');
    
    for (int i = 0; i < todaysLogs.length; i++) {
      final log = todaysLogs[i];
      developer.log('🐛 Today\'s Session $i: ${log.feature} - Accuracy: ${log.accuracy}', name: 'dyslexic_ai.debug');
    }
    
    developer.log('🐛 === END TODAYS PROGRESS DEBUG ===', name: 'dyslexic_ai.debug');
  }

  static Future<void> clearAllSessionData() async {
    developer.log('🐛 === CLEARING ALL SESSION DATA ===', name: 'dyslexic_ai.debug');
    
    await _sessionLogStore.clearAllLogs();
    
    developer.log('🐛 Session data cleared, now resetting profile...', name: 'dyslexic_ai.debug');
    await _profileStore.resetProfile();
    
    developer.log('🐛 All session data and profile cleared', name: 'dyslexic_ai.debug');
    developer.log('🐛 === SESSION DATA AND PROFILE CLEARED ===', name: 'dyslexic_ai.debug');
  }

  static void debugRecentActivity() {
    developer.log('🐛 === RECENT ACTIVITY DEBUG ===', name: 'dyslexic_ai.debug');
    
    final recentLogs = _sessionLogStore.sessionLogs.take(5).toList();
    developer.log('🐛 Recent Sessions Count: ${recentLogs.length}', name: 'dyslexic_ai.debug');
    
    for (int i = 0; i < recentLogs.length; i++) {
      final log = recentLogs[i];
      developer.log('🐛 Recent Session $i: ${log.summaryText}', name: 'dyslexic_ai.debug');
      developer.log('🐛   Accuracy: ${log.accuracy}, Type: ${log.sessionType}', name: 'dyslexic_ai.debug');
      developer.log('🐛   Data keys: ${log.data.keys.toList()}', name: 'dyslexic_ai.debug');
    }
    
    developer.log('🐛 === END RECENT ACTIVITY DEBUG ===', name: 'dyslexic_ai.debug');
  }
} 