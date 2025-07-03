import 'package:flutter/material.dart';

class VisualDictionaryScreen extends StatelessWidget {
  const VisualDictionaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visual Dictionary'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStats(),
            const SizedBox(height: 24),
            _buildCategories(),
            const SizedBox(height: 24),
            const Text(
              'Your Words',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _buildWordGrid(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: Colors.purple,
        child: const Icon(Icons.add_a_photo, color: Colors.white),
      ),
    );
  }

  Widget _buildStats() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: _buildStatItem('Total Words', '127', Colors.blue),
            ),
            Expanded(
              child: _buildStatItem('This Week', '8', Colors.green),
            ),
            Expanded(
              child: _buildStatItem('Mastered', '89', Colors.purple),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCategories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Categories',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildCategoryCard('Animals', '23', '🐾', Colors.orange),
              _buildCategoryCard('Food', '18', '🍎', Colors.red),
              _buildCategoryCard('School', '31', '📚', Colors.blue),
              _buildCategoryCard('Home', '25', '🏠', Colors.green),
              _buildCategoryCard('Actions', '19', '🏃', Colors.purple),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(String name, String count, String emoji, Color color) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            '$count words',
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordGrid() {
    final words = [
      {'word': 'elephant', 'image': '🐘', 'category': 'Animals', 'mastered': true},
      {'word': 'beautiful', 'image': '🌸', 'category': 'Descriptive', 'mastered': true},
      {'word': 'computer', 'image': '💻', 'category': 'Technology', 'mastered': false},
      {'word': 'butterfly', 'image': '🦋', 'category': 'Animals', 'mastered': true},
      {'word': 'rainbow', 'image': '🌈', 'category': 'Nature', 'mastered': false},
      {'word': 'library', 'image': '📚', 'category': 'Places', 'mastered': true},
    ];

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: words.length,
      itemBuilder: (context, index) {
        final word = words[index];
        return _buildWordCard(word);
      },
    );
  }

  Widget _buildWordCard(Map<String, dynamic> word) {
    final isMastered = word['mastered'] as bool;
    
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      word['category'] as String,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  Icon(
                    isMastered ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isMastered ? Colors.green : Colors.grey,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  word['image'] as String,
                  style: const TextStyle(fontSize: 48),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                word['word'] as String,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.volume_up, size: 16),
                      label: const Text('Play'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: Size.zero,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.edit, color: Colors.white, size: 16),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
} 