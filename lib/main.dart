import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/tools_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/reading_coach_screen.dart';
import 'screens/word_doctor_screen.dart';
import 'screens/adaptive_story_screen.dart';
import 'screens/phonics_game_screen.dart';
import 'screens/word_confusion_screen.dart';
import 'screens/thought_to_word_screen.dart';
import 'screens/text_simplifier_screen.dart';
import 'screens/sound_it_out_screen.dart';
import 'screens/build_sentence_screen.dart';
import 'screens/read_aloud_screen.dart';
import 'screens/sound_focus_game_screen.dart';
import 'screens/visual_dictionary_screen.dart';
import 'screens/model_loading_screen.dart';
import 'screens/text_simplifier_example.dart';
import 'utils/theme.dart';
import 'utils/service_locator.dart';
import 'services/model_download_service.dart';
import 'services/font_preference_service.dart';
import 'dart:developer' as developer;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupLocator();
  
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  // Always show loading screen - it will handle both download and initialization
  runApp(const DyslexiaAIApp());
}

class DyslexiaAIApp extends StatelessWidget {
  const DyslexiaAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    final fontPreferenceService = getIt<FontPreferenceService>();
    
    return ValueListenableBuilder<String>(
      valueListenable: fontPreferenceService.fontNotifier,
      builder: (context, currentFont, child) {
        return MaterialApp(
          title: 'Dyslexia AI',
          theme: DyslexiaTheme.lightTheme(fontFamily: currentFont),
          home: const ModelLoadingScreen(),
          routes: {
            '/home': (context) => const HomeScreen(),
            '/tools': (context) => const ToolsScreen(),
            '/progress': (context) => const ProgressScreen(),
            '/settings': (context) => const SettingsScreen(),
            '/reading_coach': (context) => const ReadingCoachScreen(),
            '/word_doctor': (context) => const WordDoctorScreen(),
            '/adaptive_story': (context) => const AdaptiveStoryScreen(),
            '/phonics_game': (context) => const PhonicsGameScreen(),
            '/word_confusion': (context) => const WordConfusionScreen(),
            '/thought_to_word': (context) => const ThoughtToWordScreen(),
            '/text_simplifier': (context) => const TextSimplifierScreen(),
            '/sound_it_out': (context) => const SoundItOutScreen(),
            '/build_sentence': (context) => const BuildSentenceScreen(),
            '/read_aloud': (context) => const ReadAloudScreen(),
            '/sound_focus_game': (context) => const SoundFocusGameScreen(),
            '/visual_dictionary': (context) => const VisualDictionaryScreen(),
            '/text_simplifier_example': (context) => const TextSimplifierExample(),
          },
        );
      },
    );
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _currentIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: const [
          HomeScreen(),
          ToolsScreen(),
          ProgressScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.build),
            label: 'Tools',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Progress',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
