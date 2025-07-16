import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/learn_screen.dart';
import 'screens/tools_screen.dart';

import 'screens/settings_screen.dart';
import 'screens/reading_coach_screen.dart';
import 'screens/word_doctor_screen.dart';
import 'screens/adaptive_story_screen.dart';
import 'screens/phonics_game_screen.dart';


import 'screens/text_simplifier_screen.dart';
import 'screens/sound_it_out_screen.dart';

import 'screens/sentence_fixer_screen.dart';


import 'screens/model_loading_screen.dart';
import 'screens/text_simplifier_example.dart';
import 'utils/theme.dart';
import 'utils/service_locator.dart';
import 'services/font_preference_service.dart';
import 'services/gemma_profile_update_service.dart';
import 'services/global_session_manager.dart';
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

class DyslexiaAIApp extends StatefulWidget {
  const DyslexiaAIApp({super.key});

  @override
  State<DyslexiaAIApp> createState() => _DyslexiaAIAppState();
}

class _DyslexiaAIAppState extends State<DyslexiaAIApp> with WidgetsBindingObserver {
  late final GemmaProfileUpdateService _profileUpdateService;
  late final GlobalSessionManager _sessionManager;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _profileUpdateService = getIt<GemmaProfileUpdateService>();
    _sessionManager = getGlobalSessionManager();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _profileUpdateService.dispose();
    // Don't dispose global session manager - it should persist for app lifetime
    // GlobalSessionManager is a singleton that manages its own lifecycle
    // _sessionManager.dispose(); // ❌ Removed - causes premature disposal
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    developer.log('App lifecycle state changed: $state', name: 'dyslexic_ai.main');
    _profileUpdateService.handleAppLifecycleChange(state);
    
    // Handle session lifecycle based on app state
    if (state == AppLifecycleState.resumed) {
      // Warmup session when app resumes for better performance
      _sessionManager.warmupSession().catchError((e) {
        developer.log('Session warmup failed: $e', name: 'dyslexic_ai.main');
      });
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // Optional: Could invalidate session when app goes to background to save memory
      // _sessionManager.invalidateSession();
    }
  }

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
            '/learn': (context) => const LearnScreen(),
            '/tools': (context) => const ToolsScreen(),
      
            '/settings': (context) => const SettingsScreen(),
            '/reading_coach': (context) => const ReadingCoachScreen(),
            '/word_doctor': (context) => const WordDoctorScreen(),
            '/adaptive_story': (context) => const AdaptiveStoryScreen(),
            '/phonics_game': (context) => const PhonicsGameScreen(),


            '/text_simplifier': (context) => const TextSimplifierScreen(),
            '/sound_it_out': (context) => const SoundItOutScreen(),

            '/sentence_fixer': (context) => const SentenceFixerScreen(),
      
      
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
          LearnScreen(),
          ToolsScreen(),
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
            icon: Icon(Icons.school),
            label: 'Learn',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.build),
            label: 'Tools',
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
