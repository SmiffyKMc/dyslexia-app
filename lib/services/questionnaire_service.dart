import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

import '../models/learner_profile.dart';
import '../models/assessment_item.dart';
import '../controllers/learner_profile_store.dart';
import '../utils/service_locator.dart';

class QuestionnaireService {
  static const String hasCompletedQuestionnaireKey = 'has_completed_questionnaire';
  
  /// Complete the questionnaire and bootstrap the user's profile
  static Future<void> completeQuestionnaire({
    required String userName,
    required List<String> selectedChallenges,
  }) async {
    try {
      developer.log('🧠 Completing questionnaire for user: $userName', name: 'dyslexic_ai.questionnaire');
      developer.log('🧠 Selected challenges: $selectedChallenges', name: 'dyslexic_ai.questionnaire');
      
      // Create initial profile from questionnaire data
      final profile = _createBootstrapProfile(userName, selectedChallenges);
      
      // Save to existing profile system
      final profileStore = getIt<LearnerProfileStore>();
      await profileStore.updateProfile(profile);
      
      // Mark questionnaire as completed
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(hasCompletedQuestionnaireKey, true);
      
      developer.log('🧠 Questionnaire completed successfully', name: 'dyslexic_ai.questionnaire');
    } catch (e) {
      developer.log('❌ Failed to complete questionnaire: $e', name: 'dyslexic_ai.questionnaire');
      rethrow;
    }
  }
  
  /// Bootstrap a LearnerProfile from questionnaire responses
  static LearnerProfile _createBootstrapProfile(String userName, List<String> selectedChallenges) {
    return LearnerProfile(
      // Core learning fields - bootstrap based on questionnaire
      phonologicalAwareness: _mapToPhonologicalAwareness(selectedChallenges),
      phonemeConfusions: _extractPhonemeConfusions(selectedChallenges),
      decodingAccuracy: _mapToDecodingAccuracy(selectedChallenges),
      workingMemory: _mapToWorkingMemory(selectedChallenges),
      fluency: _mapToFluency(selectedChallenges),
      confidence: _mapToConfidence(selectedChallenges),
      preferredStyle: _mapToPreferredStyle(selectedChallenges),
      focus: _mapToFocus(selectedChallenges),
      recommendedTool: _mapToRecommendedTool(selectedChallenges),
      advice: _generateInitialAdvice(selectedChallenges),
      
      // System fields
      lastUpdated: DateTime.now(),
      sessionCount: 0,
      version: 1,
      
      // Questionnaire fields
      userName: userName.trim(),
      hasCompletedQuestionnaire: true,
      selectedChallenges: selectedChallenges,
      questionnaireCompletedAt: DateTime.now(),
    );
  }
  
  /// Map challenges to phonological awareness level
  static String _mapToPhonologicalAwareness(List<String> challenges) {
    final phonicsRelated = [
      'trouble_phonemes',
      'letter_confusion',
      'difficulty_sequences',
    ];
    
    final count = challenges.where((c) => phonicsRelated.contains(c)).length;
    
    if (count >= 3) return 'needs work';
    if (count >= 2) return 'developing';
    if (count >= 1) return 'developing';
    return 'good';
  }
  
  /// Extract specific phoneme confusions from challenges
  static List<String> _extractPhonemeConfusions(List<String> challenges) {
    final confusions = <String>[];
    
    if (challenges.contains('letter_confusion')) {
      confusions.addAll(['b', 'd', 'p', 'q', 'm', 'w']);
    }
    
    if (challenges.contains('trouble_phonemes')) {
      confusions.addAll(['ch', 'sh', 'th', 'ph']);
    }
    
    return confusions.toSet().toList(); // Remove duplicates
  }
  
  /// Map challenges to decoding accuracy level
  static String _mapToDecodingAccuracy(List<String> challenges) {
    final decodingRelated = [
      'reading_below_level',
      'letter_confusion',
      'difficulty_comprehending',
      'losing_place',
    ];
    
    final count = challenges.where((c) => decodingRelated.contains(c)).length;
    
    if (count >= 3) return 'needs work';
    if (count >= 2) return 'developing';
    if (count >= 1) return 'developing';
    return 'good';
  }
  
  /// Map challenges to working memory assessment
  static String _mapToWorkingMemory(List<String> challenges) {
    final memoryRelated = [
      'memory_difficulties',
      'organization_problems',
      'attention_issues',
      'word_retrieval',
    ];
    
    final count = challenges.where((c) => memoryRelated.contains(c)).length;
    
    if (count >= 3) return 'below average';
    if (count >= 2) return 'average';
    return 'average';
  }
  
