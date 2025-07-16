import 'dart:async';
import 'dart:developer' as developer;
import '../models/session_log.dart';
import '../controllers/session_log_store.dart';
import '../controllers/learner_profile_store.dart';
import '../services/gemma_profile_update_service.dart';
import '../utils/service_locator.dart';

class SessionLoggingService {
  late final SessionLogStore _sessionLogStore;
  late final LearnerProfileStore _profileStore;
  late final GemmaProfileUpdateService _profileUpdateService;
  Timer? _sessionTimer;
  DateTime? _sessionStartTime;

  SessionLoggingService() {
    _sessionLogStore = getIt<SessionLogStore>();
    _profileStore = getIt<LearnerProfileStore>();
    _profileUpdateService = getIt<GemmaProfileUpdateService>();
  }

  Future<void> startSession({
    required SessionType sessionType,
    required String featureName,
    Map<String, dynamic>? initialData,
  }) async {
    developer.log('📝 Starting session logging for $featureName ($sessionType)', name: 'dyslexic_ai.session_logging');
    
    _sessionStartTime = DateTime.now();
    
    final data = <String, dynamic>{
      'session_start': _sessionStartTime!.toIso8601String(),
      'feature_name': featureName,
      'user_agent': 'dyslexic_ai_flutter',
      'session_version': '1.0',
      ...?initialData,
    };

    _sessionLogStore.startSession(sessionType, featureName, data);
    
    _sessionTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateSessionHeartbeat();
    });
  }

  void updateSessionData(Map<String, dynamic> data) {
    developer.log('📝 Updating session data: ${data.keys}', name: 'dyslexic_ai.session_logging');
    
    _sessionLogStore.updateCurrentSession({
      'last_update': DateTime.now().toIso8601String(),
      ...data,
    });
  }

  void logUserAction({
    required String action,
    Map<String, dynamic>? metadata,
  }) {
    developer.log('📝 Logging user action: $action', name: 'dyslexic_ai.session_logging');
    
    updateSessionData({
      'last_action': action,
      'last_action_time': DateTime.now().toIso8601String(),
      'action_metadata': metadata ?? {},
    });
  }

  void logPhonemeError(String phoneme, {String? context}) {
    developer.log('📝 Logging phoneme error: $phoneme', name: 'dyslexic_ai.session_logging');
    
    final currentData = _sessionLogStore.currentSession?.data ?? {};
    final existingErrors = List<String>.from(currentData['mispronounced_phonemes'] ?? []);
    
    if (!existingErrors.contains(phoneme)) {
      existingErrors.add(phoneme);
    }
    
    updateSessionData({
      'mispronounced_phonemes': existingErrors,
      'phoneme_error_contexts': {
        ...Map<String, String>.from(currentData['phoneme_error_contexts'] ?? {}),
        phoneme: context ?? 'unknown',
      },
    });
  }

  void logWordAnalysis({
    required String word,
    required List<String> syllables,
    required List<String> phonemes,
    bool? wasCorrect,
  }) {
    developer.log('📝 Logging word analysis: $word', name: 'dyslexic_ai.session_logging');
    
    final currentData = _sessionLogStore.currentSession?.data ?? {};
    final existingWords = List<Map<String, dynamic>>.from(currentData['analyzed_words'] ?? []);
    
    existingWords.add({
      'word': word,
      'syllables': syllables,
      'phonemes': phonemes,
      'was_correct': wasCorrect,
      'analyzed_at': DateTime.now().toIso8601String(),
    });
    
    updateSessionData({
      'analyzed_words': existingWords,
      'words_analyzed': existingWords.length,
    });
  }

  void logReadingMetrics({
    int? wordsRead,
    double? wordsPerMinute,
    double? accuracy,
    List<String>? difficultWords,
  }) {
    developer.log('📝 Logging reading metrics: WPM=$wordsPerMinute, Accuracy=$accuracy', name: 'dyslexic_ai.session_logging');
    
    updateSessionData({
      if (wordsRead != null) 'words_read': wordsRead,
      if (wordsPerMinute != null) 'words_per_minute': wordsPerMinute,
      if (accuracy != null) 'reading_accuracy': accuracy,
      if (difficultWords != null) 'difficult_words': difficultWords,
      'reading_metrics_updated': DateTime.now().toIso8601String(),
    });
  }

  void logComprehensionResults({
    required int questionsTotal,
    required int questionsCorrect,
    double? comprehensionScore,
    List<String>? incorrectAnswers,
  }) {
    developer.log('📝 Logging comprehension: $questionsCorrect/$questionsTotal', name: 'dyslexic_ai.session_logging');
    
    // Debug: Check current session data before update
    final currentData = _sessionLogStore.currentSession?.data ?? {};
    developer.log('📝 Current session data before comprehension update: questions_answered=${currentData['questions_answered']}', name: 'dyslexic_ai.session_logging');
    
    final comprehensionData = {
      'questions_total': questionsTotal,
      'questions_correct': questionsCorrect,
      'questions_answered': questionsTotal,
      'comprehension_score': comprehensionScore ?? (questionsCorrect / questionsTotal),
      if (incorrectAnswers != null) 'incorrect_answers': incorrectAnswers,
      'comprehension_updated': DateTime.now().toIso8601String(),
    };
    
    developer.log('📝 Comprehension data to update: $comprehensionData', name: 'dyslexic_ai.session_logging');
    
    updateSessionData(comprehensionData);
    
    // Debug: Check session data after update
    final updatedData = _sessionLogStore.currentSession?.data ?? {};
    developer.log('📝 Session data after comprehension update: questions_answered=${updatedData['questions_answered']}, questions_total=${updatedData['questions_total']}', name: 'dyslexic_ai.session_logging');
  }

  void logGameResults({
    required int score,
    int? maxScore,
    int? roundsCompleted,
    int? totalRounds,
    List<String>? difficultSounds,
  }) {
    developer.log('📝 Logging game results: Score=$score, Rounds=$roundsCompleted', name: 'dyslexic_ai.session_logging');
    
    updateSessionData({
      'game_score': score,
      if (maxScore != null) 'max_score': maxScore,
      if (roundsCompleted != null) 'rounds_completed': roundsCompleted,
      if (totalRounds != null) 'total_rounds': totalRounds,
      if (difficultSounds != null) 'difficult_sounds': difficultSounds,
      'game_results_updated': DateTime.now().toIso8601String(),
    });
  }

  void logConfidenceLevel(String level, {String? reason}) {
    developer.log('📝 Logging confidence: $level', name: 'dyslexic_ai.session_logging');
    
    updateSessionData({
      'confidence_level': level,
      'confidence_reason': reason ?? 'automatic',
      'confidence_updated': DateTime.now().toIso8601String(),
    });
  }

  void logLearningStyleUsage({
    bool? usedVisualAids,
    bool? usedAudioSupport,
    bool? usedKinestheticElements,
    String? preferredMode,
  }) {
    developer.log('📝 Logging learning style usage', name: 'dyslexic_ai.session_logging');
    
    updateSessionData({
      if (usedVisualAids != null) 'used_visual_aids': usedVisualAids,
      if (usedAudioSupport != null) 'used_audio_support': usedAudioSupport,
      if (usedKinestheticElements != null) 'used_kinesthetic': usedKinestheticElements,
      if (preferredMode != null) 'preferred_learning_mode': preferredMode,
      'learning_style_updated': DateTime.now().toIso8601String(),
    });
  }

  void logOCRUsage({
    required int extractedTextLength,
    required double confidence,
    required bool wasSuccessful,
    String? imageSource,
  }) {
    developer.log('📝 Logging OCR usage: Success=$wasSuccessful, Confidence=$confidence', name: 'dyslexic_ai.session_logging');
    
    final currentData = _sessionLogStore.currentSession?.data ?? {};
    final existingOCRUsage = List<Map<String, dynamic>>.from(currentData['ocr_usage_history'] ?? []);
    
    existingOCRUsage.add({
      'timestamp': DateTime.now().toIso8601String(),
      'extracted_text_length': extractedTextLength,
      'confidence': confidence,
      'was_successful': wasSuccessful,
      'image_source': imageSource ?? 'unknown',
    });
    
    updateSessionData({
      'ocr_usage_history': existingOCRUsage,
      'ocr_attempts': existingOCRUsage.length,
      'ocr_successful_attempts': existingOCRUsage.where((usage) => usage['was_successful'] == true).length,
      'last_ocr_confidence': confidence,
      'used_ocr_feature': true,
      'ocr_updated': DateTime.now().toIso8601String(),
    });
  }

  Future<void> completeSession({
    required double finalAccuracy,
    double? finalScore,
    required String completionStatus,
    Map<String, dynamic>? additionalData,
  }) async {
    if (_sessionStartTime == null) {
      developer.log('No active session to complete', name: 'dyslexic_ai.session_logging');
      return;
    }

    final duration = DateTime.now().difference(_sessionStartTime!);
    
    _sessionTimer?.cancel();
    _sessionTimer = null;

    final finalData = <String, dynamic>{
      'completion_status': completionStatus,
      'session_end': DateTime.now().toIso8601String(),
      'total_duration_seconds': duration.inSeconds,
      'final_accuracy': finalAccuracy,
      'final_score': finalScore,
      'completion_timestamp': DateTime.now().toIso8601String(),
      ...?additionalData,
    };

    developer.log('📝 Completing session: ${getCurrentSessionData()['feature_name']} - Duration: ${duration.inMinutes}m, Accuracy: ${(finalAccuracy * 100).round()}%', name: 'dyslexic_ai.session_logging');
    
    developer.log('📝 Comprehension data from final data: questions_answered=${finalData['questions_answered']}, questions_total=${finalData['questions_total']}', name: 'dyslexic_ai.session_logging');

    await _sessionLogStore.completeCurrentSession(
      duration: duration,
      accuracy: finalAccuracy,
      score: finalScore?.round(),
      finalData: finalData,
    );
    
    _profileStore.incrementSessionCount();
    
    // Schedule intelligent background profile update that waits for user inactivity
    if (_profileStore.needsUpdate && _profileUpdateService.canUpdateProfile) {
      developer.log('📝 Scheduling background profile update after session completion', name: 'dyslexic_ai.session_logging');
      _profileUpdateService.scheduleBackgroundUpdate();
    } else {
      developer.log('📝 Background update not scheduled - needsUpdate: ${_profileStore.needsUpdate}, canUpdate: ${_profileUpdateService.canUpdateProfile}, sessionsSince: ${_profileStore.sessionsSinceLastUpdate}', name: 'dyslexic_ai.session_logging');
    }
    
    _sessionStartTime = null;
    
    developer.log('📝 Session completed, profile update scheduled for background processing', name: 'dyslexic_ai.session_logging');
  }

  void cancelSession({String? reason}) {
    developer.log('📝 Cancelling session: ${reason ?? "user cancelled"}', name: 'dyslexic_ai.session_logging');
    
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _sessionStartTime = null;
    
    _sessionLogStore.cancelCurrentSession();
  }

  void _updateSessionHeartbeat() {
    if (_sessionStartTime != null) {
      final elapsed = DateTime.now().difference(_sessionStartTime!);
      updateSessionData({
        'session_heartbeat': DateTime.now().toIso8601String(),
        'elapsed_minutes': elapsed.inMinutes,
        'elapsed_seconds': elapsed.inSeconds,
      });
    }
  }

  Map<String, dynamic> getCurrentSessionData() {
    return _sessionLogStore.currentSession?.data ?? {};
  }

  bool get hasActiveSession => _sessionLogStore.currentSession != null;

  SessionType? get currentSessionType => _sessionLogStore.currentSession?.sessionType;

  String? get currentFeatureName => _sessionLogStore.currentSession?.feature;

  Duration? get currentSessionDuration {
    return _sessionStartTime != null 
        ? DateTime.now().difference(_sessionStartTime!)
        : null;
  }

  static SessionLoggingService? _instance;
  
  static SessionLoggingService getInstance() {
    _instance ??= SessionLoggingService();
    return _instance!;
  }

  void dispose() {
    developer.log('📝 Disposing SessionLoggingService', name: 'dyslexic_ai.session_logging');
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _sessionStartTime = null;
  }
} 