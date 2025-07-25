import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../../main.dart';
import 'welcome_intro_screen.dart';
import 'name_entry_screen.dart';
import 'assessment_questions_screen.dart';
import 'results_screen.dart';

class QuestionnaireFlow extends StatefulWidget {
  const QuestionnaireFlow({super.key});

  @override
  State<QuestionnaireFlow> createState() => _QuestionnaireFlowState();
}

class _QuestionnaireFlowState extends State<QuestionnaireFlow> with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _progressController;
  late final Animation<double> _progressAnimation;
  
  int _currentPage = 0;
  String _userName = '';
  List<String> _selectedChallenges = [];

  @override
  void initState() {
    super.initState();
    try {
      developer.log('🧠 Initializing QuestionnaireFlow...', name: 'dyslexic_ai.questionnaire');
      
      _pageController = PageController();
      _progressController = AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      );
      _progressAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeInOut,
      ));
      
      developer.log('🧠 QuestionnaireFlow initialized successfully', name: 'dyslexic_ai.questionnaire');
    } catch (e, stackTrace) {
      developer.log('❌ Failed to initialize QuestionnaireFlow: $e', name: 'dyslexic_ai.questionnaire', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      setState(() => _currentPage++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _updateProgress();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() => _currentPage--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _updateProgress();
    }
  }

  void _updateProgress() {
    final progress = (_currentPage + 1) / 4;
    _progressController.animateTo(progress);
  }

  void _onNameChanged(String name) {
    setState(() => _userName = name);
  }

  void _onChallengesChanged(List<String> challenges) {
    setState(() => _selectedChallenges = challenges);
  }

  @override
  Widget build(BuildContext context) {
    try {
      developer.log('🧠 Building QuestionnaireFlow, current page: $_currentPage', name: 'dyslexic_ai.questionnaire');
      
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              // Progress indicator
              _buildProgressHeader(),
              
              // Page content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(), // Disable swipe navigation
                  children: [
                    WelcomeIntroScreen(
                      onNext: _nextPage,
                    ),
                    NameEntryScreen(
                      initialName: _userName,
                      onNameChanged: _onNameChanged,
                      onNext: _nextPage,
                      onBack: _previousPage,
                    ),
                    AssessmentQuestionsScreen(
                      selectedChallenges: _selectedChallenges,
                      onChallengesChanged: _onChallengesChanged,
                      onNext: _nextPage,
                      onBack: _previousPage,
                    ),
                    ResultsScreen(
                      userName: _userName,
                      selectedChallenges: _selectedChallenges,
                      onComplete: () => _navigateToMainApp(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e, stackTrace) {
      developer.log('❌ Error building QuestionnaireFlow: $e', name: 'dyslexic_ai.questionnaire', error: e, stackTrace: stackTrace);
      
      // Return error screen instead of crashing
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Questionnaire Error',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'There was a problem loading the questionnaire. Please restart the app.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const MainApp()),
                    );
                  },
                  child: const Text('Skip to Main App'),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildProgressHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology_outlined,
                color: Theme.of(context).primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Learning Assessment',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const Spacer(),
              Text(
                '${_currentPage + 1} of 4',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return LinearProgressIndicator(
                value: _progressAnimation.value,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _navigateToMainApp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => 
        const MainApp() // Will add import later
      ),
    );
  }
} 