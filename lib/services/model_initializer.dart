import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/core/model.dart';
import 'package:flutter_gemma/pigeon.g.dart';
import 'package:flutter_gemma/flutter_gemma_interface.dart';
import 'package:get_it/get_it.dart';

enum InitializationStatus {
  notStarted,
  inProgress,
  completed,
  failed,
  retrying
}

class InitializationResult {
  final bool success;
  final String? error;
  final InitializationStatus status;
  final int attemptNumber;

  const InitializationResult({
    required this.success,
    this.error,
    required this.status,
    required this.attemptNumber,
  });
}

class ModelInitializer {
  static const int maxRetries = 3;
  static const Duration baseDelay = Duration(seconds: 2);
  static const Duration maxDelay = Duration(seconds: 30);

  final _gemmaPlugin = FlutterGemmaPlugin.instance;

  int _currentAttempt = 0;
  InitializationStatus _status = InitializationStatus.notStarted;
  String? _lastError;

  InitializationStatus get status => _status;
  String? get lastError => _lastError;
  int get currentAttempt => _currentAttempt;

  /// Initialize model with retry logic and exponential backoff
  /// This method should NEVER delete files - it only handles memory initialization
  Future<InitializationResult> initializeModelWithRetry(
      String modelPath) async {
    developer.log('🚀 Starting model initialization with retry logic...',
        name: 'dyslexic_ai.model_initializer');

    _status = InitializationStatus.inProgress;
    _currentAttempt = 0;
    _lastError = null;

    // Validate file exists before attempting initialization
    final file = File(modelPath);
    if (!file.existsSync()) {
      const error =
          'Model file does not exist - this should not happen after download validation';
      developer.log('❌ $error', name: 'dyslexic_ai.model_initializer');
      _status = InitializationStatus.failed;
      _lastError = error;
      return InitializationResult(
        success: false,
        error: error,
        status: _status,
        attemptNumber: 0,
      );
    }

    final fileSize = await file.length();
    developer.log(
        '📊 Initializing model file: ${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB',
        name: 'dyslexic_ai.model_initializer');

    // Attempt initialization with retry logic
    for (_currentAttempt = 1;
        _currentAttempt <= maxRetries;
        _currentAttempt++) {
      try {
        developer.log('🔄 Initialization attempt $_currentAttempt/$maxRetries',
            name: 'dyslexic_ai.model_initializer');

        if (_currentAttempt > 1) {
          _status = InitializationStatus.retrying;
        }

        final success = await _attemptInitialization(modelPath);

        if (success) {
          _status = InitializationStatus.completed;
          developer.log(
              '✅ Model initialization successful on attempt $_currentAttempt',
              name: 'dyslexic_ai.model_initializer');

          return InitializationResult(
            success: true,
            status: _status,
            attemptNumber: _currentAttempt,
          );
        } else {
          _lastError =
              'Model initialization failed on attempt $_currentAttempt';
          developer.log('❌ $_lastError', name: 'dyslexic_ai.model_initializer');
        }
      } catch (e) {
        _lastError = 'Initialization attempt $_currentAttempt failed: $e';
        developer.log('❌ $_lastError', name: 'dyslexic_ai.model_initializer');
      }

      // Don't delay after the last attempt
      if (_currentAttempt < maxRetries) {
        final delay = _calculateBackoffDelay(_currentAttempt);
        developer.log(
            '⏳ Waiting ${delay.inSeconds}s before retry ${_currentAttempt + 1}',
            name: 'dyslexic_ai.model_initializer');
        await Future.delayed(delay);
      }
    }

    // All attempts failed
    _status = InitializationStatus.failed;
    final finalError =
        'Model initialization failed after $maxRetries attempts. Last error: $_lastError';
    developer.log('❌ $finalError', name: 'dyslexic_ai.model_initializer');

    return InitializationResult(
      success: false,
      error: finalError,
      status: _status,
      attemptNumber: _currentAttempt,
    );
  }

