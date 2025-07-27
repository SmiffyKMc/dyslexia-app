import '../models/story.dart';
import '../models/learner_profile.dart';
import '../utils/service_locator.dart';
import '../utils/prompt_loader.dart';
import 'dart:convert';
import 'dart:developer' as developer;

class StoryService {
  static final StoryService _instance = StoryService._internal();
  factory StoryService() => _instance;
  StoryService._internal();

  Future<Story?> generateStoryWithAI(LearnerProfile profile) async {
    try {
      developer.log('🤖 Generating AI story for profile', name: 'dyslexic_ai.story_ai');
      
      // Get AI service using helper function
      final aiService = getAIInferenceService();
      if (aiService == null) {
        developer.log('❌ AI service not available', name: 'dyslexic_ai.story_ai');
        return null;
      }
      
      // Extract profile data for story generation
      final targetPhonemes = _extractTargetPhonemes(profile);
      final difficulty = _mapProfileToDifficulty(profile);
      final storyLength = _getStoryLength(difficulty);
      
      developer.log('🎯 Target phonemes: $targetPhonemes, Difficulty: $difficulty', name: 'dyslexic_ai.story_ai');
      
      // Generate story with Gemma 3n
      final prompt = await _buildStoryPrompt(targetPhonemes, difficulty, storyLength);
      final response = await aiService.generateResponse(prompt);
      
      // Parse response into Story object
      final story = parseStoryResponse(response, targetPhonemes, difficulty);
      
      if (story != null) {
        developer.log('✅ Successfully generated AI story: ${story.title}', name: 'dyslexic_ai.story_ai');
      } else {
        developer.log('❌ Failed to parse AI story response', name: 'dyslexic_ai.story_ai');
      }
      
      return story;
    } catch (e) {
      developer.log('❌ AI story generation failed: $e', name: 'dyslexic_ai.story_ai');
      return null;
    }
  }

  /// Streaming version for real-time story generation
  Stream<String> generateStoryWithAIStream(LearnerProfile profile) async* {
    final aiService = getAIInferenceService();
    if (aiService == null) {
      throw Exception('AI service not available');
    }
    
    final targetPhonemes = _extractTargetPhonemes(profile);
    final difficulty = _mapProfileToDifficulty(profile);
    final storyLength = _getStoryLength(difficulty);
    
    final prompt = await _buildStoryPrompt(targetPhonemes, difficulty, storyLength);
    
    final stream = await aiService.generateResponseStream(prompt);
    await for (final chunk in stream) {
      yield chunk;
    }
  }

  /// Chat-style streaming story generation for better performance
  Stream<String> generateStoryWithChatStream(LearnerProfile profile) async* {
    final aiService = getAIInferenceService();
    if (aiService == null) {
      throw Exception('AI service not available');
    }
    
    final prompt = await _buildSimpleStoryPrompt(profile);
    developer.log('🎯 Using simple story prompt (${prompt.length} chars)', name: 'dyslexic_ai.story_ai');
    
    final stream = await aiService.generateChatResponseStream(prompt);
    await for (final chunk in stream) {
      yield chunk;
    }
  }

  /// Build simple story-only prompt using profile information
  Future<String> _buildSimpleStoryPrompt(LearnerProfile profile) async {
    try {
      final targetPhonemes = _extractTargetPhonemes(profile);
      final difficulty = _mapProfileToDifficulty(profile);
      final sentenceCount = _getStoryLength(difficulty);
      
      final variables = <String, String>{
        'difficulty_level': difficulty,
        'user_confidence': profile.confidence,
        'user_accuracy': profile.decodingAccuracy,
        'user_focus_areas': profile.focus,
        'phoneme_patterns': targetPhonemes.join(', '),
        'sentence_count': sentenceCount.toString(),
      };
      
      final template = await PromptLoader.load('story_generation', 'story_simple.tmpl');
      return PromptLoader.fill(template, variables);
    } catch (e) {
      developer.log('❌ Failed to build simple story prompt: $e', name: 'dyslexic_ai.story_ai');
      
      // Fallback to basic prompt
      return _buildFallbackSimpleStoryPrompt(profile);
    }
  }

