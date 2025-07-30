import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:get_it/get_it.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import 'background_download_manager.dart';
import 'model_initializer.dart';
import 'model_validator.dart';

typedef DownloadProgressCallback = void Function(double progress);
typedef DownloadErrorCallback = void Function(String error);
typedef DownloadSuccessCallback = void Function();

enum ModelStatus {
  notDownloaded,
  downloading,
  downloadCompleted,
  initializing,
  ready,
  initializationFailed
}

class ModelDownloadService {
  final _dio = Dio();
  final _modelInitializer = ModelInitializer();
  final _modelValidator = ModelValidator();

  static const String _prefsKeyModelDownloaded = 'dyslexic_ai_model_downloaded';
  static const String _prefsKeyModelPath = 'dyslexic_ai_model_path';
  static const String _prefsKeyModelInitialized =
      'dyslexic_ai_model_initialized';
  static const String _modelFileName = 'gemma-3n-E2B-it-int4.task';

  bool isModelReady = false;
  String? downloadError;
  double downloadProgress = 0.0;
  ModelStatus _currentStatus = ModelStatus.notDownloaded;

  ModelDownloadService() {
    // Configure Dio for large file downloads
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(minutes: 30);
    _dio.options.sendTimeout = const Duration(minutes: 30);
    _dio.options.headers = {
      'Accept': '*/*',
      'User-Agent': 'Flutter-App-DyslexicAI/1.0',
    };

    developer.log('📚 ModelDownloadService initialized',
        name: 'dyslexic_ai.model_download');
    _logError('ModelDownloadService initialized');
  }

