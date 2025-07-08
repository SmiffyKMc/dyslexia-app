import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../controllers/adaptive_story_store.dart';
import '../models/story.dart';
import '../utils/service_locator.dart';
import '../utils/theme.dart';

class AdaptiveStoryScreen extends StatefulWidget {
  const AdaptiveStoryScreen({super.key});

  @override
  State<AdaptiveStoryScreen> createState() => _AdaptiveStoryScreenState();
}

class _AdaptiveStoryScreenState extends State<AdaptiveStoryScreen> {
  late AdaptiveStoryStore _store;

  @override
  void initState() {
    super.initState();
    _store = getIt<AdaptiveStoryStore>();
  }

  @override
  void dispose() {
    _store.clearCurrentStory();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adaptive Story Mode'),
      ),
      body: Observer(
        builder: (context) {
          if (_store.errorMessage != null) {
            return _buildErrorState();
          }

          if (_store.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!_store.hasCurrentStory) {
            return _buildStorySelectionScreen();
          }

          return _buildStoryReadingScreen();
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _store.errorMessage!,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _store.clearError,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorySelectionScreen() {
    final stories = _store.getAllStories();
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose Your Adventure! 📚',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: DyslexiaTheme.primaryAccent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a story to practice reading with fun fill-in-the-blank questions.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: stories.length,
              itemBuilder: (context, index) {
                final story = stories[index];
                return _buildStoryCard(story);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryCard(Story story) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: () => _store.startStory(story.id),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    story.coverImage,
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          story.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          story.description,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildDifficultyChip(story.difficulty),
                  const SizedBox(width: 8),
                  Text(
                    '${story.totalParts} parts',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: story.learningPatterns.map((pattern) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                         decoration: BoxDecoration(
                       color: DyslexiaTheme.primaryAccent.withOpacity(0.1),
                       borderRadius: BorderRadius.circular(12),
                     ),
                     child: Text(
                       pattern,
                       style: TextStyle(
                         fontSize: 12,
                         color: DyslexiaTheme.primaryAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyChip(StoryDifficulty difficulty) {
    final colors = {
      StoryDifficulty.beginner: Colors.green,
      StoryDifficulty.intermediate: Colors.orange,
      StoryDifficulty.advanced: Colors.red,
    };

    final labels = {
      StoryDifficulty.beginner: 'Beginner',
      StoryDifficulty.intermediate: 'Intermediate',
      StoryDifficulty.advanced: 'Advanced',
    };

    final color = colors[difficulty]!;
    final label = labels[difficulty]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildStoryReadingScreen() {
    return Column(
      children: [
        _buildProgressHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_store.currentPart != null) ...[
                  _buildStoryContent(),
                  const SizedBox(height: 24),
                  if (_store.hasCurrentQuestion) ...[
                    _buildQuestion(),
                    const SizedBox(height: 24),
                  ],
                ],
                _buildNavigationButtons(),
                const SizedBox(height: 24),
                _buildSidePanel(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressHeader() {
    final progress = _store.progressPercentage;
    final currentPart = _store.currentPartIndex + 1;
    final totalParts = _store.currentStory?.totalParts ?? 1;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
                 color: DyslexiaTheme.primaryAccent.withOpacity(0.1),
         border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _store.currentStory?.title ?? '',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _store.speakCurrentContent,
                    icon: const Icon(Icons.volume_up),
                    tooltip: 'Read aloud',
                  ),
                  IconButton(
                    onPressed: _store.restartStory,
                    icon: const Icon(Icons.restart_alt),
                    tooltip: 'Restart story',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Part $currentPart of $totalParts'),
              const SizedBox(width: 16),
              Expanded(
                child: LinearProgressIndicator(
                  value: progress / 100,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(DyslexiaTheme.primaryAccent),
                ),
              ),
              const SizedBox(width: 8),
              Text('${progress.toStringAsFixed(0)}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStoryContent() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Part ${_store.currentPartIndex + 1}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: DyslexiaTheme.primaryAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _store.speakCurrentContent,
                  icon: const Icon(Icons.play_circle_outline),
                  iconSize: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _store.currentPartContentWithMasking,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.6,
                fontSize: 18,
              ),
            ),
            if (_store.currentQuestion != null && 
                _store.currentPart != null && 
                _store.currentQuestion!.getWordsToMask(_store.currentPart!).isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.yellow.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Some words are hidden (**** ) to help you focus on the question below.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion() {
    final question = _store.currentQuestion!;
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.quiz, color: DyslexiaTheme.primaryAccent),
                const SizedBox(width: 8),
                Text(
                  'Fill in the blank:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: DyslexiaTheme.primaryAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _store.speakQuestion,
                  icon: const Icon(Icons.play_circle_outline),
                  iconSize: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              question.sentenceWithBlank,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.6,
                fontSize: 16,
              ),
            ),
            if (question.hint != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.lightbulb_outline, size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    'Hint: ${question.hint}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.orange.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            if (_store.showingFeedback) ...[
              _buildFeedback(),
            ] else ...[
              _buildAnswerOptions(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerOptions() {
    final question = _store.currentQuestion!;
    
    return Column(
      children: question.options.map((option) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          child: ElevatedButton(
            onPressed: () => _store.answerQuestion(option),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              side: BorderSide(color: Colors.grey.shade300),
              elevation: 1,
            ),
            child: Text(
              option,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFeedback() {
    final answer = _store.lastAnswer!;
    final isCorrect = answer.isCorrect;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCorrect ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCorrect ? Colors.green : Colors.red,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: isCorrect ? Colors.green : Colors.red,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? 'Correct! Well done!' : 'Not quite right.',
                style: TextStyle(
                  color: isCorrect ? Colors.green.shade700 : Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          if (!isCorrect) ...[
            const SizedBox(height: 8),
            Text(
              'The correct answer is: ${answer.correctAnswer}',
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _store.speakCorrectAnswer,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.volume_up, size: 16),
                      SizedBox(width: 4),
                      Text('Hear it'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _store.nextQuestion,
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            if (_store.canGoPrevious)
              Expanded(
                child: OutlinedButton(
                  onPressed: _store.goToPreviousPart,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back, size: 16),
                      SizedBox(width: 4),
                      Text('Previous'),
                    ],
                  ),
                ),
              ),
            if (_store.canGoPrevious && _store.hasCurrentQuestion) const SizedBox(width: 8),
            if (_store.hasCurrentQuestion)
              Expanded(
                child: OutlinedButton(
                  onPressed: _store.skipCurrentQuestion,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade700,
                    side: BorderSide(color: Colors.orange.shade300),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.skip_next, size: 16),
                      SizedBox(width: 4),
                      Text('Skip'),
                    ],
                  ),
                ),
              ),
            if (!_store.hasCurrentQuestion && _store.canGoNext) ...[
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _store.nextPart,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Next Part'),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSidePanel() {
    return Column(
      children: [
        _buildPracticedWordsPanel(),
        const SizedBox(height: 16),
        _buildLearningPatternsPanel(),
      ],
    );
  }

  Widget _buildPracticedWordsPanel() {
    final words = _store.uniquePracticedWords;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list_alt, color: DyslexiaTheme.primaryAccent),
                const SizedBox(width: 8),
                Text(
                  'Words Practiced (${words.length})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (words.isEmpty)
              Text(
                'Start answering questions to see practiced words here!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: words.map((word) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: DyslexiaTheme.successColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: DyslexiaTheme.successColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      word,
                      style: TextStyle(
                        color: DyslexiaTheme.successColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearningPatternsPanel() {
    final patterns = _store.discoveredPatterns;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pattern, color: DyslexiaTheme.primaryAccent),
                const SizedBox(width: 8),
                Text(
                  'Learning Patterns (${patterns.length})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (patterns.isEmpty)
              Text(
                'Answer questions to discover learning patterns!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              ...patterns.map((pattern) {
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: DyslexiaTheme.primaryAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: DyslexiaTheme.primaryAccent.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            pattern.pattern,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: DyslexiaTheme.primaryAccent,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: DyslexiaTheme.primaryAccent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${pattern.practiceCount}x',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pattern.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      ),
                      if (pattern.examples.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Examples: ${pattern.examples.take(3).join(', ')}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DyslexiaTheme.primaryAccent,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
} 