  /// Fallback simple story prompt for when template system fails
  String _buildFallbackSimpleStoryPrompt(LearnerProfile profile) {
    final targetPhonemes = _extractTargetPhonemes(profile);
    final difficulty = _mapProfileToDifficulty(profile);
    final sentenceCount = _getStoryLength(difficulty);
    
    return '''
You are an expert storyteller creating educational stories for dyslexic learners.

Create a $difficulty level story that helps practice ${profile.focus}.

Learner Profile:
- Reading Confidence: ${profile.confidence}
- Decoding Accuracy: ${profile.decodingAccuracy} 
- Focus Areas: ${profile.focus}

Story Requirements:
- $sentenceCount sentences long
- Use simple, clear language appropriate for $difficulty readers
- Include words with ${targetPhonemes.join(', ')} sound patterns
- Create an engaging story that builds confidence
- Use proper spacing and punctuation
- NO JSON formatting - just return the story text

Generate the story now:''';
  }

  /// Fallback story prompt for when template system fails
  String _buildFallbackStoryPrompt(List<String> targetPhonemes, String difficulty, int sentenceCount) {
    final phoneme1 = targetPhonemes.isNotEmpty ? targetPhonemes[0] : '-ox';
    final phoneme2 = targetPhonemes.length > 1 ? targetPhonemes[1] : 'qu-';
    
    return '''
You are an expert in creating educational stories for dyslexic learners. Create a short story that helps practice specific phonetic patterns.

Requirements:
- Create a $sentenceCount sentence story suitable for $difficulty readers
- Include at least 4 words with the "$phoneme1" pattern
- Include at least 3 words with the "$phoneme2" pattern  
- Make the story engaging with simple characters and clear plot
- Create exactly 4 questions about the story

Return ONLY valid JSON format with title, content, difficulty, patterns, and questions array.''';
  }

  List<String> _extractTargetPhonemes(LearnerProfile profile) {
    // Get top 2 phoneme confusions, fallback to basic patterns
    if (profile.phonemeConfusions.isNotEmpty) {
      return profile.phonemeConfusions.take(2).toList();
    }
    
    // Fallback based on difficulty
    switch (profile.decodingAccuracy.toLowerCase()) {
      case 'needs work':
      case 'developing':
        return ['-ox', '-at'];
      case 'good':
        return ['-ght', 'qu-'];
      default:
        return ['-tion', 'str-'];
    }
  }

  String _mapProfileToDifficulty(LearnerProfile profile) {
    switch (profile.decodingAccuracy.toLowerCase()) {
      case 'needs work':
      case 'developing':
        return 'beginner';
      case 'good':
        return 'intermediate';
      default:
        return 'advanced';
    }
  }

  int _getStoryLength(String difficulty) {
    switch (difficulty) {
      case 'beginner':
        return 4; // 4-5 sentences
      case 'intermediate':
        return 6; // 6-7 sentences
      case 'advanced':
        return 8; // 8-10 sentences
      default:
        return 4;
    }
  }

  Future<String> _buildStoryPrompt(List<String> targetPhonemes, String difficulty, int sentenceCount) async {
    try {
      final phoneme1 = targetPhonemes.isNotEmpty ? targetPhonemes[0] : '-ox';
      final phoneme2 = targetPhonemes.length > 1 ? targetPhonemes[1] : 'qu-';
      
      final variables = <String, String>{
        'sentence_count': sentenceCount.toString(),
        'difficulty_level': difficulty,
        'phoneme_pattern1': phoneme1,
        'phoneme_pattern2': phoneme2,
      };
      
      final template = await PromptLoader.load('story_generation', 'story_with_questions.tmpl');
      return PromptLoader.fill(template, variables);
    } catch (e) {
      developer.log('❌ Failed to build story prompt: $e', name: 'dyslexic_ai.story_ai');
      
      // Fallback to basic prompt
      return _buildFallbackStoryPrompt(targetPhonemes, difficulty, sentenceCount);
    }
  }

