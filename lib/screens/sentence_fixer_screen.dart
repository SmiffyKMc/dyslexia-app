import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../controllers/sentence_fixer_store.dart';
import '../controllers/learner_profile_store.dart';
import '../utils/service_locator.dart';

class SentenceFixerScreen extends StatefulWidget {
  const SentenceFixerScreen({super.key});

  @override
  State<SentenceFixerScreen> createState() => _SentenceFixerScreenState();
}

class _SentenceFixerScreenState extends State<SentenceFixerScreen> {
  late SentenceFixerStore _store;
  late LearnerProfileStore _profileStore;

  @override
  void initState() {
    super.initState();
    _store = getIt<SentenceFixerStore>();
    _profileStore = getIt<LearnerProfileStore>();
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sentence Fixer'),
        actions: [
          Observer(
            builder: (_) => _store.hasCurrentSession && !_store.isSessionCompleted
                ? IconButton(
                    onPressed: _store.pauseSession,
                    icon: const Icon(Icons.pause),
                    tooltip: 'Pause Session',
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            
            
            // Error state - needs Observer for errorMessage
            Observer(
              builder: (context) {
                if (_store.isLoading || _store.errorMessage == null) {
                  return const SizedBox.shrink();
                }
                return Expanded(child: _buildErrorScreen());
              },
            ),
            
            // Start screen - needs Observer for session state
            Observer(
              builder: (context) {
                if (_store.errorMessage != null || _store.hasCurrentSession) {
                  return const SizedBox.shrink();
                }
                return Expanded(child: _buildStartScreen());
              },
            ),
            
            // Completion screen - needs Observer for completion state
            Observer(
              builder: (context) {
                if (_store.isLoading || _store.errorMessage != null || !_store.hasCurrentSession || !_store.isSessionCompleted) {
                  return const SizedBox.shrink();
                }
                return Expanded(child: _buildCompletionScreen());
              },
            ),
            
            // Game screen - needs Observer for game state
            Observer(
              builder: (context) {
                if (_store.isLoading || _store.errorMessage != null || !_store.hasCurrentSession || _store.isSessionCompleted) {
                  return const SizedBox.shrink();
                }
                return Expanded(child: _buildGameScreen());
          },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _store.errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                _store.clearError();
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.search,
                    size: 48,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Find the Errors!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tap words that look wrong to find spelling and grammar mistakes.',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Choose Difficulty',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),
          _buildDifficultyCard(
            'Beginner',
            'Simple spelling errors',
            'Easy words, basic mistakes',
            Colors.green,
          ),
          const SizedBox(height: 12),
          _buildDifficultyCard(
            'Intermediate',
            'Mixed errors',
            'Grammar and spelling mistakes',
            Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildDifficultyCard(
            'Advanced',
            'Complex sentences',
            'Multiple error types',
            Colors.red,
          ),
          const SizedBox(height: 24),
          Text(
            'How to Play',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildInstructionItem('1', 'Read the sentence carefully'),
          _buildInstructionItem('2', 'Tap words that look wrong'),
          _buildInstructionItem('3', 'Submit your answer'),
          _buildInstructionItem('4', 'See the correct sentence'),
        ],
      ),
    );
  }

  Widget _buildDifficultyCard(String title, String subtitle, String description, Color color) {
    return Observer(
      builder: (context) => Card(
        child: InkWell(
          onTap: _store.isLoading ? null : () => _startGame(title.toLowerCase()),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.quiz,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionItem(String number, String instruction) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              instruction,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGameHeader(),
          const SizedBox(height: 24),
          _buildInstructionCard(),
          const SizedBox(height: 24),
          _buildSentenceCard(),
          if (_store.showFeedback) ...[
            const SizedBox(height: 24),
            _buildFeedbackCard(),
          ],
          const SizedBox(height: 24),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildGameHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Observer(
                  builder: (_) => Text(
                    _store.isGeneratingSentences 
                        ? _store.streamingStatusText
                        : 'Sentence ${_store.currentSentenceNumber} of ${_store.totalSentences}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _store.isGeneratingSentences ? Colors.orange : null,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      'Score: ${_store.currentScore}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    if (_store.currentStreak > 0) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_fire_department, size: 16, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              '${_store.currentStreak}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _store.progressPercentage,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildInstructionCard() {
    return Card(
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.search,
              color: Theme.of(context).primaryColor,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🎯 Find the errors in this sentence',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap words that look wrong. Selected: ${_store.selectedWordsCount}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSentenceCard() {
    if (_store.currentSentence == null) return const SizedBox.shrink();

    final sentence = _store.currentSentence!;
    
    return Observer(
      builder: (context) => Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sentence.hint != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline, size: 20, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Hint: ${sentence.hint}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.blue[700],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: sentence.words.asMap().entries.map((entry) {
                  final index = entry.key;
                  final word = entry.value;
                  final isSelected = index < _store.selectedWords.length && _store.selectedWords[index];
                  
                  return _buildWordButton(word, index, isSelected);
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWordButton(String word, int index, bool isSelected) {
    return InkWell(
      onTap: _store.showFeedback ? null : () => _store.toggleWordSelection(index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _getWordButtonColor(index, isSelected),
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          word,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: _getWordTextColor(index, isSelected),
          ),
        ),
      ),
    );
  }

  Color _getWordButtonColor(int index, bool isSelected) {
    if (!_store.showFeedback) {
      return isSelected 
          ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
          : Colors.grey[50]!;
    }

    // Show feedback colors
    final feedback = _store.currentFeedback;
    if (feedback == null) return Colors.grey[50]!;

    if (feedback.correctSelections.contains(index)) {
      return Colors.green.withValues(alpha: 0.2);
    } else if (feedback.incorrectSelections.contains(index)) {
      return Colors.red.withValues(alpha: 0.2);
    } else if (feedback.missedErrors.contains(index)) {
      return Colors.orange.withValues(alpha: 0.2);
    }

    return Colors.grey[50]!;
  }

  Color _getWordTextColor(int index, bool isSelected) {
    if (!_store.showFeedback) {
      return isSelected ? Theme.of(context).primaryColor : Colors.black;
    }

    // Show feedback colors
    final feedback = _store.currentFeedback;
    if (feedback == null) return Colors.black;

    if (feedback.correctSelections.contains(index)) {
      return Colors.green[700]!;
    } else if (feedback.incorrectSelections.contains(index)) {
      return Colors.red[700]!;
    } else if (feedback.missedErrors.contains(index)) {
      return Colors.orange[700]!;
    }

    return Colors.black;
  }

  Widget _buildFeedbackCard() {
    final feedback = _store.currentFeedback;
    if (feedback == null) return const SizedBox.shrink();

    return Card(
      color: feedback.isSuccess ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  feedback.isSuccess ? Icons.check_circle : Icons.info,
                  color: feedback.isSuccess ? Colors.green : Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    feedback.message,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: feedback.isSuccess ? Colors.green[700] : Colors.orange[700],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '+${feedback.score}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            
            // Show detailed feedback with correct answers
            if (_store.detailedFeedback != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Results:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _store.detailedFeedback!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_fix_high, size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 6),
                      Text(
                        'Corrected sentence:',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    feedback.correctedSentence,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: Colors.blue[800],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackItem(IconData icon, Color color, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Observer(
      builder: (context) {
        if (_store.showFeedback) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: _store.nextSentence,
                icon: const Icon(Icons.arrow_forward),
                label: Text(_store.currentSentenceNumber < _store.totalSentences 
                    ? 'Next Sentence' 
                    : 'Complete Session'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _store.retryCurrentSentence,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _store.canSubmit ? _store.submitAnswer : null,
              icon: const Icon(Icons.send),
              label: const Text('Submit Answer'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _store.skipCurrentSentence,
                    icon: const Icon(Icons.skip_next),
                    label: const Text('Skip'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _store.endSession,
                    icon: const Icon(Icons.stop),
                    label: const Text('End'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompletionScreen() {
    final session = _store.currentSession!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            color: Colors.green.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.celebration,
                    size: 64,
                    color: Colors.green[600],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Session Complete!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You found ${session.correctSentences} out of ${session.completedSentences} sentences correctly!',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Results',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStatItem('Accuracy', '${session.accuracyPercentage.round()}%'),
                  _buildStatItem('Total Score', '${session.totalScore} points'),
                  _buildStatItem('Best Streak', '${session.streak} in a row'),
                  _buildStatItem('Time Spent', '${session.duration?.inMinutes ?? 0} minutes'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _startGame(session.difficulty),
              icon: const Icon(Icons.refresh),
              label: const Text('Play Again'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.home),
              label: const Text('Back to Home'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _startGame(String difficulty) {
    _store.startNewSession(
      difficulty: difficulty,
      // Remove hardcoded sentenceCount - let store determine based on difficulty
      profile: _profileStore.currentProfile,
    );
  }
} 