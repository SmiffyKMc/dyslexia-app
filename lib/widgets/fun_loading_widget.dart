import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

class FunLoadingWidget extends StatefulWidget {
  final String title;
  final List<String> messages;
  final Duration messageDuration;
  final bool showProgress;
  final double? progressValue;
  final Color? primaryColor;

  const FunLoadingWidget({
    super.key,
    required this.title,
    required this.messages,
    this.messageDuration = const Duration(seconds: 6),
    this.showProgress = true,
    this.progressValue,
    this.primaryColor,
  });

  @override
  State<FunLoadingWidget> createState() => _FunLoadingWidgetState();
}

class _FunLoadingWidgetState extends State<FunLoadingWidget>
    with TickerProviderStateMixin {
  int _currentMessageIndex = 0;
  Timer? _messageTimer;
  final Random _random = Random();
  
  late AnimationController _fadeController;
  late AnimationController _bounceController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _bounceAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticInOut,
    ));
    
    _fadeController.forward();
    _startMessageRotation();
  }

  void _startMessageRotation() {
    if (widget.messages.length <= 1) return;
    
    _messageTimer = Timer.periodic(widget.messageDuration, (timer) {
      if (mounted) {
        setState(() {
          _currentMessageIndex = (_currentMessageIndex + 1) % widget.messages.length;
        });
        
        // Add a little bounce when message changes
        _fadeController.reset();
        _fadeController.forward();
      }
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _fadeController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = widget.primaryColor ?? theme.colorScheme.primary;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Fun animated icon
          ScaleTransition(
            scale: _bounceAnimation,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withValues(alpha: 0.1),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                _getRandomIcon(),
                size: 40,
                color: primaryColor,
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Title
          Text(
            widget.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          // Rotating fun message
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Text(
                widget.messages[_currentMessageIndex],
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Progress indicator
          if (widget.showProgress)
            widget.progressValue != null
                ? // Linear progress bar
                SizedBox(
                    width: 200,
                    child: LinearProgressIndicator(
                      value: widget.progressValue,
                      backgroundColor: primaryColor.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      minHeight: 6,
                    ),
                  )
                : // Circular progress indicator
                SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      backgroundColor: primaryColor.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  ),
        ],
      ),
    );
  }

  IconData _getRandomIcon() {
    // Keep it simple with just the education icon
    return Icons.school;
  }
} 