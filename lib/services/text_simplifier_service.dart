import 'dart:async';
import 'dart:developer' as developer;
import '../models/learner_profile.dart';
import '../utils/service_locator.dart';
import '../controllers/learner_profile_store.dart';
import '../services/session_logging_service.dart';
import '../models/session_log.dart';

class TextSimplifierService {
  static final TextSimplifierService _instance = TextSimplifierService._internal();
  factory TextSimplifierService() => _instance;
  TextSimplifierService._internal();

  late final LearnerProfileStore _profileStore;
  late final SessionLoggingService _sessionLoggingService;

  void initialize() {
    _profileStore = getIt<LearnerProfileStore>();
    _sessionLoggingService = getIt<SessionLoggingService>();
  }

  Future<String> simplifyText({
    required String originalText,
    required String readingLevel,
    bool explainChanges = false,
    bool defineKeyTerms = false,
    bool addVisuals = false,
    bool isRegenerateRequest = false,
  }) async {
    try {
      developer.log('🔄 Starting text simplification for $readingLevel level', name: 'dyslexic_ai.text_simplifier');
      
      final aiService = getAIInferenceService();
      if (aiService == null) {
        throw Exception('AI service not available. Please ensure the model is loaded.');
      }

      // Build prompt based on parameters
      final prompt = _buildSimplificationPrompt(
        originalText: originalText,
        readingLevel: readingLevel,
        explainChanges: explainChanges,
        defineKeyTerms: defineKeyTerms,
        addVisuals: addVisuals,
        isRegenerateRequest: isRegenerateRequest,
      );

      developer.log('📝 Generated prompt for AI simplification', name: 'dyslexic_ai.text_simplifier');

      // Generate simplified text
      final response = await aiService.generateResponse(
        prompt,
        isBackgroundTask: true,
      );

      final simplifiedText = _parseSimplificationResponse(response);
      
      developer.log('✅ Text simplification completed successfully', name: 'dyslexic_ai.text_simplifier');
      return simplifiedText;

    } catch (e) {
      developer.log('❌ Text simplification failed: $e', name: 'dyslexic_ai.text_simplifier');
      rethrow;
    }
  }

  /// Streaming version that yields tokens as they arrive for smoother UI updates
  Stream<String> simplifyTextStream({
    required String originalText,
    required String readingLevel,
    bool explainChanges = false,
    bool defineKeyTerms = false,
    bool addVisuals = false,
  }) async* {
    final aiService = getAIInferenceService();
    if (aiService == null) {
      throw Exception('AI service not available. Please ensure the model is loaded.');
    }

    final prompt = _buildSimplificationPrompt(
      originalText: originalText,
      readingLevel: readingLevel,
      explainChanges: explainChanges,
      defineKeyTerms: defineKeyTerms,
      addVisuals: addVisuals,
    );

    final stream = await aiService.generateResponseStream(prompt);
    await for (final chunk in stream) {
      yield chunk;
    }
  }

  Future<String> defineWord(String word) async {
    try {
      developer.log('📚 Defining word: $word', name: 'dyslexic_ai.text_simplifier');

      final aiService = getAIInferenceService();
      if (aiService == null) {
        throw Exception('AI service not available');
      }

      final prompt = _buildDefinitionPrompt(word);
      final response = await aiService.generateResponse(prompt, isBackgroundTask: true);
      final definition = _parseDefinitionResponse(response);

      developer.log('✅ Word definition completed: $word', name: 'dyslexic_ai.text_simplifier');
      return definition;

    } catch (e) {
      developer.log('❌ Word definition failed: $e', name: 'dyslexic_ai.text_simplifier');
      return 'Definition not available';
    }
  }

  String _buildSimplificationPrompt({
    required String originalText,
    required String readingLevel,
    bool explainChanges = false,
    bool defineKeyTerms = false,
    bool addVisuals = false,
    bool isRegenerateRequest = false,
  }) {
    final profile = _profileStore.currentProfile;
    
    // Get reading level description
    final levelDescription = _getReadingLevelDescription(readingLevel);
    
    // Build base prompt
    String prompt = '''
You are helping someone with dyslexia understand complex text. Please rewrite the following text to be appropriate for a $levelDescription reader.

REQUIREMENTS:
- Use shorter sentences (maximum 15 words per sentence)
- Replace complex words with simpler alternatives
- Maintain the original meaning and key information
- Use clear, direct language
- Add paragraph breaks for better readability
- Use active voice when possible
- Avoid jargon and technical terms''';

    // Add profile-specific adjustments
    if (profile != null) {
      prompt += _addProfileAdjustments(profile);
    }

    // Add feature-specific instructions
    if (explainChanges) {
      prompt += '''

EXPLAIN CHANGES:
- At the end, provide a brief explanation of key changes made
- Format as: "Key changes: [old word] → [new word], [complex sentence] → [simpler version]"''';
    }

    if (defineKeyTerms) {
      prompt += '''

DEFINE KEY TERMS:
- Identify 3-5 important terms that might be difficult
- Provide simple definitions after the simplified text
- Format as: "Key terms: [term] - [simple definition]"''';
    }

    if (addVisuals) {
      prompt += '''

VISUAL SUGGESTIONS:
- Suggest simple visual aids that would help understanding
- Format as: "Visual aids: [description of helpful images/diagrams]"''';
    }

    if (isRegenerateRequest) {
      prompt += '''

REGENERATION REQUEST:
- Create a different version with alternative word choices
- Use different sentence structures while maintaining simplicity
- Keep the same meaning but vary the presentation''';
    }

    prompt += '''

ORIGINAL TEXT:
$originalText

Please provide only the simplified version (and requested additions) without any additional commentary.''';

    return prompt;
  }