  /// Attempt a single initialization - this is the core logic from the original _setModelPathInFlutterGemma
  Future<bool> _attemptInitialization(String modelPath) async {
    try {
      developer.log('🔧 Setting model path in flutter_gemma: $modelPath',
          name: 'dyslexic_ai.model_initializer');

      // Get flutter_gemma model manager
      final modelManager = _gemmaPlugin.modelManager;
      developer.log(
          '📚 Got flutter_gemma model manager: ${modelManager.runtimeType}',
          name: 'dyslexic_ai.model_initializer');

      // Check current installation status
      final isCurrentlyInstalled = await modelManager.isModelInstalled;
      developer.log('📋 Current installation status: $isCurrentlyInstalled',
          name: 'dyslexic_ai.model_initializer');

      // Set the model path
      developer.log('⚙️ Calling setModelPath...',
          name: 'dyslexic_ai.model_initializer');
      await modelManager.setModelPath(modelPath);

      // Check if path was set successfully
      final isNowInstalled = await modelManager.isModelInstalled;
      developer.log(
          '✅ Model installation status after setModelPath: $isNowInstalled',
          name: 'dyslexic_ai.model_initializer');

      if (!isNowInstalled) {
        developer.log('❌ Model path setting failed',
            name: 'dyslexic_ai.model_initializer');
        return false;
      }

      // Now initialize the model for inference
      developer.log('🚀 Initializing model for inference...',
          name: 'dyslexic_ai.model_initializer');

      // Log device information for GPU debugging
      if (Platform.isAndroid) {
        developer.log('📱 Platform: Android',
            name: 'dyslexic_ai.model_initializer');
      } else if (Platform.isIOS) {
        developer.log('📱 Platform: iOS',
            name: 'dyslexic_ai.model_initializer');
      }

      final inferenceModel = await _createModelWithFallback();
      if (inferenceModel != null) {
        developer.log('✅ Model initialized successfully for inference',
            name: 'dyslexic_ai.model_initializer');

        // Register the model with the service locator
        final getIt = GetIt.instance;
        if (getIt.isRegistered<InferenceModel>()) {
          getIt.unregister<InferenceModel>();
        }
        getIt.registerSingleton<InferenceModel>(inferenceModel);

        developer.log('✅ Model registered successfully',
            name: 'dyslexic_ai.model_initializer');
        return true;
      } else {
        developer.log('❌ Model initialization returned null',
            name: 'dyslexic_ai.model_initializer');
        return false;
      }
    } catch (e) {
      developer.log('❌ Error during model initialization: $e',
          name: 'dyslexic_ai.model_initializer');
      return false;
    }
  }

  /// Create model with GPU/CPU fallback - extracted from original code
  Future<InferenceModel?> _createModelWithFallback() async {
    try {
      developer.log('🎮 Attempting GPU delegate initialization...',
          name: 'dyslexic_ai.model_initializer');
      final gpuModel = await _gemmaPlugin.createModel(
        modelType: ModelType.gemmaIt,
        preferredBackend: PreferredBackend.gpu,
        maxTokens: 2048,
        supportImage: true,
        maxNumImages: 1,
      );
      developer.log('✅ GPU delegate initialized successfully!',
          name: 'dyslexic_ai.model_initializer');
      return gpuModel;
    } catch (error) {
      developer.log('❌ GPU backend failed: $error',
          name: 'dyslexic_ai.model_initializer');
      developer.log('🔄 Falling back to CPU backend...',
          name: 'dyslexic_ai.model_initializer');
      try {
        final cpuModel = await _gemmaPlugin.createModel(
          modelType: ModelType.gemmaIt,
          preferredBackend: PreferredBackend.cpu,
          maxTokens: 2048,
          supportImage: true,
          maxNumImages: 1,
        );
        developer.log('✅ CPU delegate initialized successfully',
            name: 'dyslexic_ai.model_initializer');
        return cpuModel;
      } catch (cpuError) {
        developer.log('❌ CPU backend also failed: $cpuError',
            name: 'dyslexic_ai.model_initializer');
        return null;
      }
    }
  }

  /// Calculate exponential backoff delay with jitter
  Duration _calculateBackoffDelay(int attemptNumber) {
    final exponentialDelay = baseDelay * (1 << (attemptNumber - 1));
    final cappedDelay =
        exponentialDelay > maxDelay ? maxDelay : exponentialDelay;

    // Add small random jitter (±20%) to prevent thundering herd
    final jitterMs = (cappedDelay.inMilliseconds *
            0.2 *
            (DateTime.now().millisecondsSinceEpoch % 100) /
            100)
        .round();
    final jitteredDelay = Duration(
        milliseconds: cappedDelay.inMilliseconds +
            jitterMs -
            (cappedDelay.inMilliseconds * 0.1).round());

    return jitteredDelay;
  }

  /// Reset the initializer state (useful for clean retries)
  void reset() {
    _currentAttempt = 0;
    _status = InitializationStatus.notStarted;
    _lastError = null;
    developer.log('🔄 ModelInitializer reset',
        name: 'dyslexic_ai.model_initializer');
  }
}
