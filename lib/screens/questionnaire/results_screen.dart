import 'package:flutter/material.dart';
import '../../services/questionnaire_service.dart';
import '../../services/font_preference_service.dart';
import '../../main.dart';

class ResultsScreen extends StatefulWidget {
  final String userName;
  final List<String> selectedChallenges;
  final VoidCallback onComplete;

  const ResultsScreen({
    super.key,
    required this.userName,
    required this.selectedChallenges,
    required this.onComplete,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _isCompleting = false;
  String? _errorMessage;

  Future<void> _completeQuestionnaire() async {
    if (_isCompleting) return;
    
    setState(() {
      _isCompleting = true;
      _errorMessage = null;
    });

    try {
      await QuestionnaireService.completeQuestionnaire(
        userName: widget.userName,
        selectedChallenges: widget.selectedChallenges,
      );
      
      if (mounted) {
        // Navigate to MainApp
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainApp()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to complete assessment. Please try again.';
          _isCompleting = false;
        });
      }
    }
  }

  /// Check if user selected challenges that would benefit from dyslexic font
  bool _shouldRecommendDyslexicFont() {
    const visualChallenges = {
      'letter_confusion',      // Confuses similar letters (b/d, p/q)
      'skipping_words',        // Often skips words or lines when reading
      'word_recognition',      // Difficulty recognizing common words
      'slow_reading',          // Reading feels slow or effortful
    };
    
    return widget.selectedChallenges.any((challenge) => visualChallenges.contains(challenge));
  }

  Future<void> _applyDyslexicFont() async {
    try {
      await FontPreferenceService().setFontPreference(true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Dyslexia-friendly font applied! You can change this in Settings anytime.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to apply font. You can change this in Settings later.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildFontRecommendationCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.text_fields,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Font Recommendation',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Based on your responses, we recommend trying our dyslexia-friendly font',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Font comparison
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Standard Font',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Reading helps you learn\nand understand better.',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dyslexia-Friendly Font',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Reading helps you learn\nand understand better.',
                              style: TextStyle(
                                fontFamily: 'OpenDyslexic',
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            Text(
              '💡 The dyslexia-friendly font makes letters more distinct and can help reduce letter confusion and improve reading flow.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[700],
                fontStyle: FontStyle.italic,
              ),
            ),
            
            const SizedBox(height: 20),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {}, // Skip - do nothing
                    child: const Text('Maybe Later'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _applyDyslexicFont,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Try It Now'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          
          // Success card
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      size: 48,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'All Set, ${widget.userName.isNotEmpty ? widget.userName : 'Friend'}!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your personalized learning plan is ready! We\'ve analyzed your responses and prepared AI-powered recommendations just for you.',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // What's next card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: Theme.of(context).primaryColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'What\'s Next?',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _buildNextStepItem(
                    context,
                    Icons.psychology,
                    'Personalized recommendations',
                    'Get AI-powered tool suggestions based on your assessment',
                  ),
                  const SizedBox(height: 12),
                  
                  _buildNextStepItem(
                    context,
                    Icons.trending_up,
                    'Adaptive learning',
                    'Tools that adjust to your progress and learning style',
                  ),
                  const SizedBox(height: 12),
                  
                  _buildNextStepItem(
                    context,
                    Icons.insights,
                    'Progress tracking',
                    'Monitor your improvement over time with detailed insights',
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Font recommendation (only show if user has visual challenges)
          if (_shouldRecommendDyslexicFont()) ...[
            _buildFontRecommendationCard(),
            const SizedBox(height: 24),
          ],
          
          // Error message
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red[700]),
                    ),
                  ),
                ],
              ),
            ),
          
          // Assessment summary
          if (widget.selectedChallenges.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.insights,
                          color: Theme.of(context).primaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Your Focus Areas',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'We\'ll focus on ${widget.selectedChallenges.length} area${widget.selectedChallenges.length == 1 ? '' : 's'}:',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getRiskAssessment(widget.selectedChallenges.length),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: 32),
          
          // Start learning button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isCompleting ? null : _completeQuestionnaire,
              icon: _isCompleting 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.rocket_launch),
              label: Text(_isCompleting ? 'Setting up your profile...' : 'Start Learning Journey'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Encouragement message
          Center(
            child: Text(
              'Your AI learning assistant is ready to help!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextStepItem(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getRiskAssessment(int challengeCount) {
    if (challengeCount >= 8) {
      return 'We\'ll provide comprehensive support with advanced AI tools tailored to your needs.';
    } else if (challengeCount >= 4) {
      return 'We\'ll focus on targeted practice with AI-powered exercises for these specific areas.';
    } else if (challengeCount > 0) {
      return 'We\'ll provide gentle support and practice opportunities in these areas.';
    } else {
      return 'We\'ll help you build confidence and maintain strong reading skills.';
    }
  }
} 