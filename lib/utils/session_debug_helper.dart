import 'dart:developer' as developer;
import '../models/session_log.dart';
import '../controllers/session_log_store.dart';
import '../utils/service_locator.dart';

class SessionDebugHelper {
  static final SessionLogStore _sessionLogStore = getIt<SessionLogStore>();
  
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
    
    developer.log('🐛 Session Description: "${session.sessionDescription}"', name: 'dyslexic_ai.debug');
    developer.log('🐛 Is Completed: ${session.isCompleted}', name: 'dyslexic_ai.debug');
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
  
  static void debugTodaysProgress() {
    developer.log('🐛 === TODAYS PROGRESS DEBUG ===', name: 'dyslexic_ai.debug');
    developer.log('🐛 Today\'s Sessions: ${_sessionLogStore.todaysSessionCount}', name: 'dyslexic_ai.debug');
    developer.log('🐛 Today\'s Accuracy: ${(_sessionLogStore.todaysAverageAccuracy * 100).round()}%', name: 'dyslexic_ai.debug');
    developer.log('🐛 Today\'s Study Time: ${_sessionLogStore.todaysStudyTime.inMinutes}min', name: 'dyslexic_ai.debug');
    
    final todaysLogs = _sessionLogStore.todaysLogs;
    developer.log('🐛 Today\'s logs count: ${todaysLogs.length}', name: 'dyslexic_ai.debug');
    
    for (int i = 0; i < todaysLogs.length; i++) {
      developer.log('🐛 Today\'s Session ${i + 1}: ${todaysLogs[i].sessionDescription}', name: 'dyslexic_ai.debug');
    }
    
    developer.log('🐛 === END TODAYS PROGRESS DEBUG ===', name: 'dyslexic_ai.debug');
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
    
    if (!session.isCompleted) {
      issues.add('Session not marked as completed');
    }
    
    if (issues.isEmpty) {
      developer.log('🐛 ✅ Session validation passed', name: 'dyslexic_ai.debug');
    } else {
      developer.log('🐛 ❌ Session validation failed:', name: 'dyslexic_ai.debug');
      for (final issue in issues) {
        developer.log('🐛   - $issue', name: 'dyslexic_ai.debug');
      }
    }
    
    developer.log('🐛 === END SESSION VALIDATION ===', name: 'dyslexic_ai.debug');
  }
} 