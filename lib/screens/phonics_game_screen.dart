import 'package:flutter/material.dart';
import '../controllers/phonics_game_store.dart';
import '../models/phonics_game.dart';
import '../utils/service_locator.dart';

class PhonicsGameScreen extends StatefulWidget {
  const PhonicsGameScreen({super.key});

  @override
  State<PhonicsGameScreen> createState() => _PhonicsGameScreenState();
}

class _PhonicsGameScreenState extends State<PhonicsGameScreen> {
  late PhonicsGameStore _store;

  @override
  void initState() {
    super.initState();
    _store = getIt<PhonicsGameStore>();
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
        title: const Text('Phonics Game'),
        actions: [
          if (_store.hasCurrentSession && _store.isGameActive)
          IconButton(
              onPressed: _store.pauseGame,
              icon: const Icon(Icons.pause),
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _store,
          builder: (context, child) {
            if (_store.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (_store.errorMessage != null) {
              return _buildErrorScreen();
            }

            if (!_store.hasCurrentSession) {
              return _buildStartScreen();
            }

            if (_store.currentSession!.isCompleted) {
              return _buildCompletionScreen();
            }

            return _buildGameScreen();
          },
        ),
      ),
    );
  }

  Widget _buildStartScreen() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.volume_up_outlined,
              size: 60,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Phonics Game',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Listen to sounds and pick the word that starts with that sound!',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Game Settings',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Rounds:'),
                      DropdownButton<int>(
                        value: _store.sessionDuration,
                        items: [5, 6, 7, 8, 9, 10].map((rounds) {
                          return DropdownMenuItem(
                            value: rounds,
                            child: Text('$rounds'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            _store.setSessionDuration(value);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _store.startNewGame(
                rounds: _store.sessionDuration,
                difficulty: 1,
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Start Game',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameScreen() {
    final currentRound = _store.currentRound!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
      children: [
          _buildGameHeader(),
          const SizedBox(height: 24),
          _buildSoundPlayer(),
          const SizedBox(height: 24),
          _buildInstructionCard(currentRound),
          const SizedBox(height: 24),
          _buildWordOptions(currentRound),
          if (_store.showFeedback) ...[
            const SizedBox(height: 24),
            _buildFeedbackCard(),
          ],
          const SizedBox(height: 24),
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
                Text(
                  'Round ${_store.currentRoundNumber} of ${_store.totalRounds}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Score: ${_store.currentScore}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                    color: Theme.of(context).primaryColor,
                      ),
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

  Widget _buildSoundPlayer() {
    return Container(
      width: 120,
      height: 120,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _store.showFeedback ? null : _store.replaySound,
          borderRadius: BorderRadius.circular(60),
          child: Center(
            child: _store.isPlayingSound
                ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                : const Icon(
            Icons.volume_up,
            size: 50,
            color: Colors.white,
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildInstructionCard(GameRound round) {
    return Card(
      color: Colors.blue[50],
          child: Padding(
            padding: const EdgeInsets.all(16),
        child: Column(
                  children: [
                    Text(
              'Tap the word that starts with the sound you heard',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
                    Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '🔊 Listen carefully!',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the sound button to hear it again',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordOptions(GameRound round) {
    return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
      ),
      itemCount: round.options.length,
      itemBuilder: (context, index) {
        final option = round.options[index];
        final isSelected = _store.selectedAnswer == option.word;
        final isCorrect = option.isCorrect;
        
        Color? backgroundColor;
        Color? borderColor;
        
        if (_store.showFeedback && isSelected) {
          backgroundColor = isCorrect ? Colors.green[100] : Colors.red[100];
          borderColor = isCorrect ? Colors.green : Colors.red;
        } else if (_store.showFeedback && isCorrect && !isSelected) {
          backgroundColor = Colors.green[50];
          borderColor = Colors.green[300];
        }
        
        return Card(
          color: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: borderColor ?? Colors.transparent,
              width: 2,
            ),
          ),
      child: InkWell(
            onTap: _store.showFeedback ? null : () => _store.selectAnswer(option.word),
            borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  option.word,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_store.showFeedback && isSelected) ...[
                const SizedBox(height: 4),
                Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect ? Colors.green : Colors.red,
                  size: 16,
                ),
              ],
            ],
          ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeedbackCard() {
    return Card(
      color: _store.feedbackIsCorrect ? Colors.green[50] : Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              _store.feedbackIsCorrect ? Icons.check_circle : Icons.cancel,
              size: 48,
              color: _store.feedbackIsCorrect ? Colors.green : Colors.red,
              ),
            const SizedBox(height: 8),
            Text(
              _store.feedbackMessage,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _store.nextRound,
                child: Text(
                  _store.currentRoundNumber < _store.totalRounds ? 'Next Round' : 'Complete Game',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionScreen() {
    return Padding(
      padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
            width: 120,
            height: 120,
                decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
                ),
            child: const Icon(
              Icons.emoji_events,
              size: 60,
              color: Colors.green,
            ),
              ),
          const SizedBox(height: 24),
              Text(
            'Game Complete!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Your Results',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('Score', '${_store.currentScore}'),
                      _buildStatItem('Correct', '${_store.correctAnswers}/${_store.totalRounds}'),
                      _buildStatItem('Accuracy', '${_store.accuracyPercentage.toStringAsFixed(0)}%'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _store.retryGame,
                  child: const Text('Play Again'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _store.startNextSoundSet,
                  child: const Text('Next Sound Set'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ],
        ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorScreen() {
    return Padding(
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
            'Oops! Something went wrong',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _store.errorMessage ?? 'Unknown error occurred',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              _store.clearError();
              Navigator.pop(context);
            },
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }
} 