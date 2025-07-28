import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';

import '../services/model_download_service.dart';
import '../utils/service_locator.dart';
import '../widgets/fun_loading_widget.dart';
import '../main.dart';
import 'questionnaire/questionnaire_flow.dart';

class ModelLoadingScreen extends StatefulWidget {
  const ModelLoadingScreen({super.key});

  @override
  State<ModelLoadingScreen> createState() => _ModelLoadingScreenState();
}

class _ModelLoadingScreenState extends State<ModelLoadingScreen>
    with TickerProviderStateMixin {
  
  final ModelDownloadService _modelDownloadService = GetIt.instance<ModelDownloadService>();

  double _loadingProgress = 0.0;
  String? _loadingError;
  String? _debugErrorDetails; // Add debug error details
  bool _isModelReady = false;
  bool _isInitializing = false;
  
  // Additional progress info for better UX
  String _progressText = '';
  String _downloadedInfo = '';
  
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
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
    _initModel();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(
      begin: 0.85,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
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

  Future<void> _initModel() async {
    developer.log('Starting model initialization...', name: 'dyslexic_ai.init');
    
    setState(() {
      _loadingProgress = 0.0;
      _loadingError = null;
      _isModelReady = false;
      _isInitializing = false;
    });

    // Use the original pattern - call downloadModelIfNeeded with callbacks
    await _modelDownloadService.downloadModelIfNeeded(
      onProgress: (progress) {
        if (!mounted) return;
        
        if (progress == -1.0) {
          // Signal to switch UI to model initialization mode
          developer.log('📱 UI switching to model initialization mode', name: 'dyslexic_ai.init');
          setState(() {
            _isInitializing = true;
            _loadingProgress = 1.0; // Show completed progress bar
          });
        } else if (progress >= 0.0 && progress <= 1.0) {
          // Regular download progress
          final progressPercent = (progress * 100).toInt();
          developer.log('📱 UI received progress: $progressPercent%', name: 'dyslexic_ai.init');
          
          setState(() {
            _loadingProgress = progress;
            _isInitializing = false;
            _progressText = '$progressPercent%';
            
            // Note: We don't have detailed MB info in this callback, but that's OK
            // The background download still happens, we just show simpler progress
            _downloadedInfo = 'Downloading...';
          });
        }
      },
      onError: (error) async {
        if (!mounted) return;
        developer.log('Error from downloadModelIfNeeded: $error', name: 'dyslexic_ai.init.error');
        
        // Capture detailed debug information
        final status = _modelDownloadService.currentStatus;
        final downloadError = _modelDownloadService.downloadError;
        
        // Create debug details string
        final debugLog = await _modelDownloadService.getDebugLog();
        final debugDetails = '''
DEBUG INFO:
Status: $status
Raw Error: $error
Download Error: $downloadError
Progress: $_loadingProgress
Is Initializing: $_isInitializing
Model Ready: ${_modelDownloadService.isModelReady}

DEBUG LOG:
$debugLog
        '''.trim();
        
        // Provide user-friendly error message
        String errorMessage;
        switch (status) {
          case ModelStatus.notDownloaded:
          case ModelStatus.downloading:
            errorMessage = "Failed to download AI model. Please check your internet connection and try again.";
            break;
          case ModelStatus.downloadCompleted:
          case ModelStatus.initializing:
            errorMessage = "Downloaded successfully but failed to initialize. This may be due to device limitations. Try restarting the app or freeing up memory.";
            break;
          case ModelStatus.initializationFailed:
            errorMessage = "Model initialization failed. The file is ready but cannot be loaded right now. Try restarting the app or freeing up memory.";
            break;
          case ModelStatus.ready:
            errorMessage = "An unexpected error occurred: $error";
            break;
        }
        
        setState(() {
          _loadingError = errorMessage;
          _debugErrorDetails = debugDetails;
          _loadingProgress = 0.0;
          _isInitializing = false;
        });
      },
      onSuccess: () {
        if (!mounted) return;
        developer.log('Model ready, navigating to home', name: 'dyslexic_ai.init');
        setState(() {
          _isModelReady = true;
          _loadingProgress = 1.0;
          _loadingError = null;
          _isInitializing = false;
        });
        _navigateToHome();
      },
    );
  }

  void _navigateToHome() {
    if (mounted && _isModelReady) {
      developer.log("Model is ready, checking first-time user flow.", name: 'dyslexic_ai.navigation');
      _checkFirstTimeUser();
    }
  }

  Future<void> _checkFirstTimeUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasCompleted = prefs.getBool('has_completed_questionnaire') ?? false;
      
      if (!mounted) return;
      
      if (!hasCompleted) {
        developer.log("First-time user, navigating to questionnaire.", name: 'dyslexic_ai.navigation');
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const QuestionnaireFlow()),
          );
        }
      } else {
        developer.log("Returning user, navigating to MainApp.", name: 'dyslexic_ai.navigation');
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainApp()),
          );
        }
      }
    } catch (e) {
      developer.log("Error checking first-time user: $e", name: 'dyslexic_ai.navigation.error');
      // Fallback to main app on error
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainApp()),
        );
      }
    }
  }

  void _retryLoad() async {
    setState(() {
      _loadingError = null;
      _debugErrorDetails = null;
      _loadingProgress = 0.0;
      _isModelReady = false;
      _isInitializing = false;
    });
    
    // Just restart the download process - don't cancel/delete partial files
    _initModel();
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
        
        // Progress bar
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
                    Theme.of(context).primaryColor.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Progress percentage
        Text(
          _progressText.isNotEmpty ? _progressText : '0%',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        
        const SizedBox(height: 10),
        
        // Downloaded MB info
        Text(
          _downloadedInfo.isNotEmpty ? _downloadedInfo : 'Preparing download...',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 40),
        
        // Spinning icon for visual interest
        Container(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor.withValues(alpha: 0.3)),
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
    final iconColor = theme.colorScheme.primary.withValues(alpha: 0.5);

    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.1),
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
                ? // Error state
                Column(
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
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _loadingError!,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Debug details section
                      if (_debugErrorDetails != null) ...[
                        const SizedBox(height: 24),
                        ExpansionTile(
                          title: Text('Debug Details', 
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            )
                          ),
                          children: [
                            Container(
                              width: double.infinity,
                              height: 200, // Fixed height to enable scrolling
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: SingleChildScrollView(
                                child: SelectableText(
                                  _debugErrorDetails!,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _retryLoad,
                        child: const Text('Try Again'),
                      ),
                    ],
                  )
                : _isInitializing
                  ? // Initialization phase: Show messages 
                    FunLoadingWidget(
                        title: 'Configuring your reading assistant',
                        messages: _getInitializingMessages(),
                        showProgress: true,
                        progressValue: null, // Indeterminate progress for initialization
                      )
                  : // Download phase: Show progress + MB info
                    _buildDownloadProgress(),
          ),
        ],
      ),
    );
  }
} 