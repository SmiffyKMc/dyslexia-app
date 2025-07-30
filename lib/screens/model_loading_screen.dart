import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';

import '../services/model_download_service.dart';
import '../services/background_download_manager.dart';
import '../widgets/fun_loading_widget.dart';
import '../main.dart';
import 'questionnaire/questionnaire_flow.dart';

class ModelLoadingScreen extends StatefulWidget {
  const ModelLoadingScreen({super.key});

  @override
  State<ModelLoadingScreen> createState() => _ModelLoadingLScreenState();
}

class _ModelLoadingLScreenState extends State<ModelLoadingScreen>
    with TickerProviderStateMixin {
  final ModelDownloadService _modelDownloadService =
      GetIt.instance<ModelDownloadService>();
  final BackgroundDownloadManager _backgroundDownloadManager =
      GetIt.instance<BackgroundDownloadManager>();

  StreamSubscription<DownloadState>? _downloadStateSubscription;

  double _loadingProgress = 0.0;
  String? _loadingError;
  bool _isModelReady = false;
  bool _isInitializing = false;
  String _progressText = '0%';
  String _downloadedInfo = 'Preparing...';

  late final AnimationController _pulseController;
  late final AnimationController _icon1Controller;
  late final AnimationController _icon2Controller;
  late final AnimationController _icon3Controller;
  late final Animation<double> _icon1Fade;
  late final Animation<Offset> _icon1Slide;
  late final Animation<double> _icon2Fade;
  late final Animation<Offset> _icon2Slide;
  late final Animation<double> _icon3Fade;
  late final Animation<Offset> _icon3Slide;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _subscribeToDownloadManager();
    _initiateModelCheck();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _icon1Controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat(reverse: true);
    
    _icon1Fade = Tween<double>(begin: 0.1, end: 0.4).animate(
      CurvedAnimation(parent: _icon1Controller, curve: Curves.easeInOut),
    );
    
    _icon1Slide = Tween<Offset>(
      begin: const Offset(0, -0.02),
      end: const Offset(0, 0.02),
    ).animate(CurvedAnimation(
      parent: _icon1Controller,
      curve: Curves.easeInOut,
    ));
    
    _icon2Controller = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat(reverse: true);
    
    _icon2Fade = Tween<double>(begin: 0.4, end: 0.1).animate(
      CurvedAnimation(parent: _icon2Controller, curve: Curves.easeInOut),
    );
    
    _icon2Slide = Tween<Offset>(
      begin: const Offset(0.01, 0),
      end: const Offset(-0.01, 0),
    ).animate(CurvedAnimation(
      parent: _icon2Controller,
      curve: Curves.easeInOut,
    ));
    
    _icon3Controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
    
    _icon3Fade = Tween<double>(begin: 0.2, end: 0.3).animate(
      CurvedAnimation(parent: _icon3Controller, curve: Curves.easeInOut),
    );
    
    _icon3Slide = Tween<Offset>(
      begin: const Offset(-0.01, 0.01),
      end: const Offset(0.01, -0.01),
    ).animate(CurvedAnimation(
      parent: _icon3Controller,
      curve: Curves.easeInOut,
    ));
  }

  void _subscribeToDownloadManager() {
    _downloadStateSubscription?.cancel();
    _downloadStateSubscription =
        _backgroundDownloadManager.stateStream.listen((state) {
      if (!mounted) return;

      setState(() {
        _loadingProgress = state.progress;
        _progressText = '${(state.progress * 100).toInt()}%';
        
        if (state.totalBytes != null && state.downloadedBytes != null) {
          final downloadedMB = (state.downloadedBytes! / (1024 * 1024)).toStringAsFixed(1);
          final totalMB = (state.totalBytes! / (1024 * 1024)).toStringAsFixed(1);
          _downloadedInfo = '$downloadedMB MB / $totalMB MB';
        } else {
          _downloadedInfo = 'Calculating size...';
        }

        switch (state.status) {
          case DownloadStatus.notStarted:
             _downloadedInfo = 'Starting download...';
            break;
          case DownloadStatus.downloading:
            _loadingError = null;
            _isInitializing = false;
            break;
          case DownloadStatus.completed:
            _loadingProgress = 1.0;
            _progressText = '100%';
            _startModelInitialization();
            break;
          case DownloadStatus.failed:
            _loadingError = state.error ?? 'An unknown download error occurred.';
            _isInitializing = false;
            break;
          case DownloadStatus.paused:
            _downloadedInfo = 'Download paused';
            break;
          default:
            break;
        }
      });
    });
  }
  
  void _initiateModelCheck() async {
    // Check if the model is already ready to go.
    if (await _modelDownloadService.isModelAvailable()) {
      setState(() {
         _isModelReady = true;
         _loadingProgress = 1.0;
      });
      _navigateToHome();
      return;
    }
    // If not, trigger the download process. The stream listener will handle UI updates.
    await _modelDownloadService.downloadModelIfNeeded();
  }

  void _startModelInitialization() {
    if (_isInitializing || _isModelReady) return;

    setState(() {
      _isInitializing = true;
    });

    _modelDownloadService.initializeExistingModel().then((success) {
      if (!mounted) return;
      if (success) {
        setState(() {
          _isModelReady = true;
        });
        _navigateToHome();
      } else {
        setState(() {
          _loadingError = "Failed to initialize the AI model. Please try restarting the app.";
          _isInitializing = false;
        });
      }
    });
  }

  void _retry() {
    setState(() {
      _loadingError = null;
      _loadingProgress = 0.0;
      _isModelReady = false;
      _isInitializing = false;
    });
    _backgroundDownloadManager.startOrResumeDownload();
  }
  
  void _navigateToHome() {
    if (mounted && _isModelReady) {
      developer.log("Model is ready, checking first-time user flow.",
          name: 'dyslexic_ai.navigation');
      _checkFirstTimeUser();
    }
  }

  Future<void> _checkFirstTimeUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasCompleted =
          prefs.getBool('has_completed_questionnaire') ?? false;

      if (!mounted) return;

      if (!hasCompleted) {
        developer.log("First-time user, navigating to questionnaire.",
            name: 'dyslexic_ai.navigation');
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const QuestionnaireFlow()),
          );
        }
      } else {
        developer.log("Returning user, navigating to MainApp.",
            name: 'dyslexic_ai.navigation');
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainApp()),
          );
        }
      }
    } catch (e) {
      developer.log("Error checking first-time user: $e",
          name: 'dyslexic_ai.navigation.error');
      // Fallback to main app on error
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainApp()),
        );
      }
    }
  }

  Widget _buildDownloadProgress() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Downloading AI Reading Assistant',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        Container(
          width: double.infinity,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _loadingProgress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withAlpha(200),
                  ],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _progressText,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _downloadedInfo,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor.withOpacity(0.3)),
          ),
        ),
      ],
    );
  }

  List<String> _getInitializingMessages() {
    return [
      "Loading AI model into memory...",
      "Optimizing performance settings...",
      "Finalizing system configuration...",
      "Preparing adaptive features...",
      "Testing model responsiveness...",
      "Completing initialization...",
      "Ready to start learning...",
    ];
  }

  @override
  void dispose() {
    developer.log("Disposing ModelLoadingScreen", name: 'dyslexic_ai.lifecycle');
    _downloadStateSubscription?.cancel();
    _pulseController.dispose();
    _icon1Controller.dispose();
    _icon2Controller.dispose();
    _icon3Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final iconColor = theme.colorScheme.primary.withAlpha(128);

    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withOpacity(0.1),
                  theme.colorScheme.surface,
                  theme.colorScheme.surface,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
          Positioned(
            top: size.height * 0.2,
            left: size.width * 0.15,
            child: SlideTransition(
              position: _icon1Slide,
              child: FadeTransition(
                opacity: _icon1Fade,
                child: Icon(
                  Icons.auto_stories,
                  size: 30,
                  color: iconColor,
                ),
              ),
            ),
          ),
          Positioned(
            top: size.height * 0.4,
            right: size.width * 0.1,
            child: SlideTransition(
              position: _icon2Slide,
              child: FadeTransition(
                opacity: _icon2Fade,
                child: Icon(
                  Icons.psychology,
                  size: 35,
                  color: iconColor,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: size.height * 0.2,
            left: size.width * 0.25,
            child: SlideTransition(
              position: _icon3Slide,
              child: FadeTransition(
                opacity: _icon3Fade,
                child: Icon(
                  Icons.lightbulb_outline,
                  size: 25,
                  color: iconColor,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(40.0),
            child: _loadingError != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 80,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Something went wrong',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _loadingError!,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _retry,
                        child: const Text('Try Again'),
                      ),
                    ],
                  )
                : _isInitializing
                    ? FunLoadingWidget(
                        title: 'Configuring your reading assistant',
                        messages: _getInitializingMessages(),
                        showProgress: true,
                        progressValue:
                            null, // Indeterminate progress for initialization
                      )
                    : _buildDownloadProgress(),
          ),
        ],
      ),
    );
  }
} 