import 'dart:async';
import 'dart:developer' as developer;
import '../models/learner_profile.dart';
import '../utils/service_locator.dart';
import '../utils/prompt_loader.dart';
import '../controllers/learner_profile_store.dart';


class TextSimplifierService {
  static final TextSimplifierService _instance = TextSimplifierService._internal();
  factory TextSimplifierService() => _instance;
  TextSimplifierService._internal();

  late final LearnerProfileStore _profileStore;

  void initialize() {
    _profileStore = getIt<LearnerProfileStore>();
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
      final prompt = await _buildSimplificationPrompt(
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

    final prompt = await _buildSimplificationPrompt(
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

      final prompt = await _buildDefinitionPrompt(word);
      final response = await aiService.generateResponse(prompt, isBackgroundTask: true);
      final definition = _parseDefinitionResponse(response);

      developer.log('✅ Word definition completed: $word', name: 'dyslexic_ai.text_simplifier');
      return definition;

    } catch (e) {
      developer.log('❌ Word definition failed: $e', name: 'dyslexic_ai.text_simplifier');
      return 'Definition not available';
    }
  }

  Future<String> _buildSimplificationPrompt({
    required String originalText,
    required String readingLevel,
    bool explainChanges = false,
    bool defineKeyTerms = false,
    bool addVisuals = false,
    bool isRegenerateRequest = false,
  }) async {
    try {
      final profile = _profileStore.currentProfile;
      
      // Determine which add-on templates to include
      final addOns = <String>[];
      if (explainChanges) addOns.add('explain_changes.tmpl');
      if (defineKeyTerms) addOns.add('define_terms.tmpl');
      if (addVisuals) addOns.add('add_visuals.tmpl');
      if (isRegenerateRequest) addOns.add('regeneration.tmpl');
      
      // Build standardized variables
      final variables = <String, String>{
        'reading_level': _getReadingLevelDescription(readingLevel),
        'target_text': originalText,
        'profile_adjustments': profile != null ? _addProfileAdjustments(profile) : '',
      };
      
      // Build composite template
      final prompt = await PromptLoader.buildComposite(
        'text_simplifier',
        'base.tmpl',
        addOns,
        variables,
      );
      
      developer.log('✅ Built simplification prompt using ${addOns.length} add-ons', 
          name: 'dyslexic_ai.text_simplifier');
      
      return prompt;
    } catch (e) {
      developer.log('❌ Failed to build simplification prompt: $e', 
          name: 'dyslexic_ai.text_simplifier');
      
      // Fallback to basic prompt if template system fails
      return _buildFallbackPrompt(originalText, readingLevel);
    }
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

  Future<String> _buildDefinitionPrompt(String word) async {
    try {
      final variables = <String, String>{
        'word_target': word,
      };
      
      return await PromptLoader.load('word_analysis', 'definition.tmpl')
        .then((template) => PromptLoader.fill(template, variables));
    } catch (e) {
      developer.log('❌ Failed to build definition prompt: $e', 
          name: 'dyslexic_ai.text_simplifier');
      
      // Fallback to basic definition prompt
      return '''
Provide a simple definition for the word "$word" that would be appropriate for someone with dyslexia.

REQUIREMENTS:
- Use simple, clear language
- Keep the definition under 20 words
- Use familiar vocabulary
- Include the word in a simple example sentence

Format: [simple definition] Example: [simple sentence using the word]''';
    }
  }

  /// Fallback prompt builder for when template system fails
  String _buildFallbackPrompt(String originalText, String readingLevel) {
    final levelDescription = _getReadingLevelDescription(readingLevel);
    
    return '''
You are helping someone with dyslexia understand complex text. Please rewrite the following text to be appropriate for a $levelDescription reader.

REQUIREMENTS:
- Use shorter sentences (maximum 15 words per sentence)
- Replace complex words with simpler alternatives
- Maintain the original meaning and key information
- Use clear, direct language
- Add paragraph breaks for better readability
- Use active voice when possible
- Avoid jargon and technical terms

ORIGINAL TEXT:
$originalText

Please provide only the simplified version without any additional commentary.''';
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