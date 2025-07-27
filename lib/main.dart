import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';
import 'screens/home_screen.dart';
import 'screens/learn_screen.dart';
import 'screens/tools_screen.dart';

import 'screens/settings_screen.dart';
import 'screens/reading_coach_screen.dart';
import 'screens/word_doctor_screen.dart';
import 'screens/adaptive_story_screen.dart';
import 'screens/phonics_game_screen.dart';


import 'screens/text_simplifier_screen.dart';
import 'screens/sentence_fixer_screen.dart';

import 'screens/model_loading_screen.dart';

import 'utils/theme.dart';
import 'utils/service_locator.dart';
import 'services/font_preference_service.dart';
import 'services/gemma_profile_update_service.dart';
import 'services/background_download_manager.dart';
import 'dart:developer' as developer;

@pragma('vm:entry-point')
void callbackDispatcher() {
  developer.log('🎯 WorkManager callback dispatcher initialized', name: 'dyslexic_ai.workmanager');
  
  Workmanager().executeTask((task, inputData) async {
    try {
      developer.log('🔧 Background task started: $task with data: $inputData', name: 'dyslexic_ai.workmanager');
      
      switch (task) {
        case 'model_download_task':
          developer.log('📥 Starting model download task execution', name: 'dyslexic_ai.workmanager');
          await _handleModelDownloadTask(inputData);
          developer.log('✅ Model download task completed successfully', name: 'dyslexic_ai.workmanager');
          break;
        default:
          developer.log('❓ Unknown background task: $task', name: 'dyslexic_ai.workmanager');
          return Future.value(false);
      }
      
      developer.log('✅ Background task completed: $task', name: 'dyslexic_ai.workmanager');
      return Future.value(true);
    } catch (e, stackTrace) {
      developer.log('❌ Background task failed: $task - $e\n$stackTrace', name: 'dyslexic_ai.workmanager');
      return Future.value(false);
    }
  });
}

Future<void> _handleModelDownloadTask(Map<String, dynamic>? inputData) async {
  try {
    // Initialize minimal services needed for download
    final downloadManager = BackgroundDownloadManager.instance;
    await downloadManager.initialize();
    
    // Check if model is already available before starting download
    if (await downloadManager.isModelAvailable()) {
      developer.log('✅ Model already available in background task, skipping download', name: 'dyslexic_ai.workmanager');
      return;
    }
    
    // Perform pure download (no task registration - worker only)
    developer.log('📥 Worker starting actual model download', name: 'dyslexic_ai.workmanager');
    await downloadManager.performActualDownload();
    
    developer.log('✅ Worker download task completed', name: 'dyslexic_ai.workmanager');
  } catch (e, stackTrace) {
    developer.log('❌ Background download failed: $e\n$stackTrace', name: 'dyslexic_ai.workmanager');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize WorkManager for background model downloads
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: kDebugMode, // Only enable debug in debug builds
  );
  developer.log('🎯 WorkManager initialized with debug mode: $kDebugMode', name: 'dyslexic_ai.workmanager');
  
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _profileUpdateService = getIt<GemmaProfileUpdateService>();
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
    
    // Note: Removed session warmup on app resume as it creates unnecessary sessions
    // Sessions are created on-demand when needed for better resource management
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
            '/sentence_fixer': (context) => const SentenceFixerScreen(),
      
      
    
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
