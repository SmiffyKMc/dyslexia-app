import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import '../models/learner_profile.dart';
import '../utils/service_locator.dart';

part 'learner_profile_store.g.dart';

class LearnerProfileStore = _LearnerProfileStore with _$LearnerProfileStore;

abstract class _LearnerProfileStore with Store {
  static const String _profileKey = 'dyslexic_ai_learner_profile';
  static const String _profileHistoryKey = 'dyslexic_ai_profile_history';

  @observable
  LearnerProfile? currentProfile;

  @observable
  bool isLoading = false;

  @observable
  bool isUpdating = false;

  @observable
  String? errorMessage;

  @observable
  int sessionsSinceLastUpdate = 0;

  @observable
  List<LearnerProfile> profileHistory = [];

  @computed
  bool get hasProfile => currentProfile != null;

  @computed
  bool get isInitialProfile => currentProfile?.isInitial ?? true;

  @computed
  bool get needsUpdate => sessionsSinceLastUpdate >= 3 || (currentProfile?.needsUpdate ?? false);

  @computed
  String get recommendedTool => currentProfile?.recommendedTool ?? 'Reading Coach';

  @computed
  String get currentFocus => currentProfile?.focus ?? 'basic phonemes';

  @computed
  List<String> get phonemeConfusions => currentProfile?.phonemeConfusions ?? [];

  @computed
  String get learningAdvice => currentProfile?.advice ?? 'Complete some sessions to get personalized advice!';

  @computed
  List<String> get strengthAreas => currentProfile?.strengthAreas ?? [];

  @computed
  List<String> get improvementAreas => currentProfile?.improvementAreas ?? [];

  @computed
  String get confidenceLevel => currentProfile?.confidenceLevel ?? '🌱 Building';

  @computed
  String get accuracyLevel => currentProfile?.accuracyLevel ?? '📈 Developing';

  @computed
  bool get canUpdateManually => hasProfile && !isUpdating && sessionsSinceLastUpdate > 0;

