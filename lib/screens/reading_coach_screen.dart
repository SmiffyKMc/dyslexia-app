import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../controllers/reading_coach_store.dart';
import '../controllers/learner_profile_store.dart';
import '../models/reading_session.dart';
import '../utils/service_locator.dart';
import '../widgets/story_selector_modal.dart';

class ReadingCoachScreen extends StatefulWidget {
  const ReadingCoachScreen({super.key});

  @override
  State<ReadingCoachScreen> createState() => _ReadingCoachScreenState();
}

class _ReadingCoachScreenState extends State<ReadingCoachScreen> {
  late ReadingCoachStore _store;
  late LearnerProfileStore _profileStore;
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _store = getIt<ReadingCoachStore>();
    _profileStore = getIt<LearnerProfileStore>();
    _store.initialize();
    
    // Initialize text field with current text
    _textController.text = _store.currentText;
  }

  @override
  void dispose() {
    _textController.dispose();
    _store.dispose();
    super.dispose();
  }

  void _showStorySelectorModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StorySelectorModal(
        stories: _store.presetStories,
        onStorySelected: (story) {
          _store.selectPresetStory(story);
          _textController.text = story.content;
        },
        onAIStoryRequested: () {
          // Close the modal and start streaming story generation
          Navigator.of(context).pop();
          _startAIStoryGeneration();
        },
        learnerProfile: _profileStore.currentProfile,
      ),
    );
  }

  void _startAIStoryGeneration() {
    _store.generateAIStory((text) {
      // Update text field as story streams in
      _textController.text = text;
    });
  }

  void _selectImageFromGallery() {
                _store.pickImageFromGallery();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading Coach'),
        actions: [
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Reading Coach Help'),
                  content: const Text(
                    'Choose text to practice reading aloud. '
                    'The app will listen to your reading and provide feedback on pronunciation and accuracy.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.help_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Loading state - needs Observer for isLoading
            Observer(
              builder: (context) {
                if (_store.isLoading) {
                  return const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            
            // Main content - only show when not loading
            Observer(
          builder: (context) {
            if (_store.isLoading) {
                  return const SizedBox.shrink();
            }

                return Expanded(
                  child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                        // Error message - needs Observer for errorMessage
                        Observer(
                          builder: (context) {
                            if (_store.errorMessage == null) {
                              return const SizedBox.shrink();
                            }
                            return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        border: Border.all(color: Colors.red[200]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error, color: Colors.red[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _store.errorMessage!,
                              style: TextStyle(color: Colors.red[600]),
                            ),
                          ),
                          IconButton(
                            onPressed: _store.clearError,
                            icon: const Icon(Icons.close),
                            iconSize: 16,
                          ),
                        ],
                      ),
                            );
                          },
                        ),
                        
                        // Space after error message
                        Observer(
                          builder: (context) => _store.errorMessage != null 
                              ? const SizedBox(height: 16) 
                              : const SizedBox.shrink(),
                        ),
                        
                        // Static text selection section - no Observer needed
                  _buildTextSelection(),
                  const SizedBox(height: 24),
                        
                        // Current text display - needs Observer for currentText
                        Observer(
                          builder: (context) => _buildCurrentText(),
                        ),
                  const SizedBox(height: 24),
                        
                        // Reading controls - needs Observer for multiple states
                        Observer(
                          builder: (context) => _buildReadingControls(),
                        ),
                        
                        // Session results - needs Observer for hasSession
                        Observer(
                          builder: (context) {
                            if (!_store.hasSession) {
                              return const SizedBox.shrink();
                            }
                            return Column(
                              children: [
                    const SizedBox(height: 24),
                    _buildSessionResults(),
                                const SizedBox(height: 24),
                    _buildPracticeWords(),
                  ],
                            );
                          },
                        ),
                ],
                    ),
              ),
            );
          },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextSelection() {
    return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            const Text(
          'Enter text to read',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
        const SizedBox(height: 16),
        TextField(
          controller: _textController,
          maxLines: 4,
          minLines: 3,
          decoration: InputDecoration(
            hintText: 'Type or paste text to practice reading...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          onChanged: (text) {
            _store.setCurrentText(text);
          },
        ),
        const SizedBox(height: 8),
        Observer(
          builder: (_) => _store.isGeneratingStory
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AI Generating Story...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.purple[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(height: 8),
        ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                onPressed: _showStorySelectorModal,
                    icon: const Icon(Icons.library_books),
                    label: const Text('Choose Story'),
                  ),
                ),
            const SizedBox(width: 12),
            Expanded(
          child: OutlinedButton.icon(
                onPressed: _selectImageFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Scan Image'),
          ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCurrentText() {
    if (_store.currentText.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Icon(Icons.text_fields, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No text selected',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a story, paste text, or scan an image to get started',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Text to read:',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _store.speakText(_store.currentText),
                icon: const Icon(Icons.volume_up, size: 20),
                tooltip: 'Listen to text',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _store.currentText,
            style: const TextStyle(
                  fontSize: 18,
                  height: 1.6,
                  letterSpacing: 0.5,
                ),
              ),
        ],
            ),
    );
  }

  Widget _buildReadingControls() {
    return Column(
      children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
              decoration: BoxDecoration(
                color: _store.isListening ? Colors.red : Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
            Text(_store.isListening ? 'Recording...' : 'Mic ready'),
                const Spacer(),
            if (_store.hasSession) ...[
              Text(
                'Accuracy: ${_store.formattedAccuracy}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 16),
            ],
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.settings),
                ),
              ],
            ),
            const SizedBox(height: 16),
        if (!_store.hasSession) ...[
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
              onPressed: _store.canStartReading ? _store.startReading : null,
                icon: const Icon(Icons.mic, size: 28),
                label: const Text(
                  'Start Reading',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ] else ...[
            Row(
              children: [
                Expanded(
                child: SizedBox(
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _store.isListening ? _store.stopReading : null,
                    icon: const Icon(Icons.stop, size: 28),
                    label: const Text(
                      'Stop Reading',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ),
                ),
                const SizedBox(width: 12),
              if (_store.currentSession?.status == ReadingSessionStatus.paused)
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: OutlinedButton.icon(
                      onPressed: _store.resumeReading,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Resume'),
                    ),
                  ),
                )
              else
                Expanded(
                  child: SizedBox(
                    height: 60,
                  child: OutlinedButton.icon(
                      onPressed: _store.isListening ? _store.pauseReading : null,
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _store.restartSession,
                  child: const Text('Try Again'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _store.clearSession,
                  child: const Text('New Text'),
                ),
              ),
            ],
          ),
          // Add restart listening button if there are mic issues during a session
          if (_store.hasSession && 
              _store.currentSession?.status == ReadingSessionStatus.reading && 
              !_store.isListening) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _store.restartListening,
                icon: const Icon(Icons.refresh),
                label: const Text('Restart Microphone'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildLiveFeedback() {
    if (_store.liveFeedback.isEmpty) return const SizedBox.shrink();

    return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live Feedback',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
            ..._store.liveFeedback.map((feedback) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                      children: [
                  Icon(
                    feedback.contains('Great') || feedback.contains('Good')
                        ? Icons.check_circle
                        : Icons.cancel,
                    color: feedback.contains('Great') || feedback.contains('Good')
                        ? Colors.green
                        : Colors.red,
                    size: 20,
                  ),
                        const SizedBox(width: 8),
                  Expanded(child: Text(feedback)),
                      ],
                    ),
            )),
                  ],
                ),
              ),
    );
  }

  Widget _buildSessionResults() {
    if (!_store.hasSession || _store.currentSession?.status != ReadingSessionStatus.completed) {
      return const SizedBox.shrink();
    }

    final session = _store.currentSession!;
    final accuracy = session.calculateAccuracy();

    return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.star, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 16),
                Expanded(
                  child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                      Text(
                        accuracy > 0.8
                            ? 'Excellent work!'
                            : accuracy > 0.6
                                ? 'Good job!'
                                : 'Keep practicing!',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Reading accuracy: ${(accuracy * 100).round()}%',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Reading accuracy'),
                const Spacer(),
                Text(
                  '${(accuracy * 100).round()}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${session.correctWordsCount} of ${session.wordResults.length} words correct',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: accuracy,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPracticeWords() {
    if (_store.practiceWords.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Words to Focus On',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: _store.practiceWords.map((word) => _buildWordChip(word)).toList(),
        ),
      ],
    );
  }

  Widget _buildWordChip(String word) {
    return InkWell(
      onTap: () => _store.speakWord(word),
      borderRadius: BorderRadius.circular(20),
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(word, style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
            Icon(Icons.volume_up, size: 16, color: Theme.of(context).primaryColor),
          ],
        ),
      ),
    );
  }
} 