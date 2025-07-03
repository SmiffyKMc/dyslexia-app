import '../models/story.dart';

class StoryService {
  static final StoryService _instance = StoryService._internal();
  factory StoryService() => _instance;
  StoryService._internal();

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
              sentence: 'The fox lived in a big wooden box.',
              blankPosition: 5,
              correctAnswer: 'box',
              options: ['fox', 'box', 'rock'],
              pattern: '-ox',
              hint: 'Rhymes with fox!',
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
              sentence: 'Ralph flew through the bright moonlight every night.',
              blankPosition: 4,
              correctAnswer: 'bright',
              options: ['light', 'bright', 'night'],
              pattern: '-ght',
              hint: 'Means very light or shiny',
            ),
            Question(
              id: 'dragon_2_q2',
              sentence: 'The beautiful sight made him dream.',
              blankPosition: 2,
              correctAnswer: 'sight',
              options: ['light', 'sight', 'night'],
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
              sentence: 'She worked at the space station.',
              blankPosition: 4,
              correctAnswer: 'station',
              options: ['station', 'nation', 'creation'],
              pattern: '-tion',
              hint: 'A place where people work',
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
} 