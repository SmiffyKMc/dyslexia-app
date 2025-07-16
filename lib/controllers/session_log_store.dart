import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import '../models/session_log.dart';
import '../utils/service_locator.dart';

part 'session_log_store.g.dart';

class SessionLogStore = _SessionLogStore with _$SessionLogStore;

abstract class _SessionLogStore with Store {
  static const String _sessionLogsKey = 'dyslexic_ai_session_logs';
  static const int maxStoredLogs = 50;

  @observable
  List<SessionLog> sessionLogs = [];

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  SessionLog? currentSession;

  @computed
  List<SessionLog> get recentLogs => sessionLogs.take(10).toList();

  @computed
  List<SessionLog> get completedLogs => sessionLogs;

  @computed
  SessionLogSummary? get last3SessionsSummary {
    final recent = completedLogs.take(3).toList();
    if (recent.isEmpty) return null;
    
    return SessionLogSummary(
      logs: recent,
      startDate: recent.last.timestamp,
      endDate: recent.first.timestamp,
    );
  }

  @computed
  Map<SessionType, int> get sessionTypeCount {
    final counts = <SessionType, int>{};
    for (final log in sessionLogs) {
      counts[log.sessionType] = (counts[log.sessionType] ?? 0) + 1;
    }
    return counts;
  }

  @computed
  double get averageAccuracy {
    final accuracies = completedLogs
        .where((log) => log.accuracy != null)
        .map((log) => log.accuracy!)
        .toList();
    
    if (accuracies.isEmpty) return 0.0;
    return accuracies.reduce((a, b) => a + b) / accuracies.length;
  }

  @computed
  Duration get totalStudyTime => sessionLogs.fold(
    Duration.zero, 
    (total, log) => total + log.duration
  );

  @computed
  List<String> get commonPhonemeErrors {
    final errorFreq = <String, int>{};
    for (final log in completedLogs) {
      for (final error in log.phonemeErrors) {
        errorFreq[error] = (errorFreq[error] ?? 0) + 1;
      }
    }
    
    final sortedErrors = errorFreq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedErrors.take(5).map((entry) => entry.key).toList();
  }

  @computed
  List<SessionLog> get todaysLogs {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    return sessionLogs.where((log) => 
      log.timestamp.isAfter(startOfDay) && 
      log.timestamp.isBefore(endOfDay)
    ).toList();
  }

  @computed
  double get todaysAverageAccuracy {
    final accuracies = todaysLogs
        .where((log) => log.accuracy != null)
        .map((log) => log.accuracy!)
        .toList();
    
    if (accuracies.isEmpty) return 0.0;
    return accuracies.reduce((a, b) => a + b) / accuracies.length;
  }

  @computed
  Duration get todaysStudyTime => todaysLogs.fold(
    Duration.zero, 
    (total, log) => total + log.duration
  );

  @computed
  int get todaysSessionCount => todaysLogs.length;

