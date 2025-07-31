import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'dart:isolate';
import 'dart:ui';
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
import 'services/profile_update_service.dart';
import 'dart:developer' as developer;
import 'package:permission_handler/permission_handler.dart';

// Flutter downloader callback - must be top level
@pragma('vm:entry-point')
void downloadCallback(String id, int status, int progress) {
  developer.log('📥 Download progress: $progress%', name: 'dyslexic_ai.flutter_download');
  
  final SendPort? send = IsolateNameServer.lookupPortByName('downloader_send_port');
  send?.send([id, status, progress]);
}

// Request notification permission for Android 13+ (API 33+)
Future<void> _requestNotificationPermission() async {
  try {
    // First check current status
    final PermissionStatus currentStatus = await Permission.notification.status;
    developer.log('📱 Current notification permission status: $currentStatus', 
        name: 'dyslexic_ai.permissions');
    
    if (currentStatus.isGranted) {
      developer.log('✅ Notification permission already granted', 
          name: 'dyslexic_ai.permissions');
      return;
    }
    
    // Request permission
    final PermissionStatus status = await Permission.notification.request();
    
    switch (status) {
      case PermissionStatus.granted:
        developer.log('✅ Notification permission granted', 
            name: 'dyslexic_ai.permissions');
        break;
      case PermissionStatus.denied:
        developer.log('❌ Notification permission denied - download progress notifications will not be shown', 
            name: 'dyslexic_ai.permissions');
        break;
      case PermissionStatus.permanentlyDenied:
        developer.log('🚫 Notification permission permanently denied - user needs to enable in settings', 
            name: 'dyslexic_ai.permissions');
        break;
      default:
        developer.log('❓ Notification permission status: $status', 
            name: 'dyslexic_ai.permissions');
    }
  } catch (e) {
    developer.log('⚠️ Error requesting notification permission: $e', 
        name: 'dyslexic_ai.permissions');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FlutterDownloader for background model downloads
  await FlutterDownloader.initialize(debug: kDebugMode);
  
  // Register the callback for progress updates
  FlutterDownloader.registerCallback(downloadCallback);
  
  developer.log('🎯 FlutterDownloader initialized with debug mode: $kDebugMode',
      name: 'dyslexic_ai.flutter_download');

  // Request notification permission for Android 13+ (API 33+)
  await _requestNotificationPermission();

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

class _DyslexiaAIAppState extends State<DyslexiaAIApp>
    with WidgetsBindingObserver {
  late final ProfileUpdateService _profileUpdateService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _profileUpdateService = getIt<ProfileUpdateService>();
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
    developer.log('App lifecycle state changed: $state',
        name: 'dyslexic_ai.main');
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