  @action
  Future<void> initialize() async {
    developer.log('🧠 Initializing LearnerProfileStore...', name: 'dyslexic_ai.profile');
    
    isLoading = true;
    errorMessage = null;

    try {
      await _loadProfileFromStorage();
      await _loadProfileHistory();
      
      if (currentProfile == null) {
        developer.log('🧠 No existing profile found, creating initial profile', name: 'dyslexic_ai.profile');
        currentProfile = LearnerProfile.initial();
        await _saveProfileToStorage();
      }
      
      developer.log('🧠 Profile initialized: ${currentProfile.toString()}', name: 'dyslexic_ai.profile');
    } catch (e) {
      developer.log('❌ Failed to initialize profile: $e', name: 'dyslexic_ai.profile');
      errorMessage = 'Failed to load learning profile: $e';
      currentProfile = LearnerProfile.initial();
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> updateProfile(LearnerProfile newProfile) async {
    developer.log('🧠 Updating profile...', name: 'dyslexic_ai.profile');
    
    isUpdating = true;
    errorMessage = null;

    try {
      if (currentProfile != null) {
        profileHistory.add(currentProfile!);
        await _saveProfileHistory();
      }

      currentProfile = newProfile.copyWith(
        sessionCount: (currentProfile?.sessionCount ?? 0) + sessionsSinceLastUpdate,
        lastUpdated: DateTime.now(),
        version: (currentProfile?.version ?? 0) + 1,
      );

      sessionsSinceLastUpdate = 0;
      
      await _saveProfileToStorage();
      
      developer.log('🧠 Profile updated successfully: ${currentProfile.toString()}', name: 'dyslexic_ai.profile');
    } catch (e) {
      developer.log('❌ Failed to update profile: $e', name: 'dyslexic_ai.profile');
      errorMessage = 'Failed to update learning profile: $e';
    } finally {
      isUpdating = false;
    }
  }

  @action
  void incrementSessionCount() {
    sessionsSinceLastUpdate++;
    developer.log('🧠 Session count incremented: $sessionsSinceLastUpdate', name: 'dyslexic_ai.profile');
    
    if (needsUpdate) {
      developer.log('🧠 Profile needs update after $sessionsSinceLastUpdate sessions', name: 'dyslexic_ai.profile');
    }
  }

  @action
  void clearError() {
    errorMessage = null;
  }

  @action
  void setUpdating(bool updating) {
    isUpdating = updating;
    developer.log('🧠 Profile updating state set to: $updating', name: 'dyslexic_ai.profile');
  }

  @action
  void startUpdate() {
    isUpdating = true;
    errorMessage = null;
    developer.log('🧠 Profile update started', name: 'dyslexic_ai.profile');
  }

  @action
  void finishUpdate() {
    isUpdating = false;
    developer.log('🧠 Profile update finished', name: 'dyslexic_ai.profile');
  }

  @action
  Future<void> resetProfile() async {
    developer.log('🧠 Resetting profile to initial state', name: 'dyslexic_ai.profile');
    
    isUpdating = true;
    
    try {
      if (currentProfile != null) {
        profileHistory.add(currentProfile!);
        await _saveProfileHistory();
      }

      currentProfile = LearnerProfile.initial();
      sessionsSinceLastUpdate = 0;
      
      await _saveProfileToStorage();
      
      developer.log('🧠 Profile reset successfully', name: 'dyslexic_ai.profile');
    } catch (e) {
      developer.log('❌ Failed to reset profile: $e', name: 'dyslexic_ai.profile');
      errorMessage = 'Failed to reset profile: $e';
    } finally {
      isUpdating = false;
    }
  }

  @action
  Future<void> restorePreviousProfile() async {
    if (profileHistory.isEmpty) {
      errorMessage = 'No previous profile available';
      return;
    }

    developer.log('🧠 Restoring previous profile', name: 'dyslexic_ai.profile');
    
    isUpdating = true;
    
    try {
      final previousProfile = profileHistory.removeLast();
      currentProfile = previousProfile;
      
      await _saveProfileToStorage();
      await _saveProfileHistory();
      
      developer.log('🧠 Previous profile restored successfully', name: 'dyslexic_ai.profile');
    } catch (e) {
      developer.log('❌ Failed to restore previous profile: $e', name: 'dyslexic_ai.profile');
      errorMessage = 'Failed to restore previous profile: $e';
    } finally {
      isUpdating = false;
    }
  }

  Future<void> _loadProfileFromStorage() async {
    final prefs = getIt<SharedPreferences>();
    final profileJson = prefs.getString(_profileKey);
    
    if (profileJson != null) {
      try {
        final profileMap = json.decode(profileJson) as Map<String, dynamic>;
        currentProfile = LearnerProfile.fromJson(profileMap);
        developer.log('🧠 Profile loaded from storage', name: 'dyslexic_ai.profile');
      } catch (e) {
        developer.log('❌ Failed to parse stored profile: $e', name: 'dyslexic_ai.profile');
        throw Exception('Invalid stored profile format');
      }
    }
  }

  Future<void> _saveProfileToStorage() async {
    if (currentProfile == null) return;
    
    try {
      final prefs = getIt<SharedPreferences>();
      final profileJson = json.encode(currentProfile!.toJson());
      await prefs.setString(_profileKey, profileJson);
      developer.log('🧠 Profile saved to storage', name: 'dyslexic_ai.profile');
    } catch (e) {
      developer.log('❌ Failed to save profile: $e', name: 'dyslexic_ai.profile');
      throw Exception('Failed to save profile to storage');
    }
  }

  Future<void> _loadProfileHistory() async {
    final prefs = getIt<SharedPreferences>();
    final historyJson = prefs.getString(_profileHistoryKey);
    
    if (historyJson != null) {
      try {
        final historyList = json.decode(historyJson) as List<dynamic>;
        profileHistory = historyList
            .map((item) => LearnerProfile.fromJson(item as Map<String, dynamic>))
            .toList();
        developer.log('🧠 Profile history loaded: ${profileHistory.length} entries', name: 'dyslexic_ai.profile');
      } catch (e) {
        developer.log('❌ Failed to parse profile history: $e', name: 'dyslexic_ai.profile');
        profileHistory = [];
      }
    }
  }

  Future<void> _saveProfileHistory() async {
    try {
      final prefs = getIt<SharedPreferences>();
      
      final limitedHistory = profileHistory.length > 10 
          ? profileHistory.sublist(profileHistory.length - 10) 
          : profileHistory;
      
      final historyJson = json.encode(
        limitedHistory.map((profile) => profile.toJson()).toList()
      );
      
      await prefs.setString(_profileHistoryKey, historyJson);
      developer.log('🧠 Profile history saved: ${limitedHistory.length} entries', name: 'dyslexic_ai.profile');
    } catch (e) {
      developer.log('❌ Failed to save profile history: $e', name: 'dyslexic_ai.profile');
      throw Exception('Failed to save profile history');
    }
  }

  LearnerProfile? getProfileByVersion(int version) {
    return profileHistory.where((p) => p.version == version).firstOrNull;
  }

  Map<String, dynamic> getProfileInsights() {
    if (currentProfile == null) return {};
    
    return {
      'confidence_trend': _getConfidenceTrend(),
      'accuracy_trend': _getAccuracyTrend(),
      'learning_velocity': _getLearningVelocity(),
      'consistency_score': _getConsistencyScore(),
    };
  }

  String _getConfidenceTrend() {
    if (profileHistory.length < 2) return 'stable';
    
    final recent = profileHistory.length > 3 
        ? profileHistory.skip(profileHistory.length - 3).toList()
        : profileHistory;
    final confidenceLevels = ['low', 'building', 'medium', 'high'];
    
    final currentIndex = confidenceLevels.indexOf(currentProfile!.confidence);
    final previousIndex = confidenceLevels.indexOf(recent.first.confidence);
    
    if (currentIndex > previousIndex) return 'improving';
    if (currentIndex < previousIndex) return 'declining';
    return 'stable';
  }

  String _getAccuracyTrend() {
    if (profileHistory.length < 2) return 'stable';
    
    final recent = profileHistory.length > 3 
        ? profileHistory.skip(profileHistory.length - 3).toList()
        : profileHistory;
    final accuracyLevels = ['needs work', 'developing', 'good', 'excellent'];
    
    final currentIndex = accuracyLevels.indexOf(currentProfile!.decodingAccuracy);
    final previousIndex = accuracyLevels.indexOf(recent.first.decodingAccuracy);
    
    if (currentIndex > previousIndex) return 'improving';
    if (currentIndex < previousIndex) return 'declining';
    return 'stable';
  }

  double _getLearningVelocity() {
    if (profileHistory.isEmpty) return 0.5;
    
    final daysSinceFirst = DateTime.now().difference(profileHistory.first.lastUpdated).inDays;
    final totalSessions = currentProfile!.sessionCount;
    
    if (daysSinceFirst == 0) return 1.0;
    return (totalSessions / daysSinceFirst).clamp(0.0, 2.0);
  }

  double _getConsistencyScore() {
    if (profileHistory.length < 3) return 0.5;
    
    final recentProfiles = profileHistory.length > 5 
        ? profileHistory.skip(profileHistory.length - 5).toList()
        : profileHistory;
    final focusChanges = recentProfiles
        .where((p) => p.focus != currentProfile!.focus)
        .length;
    
    return (1.0 - (focusChanges / recentProfiles.length)).clamp(0.0, 1.0);
  }

  void dispose() {
    developer.log('🧠 Disposing LearnerProfileStore', name: 'dyslexic_ai.profile');
  }
} 