  Story? parseStoryResponse(String response, List<String> targetPhonemes, String difficulty) {
    try {
      // LOG: Full AI response
      developer.log('🔍 FULL AI RESPONSE:\n$response', name: 'dyslexic_ai.story_ai');
      
      // Extract JSON from response
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(response);
      if (jsonMatch == null) {
        developer.log('❌ No JSON found in AI response', name: 'dyslexic_ai.story_ai');
        return null;
      }
      
      final jsonString = jsonMatch.group(0)!;
      developer.log('🔍 EXTRACTED JSON:\n$jsonString', name: 'dyslexic_ai.story_ai');
      
      final data = json.decode(jsonString) as Map<String, dynamic>;
      developer.log('🔍 PARSED DATA: $data', name: 'dyslexic_ai.story_ai');
      
      // Validate required fields
      if (!data.containsKey('title') || !data.containsKey('content') || !data.containsKey('questions')) {
        developer.log('❌ Missing required fields in AI response', name: 'dyslexic_ai.story_ai');
        return null;
      }
      
      // Create questions
      final questions = <Question>[];
      final questionsData = data['questions'] as List<dynamic>;
      
      developer.log('🔍 PROCESSING ${questionsData.length} QUESTIONS:', name: 'dyslexic_ai.story_ai');
      
      for (int i = 0; i < questionsData.length; i++) {
        final qData = questionsData[i] as Map<String, dynamic>;
        
        developer.log('🔍 QUESTION $i RAW DATA: $qData', name: 'dyslexic_ai.story_ai');
        
        final sentence = qData['type'] == 'fill_in_blank' ? qData['sentence'] ?? '' : qData['question'] ?? '';
        final blankPosition = qData['blank_position'] ?? 0;
        final correctAnswer = qData['correct_answer'] ?? '';
        final options = List<String>.from(qData['options'] ?? []);
        
        // RANDOMIZE: Shuffle the options so correct answer isn't always first
        if (options.isNotEmpty) {
          options.shuffle();
          developer.log('🎲 SHUFFLED OPTIONS: $options (correct: "$correctAnswer")', name: 'dyslexic_ai.story_ai');
        }
        
        // AUTO-FIX: Calculate correct blank position for fill-in-blank questions
        int actualBlankPosition = blankPosition;
        if (qData['type'] == 'fill_in_blank' && sentence.isNotEmpty && correctAnswer.isNotEmpty) {
          final words = sentence.split(' ');
          // Find where the correct answer actually appears in the sentence
          for (int i = 0; i < words.length; i++) {
            final word = words[i].replaceAll(RegExp(r'[^\w]'), ''); // Remove punctuation
            final answer = correctAnswer.replaceAll(RegExp(r'[^\w]'), '');
            if (word.toLowerCase() == answer.toLowerCase()) {
              actualBlankPosition = i;
              developer.log('🔧 AUTO-CORRECTED blank position from $blankPosition to $actualBlankPosition for "$correctAnswer"', name: 'dyslexic_ai.story_ai');
              break;
            }
          }
        }
        
        developer.log('🔍 QUESTION $i PARSED:', name: 'dyslexic_ai.story_ai');
        developer.log('   - Type: ${qData['type']}', name: 'dyslexic_ai.story_ai');
        developer.log('   - Sentence: "$sentence"', name: 'dyslexic_ai.story_ai');
        developer.log('   - AI Blank Position: $blankPosition', name: 'dyslexic_ai.story_ai');
        developer.log('   - Corrected Blank Position: $actualBlankPosition', name: 'dyslexic_ai.story_ai');
        developer.log('   - Correct Answer: "$correctAnswer"', name: 'dyslexic_ai.story_ai');
        developer.log('   - Options: $options', name: 'dyslexic_ai.story_ai');
        
        final question = Question(
          id: qData['id'] ?? 'ai_q$i',
          sentence: sentence,
          blankPosition: actualBlankPosition,
          correctAnswer: correctAnswer,
          options: options,
          type: qData['type'] == 'fill_in_blank' ? QuestionType.fillInBlank : QuestionType.multipleChoice,
          hint: qData['hint'],
          pattern: qData['pattern'] ?? '',
        );
        
        // LOG: Test the sentenceWithBlank generation
        developer.log('🔍 QUESTION $i FINAL RESULT:', name: 'dyslexic_ai.story_ai');
        developer.log('   - Original sentence: "${question.sentence}"', name: 'dyslexic_ai.story_ai');
        developer.log('   - Sentence words: ${question.sentenceWords}', name: 'dyslexic_ai.story_ai');
        developer.log('   - Blank position: ${question.blankPosition}', name: 'dyslexic_ai.story_ai');
        developer.log('   - Generated sentenceWithBlank: "${question.sentenceWithBlank}"', name: 'dyslexic_ai.story_ai');
        
        questions.add(question);
      }
      
      // Create story part
      final storyPart = StoryPart(
        id: 'ai_generated_part',
        partNumber: 1,
        content: data['content'] as String,
        questions: questions,
      );
      
      developer.log('🔍 STORY CONTENT: "${data['content']}"', name: 'dyslexic_ai.story_ai');
      
      // Create story
      final story = Story(
        id: 'ai_generated_${DateTime.now().millisecondsSinceEpoch}',
        title: data['title'] as String,
        description: 'AI-generated story targeting ${targetPhonemes.join(", ")} patterns',
        difficulty: _stringToDifficulty(difficulty),
        parts: [storyPart],
        learningPatterns: targetPhonemes,
        coverImage: '🤖',
      );
      
      developer.log('✅ STORY CREATED SUCCESSFULLY: ${story.title}', name: 'dyslexic_ai.story_ai');
      return story;
    } catch (e) {
      developer.log('❌ Failed to parse AI story response: $e', name: 'dyslexic_ai.story_ai');
      return null;
    }
  }

