import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';

class DailyStreakService {
  static const String _lastOpenDateKey = 'dyslexic_ai_last_open_date';
  static const String _currentStreakKey = 'dyslexic_ai_current_streak';
  static const String _bestStreakKey = 'dyslexic_ai_best_streak';
  
  final SharedPreferences _prefs;
  
  DailyStreakService(this._prefs);
  
  /// Record that the app was opened today and update streak
  Future<void> recordAppOpen() async {
    final today = _getTodayDateString();
    final lastOpenDate = _prefs.getString(_lastOpenDateKey);
    final currentStreak = _prefs.getInt(_currentStreakKey) ?? 0;
    
    developer.log('🔥 Recording app open - Today: $today, Last: $lastOpenDate, Current streak: $currentStreak', 
                 name: 'dyslexic_ai.daily_streak');
    
    if (lastOpenDate == today) {
      // Already recorded today, no change needed
      developer.log('🔥 Already recorded today, no streak update needed', name: 'dyslexic_ai.daily_streak');
      return;
    }
    
    int newStreak;
    
    if (lastOpenDate == null) {
      // First time opening the app
      newStreak = 1;
      developer.log('🔥 First time opening app, starting streak at 1', name: 'dyslexic_ai.daily_streak');
    } else {
      final lastDate = DateTime.parse(lastOpenDate);
      final todayDate = DateTime.parse(today);
      final daysDifference = todayDate.difference(lastDate).inDays;
      
      if (daysDifference == 1) {
        // Consecutive day - increment streak
        newStreak = currentStreak + 1;
        developer.log('🔥 Consecutive day! Streak increased to $newStreak', name: 'dyslexic_ai.daily_streak');
      } else if (daysDifference > 1) {
        // Missed days - reset streak to 1
        newStreak = 1;
        developer.log('🔥 Missed ${daysDifference - 1} days, streak reset to 1', name: 'dyslexic_ai.daily_streak');
      } else {
        // daysDifference <= 0 should not happen in normal flow, but handle gracefully
        newStreak = currentStreak;
        developer.log('🔥 Unexpected date difference: $daysDifference, keeping current streak', name: 'dyslexic_ai.daily_streak');
      }
    }
    
    // Save the new values
    await _prefs.setString(_lastOpenDateKey, today);
    await _prefs.setInt(_currentStreakKey, newStreak);
    
    // Update best streak if current is higher
    final bestStreak = _prefs.getInt(_bestStreakKey) ?? 0;
    if (newStreak > bestStreak) {
      await _prefs.setInt(_bestStreakKey, newStreak);
      developer.log('🔥 New best streak! $newStreak days', name: 'dyslexic_ai.daily_streak');
    }
    
    developer.log('🔥 Streak updated - Current: $newStreak, Best: ${_prefs.getInt(_bestStreakKey)}', 
                 name: 'dyslexic_ai.daily_streak');
  }
  
  /// Get the current daily streak
  int getCurrentStreak() {
    final currentStreak = _prefs.getInt(_currentStreakKey) ?? 0;
    final lastOpenDate = _prefs.getString(_lastOpenDateKey);
    
    if (lastOpenDate == null) {
      return 0;
    }
    
    // Check if streak should be reset due to missing yesterday
    final lastDate = DateTime.parse(lastOpenDate);
    final today = DateTime.now();
    final daysSinceLastOpen = today.difference(lastDate).inDays;
    
    if (daysSinceLastOpen > 1) {
      // Streak is broken - should be reset to 0 until next app open
      developer.log('🔥 Streak broken - $daysSinceLastOpen days since last open', name: 'dyslexic_ai.daily_streak');
      return 0;
    }
    
    return currentStreak;
  }
  
  /// Get the best (longest) streak ever achieved
  int getBestStreak() {
    return _prefs.getInt(_bestStreakKey) ?? 0;
  }
  
  /// Get the last date the app was opened
  String? getLastOpenDate() {
    return _prefs.getString(_lastOpenDateKey);
  }
  
  /// Check if the app was opened today
  bool wasOpenedToday() {
    final lastOpenDate = _prefs.getString(_lastOpenDateKey);
    if (lastOpenDate == null) return false;
    
    return lastOpenDate == _getTodayDateString();
  }
  
  /// Reset the streak (for testing or user request)
  Future<void> resetStreak() async {
    await _prefs.remove(_lastOpenDateKey);
    await _prefs.remove(_currentStreakKey);
    developer.log('🔥 Streak reset by user', name: 'dyslexic_ai.daily_streak');
  }
  
  /// Get today's date as a string (YYYY-MM-DD format)
  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
  
  /// Get streak status message for UI display
  String getStreakMessage() {
    final currentStreak = getCurrentStreak();
    
    if (currentStreak == 0) {
      return 'Start your streak today!';
    } else if (currentStreak == 1) {
      return 'Daily streak: 1 day';
    } else {
      return 'Daily streak: $currentStreak days';
    }
  }
  
  /// Get detailed streak info for debugging
  Map<String, dynamic> getStreakInfo() {
    return {
      'currentStreak': getCurrentStreak(),
      'bestStreak': getBestStreak(),
      'lastOpenDate': getLastOpenDate(),
      'wasOpenedToday': wasOpenedToday(),
      'todayDate': _getTodayDateString(),
    };
  }
} 