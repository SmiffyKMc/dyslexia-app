import '../models/reading_session.dart';

class PresetStoriesService {
  static List<PresetStory> getPresetStories() {
    return [
      PresetStory(
        id: '1',
        title: 'The Quick Brown Fox',
        content: 'The quick brown fox jumps over the lazy dog. This pangram contains every letter of the alphabet.',
        difficulty: 'Easy',
        tags: ['pangram', 'alphabet'],
      ),
      PresetStory(
        id: '2',
        title: 'A Day at the Beach',
        content: '''Sarah walked along the sandy beach. The waves crashed gently against the shore. 
She collected colorful shells and watched seagulls fly overhead. 
The sun was warm on her face as she built a sandcastle with her friends.''',
        difficulty: 'Easy',
        tags: ['beach', 'adventure'],
      ),
      PresetStory(
        id: '3',
        title: 'The Magic Garden',
        content: '''In a hidden corner of the forest, there was a magical garden. 
Flowers of every color bloomed here, and butterflies danced from petal to petal. 
A gentle fairy tended to the plants, whispering songs to help them grow. 
Anyone who found this garden would be blessed with good luck.''',
        difficulty: 'Medium',
        tags: ['fantasy', 'nature'],
      ),
      PresetStory(
        id: '4',
        title: 'The Brave Little Mouse',
        content: '''Once upon a time, there lived a tiny mouse named Max. 
Despite his small size, Max had the biggest heart in the entire barn. 
When the farmer's cat threatened the other animals, Max devised a clever plan. 
He used his intelligence and courage to protect his friends, proving that size doesn't matter when you have a brave spirit.''',
        difficulty: 'Medium',
        tags: ['animals', 'courage', 'friendship'],
      ),
      PresetStory(
        id: '5',
        title: 'Journey to the Stars',
        content: '''Captain Luna adjusted her helmet as she prepared for the most important mission of her career. 
The spacecraft hummed with energy as it launched toward the distant constellation. 
Through the viewport, she could see Earth growing smaller, a beautiful blue marble suspended in the vast darkness of space. 
Her mission was to establish communication with a newly discovered civilization on the planet Zephyr.''',
        difficulty: 'Hard',
        tags: ['space', 'adventure', 'science fiction'],
      ),
    ];
  }

  static PresetStory? getStoryById(String id) {
    try {
      return getPresetStories().firstWhere((story) => story.id == id);
    } catch (e) {
      return null;
    }
  }

  static List<PresetStory> getStoriesByDifficulty(String difficulty) {
    return getPresetStories().where((story) => story.difficulty == difficulty).toList();
  }

  static List<PresetStory> getStoriesByTag(String tag) {
    return getPresetStories().where((story) => story.tags.contains(tag)).toList();
  }
} 