  StoryDifficulty _stringToDifficulty(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return StoryDifficulty.beginner;
      case 'intermediate':
        return StoryDifficulty.intermediate;
      case 'advanced':
        return StoryDifficulty.advanced;
      default:
        return StoryDifficulty.beginner;
    }
  }

  final List<Story> _stories = [
    Story(
      id: 'fox_adventure',
      title: 'The Clever Fox',
      description: 'Follow a smart fox on an exciting adventure through the forest.',
      difficulty: StoryDifficulty.beginner,
      learningPatterns: ['-ox', 'qu-', '-ck'],
      coverImage: '🦊',
      parts: [
        StoryPart(
          id: 'fox_1',
          partNumber: 1,
          content: 'Once upon a time, there lived a clever fox in a magical forest. The fox found an old wooden box hidden under a rock. Inside the box was a treasure map!',
          questions: [
            Question(
              id: 'fox_1_q1',
              sentence: 'The treasure was hidden in a wooden ____.',
              blankPosition: 7,
              correctAnswer: 'box',
              options: ['fox', 'box', 'rock'],
              pattern: '-ox',
              hint: 'Rhymes with fox! A container to store things.',
            ),
          ],
        ),
        StoryPart(
          id: 'fox_2',
          partNumber: 2,
          content: 'One morning, the fox heard a quick knock at his door. "Who could that be?" wondered the fox.',
          questions: [
            Question(
              id: 'fox_2_q1',
              sentence: 'The fox heard a ____ knock at his door.',
              blankPosition: 4,
              correctAnswer: 'quick',
              options: ['slow', 'quick', 'loud'],
              pattern: 'qu-',
              hint: 'Starts with "qu"',
            ),
            Question(
              id: 'fox_2_q2',
              sentence: 'There was a ____ at the door.',
              blankPosition: 3,
              correctAnswer: 'knock',
              options: ['knock', 'rock', 'clock'],
              pattern: '-ck',
              hint: 'Ends with "ck"',
            ),
          ],
        ),
        StoryPart(
          id: 'fox_3',
          partNumber: 3,
          content: 'Outside stood a quiet rabbit holding a thick book. "Please help me!" said the rabbit. "I lost my lucky sock!"',
          questions: [
            Question(
              id: 'fox_3_q1',
              sentence: 'Outside stood a ____ rabbit holding a thick book.',
              blankPosition: 3,
              correctAnswer: 'quiet',
              options: ['quick', 'quiet', 'quite'],
              pattern: 'qu-',
              hint: 'Means not noisy',
            ),
            Question(
              id: 'fox_3_q2',
              sentence: 'I lost my lucky ____!',
              blankPosition: 4,
              correctAnswer: 'sock',
              options: ['sock', 'rock', 'dock'],
              pattern: '-ck',
              hint: 'You wear it on your foot',
            ),
          ],
        ),
      ],
    ),
    Story(
      id: 'dragon_tale',
      title: 'The Friendly Dragon',
      description: 'Meet a kind dragon who loves helping others in his magical kingdom.',
      difficulty: StoryDifficulty.intermediate,
      learningPatterns: ['ph', '-ght', 'dr-'],
      coverImage: '🐲',
      parts: [
        StoryPart(
          id: 'dragon_1',
          partNumber: 1,
          content: 'In a bright kingdom lived a friendly dragon named Ralph. He was different from other dragons because he loved taking photographs.',
          questions: [
            Question(
              id: 'dragon_1_q1',
              sentence: 'He loved taking ____ of nature.',
              blankPosition: 3,
              correctAnswer: 'photographs',
              options: ['photos', 'photographs', 'pictures'],
              pattern: 'ph',
              hint: 'Contains "ph" sound',
            ),
          ],
        ),
        StoryPart(
          id: 'dragon_2',
          partNumber: 2,
          content: 'Every night, Ralph would fly through the bright moonlight. The sight of stars always made him dream of adventures.',
          questions: [
            Question(
              id: 'dragon_2_q1',
              sentence: 'Ralph would fly through the ____ moonlight.',
              blankPosition: 5,
              correctAnswer: 'bright',
              options: ['light', 'bright', 'tight'],
              pattern: '-ght',
              hint: 'Means very light or shiny',
            ),
            Question(
              id: 'dragon_2_q2',
              sentence: 'The ____ of stars always made him dream.',
              blankPosition: 1,
              correctAnswer: 'sight',
              options: ['light', 'sight', 'right'],
              pattern: '-ght',
              hint: 'What you see with your eyes',
            ),
          ],
        ),
        StoryPart(
          id: 'dragon_3',
          partNumber: 3,
          content: 'One day, Ralph decided to draw a map of all the places he had seen. He drew mountains, rivers, and castles.',
          questions: [
            Question(
              id: 'dragon_3_q1',
              sentence: 'Ralph decided to ____ a map of all the places.',
              blankPosition: 3,
              correctAnswer: 'draw',
              options: ['draw', 'fly', 'see'],
              pattern: 'dr-',
              hint: 'To make pictures with a pencil',
            ),
            Question(
              id: 'dragon_3_q2',
              sentence: 'He ____ mountains, rivers, and castles.',
              blankPosition: 1,
              correctAnswer: 'drew',
              options: ['drew', 'flew', 'knew'],
              pattern: 'dr-',
              hint: 'Past tense of draw',
            ),
          ],
        ),
      ],
    ),
    Story(
      id: 'space_journey',
      title: 'Journey to the Stars',
      description: 'Join Captain Luna on an exciting space adventure to discover new planets.',
      difficulty: StoryDifficulty.advanced,
      learningPatterns: ['str-', '-tion', 'sp-'],
      coverImage: '🚀',
      parts: [
        StoryPart(
          id: 'space_1',
          partNumber: 1,
          content: 'Captain Luna stood on the space station, looking at the stars through her strong telescope. Today was the start of an important mission.',
          questions: [
            Question(
              id: 'space_1_q1',
              sentence: 'Looking at the stars through her ____ telescope.',
              blankPosition: 6,
              correctAnswer: 'strong',
              options: ['long', 'strong', 'wrong'],
              pattern: 'str-',
              hint: 'Means powerful or sturdy',
            ),
            Question(
              id: 'space_1_q2',
              sentence: 'Captain Luna stood on the space ____.',
              blankPosition: 5,
              correctAnswer: 'station',
              options: ['station', 'nation', 'creation'],
              pattern: '-tion',
              hint: 'A place where people work or travel',
            ),
          ],
        ),
        StoryPart(
          id: 'space_2',
          partNumber: 2,
          content: 'The spaceship had special equipment for exploration. Luna felt excited about the space exploration that lay ahead.',
          questions: [
            Question(
              id: 'space_2_q1',
              sentence: 'Luna felt excited about the ____ exploration.',
              blankPosition: 5,
              correctAnswer: 'space',
              options: ['space', 'place', 'race'],
              pattern: 'sp-',
              hint: 'Where the stars and planets are',
            ),
            Question(
              id: 'space_2_q2',
              sentence: 'The spaceship had special equipment for ____.',
              blankPosition: 6,
              correctAnswer: 'exploration',
              options: ['exploration', 'creation', 'education'],
              pattern: '-tion',
              hint: 'The act of discovering new places',
            ),
          ],
        ),
        StoryPart(
          id: 'space_3',
          partNumber: 3,
          content: 'As the spaceship traveled through space, Luna made an amazing discovery. She found a planet with strange, colorful creatures.',
          questions: [
            Question(
              id: 'space_3_q1',
              sentence: 'She found a planet with ____, colorful creatures.',
              blankPosition: 5,
              correctAnswer: 'strange',
              options: ['strange', 'orange', 'change'],
              pattern: 'str-',
              hint: 'Unusual or different',
            ),
            Question(
              id: 'space_3_q2',
              sentence: 'As the ____ traveled through space...',
              blankPosition: 2,
              correctAnswer: 'spaceship',
              options: ['spaceship', 'friendship', 'ownership'],
              pattern: 'sp-',
              hint: 'Vehicle that travels in space',
            ),
          ],
        ),
      ],
    ),
  ];

  List<Story> getAllStories() {
    return List.unmodifiable(_stories);
  }

  Story? getStoryById(String id) {
    try {
      return _stories.firstWhere((story) => story.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Story> getStoriesByDifficulty(StoryDifficulty difficulty) {
    return _stories.where((story) => story.difficulty == difficulty).toList();
  }

  List<String> getAllLearningPatterns() {
    final patterns = <String>{};
    for (final story in _stories) {
      patterns.addAll(story.learningPatterns);
    }
    return patterns.toList()..sort();
  }

  List<Story> getStoriesWithPattern(String pattern) {
    return _stories.where((story) => story.learningPatterns.contains(pattern)).toList();
  }

  Map<String, List<String>> getPatternExamples() {
    return {
      '-ox': ['fox', 'box', 'sox', 'ox'],
      'qu-': ['quick', 'quiet', 'question', 'queen'],
      '-ck': ['knock', 'sock', 'rock', 'luck'],
      'ph': ['phone', 'graph', 'photo', 'elephant'],
      '-ght': ['night', 'light', 'sight', 'bright'],
      'dr-': ['draw', 'dream', 'dragon', 'drive'],
      'str-': ['strong', 'strange', 'street', 'story'],
      '-tion': ['station', 'creation', 'action', 'nation'],
      'sp-': ['space', 'special', 'speak', 'sport'],
    };
  }

  String getPatternDescription(String pattern) {
    final descriptions = {
      '-ox': 'Words that end with the "-ox" sound',
      'qu-': 'Words that start with "qu"',
      '-ck': 'Words that end with "-ck"',
      'ph': 'Words with "ph" making the "f" sound',
      '-ght': 'Words ending with "-ght"',
      'dr-': 'Words that start with "dr"',
      'str-': 'Words that start with "str"',
      '-tion': 'Words ending with "-tion"',
      'sp-': 'Words that start with "sp"',
    };
    
    return descriptions[pattern] ?? 'Learning pattern: $pattern';
  }
  
  void validateAllQuestions() {
    
    int problematicQuestions = 0;
    
    for (final story in _stories) {
      
      for (final part in story.parts) {
        for (final question in part.questions) {
          final quality = question.validateQuality(part);
          
          if (quality.hasIssues) {
            problematicQuestions++;
          }
        }
      }
    }
    
    
    if (problematicQuestions > 0) {
    } else {
    }
  }
  
  Map<String, dynamic> getStoryQualityReport(String storyId) {
    final story = getStoryById(storyId);
    if (story == null) return {};
    
    int totalQuestions = 0;
    int issuesFound = 0;
    final issueList = <String>[];
    
    for (final part in story.parts) {
      for (final question in part.questions) {
        totalQuestions++;
        final quality = question.validateQuality(part);
        
        if (quality.hasIssues) {
          issuesFound++;
          issueList.addAll(quality.issues);
        }
      }
    }
    
    return {
      'story_id': storyId,
      'story_title': story.title,
      'total_questions': totalQuestions,
      'issues_found': issuesFound,
      'quality_score': totalQuestions > 0 ? (totalQuestions - issuesFound) / totalQuestions * 100 : 0,
      'issues': issueList,
      'recommendation': issuesFound == 0 ? 'Excellent' : issuesFound < totalQuestions * 0.3 ? 'Good' : 'Needs Improvement',
    };
  }
} 