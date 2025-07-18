import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../controllers/word_doctor_store.dart';
import '../utils/service_locator.dart';
import '../utils/theme.dart';
import '../utils/input_validation_helper.dart';

class WordDoctorScreen extends StatefulWidget {
  const WordDoctorScreen({super.key});

  @override
  State<WordDoctorScreen> createState() => _WordDoctorScreenState();
}

class _WordDoctorScreenState extends State<WordDoctorScreen> {
  late WordDoctorStore _store;
  final TextEditingController _wordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _store = getIt<WordDoctorStore>();
  }

  void _onSubmit() {
    final wordToAnalyze = _wordController.text.trim();
    if (wordToAnalyze.isEmpty) {
      InputValidationHelper.showInputError(
        context,
        'Please enter a word to analyze. Type any word in the text field above.',
      );
      return;
    }
    
    _store.setInputWord(wordToAnalyze);
    _store.analyzeCurrentWord();
  }

  @override
  void dispose() {
    _wordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DyslexiaTheme.primaryBackground,
      appBar: AppBar(
        title: const Text('Word Doctor'),
        actions: [
          Observer(
            builder: (_) => IconButton(
              icon: const Icon(Icons.bookmark),
              onPressed: () => _showSavedWords(context),
              tooltip: 'Saved Words (${_store.savedWordsCount})',
            ),
          ),
          Observer(
            builder: (_) => IconButton(
              icon: const Icon(Icons.history),
              onPressed: () => _showRecentWords(context),
              tooltip: 'Recent Words (${_store.recentWordsCount})',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Input section - no Observer wrapper needed
          _buildWordInput(),
          
          // Results section - separate Observer for analysis results
          Expanded(
            child: Observer(
        builder: (_) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_store.errorMessage != null) _buildErrorMessage(),
              if (_store.isAnalyzing) _buildLoadingIndicator(),
              if (_store.hasCurrentAnalysis) ...[
                _buildAnalysisCard(),
                const SizedBox(height: 16),
                _buildSyllablesCard(),
                const SizedBox(height: 16),
                _buildMnemonicCard(),
                const SizedBox(height: 16),
                _buildExampleSentenceCard(),
                const SizedBox(height: 16),
                _buildActionButtons(),
              ],
            ],
          ),
        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordInput() {
    return Container(
      color: DyslexiaTheme.primaryBackground,
      child: Card(
        margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            const Text(
              'Enter a word to analyze',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _wordController,
              decoration: InputDecoration(
                hintText: 'Type a word here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _onSubmit,
                  ),
            ),
                onSubmitted: (_) => _onSubmit(),
                    ),
                    const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: DyslexiaTheme.primaryAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                      ),
                      child: const Text(
                  'Analyze Word',
                  style: TextStyle(
                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            const SizedBox(height: 12),
            const Text(
              'Or scan a word from an image:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => _store.scanWordFromGallery(),
                icon: const Icon(Icons.photo_library),
                label: const Text('Select Image'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error, color: Colors.red.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _store.errorMessage!,
                style: TextStyle(
                  color: Colors.red.shade700,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _store.clearError,
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Analyzing word...',
              style: TextStyle(
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisCard() {
    final analysis = _store.currentAnalysis!;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
        padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    analysis.word.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: DyslexiaTheme.primaryAccent,
                    ),
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up),
                  onPressed: () => _store.speakWord(analysis.word),
                  tooltip: 'Speak word',
                    ),
                  ],
                ),
            const SizedBox(height: 8),
            Text(
              'Phonetic: ${analysis.phonemes.join(" ")}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyllablesCard() {
    final analysis = _store.currentAnalysis!;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
        padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
              'Syllables',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
              'Tap each syllable to hear it spoken:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
                    ),
                    const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: analysis.syllables.asMap().entries.map((entry) {
                final index = entry.key;
                final syllable = entry.value;
                final phoneme = index < analysis.phonemes.length 
                    ? analysis.phonemes[index] 
                    : '';
                
                return GestureDetector(
                  onTap: () => _store.speakSyllable(syllable),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: DyslexiaTheme.primaryAccent.withOpacity(0.1),
                      border: Border.all(color: DyslexiaTheme.primaryAccent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          syllable,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: DyslexiaTheme.primaryAccent,
                          ),
                        ),
                        if (phoneme.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            phoneme,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                    ),
                  ],
                      ],
              ),
            ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMnemonicCard() {
    final analysis = _store.currentAnalysis!;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Memory Trick',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              analysis.mnemonic,
              style: const TextStyle(
                fontSize: 16,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExampleSentenceCard() {
    final analysis = _store.currentAnalysis!;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.format_quote, color: DyslexiaTheme.primaryAccent),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Example Sentence',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up),
                  onPressed: () => _store.speakExampleSentence(analysis.exampleSentence),
                  tooltip: 'Read sentence aloud',
            ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              analysis.exampleSentence,
              style: const TextStyle(
                fontSize: 16,
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Observer(
      builder: (_) => Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _store.isCurrentWordSaved 
                  ? () => _store.removeSavedWord(_store.currentAnalysis!.word)
                  : _store.saveCurrentWord,
              icon: Icon(_store.isCurrentWordSaved ? Icons.bookmark : Icons.bookmark_border),
              label: Text(
                _store.isCurrentWordSaved ? 'Remove from Dictionary' : 'Save to Dictionary',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _store.isCurrentWordSaved 
                    ? Colors.red 
                    : DyslexiaTheme.primaryAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _store.clearCurrentAnalysis,
            icon: const Icon(Icons.refresh),
            label: const Text(
              'New Word',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSavedWords(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => _SavedWordsSheet(
          store: _store,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _showRecentWords(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => _RecentWordsSheet(
          store: _store,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class _SavedWordsSheet extends StatelessWidget {
  final WordDoctorStore store;
  final ScrollController scrollController;

  const _SavedWordsSheet({
    required this.store,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Saved Words (${store.savedWordsCount})',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: store.savedWords.isEmpty
                  ? const Center(
                      child: Text(
                        'No saved words yet.\nSave words to review them later!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: store.savedWords.length,
                      itemBuilder: (context, index) {
                        final word = store.savedWords[index];
                        return ListTile(
                          title: Text(
                            word.word,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            word.syllables.join('-'),
                            style: const TextStyle(
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.volume_up),
                                onPressed: () => store.speakWord(word.word),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => store.removeSavedWord(word.word),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            store.reAnalyzeWord(word);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentWordsSheet extends StatelessWidget {
  final WordDoctorStore store;
  final ScrollController scrollController;

  const _RecentWordsSheet({
    required this.store,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Recent Words (${store.recentWordsCount})',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
            ),
                  ),
                  if (store.recentWords.isNotEmpty)
                    TextButton(
                      onPressed: store.clearRecentWords,
                      child: const Text(
                        'Clear All',
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: store.recentWords.isEmpty
                  ? const Center(
                      child: Text(
                        'No recent words yet.\nAnalyze words to see them here!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: store.recentWords.length,
                      itemBuilder: (context, index) {
                        final word = store.recentWords[index];
                        return ListTile(
                          title: Text(
                            word.word,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            word.syllables.join('-'),
                            style: const TextStyle(
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (word.isSaved)
                                const Icon(Icons.bookmark, color: DyslexiaTheme.primaryAccent),
                              IconButton(
                                icon: const Icon(Icons.volume_up),
                                onPressed: () => store.speakWord(word.word),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            store.reAnalyzeWord(word);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
} 