  /// Map challenges to fluency level
  static String _mapToFluency(List<String> challenges) {
    final fluencyRelated = [
      'reading_below_level',
      'losing_place',
      'visual_tracking',
      'attention_issues',
    ];
    
    final count = challenges.where((c) => fluencyRelated.contains(c)).length;
    
    if (count >= 3) return 'needs work';
    if (count >= 2) return 'developing';
    if (count >= 1) return 'developing';
    return 'good';
  }
  
  /// Map challenges to confidence level
  static String _mapToConfidence(List<String> challenges) {
    final totalChallenges = challenges.length;
    
    if (totalChallenges >= 8) return 'low';
    if (totalChallenges >= 5) return 'building';
    if (totalChallenges >= 2) return 'building';
    return 'medium';
  }
  
  /// Map challenges to preferred learning style
  static String _mapToPreferredStyle(List<String> challenges) {
    if (challenges.contains('visual_tracking') || challenges.contains('letter_confusion')) {
      return 'auditory'; // Prefer auditory if visual processing issues
    }
    
    if (challenges.contains('attention_issues')) {
      return 'kinesthetic'; // Prefer hands-on if attention issues
    }
    
    return 'visual'; // Default to visual learning
  }
  
  /// Map challenges to primary focus area
  static String _mapToFocus(List<String> challenges) {
    // Priority-based focus determination
    if (challenges.contains('letter_confusion') || challenges.contains('trouble_phonemes')) {
      return 'phoneme recognition';
    }
    
    if (challenges.contains('spelling_mistakes') || challenges.contains('inconsistent_spelling')) {
      return 'spelling patterns';
    }
    
    if (challenges.contains('reading_below_level') || challenges.contains('losing_place')) {
      return 'reading fluency';
    }
    
    if (challenges.contains('difficulty_comprehending')) {
      return 'reading comprehension';
    }
    
    if (challenges.contains('memory_difficulties') || challenges.contains('organization_problems')) {
      return 'working memory';
    }
    
    return 'basic phonemes'; // Default focus
  }
  
  /// Map challenges to recommended tool
  static String _mapToRecommendedTool(List<String> challenges) {
    // Priority-based tool recommendation
    if (challenges.contains('letter_confusion') || challenges.contains('difficulty_sequences')) {
      return 'Word Doctor';
    }
    
    if (challenges.contains('reading_below_level') || challenges.contains('losing_place')) {
      return 'Reading Coach';
    }
    
    if (challenges.contains('spelling_mistakes') || challenges.contains('grammar_issues')) {
      return 'Sentence Fixer';
    }
    
    if (challenges.contains('trouble_phonemes')) {
      return 'Phonics Game';
    }
    
    if (challenges.contains('difficulty_comprehending')) {
      return 'Adaptive Story';
    }
    
    return 'Reading Coach'; // Default recommendation
  }
  
  /// Generate initial AI-style advice based on challenges
  static String _generateInitialAdvice(List<String> challenges) {
    final totalChallenges = challenges.length;
    final focus = _mapToFocus(challenges);
    final tool = _mapToRecommendedTool(challenges);
    
    if (totalChallenges == 0) {
      return 'Great! You\'re ready to strengthen your reading skills. Start with any activity that interests you!';
    }
    
    if (totalChallenges >= 8) {
      return 'I notice you\'re experiencing several reading challenges. Let\'s start with $focus using $tool. We\'ll take it step by step and build your confidence!';
    }
    
    if (totalChallenges >= 4) {
      return 'I see a few areas where we can help you improve. Let\'s focus on $focus with $tool to build a strong foundation.';
    }
    
    return 'You\'re doing well! Let\'s work on $focus using $tool to make your reading even stronger.';
  }
  
  /// Get risk assessment level based on number of challenges
  static String getRiskLevel(List<String> challenges) {
    final count = challenges.length;
    
    if (count >= 8) return 'high';
    if (count >= 4) return 'moderate'; 
    if (count > 0) return 'low';
    return 'minimal';
  }
  
  /// Get category distribution for insights
  static Map<String, int> getCategoryDistribution(List<String> challenges) {
    final distribution = <String, int>{
      'reading': 0,
      'spelling': 0,
      'letters': 0,
      'organization': 0,
    };
    
    for (final challengeId in challenges) {
      final item = AssessmentItem.assessmentItems.firstWhere(
        (item) => item.id == challengeId,
        orElse: () => const AssessmentItem(
          id: 'unknown',
          text: 'Unknown',
          category: 'other',
          focusArea: 'General',
        ),
      );
      
      if (distribution.containsKey(item.category)) {
        distribution[item.category] = distribution[item.category]! + 1;
      }
    }
    
    return distribution;
  }
} 