  @action
  Future<void> initialize() async {
    developer.log('📊 Initializing SessionLogStore...', name: 'dyslexic_ai.sessions');
    
    isLoading = true;
    errorMessage = null;

    try {
      await _loadSessionLogsFromStorage();
      developer.log('📊 SessionLogStore initialized with ${sessionLogs.length} logs', name: 'dyslexic_ai.sessions');
    } catch (e) {
      developer.log('❌ Failed to initialize session logs: $e', name: 'dyslexic_ai.sessions');
      errorMessage = 'Failed to load session history: $e';
      sessionLogs = [];
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> logSession(SessionLog sessionLog) async {
    developer.log('📊 Logging session: ${sessionLog.feature} (${sessionLog.sessionType.name})', name: 'dyslexic_ai.sessions');
    
    try {
      sessionLogs.insert(0, sessionLog);
      
      if (sessionLogs.length > maxStoredLogs) {
        sessionLogs = sessionLogs.take(maxStoredLogs).toList();
        developer.log('📊 Trimmed session logs to $maxStoredLogs entries', name: 'dyslexic_ai.sessions');
      }
      
      await _saveSessionLogsToStorage();
      
      developer.log('📊 Session logged successfully: ${sessionLog.summaryText}', name: 'dyslexic_ai.sessions');
    } catch (e) {
      developer.log('❌ Failed to log session: $e', name: 'dyslexic_ai.sessions');
      errorMessage = 'Failed to save session data: $e';
    }
  }

  @action
  void startSession(SessionType type, String feature, Map<String, dynamic> initialData) {
    developer.log('📊 Starting session: $feature ($type)', name: 'dyslexic_ai.sessions');
    
    currentSession = SessionLog(
      sessionType: type,
      feature: feature,
      data: Map<String, dynamic>.from(initialData),
      duration: Duration.zero,
    );
  }

  @action
  void updateCurrentSession(Map<String, dynamic> data) {
    if (currentSession == null) return;
    
    final updatedData = Map<String, dynamic>.from(currentSession!.data);
    updatedData.addAll(data);
    
    currentSession = currentSession!.copyWith(data: updatedData);
  }

  @action
  Future<void> completeCurrentSession({
    Duration? duration,
    double? accuracy,
    int? score,
    Map<String, dynamic>? finalData,
  }) async {
    if (currentSession == null) return;
    
    developer.log('📊 Completing session: ${currentSession!.feature}', name: 'dyslexic_ai.sessions');
    
    final completedData = Map<String, dynamic>.from(currentSession!.data);
    developer.log('📊 Current session data before merging: questions_answered=${completedData['questions_answered']}, questions_total=${completedData['questions_total']}', name: 'dyslexic_ai.sessions');
    
    if (finalData != null) {
      developer.log('📊 Final data to merge: $finalData', name: 'dyslexic_ai.sessions');
      completedData.addAll(finalData);
    }
    completedData['status'] = 'completed';
    
    developer.log('📊 Completed session data after merging: questions_answered=${completedData['questions_answered']}, questions_total=${completedData['questions_total']}', name: 'dyslexic_ai.sessions');
    
    final completedSession = currentSession!.copyWith(
      data: completedData,
      duration: duration ?? Duration(minutes: 1),
      accuracy: accuracy,
      score: score,
      timestamp: DateTime.now(),
    );
    
    developer.log('📊 Final session log data: questions_answered=${completedSession.data['questions_answered']}, questions_total=${completedSession.data['questions_total']}', name: 'dyslexic_ai.sessions');
    
    await logSession(completedSession);
    currentSession = null;
    
    developer.log('📊 Session completed and logged', name: 'dyslexic_ai.sessions');
  }

  @action
  void cancelCurrentSession() {
    if (currentSession != null) {
      developer.log('📊 Cancelling session: ${currentSession!.feature}', name: 'dyslexic_ai.sessions');
      currentSession = null;
    }
  }

  @action
  Future<void> clearAllLogs() async {
    developer.log('📊 Clearing all session logs', name: 'dyslexic_ai.sessions');
    
    sessionLogs = [];
    currentSession = null;
    
    try {
      await _saveSessionLogsToStorage();
      developer.log('📊 All session logs cleared', name: 'dyslexic_ai.sessions');
    } catch (e) {
      developer.log('❌ Failed to clear session logs: $e', name: 'dyslexic_ai.sessions');
      errorMessage = 'Failed to clear session history: $e';
    }
  }

  @action
  void clearError() {
    errorMessage = null;
  }

  Future<void> _loadSessionLogsFromStorage() async {
    final prefs = getIt<SharedPreferences>();
    final logsJson = prefs.getString(_sessionLogsKey);
    
    if (logsJson != null) {
      try {
        final logsList = json.decode(logsJson) as List<dynamic>;
        sessionLogs = logsList
            .map((item) => SessionLog.fromJson(item as Map<String, dynamic>))
            .toList();
        developer.log('📊 Loaded ${sessionLogs.length} session logs from storage', name: 'dyslexic_ai.sessions');
      } catch (e) {
        developer.log('❌ Failed to parse stored session logs: $e', name: 'dyslexic_ai.sessions');
        throw Exception('Invalid stored session logs format');
      }
    }
  }

  Future<void> _saveSessionLogsToStorage() async {
    try {
      final prefs = getIt<SharedPreferences>();
      final logsJson = json.encode(
        sessionLogs.map((log) => log.toJson()).toList()
      );
      
      await prefs.setString(_sessionLogsKey, logsJson);
      developer.log('📊 Saved ${sessionLogs.length} session logs to storage', name: 'dyslexic_ai.sessions');
    } catch (e) {
      developer.log('❌ Failed to save session logs: $e', name: 'dyslexic_ai.sessions');
      throw Exception('Failed to save session logs to storage');
    }
  }

  SessionLogSummary? getSessionSummaryForDateRange(DateTime start, DateTime end) {
    final filteredLogs = sessionLogs
        .where((log) => log.timestamp.isAfter(start) && log.timestamp.isBefore(end))
        .toList();
    
    if (filteredLogs.isEmpty) return null;
    
    return SessionLogSummary(
      logs: filteredLogs,
      startDate: start,
      endDate: end,
    );
  }

  List<SessionLog> getLogsByType(SessionType type) {
    return sessionLogs.where((log) => log.sessionType == type).toList();
  }

  List<SessionLog> getLogsForPhonemePattern(String phoneme) {
    return sessionLogs
        .where((log) => log.phonemeErrors.contains(phoneme))
        .toList();
  }

  Map<String, dynamic> getLearningAnalytics() {
    if (sessionLogs.isEmpty) return {};
    
    final analytics = <String, dynamic>{};
    
    analytics['total_sessions'] = sessionLogs.length;
    analytics['total_study_time'] = totalStudyTime.inMinutes;
    analytics['average_accuracy'] = averageAccuracy;
    analytics['most_used_tool'] = _getMostUsedTool();
    analytics['improvement_rate'] = _getImprovementRate();
    analytics['consistency_score'] = _getConsistencyScore();
    analytics['phoneme_focus_areas'] = commonPhonemeErrors;
    
    return analytics;
  }

  String _getMostUsedTool() {
    if (sessionTypeCount.isEmpty) return 'none';
    
    return sessionTypeCount.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key
        .name;
  }

  double _getImprovementRate() {
    if (sessionLogs.length < 5) return 0.0;
    
    final recentLogs = sessionLogs.take(5).toList();
    final olderLogs = sessionLogs.length > 10 
        ? sessionLogs.skip(sessionLogs.length - 5).take(5).toList()
        : [];
    
    if (olderLogs.isEmpty) return 0.0;
    
    final recentAccuracy = recentLogs
        .where((log) => log.accuracy != null)
        .map((log) => log.accuracy!)
        .fold(0.0, (sum, acc) => sum + acc) / recentLogs.length;
    
    final olderAccuracy = olderLogs
        .where((log) => log.accuracy != null)
        .map((log) => log.accuracy!)
        .fold(0.0, (sum, acc) => sum + acc) / olderLogs.length;
    
    return recentAccuracy - olderAccuracy;
  }

  double _getConsistencyScore() {
    if (sessionLogs.length < 7) return 0.0;
    
    final now = DateTime.now();
    final last7Days = List.generate(7, (i) => now.subtract(Duration(days: i)));
    
    int daysWithSessions = 0;
    for (final day in last7Days) {
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      
      final hasSessions = sessionLogs.any((log) => 
          log.timestamp.isAfter(dayStart) && log.timestamp.isBefore(dayEnd)
      );
      
      if (hasSessions) daysWithSessions++;
    }
    
    return daysWithSessions / 7.0;
  }

  void dispose() {
    developer.log('📊 Disposing SessionLogStore', name: 'dyslexic_ai.sessions');
  }
} 