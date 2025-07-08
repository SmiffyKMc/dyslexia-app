import '../models/story.dart';
import '../models/learner_profile.dart';
import '../services/ai_inference_service.dart';
import '../utils/service_locator.dart';
import 'dart:convert';
import 'dart:developer' as developer;

class StoryService {
  static final StoryService _instance = StoryService._internal();
  factory StoryService() => _instance;
  StoryService._internal();

  late final AIInferenceService _aiService = getIt<AIInferenceService>();

  Future<Story?> generateStoryWithAI(LearnerProfile profile) async {
    try {
      developer.log('🤖 Generating AI story for profile', name: 'dyslexic_ai.story_ai');
      
      // Extract profile data for story generation
      final targetPhonemes = _extractTargetPhonemes(profile);
      final difficulty = _mapProfileToDifficulty(profile);
      final storyLength = _getStoryLength(difficulty);
      
      developer.log('🎯 Target phonemes: $targetPhonemes, Difficulty: $difficulty', name: 'dyslexic_ai.story_ai');
      
      // Generate story with Gemma 3n
      final prompt = _buildStoryPrompt(targetPhonemes, difficulty, storyLength);
      final response = await _aiService.generateResponse(prompt);
      
      // Parse response into Story object
      final story = _parseStoryResponse(response, targetPhonemes, difficulty);
      
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

  String _buildStoryPrompt(List<String> targetPhonemes, String difficulty, int sentenceCount) {
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

Question types needed:
1. Fill-in-blank question testing "$phoneme1" pattern
2. Fill-in-blank question testing "$phoneme2" pattern  
3. Comprehension question about the main character or setting
4. Comprehension question about what happens in the story

Output MUST be valid JSON in exactly this format:
{
  "title": "Story Title",
  "content": "The complete story text...",
  "difficulty": "$difficulty",
  "patterns": ["$phoneme1", "$phoneme2"],
  "questions": [
    {
      "id": "q1",
      "type": "fill_in_blank",
      "sentence": "Sentence with ____ blank",
      "blank_position": 3,
      "correct_answer": "word",
      "options": ["word", "option2", "option3"],
      "pattern": "$phoneme1",
      "hint": "Helpful hint"
    },
    {
      "id": "q2", 
      "type": "fill_in_blank",
      "sentence": "Another sentence with ____ blank",
      "blank_position": 4,
      "correct_answer": "word2",
      "options": ["word2", "option2", "option3"],
      "pattern": "$phoneme2",
      "hint": "Helpful hint"
    },
    {
      "id": "q3",
      "type": "comprehension",
      "question": "Who is the main character?",
      "correct_answer": "Answer",
      "options": ["Answer", "Wrong1", "Wrong2"]
    },
    {
      "id": "q4", 
      "type": "comprehension",
      "question": "What happened in the story?",
      "correct_answer": "Answer",
      "options": ["Answer", "Wrong1", "Wrong2"]
    }
  ]
}

Generate the story now:''';
  }

  Story? _parseStoryResponse(String response, List<String> targetPhonemes, String difficulty) {
    try {
      // Extract JSON from response
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(response);
      if (jsonMatch == null) {
        developer.log('❌ No JSON found in AI response', name: 'dyslexic_ai.story_ai');
        return null;
      }
      
      final jsonString = jsonMatch.group(0)!;
      final data = json.decode(jsonString) as Map<String, dynamic>;
      
      // Validate required fields
      if (!data.containsKey('title') || !data.containsKey('content') || !data.containsKey('questions')) {
        developer.log('❌ Missing required fields in AI response', name: 'dyslexic_ai.story_ai');
        return null;
      }
      
      // Create questions
      final questions = <Question>[];
      final questionsData = data['questions'] as List<dynamic>;
      
      for (int i = 0; i < questionsData.length; i++) {
        final qData = questionsData[i] as Map<String, dynamic>;
        
        final question = Question(
          id: qData['id'] ?? 'ai_q$i',
          sentence: qData['type'] == 'fill_in_blank' ? qData['sentence'] ?? '' : qData['question'] ?? '',
          blankPosition: qData['blank_position'] ?? 0,
          correctAnswer: qData['correct_answer'] ?? '',
          options: List<String>.from(qData['options'] ?? []),
          type: qData['type'] == 'fill_in_blank' ? QuestionType.fillInBlank : QuestionType.multipleChoice,
          hint: qData['hint'],
          pattern: qData['pattern'] ?? '',
        );
        
        questions.add(question);
      }
      
      // Create story part
      final storyPart = StoryPart(
        id: 'ai_generated_part',
        partNumber: 1,
        content: data['content'] as String,
        questions: questions,
      );
      
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
          content: 'Once upon a time, there lived a clever fox in a magical forest. The fox had bright orange fur and a quick mind.',
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
              sentence: 'The fox heard a quick sound at the door.',
              blankPosition: 3,
              correctAnswer: 'quick',
              options: ['slow', 'quick', 'loud'],
              pattern: 'qu-',
              hint: 'Starts with "qu"',
            ),
            Question(
              id: 'fox_2_q2',
              sentence: 'There was a knock at the door.',
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
              sentence: 'The rabbit was very quiet and polite.',
              blankPosition: 3,
              correctAnswer: 'quiet',
              options: ['quick', 'quiet', 'quite'],
              pattern: 'qu-',
              hint: 'Means not noisy',
            ),
            Question(
              id: 'fox_3_q2',
              sentence: 'The rabbit lost his lucky sock.',
              blankPosition: 5,
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
              sentence: 'The dragon loved taking photographs of nature.',
              blankPosition: 4,
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
              sentence: 'The sun was very ____ in the morning sky.',
              blankPosition: 4,
              correctAnswer: 'bright',
              options: ['light', 'bright', 'tight'],
              pattern: '-ght',
              hint: 'Means very light or shiny',
            ),
            Question(
              id: 'dragon_2_q2',
              sentence: 'What a wonderful ____ to see from above!',
              blankPosition: 3,
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
              sentence: 'Ralph decided to draw a beautiful map.',
              blankPosition: 3,
              correctAnswer: 'draw',
              options: ['draw', 'fly', 'see'],
              pattern: 'dr-',
              hint: 'To make pictures with a pencil',
            ),
            Question(
              id: 'dragon_3_q2',
              sentence: 'He drew many wonderful places on the map.',
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
              sentence: 'Captain Luna had a strong telescope.',
              blankPosition: 4,
              correctAnswer: 'strong',
              options: ['long', 'strong', 'wrong'],
              pattern: 'str-',
              hint: 'Means powerful or sturdy',
            ),
            Question(
              id: 'space_1_q2',
              sentence: 'The train arrived at the ____.',
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
              sentence: 'Luna was excited about the space exploration.',
              blankPosition: 5,
              correctAnswer: 'space',
              options: ['space', 'place', 'race'],
              pattern: 'sp-',
              hint: 'Where the stars and planets are',
            ),
            Question(
              id: 'space_2_q2',
              sentence: 'The mission was about exploration of new worlds.',
              blankPosition: 4,
              correctAnswer: 'exploration',
              options: ['exploration', 'creation', 'education'],
              pattern: '-tion',
              hint: 'Discovering new places',
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
              sentence: 'Luna found creatures that looked strange.',
              blankPosition: 4,
              correctAnswer: 'strange',
              options: ['strange', 'orange', 'change'],
              pattern: 'str-',
              hint: 'Unusual or different',
            ),
            Question(
              id: 'space_3_q2',
              sentence: 'The spaceship continued its space journey.',
              blankPosition: 1,
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
    print('📚 Loaded ${_stories.length} stories');
    
    // Validate question quality on first load (in debug mode)
    assert(() {
      validateAllQuestions();
      return true;
    }());
    
    return List.unmodifiable(_stories);
  }

  Story? getStoryById(String id) {
    try {
      return _stories.firstWhere((story) => story.id == id);
    } catch (e) {
      print('❌ Story not found: $id');
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
    print('🔍 Validating question quality for all stories...');
    
    int totalQuestions = 0;
    int problematicQuestions = 0;
    
    for (final story in _stories) {
      print('📖 Validating story: ${story.title}');
      
      for (final part in story.parts) {
        for (final question in part.questions) {
          totalQuestions++;
          final quality = question.validateQuality(part);
          
          if (quality.hasIssues) {
            problematicQuestions++;
            print('⚠️ Question ${question.id} has issues:');
            for (final issue in quality.issues) {
              print('   - $issue');
            }
            print('   Question: "${question.sentence}"');
            print('   Options: ${question.options}');
            print('   Educational Value: ${quality.educationalValue}');
            print('');
          }
        }
      }
    }
    
    print('📊 Question Quality Report:');
    print('   Total Questions: $totalQuestions');
    print('   Problematic Questions: $problematicQuestions');
    print('   Quality Score: ${((totalQuestions - problematicQuestions) / totalQuestions * 100).toStringAsFixed(1)}%');
    
    if (problematicQuestions > 0) {
      print('❌ Found $problematicQuestions questions that need improvement');
    } else {
      print('✅ All questions passed quality validation');
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