  // Simple error logging to file (works in release mode)
  Future<void> _logError(String message) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logFile = File('${directory.path}/dyslexic_ai_debug.log');
      final timestamp = DateTime.now().toIso8601String();
      await logFile.writeAsString('[$timestamp] $message\n', mode: FileMode.append);
    } catch (e) {
      // Ignore logging errors to prevent infinite loops
    }
  }
  
  // Get debug log contents (for troubleshooting)
  Future<String> getDebugLog() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logFile = File('${directory.path}/dyslexic_ai_debug.log');
      if (await logFile.exists()) {
        return await logFile.readAsString();
      }
      return 'No debug log found';
    } catch (e) {
      return 'Error reading debug log: $e';
    }
  }
  
  // Clear debug log
  Future<void> clearDebugLog() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logFile = File('${directory.path}/dyslexic_ai_debug.log');
      if (await logFile.exists()) {
        await logFile.delete();
      }
    } catch (e) {
      // Ignore errors
    }
  }

  /// Check if model file is downloaded and validated (but not necessarily initialized)
  Future<bool> isFileDownloaded() async {
    final prefs = await SharedPreferences.getInstance();
    final isDownloaded = prefs.getBool(_prefsKeyModelDownloaded) ?? false;
    final modelPath = prefs.getString(_prefsKeyModelPath);

    developer.log(
        '🔍 File download check - Downloaded: $isDownloaded, Path: $modelPath',
        name: 'dyslexic_ai.model_download');

    if (isDownloaded && modelPath != null) {
      // Use validator for proper file checking
      final isValid = await _modelValidator.isFileBasicallyValid(modelPath);
      developer.log('📁 Model file valid: $isValid',
          name: 'dyslexic_ai.model_download');
      return isValid;
    }

    return false;
  }

  /// Check if model is initialized in memory and ready for use
  Future<bool> isModelInitialized() async {
    final prefs = await SharedPreferences.getInstance();
    final isInitialized = prefs.getBool(_prefsKeyModelInitialized) ?? false;

    // Also check if model is registered in service locator
    final getIt = GetIt.instance;
    final hasRegisteredModel = getIt.isRegistered<InferenceModel>();

    final result = isInitialized && hasRegisteredModel && isModelReady;
    developer.log(
        '🔍 Model initialization check - Prefs: $isInitialized, ServiceLocator: $hasRegisteredModel, Ready: $isModelReady, Result: $result',
        name: 'dyslexic_ai.model_download');

    return result;
  }

  /// Check if model is fully ready (downloaded AND initialized)
  Future<bool> isModelAvailable() async {
    final downloaded = await isFileDownloaded();
    final initialized = await isModelInitialized();
    final result = downloaded && initialized;

    developer.log(
        '🔍 Model availability check - Downloaded: $downloaded, Initialized: $initialized, Available: $result',
        name: 'dyslexic_ai.model_download');

    return result;
  }

  /// Get current model status
  ModelStatus get currentStatus => _currentStatus;

  Future<String> _getModelFilePath() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory(path.join(appDir.path, 'models'));

    if (!modelDir.existsSync()) {
      await modelDir.create(recursive: true);
      developer.log('📁 Created models directory: ${modelDir.path}',
          name: 'dyslexic_ai.model_download');
    }

    final modelPath = path.join(modelDir.path, _modelFileName);
    developer.log('📍 Model path: $modelPath',
        name: 'dyslexic_ai.model_download');
    return modelPath;
  }

  /// Attempt model initialization using the new ModelInitializer with retry logic
  /// This method handles initialization failures properly without deleting files
  Future<void> _attemptModelInitialization(
    DownloadProgressCallback? onProgress,
    DownloadErrorCallback? onError,
    DownloadSuccessCallback? onSuccess,
  ) async {
    try {
      developer.log('🚀 Starting model initialization phase...',
          name: 'dyslexic_ai.model_download');

      _currentStatus = ModelStatus.initializing;

      // Signal UI to switch to circular progress for model initialization
      onProgress?.call(-1.0);

      final modelPath = await _getModelFilePath();

      // Use the new ModelInitializer with retry logic
      final result =
          await _modelInitializer.initializeModelWithRetry(modelPath);

      if (result.success) {
        // Initialization successful
        _currentStatus = ModelStatus.ready;
        isModelReady = true;
        downloadProgress = 1.0;

        // Mark as initialized in preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefsKeyModelInitialized, true);

        onProgress?.call(1.0);
        onSuccess?.call();
        developer.log(
            '🎉 Model initialization completed successfully after ${result.attemptNumber} attempts!',
            name: 'dyslexic_ai.model_download');
      } else {
        // Initialization failed after all retries
        _currentStatus = ModelStatus.initializationFailed;

        // CRITICAL: Do NOT delete the file - it's valid, just can't initialize right now
        developer.log(
            '❌ Model initialization failed after all attempts: ${result.error}',
            name: 'dyslexic_ai.model_download');
        developer.log('📁 File preserved - user can retry later or restart app',
            name: 'dyslexic_ai.model_download');

        final errorString =
            'Model initialization failed. The file is downloaded but cannot be loaded right now. '
            'This may be due to device limitations. Try restarting the app or freeing up memory.';
        downloadError = errorString;
        await _logError('INITIALIZATION_FAILED: $errorString. Details: ${result.error}');
        onError?.call(errorString);
      }
    } catch (e) {
      _currentStatus = ModelStatus.initializationFailed;
      final errorString = 'Error during model initialization: $e';
      developer.log('❌ $errorString', name: 'dyslexic_ai.model_download');
      downloadError = errorString;
      await _logError('INITIALIZATION_EXCEPTION: $errorString');
      onError?.call(errorString);
    }
  }

  Future<void> downloadModelIfNeeded({
    DownloadProgressCallback? onProgress,
    DownloadErrorCallback? onError,
    DownloadSuccessCallback? onSuccess,
  }) async {
    try {
      developer.log('🚀 Starting model download process...',
          name: 'dyslexic_ai.model_download');

      downloadError = null;
      downloadProgress = 0.0;
      onProgress?.call(0.0);

      // Check current status using separated checks
      final fileDownloaded = await isFileDownloaded();
      final modelInitialized = await isModelInitialized();

      if (fileDownloaded && modelInitialized) {
        // Model is fully ready
        developer.log('✅ Model already fully available',
            name: 'dyslexic_ai.model_download');
        _currentStatus = ModelStatus.ready;
        isModelReady = true;
        downloadProgress = 1.0;
        onProgress?.call(1.0);
        onSuccess?.call();
        return;
      } else if (fileDownloaded && !modelInitialized) {
        // File exists but not initialized - try initialization only
        developer.log(
            '✅ Model file downloaded but not initialized, attempting initialization...',
            name: 'dyslexic_ai.model_download');
        await _attemptModelInitialization(onProgress, onError, onSuccess);
        return;
      }

      // If we reach here, a download is needed.
      _currentStatus = ModelStatus.downloading;
      final getIt = GetIt.instance;
      final backgroundDownloadManager = getIt<BackgroundDownloadManager>();

      // This is now a fire-and-forget call.
      // The UI will listen to the background manager's stream for progress.
      developer.log('🚀 Triggering background download manager...', name: 'dyslexic_ai.model_download');
      await backgroundDownloadManager.startOrResumeDownload();

    } catch (e, stackTrace) {
      final errorString = 'Model download failed: $e';
      developer.log(errorString,
          name: 'dyslexic_ai.model_download', error: e, stackTrace: stackTrace);
      downloadError = errorString;
      _currentStatus = ModelStatus.notDownloaded;
      onError?.call(errorString);
    }
  }

  /// Initialize existing model into memory (without download)
  /// Returns true if successful, false if failed
  Future<bool> initializeExistingModel() async {
    try {
      developer.log('🚀 Initializing existing model into memory...',
          name: 'dyslexic_ai.model_download');

      // Check if model file is downloaded
      if (!await isFileDownloaded()) {
        developer.log('❌ No model file available for initialization',
            name: 'dyslexic_ai.model_download');
        return false;
      }

      // Get the existing model path
      final prefs = await SharedPreferences.getInstance();
      final existingPath = prefs.getString(_prefsKeyModelPath);

      if (existingPath == null) {
        developer.log('❌ No model path found in preferences',
            name: 'dyslexic_ai.model_download');
        return false;
      }

      // Use the new ModelInitializer with retry logic
      final result =
          await _modelInitializer.initializeModelWithRetry(existingPath);

      if (result.success) {
        developer.log(
            '✅ Model initialized successfully into memory after ${result.attemptNumber} attempts',
            name: 'dyslexic_ai.model_download');

        // Mark as initialized in preferences
        await prefs.setBool(_prefsKeyModelInitialized, true);

        _currentStatus = ModelStatus.ready;
        isModelReady = true;
        return true;
      } else {
        developer.log(
            '❌ Failed to initialize model into memory: ${result.error}',
            name: 'dyslexic_ai.model_download');
        _currentStatus = ModelStatus.initializationFailed;
        return false;
      }
    } catch (e) {
      developer.log('❌ Error initializing existing model: $e',
          name: 'dyslexic_ai.model_download');
      _currentStatus = ModelStatus.initializationFailed;
      return false;
    }
  }

  Future<void> clearModelData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyModelDownloaded);
    await prefs.remove(_prefsKeyModelPath);
    await prefs.remove(_prefsKeyModelInitialized);

    // Clear validation cache
    await _modelValidator.clearValidationCache();

    // Reset initializer state
    _modelInitializer.reset();

    // Also try to delete the actual file
    try {
      final modelPath = await _getModelFilePath();
      final file = File(modelPath);
      if (file.existsSync()) {
        await file.delete();
        developer.log('🗑️ Deleted model file',
            name: 'dyslexic_ai.model_download');
      }
    } catch (e) {
      developer.log('⚠️ Error deleting model file: $e',
          name: 'dyslexic_ai.model_download');
    }

    _currentStatus = ModelStatus.notDownloaded;
    isModelReady = false;
    downloadProgress = 0.0;
    downloadError = null;
    developer.log('🧹 Model data cleared', name: 'dyslexic_ai.model_download');
  }
}
