import 'package:flutter/material.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Progress'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.share),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCurrentStreak(context),
              const SizedBox(height: 16),
              _buildMasteredWords(context),
              const SizedBox(height: 16),
              _buildPracticedPhonemes(context),
              const SizedBox(height: 16),
              _buildWeeklyActivity(context),
              const SizedBox(height: 16),
              _buildRecommendedNextSteps(context),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStreak(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Current Streak',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  'June 2025',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '12',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '12 Day Streak!',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Your longest streak: 21 days',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDayIndicator('M', true),
                _buildDayIndicator('T', true),
                _buildDayIndicator('W', true),
                _buildDayIndicator('T', true),
                _buildDayIndicator('F', true),
                _buildDayIndicator('S', true),
                _buildDayIndicator('S', false, isToday: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayIndicator(String day, bool completed, {bool isToday = false}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: completed 
          ? Colors.blue 
          : isToday 
            ? Colors.grey[300] 
            : Colors.transparent,
        shape: BoxShape.circle,
        border: isToday ? Border.all(color: Colors.blue, width: 2) : null,
      ),
      child: Center(
        child: Text(
          day,
          style: TextStyle(
            color: completed ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildMasteredWords(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Mastered Words',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Total: 83',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'This Week',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                const Text(
                  '24',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: 0.8,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 16),
            const Text(
              'Recently Mastered',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildWordChip('elephant'),
                _buildWordChip('mountain'),
                _buildWordChip('beautiful'),
                _buildWordChip('through'),
                _buildWordChip('thought'),
                _buildWordChip('because'),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () {},
                child: const Text('View all mastered words >'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordChip(String word) {
    return Chip(
      label: Text(word, style: const TextStyle(fontSize: 12)),
      backgroundColor: Colors.blue.withOpacity(0.1),
      side: BorderSide.none,
    );
  }

  Widget _buildPracticedPhonemes(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Most Practiced Phonemes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
              ],
            ),
            const SizedBox(height: 16),
            _buildPhonemeProgress('th', 'th sound', 42, 0.85),
            _buildPhonemeProgress('ch', 'ch sound', 36, 0.72),
            _buildPhonemeProgress('ou', 'ou sound', 28, 0.56),
            _buildPhonemeProgress('b/d', 'b/d confusion', 25, 0.5),
          ],
        ),
      ),
    );
  }

  Widget _buildPhonemeProgress(String sound, String description, int exercises, double progress) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                sound,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      description,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '$exercises exercises',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyActivity(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Weekly Activity',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                DropdownButton<String>(
                  value: 'Last 7 days',
                  underline: Container(),
                  items: const [
                    DropdownMenuItem(value: 'Last 7 days', child: Text('Last 7 days')),
                    DropdownMenuItem(value: 'Last 30 days', child: Text('Last 30 days')),
                  ],
                  onChanged: (value) {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildActivityBar('Mon', 0.3),
                  _buildActivityBar('Tue', 0.6),
                  _buildActivityBar('Wed', 0.4),
                  _buildActivityBar('Thu', 0.9),
                  _buildActivityBar('Fri', 0.7),
                  _buildActivityBar('Sat', 0.5),
                  _buildActivityBar('Sun', 0.6),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildActivityStat('Total time', '4h 25m'),
                _buildActivityStat('Daily average', '38m'),
                _buildActivityStat('Best day', 'Thu (1h 15m)'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityBar(String day, double height) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 20,
          height: 80 * height,
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildActivityStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildRecommendedNextSteps(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recommended Next Steps',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildRecommendationItem(
              Icons.psychology,
              'Practice b/d differentiation',
              'Based on your recent activity',
            ),
            const SizedBox(height: 12),
            _buildRecommendationItem(
              Icons.emoji_events,
              'Review recently mastered words',
              'Reinforce your learning',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.orange, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 