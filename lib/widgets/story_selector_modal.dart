import 'package:flutter/material.dart';
import '../models/reading_session.dart';
import '../models/story.dart';
import '../models/learner_profile.dart';
import '../services/story_service.dart';
import '../utils/service_locator.dart';
import 'dart:async';

class StorySelectorModal extends StatefulWidget {
  final List<PresetStory> stories;
  final Function(PresetStory) onStorySelected;
  final VoidCallback? onAIStoryRequested;
  final LearnerProfile? learnerProfile;

  const StorySelectorModal({
    super.key,
    required this.stories,
    required this.onStorySelected,
    this.onAIStoryRequested,
    this.learnerProfile,
  });

  @override
  State<StorySelectorModal> createState() => _StorySelectorModalState();
}

class _StorySelectorModalState extends State<StorySelectorModal> {
  final StringBuffer _storyBuffer = StringBuffer();
  StreamSubscription<String>? _storySub;

  @override
  void dispose() {
    _storySub?.cancel();
    super.dispose();
  }

  Future<void> _generateAIStory(BuildContext context) async {
    if (widget.learnerProfile == null) return;
    
    final messenger = ScaffoldMessenger.of(context);
    
    _storyBuffer.clear();
    _storySub?.cancel();
    
    try {
      // Show streaming dialog with proper StatefulBuilder
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, dialogSetState) => AlertDialog(
            title: const Text('Generating Story...'),
            content: SizedBox(
              width: double.maxFinite,
              height: 200,
              child: _storyBuffer.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Starting story generation...'),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Text(
                        _storyBuffer.toString(),
                        style: const TextStyle(fontSize: 16, height: 1.4),
                      ),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _storySub?.cancel();
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      );
      
      final storyService = getIt<StoryService>();
      final stream = storyService.generateStoryWithAIStream(widget.learnerProfile!);
      
      _storySub = stream.listen((chunk) {
        _storyBuffer.write(chunk);
        
        // Force dialog rebuild with the updated content
        if (context.mounted) {
          // Use a microtask to avoid build conflicts
          Future.microtask(() {
            if (context.mounted) {
              (context as Element).markNeedsBuild();
            }
          });
        }
      }, onError: (e) {
        if (context.mounted) {
          Navigator.of(context).pop();
          messenger.showSnackBar(
            SnackBar(
              content: Text('Error generating story: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }, onDone: () async {
        // Parse the complete story and close dialog
        if (context.mounted) {
          Navigator.of(context).pop();
          
          // Try to parse as structured story, fallback to simple text
          final storyService = getIt<StoryService>();
          final aiStory = storyService.parseStoryResponse(_storyBuffer.toString(), [], 'intermediate');
          
          if (aiStory != null) {
            final presetStory = PresetStory(
              id: aiStory.id,
              title: '🤖 ${aiStory.title}',
              content: aiStory.parts.first.content,
              difficulty: _mapDifficultyToString(aiStory.difficulty),
              tags: aiStory.learningPatterns,
            );
            
            Navigator.of(context).pop();
            widget.onStorySelected(presetStory);
          } else {
            // Fallback: use raw text as story content
            final presetStory = PresetStory(
              id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
              title: '🤖 Generated Story',
              content: _storyBuffer.toString(),
              difficulty: 'intermediate',
              tags: ['ai-generated'],
            );
            
            Navigator.of(context).pop();
            widget.onStorySelected(presetStory);
          }
        }
      });
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error generating story: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
          if (widget.learnerProfile != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: widget.onAIStoryRequested ?? () => _generateAIStory(context),
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
              itemCount: widget.stories.length,
              itemBuilder: (context, index) {
                final story = widget.stories[index];
                return _StoryCard(
                  story: story,
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onStorySelected(story);
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