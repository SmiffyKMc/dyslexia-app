import 'package:flutter/material.dart';
import 'dart:developer' as developer;

import '../services/model_download_service.dart';
import '../main.dart';

class ModelLoadingScreen extends StatefulWidget {
  const ModelLoadingScreen({super.key});

  @override
  State<ModelLoadingScreen> createState() => _ModelLoadingScreenState();
}

class _ModelLoadingScreenState extends State<ModelLoadingScreen>
    with TickerProviderStateMixin {
  
  final ModelDownloadService _modelDownloadService = ModelDownloadService();

  double _loadingProgress = 0.0;
  String? _loadingError;
  bool _isModelReady = false;
  bool _isInitializing = false;
  
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
    });

    try {
      await _modelDownloadService.downloadModelIfNeeded(
        onProgress: (progress) {
          if (mounted) {
            if (progress == -1.0) {
              // Switch to initialization mode (circular progress)
              setState(() {
                _isInitializing = true;
                _loadingProgress = 0.8;
              });
              developer.log('Switching to model initialization mode', name: 'dyslexic_ai.init');
            } else {
              // Regular download progress (linear progress)
              setState(() => _loadingProgress = progress * 0.8);
              developer.log('Download progress: ${(progress * 100).toStringAsFixed(1)}%', name: 'dyslexic_ai.init');
            }
          }
        },
        onError: (error) {
          if (mounted) {
            developer.log('Error downloading model: $error', name: 'dyslexic_ai.init.error', error: error);
            setState(() {
              _loadingError = "Failed to download AI model. Please check your internet connection and try again.";
              _loadingProgress = 0.0;
            });
          }
        },
        onSuccess: () async {
          if (mounted) {
            developer.log('Model initialization completed successfully', name: 'dyslexic_ai.init');
            setState(() {
              _isModelReady = true;
              _loadingProgress = 1.0;
              _loadingError = null;
            });
            _navigateToHome();
          }
        },
      );
    } catch (e, stackTrace) {
      if (mounted) {
        final errorMsg = 'Unexpected error during model setup: $e';
        developer.log(errorMsg, name: 'dyslexic_ai.init.error', error: e, stackTrace: stackTrace);
        setState(() {
          _loadingError = "An unexpected error occurred. Please try again.";
        });
      }
    }
  }

  void _navigateToHome() {
    if (mounted && _isModelReady) {
      developer.log("Model is ready, navigating to MainApp.", name: 'dyslexic_ai.navigation');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainApp()),
      );
    }
  }

  void _retryLoad() {
    setState(() {
      _loadingError = null;
      _loadingProgress = 0.0;
      _isInitializing = false;
    });
    _initModel();
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
    final iconColor = theme.colorScheme.primary.withOpacity(0.5);

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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: size.width * 0.5,
                  height: size.width * 0.5,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary.withOpacity(0.08),
                        ),
                      ),
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          width: size.width * 0.4,
                          height: size.width * 0.4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary.withOpacity(0.15),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.school,
                              size: size.width * 0.2,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 50),
                
                Text(
                  _isInitializing ? 'Configuring your reading assistant' : 'Preparing your reading assistant',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                
                const SizedBox(height: 15),
                
                Text(
                  _loadingError ?? (_isInitializing 
                    ? 'Loading AI model into memory...'
                    : 'Setting up AI tools to help with reading and learning...'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: _loadingError != null
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                if (_loadingError == null)
                  _isInitializing
                    ? SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary,
                          ),
                        ),
                      )
                    : SizedBox(
                        width: size.width * 0.6,
                        child: LinearProgressIndicator(
                          value: _loadingProgress.clamp(0.0, 1.0),
                          backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary,
                          ),
                          minHeight: 6,
                        ),
                      ),
                
                if (_loadingError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: ElevatedButton(
                      onPressed: _retryLoad,
                      child: const Text('Try Again'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 