import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReadAloudScreen extends StatefulWidget {
  const ReadAloudScreen({super.key});

  @override
  State<ReadAloudScreen> createState() => _ReadAloudScreenState();
}

class _ReadAloudScreenState extends State<ReadAloudScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _isPlaying = false;
  bool _isPaused = false;
  double _speechRate = 1.0;
  bool _dyslexiaFriendlyFont = true;
  bool _wordHighlighting = true;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Read Aloud'),
        actions: [
          IconButton(
            onPressed: _showInfoDialog,
            icon: const Icon(Icons.info),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter text below and I\'ll read it aloud with '
                'dyslexia-friendly highlighting and pacing.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              
              // Text input section
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _handlePasteText,
                      icon: const Icon(Icons.paste),
                      label: const Text('Paste Text'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _handleClearText,
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              SizedBox(
                height: 150,
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  expands: true,
                  decoration: const InputDecoration(
                    hintText: 'Paste or type text here...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Reading controls section
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reading Controls',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Play/Pause/Stop buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildControlButton(
                            context,
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            _isPlaying ? 'Pause' : 'Play',
                            _textController.text.trim().isEmpty ? null : _handlePlayPause,
                          ),
                          _buildControlButton(
                            context,
                            Icons.stop,
                            'Stop',
                            _isPlaying || _isPaused ? _handleStop : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Speed control
                      Row(
                        children: [
                          Text(
                            'Speed: ${_speechRate.toStringAsFixed(1)}x',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Slider(
                              value: _speechRate,
                              min: 0.5,
                              max: 2.0,
                              divisions: 6,
                              onChanged: (value) {
                                setState(() {
                                  _speechRate = value;
                                });
                              },
                              activeColor: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Essential accessibility options
                      _buildAccessibilityOption(
                        'Dyslexia-Friendly Font',
                        _dyslexiaFriendlyFont,
                        (value) => setState(() => _dyslexiaFriendlyFont = value),
                        Icons.text_fields,
                      ),
                      _buildAccessibilityOption(
                        'Word Highlighting',
                        _wordHighlighting,
                        (value) => setState(() => _wordHighlighting = value),
                        Icons.highlight,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Text preview
              if (_textController.text.trim().isNotEmpty) ...[
                Text(
                  'Preview',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildTextPreview(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Read Aloud'),
        content: const Text(
          'This tool reads text aloud with dyslexia-friendly features:\n\n'
          '• Adjustable reading speed\n'
          '• Word highlighting during reading\n'
          '• Dyslexia-friendly font options\n'
          '• Easy play/pause/stop controls\n\n'
          'Paste or type your text, then tap "Play" to begin reading.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePasteText() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null) {
        setState(() {
          _textController.text = clipboardData!.text!;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to paste text: $e');
    }
  }

  void _handleClearText() {
    setState(() {
      _textController.clear();
      _isPlaying = false;
      _isPaused = false;
    });
  }

  Future<void> _handlePlayPause() async {
    if (_textController.text.trim().isEmpty) return;
    
    setState(() {
      if (_isPlaying) {
        _isPaused = true;
        _isPlaying = false;
      } else {
        _isPlaying = true;
        _isPaused = false;
      }
    });
    
    // TODO: Implement actual TTS functionality
    _showInfoSnackBar(_isPlaying ? 'Started reading' : 'Paused reading');
  }

  void _handleStop() {
    setState(() {
      _isPlaying = false;
      _isPaused = false;
    });
    
    // TODO: Implement actual TTS stop functionality
    _showInfoSnackBar('Stopped reading');
  }

  Widget _buildControlButton(BuildContext context, IconData icon, String label, VoidCallback? onPressed) {
    return Column(
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: FloatingActionButton(
            onPressed: onPressed,
            backgroundColor: onPressed != null 
                ? Theme.of(context).primaryColor 
                : Colors.grey[400],
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAccessibilityOption(String title, bool value, Function(bool) onChanged, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildTextPreview() {
    return Container(
      width: double.infinity,
      height: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: SingleChildScrollView(
        child: Text(
          _textController.text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            height: _dyslexiaFriendlyFont ? 1.8 : 1.4,
            letterSpacing: _dyslexiaFriendlyFont ? 1.0 : 0.0,
            fontFamily: _dyslexiaFriendlyFont ? 'OpenDyslexic' : null,
            backgroundColor: _wordHighlighting ? Colors.yellow.withValues(alpha: 0.3) : null,
          ),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
      ),
    );
  }
} 