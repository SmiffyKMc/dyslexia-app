import 'package:flutter/material.dart';

class ReadAloudScreen extends StatelessWidget {
  const ReadAloudScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Read Aloud Tool'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.help_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.paste),
                        label: const Text('Paste Text'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Select Image'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 180,
                child: TextField(
                  maxLines: null,
                  expands: true,
                  decoration: const InputDecoration(
                    hintText: 'Paste or type text here...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Reading Controls',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: FloatingActionButton(
                      onPressed: () {},
                      backgroundColor: Theme.of(context).primaryColor,
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: FloatingActionButton(
                      onPressed: () {},
                      backgroundColor: Colors.grey[400],
                      child: const Icon(Icons.pause, color: Colors.white, size: 30),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: FloatingActionButton(
                      onPressed: () {},
                      backgroundColor: Colors.grey[400],
                      child: const Icon(Icons.stop, color: Colors.white, size: 30),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Reading Speed',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Slow',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Expanded(
                    child: Slider(
                      value: 1.0,
                      min: 0.5,
                      max: 2.0,
                      divisions: 6,
                      onChanged: (value) {},
                      activeColor: Theme.of(context).primaryColor,
                    ),
                  ),
                  Text(
                    'Fast',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '1.0x', 
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Voice',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: 'Natural Female Voice',
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Natural Female Voice', child: Text('Natural Female Voice')),
                  DropdownMenuItem(value: 'Natural Male Voice', child: Text('Natural Male Voice')),
                  DropdownMenuItem(value: 'Child-Friendly Voice', child: Text('Child-Friendly Voice')),
                ],
                onChanged: (value) {},
              ),
              const SizedBox(height: 24),
              Text(
                'Display Options',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _buildSwitchTile(
                context,
                'Dyslexia-Friendly Font',
                true,
                Icons.text_fields,
              ),
              _buildSwitchTile(
                context,
                'Increased Letter Spacing',
                true,
                Icons.space_bar,
              ),
              _buildSwitchTile(
                context,
                'High Contrast',
                false,
                Icons.contrast,
              ),
              _buildSwitchTile(
                context,
                'Word Highlighting',
                true,
                Icons.highlight,
              ),
              const SizedBox(height: 24),
              Text(
                'Text Preview',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                height: 150,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    'The quick brown fox jumps over '
                    'the lazy dog. This is a sample of '
                    'how your text will appear with '
                    'the current settings.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.8,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(BuildContext context, String title, bool value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Switch(
            value: value,
            onChanged: (value) {},
            activeColor: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }
} 