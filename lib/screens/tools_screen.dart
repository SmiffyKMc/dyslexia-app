import 'package:flutter/material.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tools'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.9,
          children: [
            _buildToolCard(
              context,
              'Reading Coach',
              'Practice reading with real-time feedback',
              Icons.mic_outlined,
              '/reading_coach',
              Colors.blue,
            ),
            _buildToolCard(
              context,
              'Word Doctor',
              'Break down tricky words',
              Icons.search_outlined,
              '/word_doctor',
              Colors.green,
            ),
            _buildToolCard(
              context,
              'Story Mode',
              'Interactive reading stories',
              Icons.menu_book_outlined,
              '/adaptive_story',
              Colors.purple,
            ),
            _buildToolCard(
              context,
              'Phonics Game',
              'Fun sound-based games',
              Icons.games_outlined,
              '/phonics_game',
              Colors.orange,
            ),
            _buildToolCard(
              context,
              'Text Simplifier',
              'Make text easier to read',
              Icons.text_fields_outlined,
              '/text_simplifier',
              Colors.teal,
            ),
            _buildToolCard(
              context,
              'Text Simplifier AI Example',
              'Make text easier to read',
              Icons.text_fields_outlined,
              '/text_simplifier_example',
              Colors.teal,
            ),
            _buildToolCard(
              context,
              'Sound It Out',
              'Phonetic sound practice',
              Icons.volume_up_outlined,
              '/sound_it_out',
              Colors.red,
            ),
            _buildToolCard(
              context,
              'Build Sentence',
              'Sentence construction help',
              Icons.construction_outlined,
              '/build_sentence',
              Colors.indigo,
            ),
            _buildToolCard(
              context,
              'Read Aloud',
              'Text-to-speech with highlighting',
              Icons.record_voice_over_outlined,
              '/read_aloud',
              Colors.pink,
            ),
            _buildToolCard(
              context,
              'Thought to Word',
              'Express your thoughts clearly',
              Icons.psychology_outlined,
              '/thought_to_word',
              Colors.cyan,
            ),
            _buildToolCard(
              context,
              'Sound & Focus',
              'Concentration and memory games',
              Icons.headphones_outlined,
              '/sound_focus_game',
              Colors.brown,
            ),
            _buildToolCard(
              context,
              'Visual Dictionary',
              'Build your personal word collection',
              Icons.library_books_outlined,
              '/visual_dictionary',
              Colors.deepOrange,
            ),
            _buildToolCard(
              context,
              'Word Confusion',
              'Track challenging words',
              Icons.psychology_alt_outlined,
              '/word_confusion',
              Colors.amber,
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    String route,
    Color color,
  ) {
    return Card(
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, route),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 