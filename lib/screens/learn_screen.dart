import 'package:flutter/material.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learn & Practice'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Educational Activities',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Interactive learning activities to improve your reading skills',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
                children: [
                  _buildLearningCard(
                    context,
                    'Reading Coach',
                    'Practice reading with real-time feedback and pronunciation help',
                    Icons.mic_outlined,
                    '/reading_coach',
                    Colors.blue,
                    isRecommended: true,
                  ),
                  _buildLearningCard(
                    context,
                    'Story Mode',
                    'Interactive fill-in-the-blank stories with word pattern learning',
                    Icons.menu_book_outlined,
                    '/adaptive_story',
                    Colors.purple,
                  ),
                  _buildLearningCard(
                    context,
                    'Phonics Game',
                    'Match words to sounds and learn phoneme patterns',
                    Icons.games_outlined,
                    '/phonics_game',
                    Colors.orange,
                  ),
                  _buildLearningCard(
                    context,
                    'Sentence Fixer',
                    'Find and fix spelling or grammar mistakes in sentences',
                    Icons.search_outlined,
                    '/sentence_fixer',
                    Colors.deepPurple,
                  ),
                  _buildComingSoonCard(context),
                ],
              ),
              const SizedBox(height: 20),
              _buildLearningTips(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLearningCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    String route,
    Color color, {
    bool isRecommended = false,
  }) {
    return Card(
      elevation: isRecommended ? 4 : 2,
      child: Stack(
        children: [
          InkWell(
            onTap: () => Navigator.pushNamed(context, route),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 26,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isRecommended)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'RECOMMENDED',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComingSoonCard(BuildContext context) {
    return Card(
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add,
                size: 26,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Coming Soon',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'More learning activities are on the way!',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
                height: 1.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearningTips(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Learning Tips',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Start with activities that match your current level\n'
            '• Practice regularly for 10-15 minutes daily\n'
            '• Focus on one skill area before moving to the next\n'
            '• Check your progress to see improvement over time',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.blue[800],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
} 