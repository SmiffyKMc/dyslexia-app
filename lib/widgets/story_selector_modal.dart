import 'package:flutter/material.dart';
import '../models/reading_session.dart';
import '../models/story.dart';
import '../models/learner_profile.dart';
import '../services/story_service.dart';
import '../utils/service_locator.dart';

class StorySelectorModal extends StatelessWidget {
  final List<PresetStory> stories;
  final Function(PresetStory) onStorySelected;
  final LearnerProfile? learnerProfile;

  const StorySelectorModal({
    super.key,
    required this.stories,
    required this.onStorySelected,
    this.learnerProfile,
  });

  Future<void> _generateAIStory(BuildContext context) async {
    if (learnerProfile == null) return;
    
    final messenger = ScaffoldMessenger.of(context);
    
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Generate AI story
      final storyService = getIt<StoryService>();
      final aiStory = await storyService.generateStoryWithAI(learnerProfile!);
      
      // Hide loading indicator
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      if (aiStory != null) {
        // Convert AI story to PresetStory for compatibility
        final presetStory = PresetStory(
          id: aiStory.id,
          title: '🤖 ${aiStory.title}',
          content: aiStory.parts.first.content,
          difficulty: _mapDifficultyToString(aiStory.difficulty),
          tags: aiStory.learningPatterns,
        );
        
        // Close modal and return AI story
        if (context.mounted) {
          Navigator.of(context).pop();
          onStorySelected(presetStory);
        }
      } else {
        // Show error message
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Failed to generate AI story. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Hide loading indicator if still showing
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      // Show error message
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error generating story: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _mapDifficultyToString(StoryDifficulty difficulty) {
    switch (difficulty) {
      case StoryDifficulty.beginner:
        return 'Easy';
      case StoryDifficulty.intermediate:
        return 'Medium';
      case StoryDifficulty.advanced:
        return 'Hard';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Choose a Story',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          if (learnerProfile != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: () => _generateAIStory(context),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate AI Story'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: stories.length,
              itemBuilder: (context, index) {
                final story = stories[index];
                return _StoryCard(
                  story: story,
                  onTap: () {
                    Navigator.of(context).pop();
                    onStorySelected(story);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  final PresetStory story;
  final VoidCallback onTap;

  const _StoryCard({
    required this.story,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      story.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getDifficultyColor(story.difficulty),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      story.difficulty,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                story.content.length > 100
                    ? '${story.content.substring(0, 100)}...'
                    : story.content,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  height: 1.4,
                ),
              ),
              if (story.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: story.tags.take(3).map((tag) => Chip(
                    label: Text(
                      tag,
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: Colors.grey[100],
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
} 