  String _getReadingLevelDescription(String readingLevel) {
    switch (readingLevel) {
      case 'Grade 1':
      case 'Grade 2':
        return 'early elementary (grades 1-2) with very simple words and short sentences';
      case 'Grade 3':
      case 'Grade 4':
        return 'elementary (grades 3-4) with basic vocabulary and clear sentences';
      case 'Grade 5':
      case 'Grade 6':
        return 'middle elementary (grades 5-6) with intermediate vocabulary';
      case 'Grade 7':
      case 'Grade 8':
        return 'middle school (grades 7-8) with more complex but still accessible language';
      default:
        return 'elementary (grades 3-4) with basic vocabulary and clear sentences';
    }
  }

  String _addProfileAdjustments(LearnerProfile profile) {
    String adjustments = '''

PROFILE ADJUSTMENTS:''';
    
    // Add confidence-based adjustments
    if (profile.confidence == 'low') {
      adjustments += '''
- Use extra simple vocabulary
- Keep sentences very short (10 words max)
- Add encouragement and positive phrasing''';
    } else if (profile.confidence == 'high') {
      adjustments += '''
- Can use slightly more complex vocabulary
- Sentences can be up to 15 words
- Include challenging but accessible concepts''';
    }

    // Add decoding accuracy adjustments
    if (profile.decodingAccuracy == 'needs work') {
      adjustments += '''
- Avoid complex consonant clusters
- Use simple, common words
- Focus on clear, predictable spelling patterns''';
    }

    // Add phoneme confusion adjustments
    if (profile.phonemeConfusions.isNotEmpty) {
      final confusions = profile.phonemeConfusions.take(3).join(', ');
      adjustments += '''
- Be careful with words containing these phonemes: $confusions
- Use alternative words when possible to avoid confusion''';
    }

    return adjustments;
  }

  String _buildDefinitionPrompt(String word) {
    return '''
Provide a simple definition for the word "$word" that would be appropriate for someone with dyslexia.

REQUIREMENTS:
- Use simple, clear language
- Keep the definition under 20 words
- Use familiar vocabulary
- Include the word in a simple example sentence

Format: [simple definition] Example: [simple sentence using the word]''';
  }

  String _parseSimplificationResponse(String response) {
    // Clean up the response
    String cleaned = response.trim();
    
    // Remove any unwanted prefixes - use string contains instead of regex
    final prefixes = ['here\'s the simplified version:', 'simplified text:', 'simplified version:'];
    for (String prefix in prefixes) {
      if (cleaned.toLowerCase().startsWith(prefix)) {
        cleaned = cleaned.substring(prefix.length).trim();
        break;
      }
    }
    
    // Remove any trailing explanations that weren't requested
    final lines = cleaned.split('\n');
    String result = '';
    
    for (String line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      
      // Stop at explanations or visual suggestions if they appear unexpectedly
      if (line.toLowerCase().startsWith('key changes:') || 
          line.toLowerCase().startsWith('visual aids:') ||
          line.toLowerCase().startsWith('key terms:')) {
        break;
      }
      
      result += '$line\n';
    }
    
    return result.trim();
  }

  String _parseDefinitionResponse(String response) {
    // Clean up definition response
    String cleaned = response.trim();
    
    // Remove any unwanted prefixes
    if (cleaned.toLowerCase().startsWith('definition:')) {
      cleaned = cleaned.substring(11).trim();
    }
    
    return cleaned;
  }

  // Helper method to get appropriate reading level from profile
  String getRecommendedReadingLevel(LearnerProfile? profile) {
    if (profile == null) return 'Grade 3';
    
    switch (profile.decodingAccuracy.toLowerCase()) {
      case 'needs work':
        return 'Grade 2';
      case 'developing':
        return 'Grade 3';
      case 'good':
        return 'Grade 5';
      case 'excellent':
        return 'Grade 7';
      default:
        return 'Grade 3';
    }
  }
} 