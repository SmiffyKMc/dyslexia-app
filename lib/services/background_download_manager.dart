import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../utils/resource_diagnostics.dart';

enum DownloadStatus {
  notStarted,
  partiallyDownloaded,  // Google's approach: separate state for partial files
  downloading,
  paused,
  completed,
  failed,
  initializing
}

class DownloadState {
  final DownloadStatus status;
  final double progress;
  final String? error;
  final int? totalBytes;
  final int? downloadedBytes;
  final DateTime? startTime;
  final DateTime? lastUpdate;

  const DownloadState({
    required this.status,
    required this.progress,
    this.error,
    this.totalBytes,
    this.downloadedBytes,
    this.startTime,
    this.lastUpdate,
  });

  factory DownloadState.initial() {
    return const DownloadState(
      status: DownloadStatus.notStarted,
      progress: 0.0,
    );
  }

  DownloadState copyWith({
    DownloadStatus? status,
    double? progress,
    String? error,
    int? totalBytes,
    int? downloadedBytes,
    DateTime? startTime,
    DateTime? lastUpdate,
  }) {
    return DownloadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error ?? this.error,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      startTime: startTime ?? this.startTime,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status.index,
      'progress': progress,
      'error': error,
      'totalBytes': totalBytes,
      'downloadedBytes': downloadedBytes,
      'startTime': startTime?.millisecondsSinceEpoch,
      'lastUpdate': lastUpdate?.millisecondsSinceEpoch,
    };
  }

  factory DownloadState.fromJson(Map<String, dynamic> json) {
    return DownloadState(
      status: DownloadStatus.values[json['status'] ?? 0],
      progress: (json['progress'] ?? 0.0).toDouble(),
      error: json['error'],
      totalBytes: json['totalBytes'],
      downloadedBytes: json['downloadedBytes'],
      startTime: json['startTime'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['startTime'])
          : null,
      lastUpdate: json['lastUpdate'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['lastUpdate'])
          : null,
    );
  }
}

class BackgroundDownloadManager {
  static const String _downloadStateKey = 'dyslexic_ai_download_state';
  static const String _modelFileName = 'gemma-3n-E2B-it-int4.task';
  static const String _modelUrl = 'https://kaggle-gemma3.b-cdn.net/gemma-3n-E2B-it-int4.task';
  static const String _backgroundTaskName = 'model_download_task';
  static const String _taskLockKey = 'dyslexic_ai_workmanager_lock';
  
  // Track last logged progress to avoid spam
  static double _lastLoggedProgress = -1;
  
  static BackgroundDownloadManager? _instance;
  static BackgroundDownloadManager get instance => _instance ??= BackgroundDownloadManager._();
  
  BackgroundDownloadManager._() {
    // DIAGNOSTIC: Register StreamController creation
    ResourceDiagnostics().registerStreamController('BackgroundDownloadManager', 'stateController', _stateController);
  }

  final _dio = Dio();
  final _stateController = StreamController<DownloadState>.broadcast();
  DownloadState _currentState = DownloadState.initial();
  CancelToken? _cancelToken;
  Timer? _progressTimer;
  int? _sessionStartBytes; // Bytes that existed when download session started

  Stream<DownloadState> get stateStream async* {
    // Immediately emit current state when someone subscribes
    yield _currentState;
    // Then emit all future state changes
    yield* _stateController.stream;
  }
  DownloadState get currentState => _currentState;

  Future<void> initialize() async {
    developer.log('🔄 Initializing BackgroundDownloadManager', name: 'dyslexic_ai.background_download');
    
    // Configure Dio for background downloads
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(hours: 2); // Long timeout for large files
    _dio.options.sendTimeout = const Duration(minutes: 5);
    _dio.options.headers = {
      'Accept': '*/*',
      'User-Agent': 'Flutter-App-DyslexicAI/1.0',
    };

    // Load previous download state
    await _loadState();
    
    // Check if model is already available and clean up background tasks
    if (await isModelAvailable()) {
      developer.log('✅ Model already available, cleaning up background tasks', name: 'dyslexic_ai.background_download');
      await _cancelBackgroundTask();
      // Update state to completed if it wasn't already
      if (_currentState.status != DownloadStatus.completed) {
        await _updateState(_currentState.copyWith(
          status: DownloadStatus.completed,
          progress: 1.0,
        ));
      }
    } else if (await isDownloadInProgress()) {
      // Check if there's an incomplete download to resume
      developer.log('🔄 Found incomplete download, resuming progress monitoring', name: 'dyslexic_ai.background_download');
      await _checkResumeDownload();
      
      // Start progress monitoring for UI updates since download is in progress
      _startProgressMonitoring();
    }

    developer.log('✅ BackgroundDownloadManager initialized', name: 'dyslexic_ai.background_download');
  }

  Future<void> startDownload() async {
    // Check if model is already available
    if (await isModelAvailable()) {
      developer.log('✅ Model already downloaded, skipping download', name: 'dyslexic_ai.background_download');
      await _updateState(_currentState.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
      ));
      // Cancel any existing background tasks since model is ready
      await _cancelBackgroundTask();
      return;
    }

    if (_currentState.status == DownloadStatus.downloading) {
      developer.log('⚠️ Download already in progress', name: 'dyslexic_ai.background_download');
      return;
    }

    developer.log('🚀 Starting background model download', name: 'dyslexic_ai.background_download');

    // Reset progress logging tracker
    _lastLoggedProgress = -1;

    // Register background task for native download continuation
    await _registerBackgroundTask();

    _cancelToken = CancelToken();
    await _updateState(_currentState.copyWith(
      status: DownloadStatus.downloading,
      startTime: DateTime.now(),
      error: null,
    ));

    try {
      final modelPath = await _getModelFilePath();
      final file = File(modelPath);
      
      // Ensure directory exists
      await file.parent.create(recursive: true);

      // Check if partial download exists
      int rangeStart = 0;
      if (file.existsSync()) {
        rangeStart = await file.length();
        developer.log('📁 Found partial download: ${rangeStart} bytes', name: 'dyslexic_ai.background_download');
      }

      // Set up range headers for resumable download
      final headers = <String, dynamic>{};
      if (rangeStart > 0) {
        headers['Range'] = 'bytes=$rangeStart-';
        developer.log('🔄 Resuming download from byte $rangeStart (Google AI Edge approach)', name: 'dyslexic_ai.background_download');
      }

      // GOOGLE'S APPROACH: More explicit HTTP response validation
      try {
        final response = await _dio.download(
          _modelUrl,
          modelPath,
          cancelToken: _cancelToken,
          options: Options(
            headers: headers,
            validateStatus: (status) {
              // Google accepts both HTTP_OK (200) and HTTP_PARTIAL (206)
              return status == 200 || status == 206;
            },
          ),
          deleteOnError: false, // Google's approach: preserve partial downloads
          onReceiveProgress: _onReceiveProgress,
        );
        
        developer.log('✅ HTTP ${response.statusCode}: Download completed successfully', name: 'dyslexic_ai.background_download');
      } catch (e) {
        if (e is DioException && e.response?.statusCode != null) {
          developer.log('❌ HTTP ${e.response!.statusCode}: ${e.message}', name: 'dyslexic_ai.background_download');
        }
        rethrow;
      }

      // Download completed successfully
      await _updateState(_currentState.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        lastUpdate: DateTime.now(),
      ));

      // Cancel background task since download is complete
      await _cancelBackgroundTask();

      developer.log('✅ Background download completed successfully', name: 'dyslexic_ai.background_download');

    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        developer.log('⏸️ Download cancelled by user', name: 'dyslexic_ai.background_download');
        await _updateState(_currentState.copyWith(
          status: DownloadStatus.paused,
          lastUpdate: DateTime.now(),
        ));
      } else {
        // Google's approach: Simple binary failure, let WorkManager handle retries
        developer.log('❌ Download failed: $e', name: 'dyslexic_ai.background_download');
        await _updateState(_currentState.copyWith(
          status: DownloadStatus.failed,
          error: 'Download failed: $e',
          lastUpdate: DateTime.now(),
        ));
      }
    }
  }

  Future<void> pauseDownload() async {
    if (_currentState.status != DownloadStatus.downloading) {
      return;
    }

    developer.log('⏸️ Pausing download', name: 'dyslexic_ai.background_download');
    _cancelToken?.cancel('User paused download');
    
    await _updateState(_currentState.copyWith(
      status: DownloadStatus.paused,
      lastUpdate: DateTime.now(),
    ));
  }

  Future<void> resumeDownload() async {
    if (_currentState.status != DownloadStatus.paused) {
      return;
    }

    developer.log('▶️ Resuming download', name: 'dyslexic_ai.background_download');
    await startDownload();
  }

  Future<void> cancelDownload() async {
    developer.log('❌ Cancelling download', name: 'dyslexic_ai.background_download');
    
    // Cancel background task
    await _cancelBackgroundTask();
    
    _cancelToken?.cancel('User cancelled download');
    _progressTimer?.cancel();

    // Delete partial download file and cached expected size
    try {
      final modelPath = await _getModelFilePath();
      final file = File(modelPath);
      if (file.existsSync()) {
        await file.delete();
        developer.log('🗑️ Deleted partial download file', name: 'dyslexic_ai.background_download');
      }
      
      // Clear cached expected size so it gets re-fetched
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('expected_model_size');
      developer.log('🧹 Cleared cached expected model size', name: 'dyslexic_ai.background_download');
    } catch (e) {
      developer.log('⚠️ Error deleting partial file: $e', name: 'dyslexic_ai.background_download');
    }

    await _updateState(DownloadState.initial());
  }

  /// Check if a download is currently in progress
  /// Simple logic: file exists + incomplete = download in progress
  Future<bool> isDownloadInProgress() async {
    // First check if model is already complete
    if (await isModelAvailable()) {
      return false;
    }
    
    // Check if there's a partial file
    final modelPath = await _getModelFilePath();
    final file = File(modelPath);
    
    if (!file.existsSync()) {
      developer.log('🔍 No download in progress - no file exists', 
                   name: 'dyslexic_ai.background_download');
      return false;
    }
    
    final actualSize = await file.length();
    final expectedSize = await _getExpectedModelSize();
    
    if (expectedSize == null || expectedSize <= 0) {
      developer.log('🔍 No download in progress - no expected size', 
                   name: 'dyslexic_ai.background_download');
      return false;
    }
    
    // Simple logic: if file exists and is incomplete, download is in progress
    final isIncomplete = actualSize > 0 && actualSize < expectedSize;
    
    developer.log('🔍 Download check: File ${(actualSize / (1024 * 1024)).toStringAsFixed(1)}MB/${(expectedSize / (1024 * 1024)).toStringAsFixed(1)}MB, incomplete: $isIncomplete', 
                 name: 'dyslexic_ai.background_download');
    
    if (isIncomplete) {
      // Update our state to match reality
      await _loadState(); // Refresh from SharedPreferences
      
      // If state doesn't match reality, update it
      if (_currentState.status != DownloadStatus.downloading) {
        await _updateState(_currentState.copyWith(
          status: DownloadStatus.downloading,
          progress: (actualSize / expectedSize).clamp(0.0, 1.0),
          downloadedBytes: actualSize,
          totalBytes: expectedSize,
        ));
      }
    }
    
    return isIncomplete;
  }

  Future<bool> isModelAvailable() async {
    try {
      final modelPath = await _getModelFilePath();
      final file = File(modelPath);
      
      if (!file.existsSync()) {
        return false;
      }

      // Google's approach: Trust file existence for basic availability check
      // Only do size validation if we have cached expected size (avoid HEAD request)
      final prefs = await SharedPreferences.getInstance();
      final expectedSize = prefs.getInt('expected_model_size');
      
      if (expectedSize == null) {
        // No cached size - trust file exists (more lenient for stability)
        final actualSize = await file.length();
        developer.log('📊 Model file exists (${(actualSize / (1024 * 1024)).toStringAsFixed(1)}MB) - trusting availability (no cached expected size)', 
                     name: 'dyslexic_ai.background_download');
        return actualSize > 1024 * 1024; // At least 1MB to avoid empty files
      }

      // We have cached expected size - do lenient validation (within 1% tolerance)
      final actualSize = await file.length();
      final tolerance = expectedSize * 0.01; // 1% tolerance
      final sizeDiff = (actualSize - expectedSize).abs();
      final isWithinTolerance = sizeDiff <= tolerance;
      
      developer.log('📊 Lenient size check - Expected: ${(expectedSize / (1024 * 1024)).toStringAsFixed(1)}MB, Actual: ${(actualSize / (1024 * 1024)).toStringAsFixed(1)}MB, Within 1% tolerance: $isWithinTolerance', 
                   name: 'dyslexic_ai.background_download');
      
      return isWithinTolerance;
    } catch (e) {
      developer.log('❌ Error checking model availability: $e', name: 'dyslexic_ai.background_download');
      return false;
    }
  }

  /// Get expected model size from server or cache
  Future<int?> _getExpectedModelSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // First try to get cached expected size
      final cachedSize = prefs.getInt('expected_model_size');
      if (cachedSize != null) {
        return cachedSize;
      }

      // If not cached, get from server via HEAD request
      developer.log('🔍 Getting expected model size from server...', name: 'dyslexic_ai.background_download');
      final response = await _dio.head(_modelUrl);
      final contentLength = response.headers.value('content-length');
      
      if (contentLength != null) {
        final serverSize = int.parse(contentLength);
        
        // Cache the expected size for future use
        await prefs.setInt('expected_model_size', serverSize);
        
        developer.log('📏 Server model size: ${(serverSize / (1024 * 1024)).toStringAsFixed(1)}MB (cached)', 
                     name: 'dyslexic_ai.background_download');
        
        return serverSize;
      } else {
        developer.log('❌ Server did not provide Content-Length header', name: 'dyslexic_ai.background_download');
        return null;
      }
    } catch (e) {
      developer.log('❌ Error getting expected model size: $e', name: 'dyslexic_ai.background_download');
      return null;
    }
  }

  void _onReceiveProgress(int received, int total) {
    if (total <= 0) return;

    final sessionStartBytes = _sessionStartBytes ?? 0;
    final actualReceived = sessionStartBytes + received;
    final actualTotal = _currentState.totalBytes!;
    final progress = actualReceived / actualTotal;
    final now = DateTime.now();

    // Simplified progress updates - only update every 1% to avoid killing WorkManager
    final progressPercent = (progress * 100).toInt();
    if (progressPercent > _lastLoggedProgress && progressPercent % 1 == 0) {
      _lastLoggedProgress = progressPercent.toDouble();
      
      // Update state much less frequently to keep WorkManager alive
      _updateState(_currentState.copyWith(
        progress: progress,
        downloadedBytes: actualReceived,
        totalBytes: actualTotal,
        lastUpdate: now,
      ));
      
      // Simple logging
      if (progressPercent % 5 == 0) {
        final receivedMB = (actualReceived / (1024 * 1024)).toStringAsFixed(1);
        final totalMB = (actualTotal / (1024 * 1024)).toStringAsFixed(1);
        developer.log('📥 Download: ${progressPercent}% (${receivedMB}/${totalMB}MB)', 
                     name: 'dyslexic_ai.background_download');
      }
    }
  }



  Future<void> _checkResumeDownload() async {
    try {
      final modelPath = await _getModelFilePath();
      final file = File(modelPath);
      
      if (file.existsSync()) {
        final currentSize = await file.length();
        developer.log('📁 Found partial download: ${(currentSize / (1024 * 1024)).toStringAsFixed(1)}MB', 
                     name: 'dyslexic_ai.background_download');
        
        // Update state with current progress
        await _updateState(_currentState.copyWith(
          status: DownloadStatus.paused,
          downloadedBytes: currentSize,
          progress: _currentState.totalBytes != null ? currentSize / _currentState.totalBytes! : 0.0,
        ));
      } else {
        // No partial download found, reset state
        await _updateState(DownloadState.initial());
      }
    } catch (e) {
      developer.log('❌ Error checking resume download: $e', name: 'dyslexic_ai.background_download');
      await _updateState(DownloadState.initial());
    }
  }

  Future<String> _getModelFilePath() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(path.join(appDir.path, 'models'));
    return path.join(modelsDir.path, _modelFileName);
  }

  Future<void> _updateState(DownloadState newState) async {
    _currentState = newState;
    _stateController.add(newState);
    await _saveState();
  }

  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateJson = jsonEncode(_currentState.toJson());
      await prefs.setString(_downloadStateKey, stateJson);
    } catch (e) {
      developer.log('❌ Error saving download state: $e', name: 'dyslexic_ai.background_download');
    }
  }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateString = prefs.getString(_downloadStateKey);
      
      if (stateString != null) {
        final stateJson = jsonDecode(stateString) as Map<String, dynamic>;
        _currentState = DownloadState.fromJson(stateJson);
        developer.log('📂 Loaded download state: ${_currentState.status}', name: 'dyslexic_ai.background_download');
      }
    } catch (e) {
      developer.log('❌ Error loading download state: $e', name: 'dyslexic_ai.background_download');
      _currentState = DownloadState.initial();
    }
  }

  // WorkManager Integration Methods
  
  /// Checks if model is available and cancels any unnecessary background tasks
  /// This should be called on app startup to clean up orphaned tasks
  Future<void> validateAndCleanupBackgroundTasks() async {
    if (await isModelAvailable()) {
      developer.log('🧹 Model available, cleaning up any orphaned background tasks', name: 'dyslexic_ai.workmanager');
      await _cancelBackgroundTask();
    }
    
    // CRITICAL: Validate state consistency between file and SharedPreferences
    await _validateStateConsistency();
  }

  /// Simplified state validation - only check file existence, trust cached state for stability
  Future<void> _validateStateConsistency() async {
    try {
      final modelPath = await _getModelFilePath();
      final file = File(modelPath);
      
      // Get actual file size (source of truth)
      final actualFileBytes = file.existsSync() ? await file.length() : 0;
      
      developer.log('🔍 Simple state validation - File: ${(actualFileBytes / (1024 * 1024)).toStringAsFixed(1)}MB', 
                   name: 'dyslexic_ai.background_download');
      
      if (actualFileBytes == 0) {
        // No file exists, reset to initial state
        developer.log('📁 No file found, resetting to initial state', name: 'dyslexic_ai.background_download');
        await _updateState(DownloadState.initial());
      } else {
        // File exists - trust it's valid and mark as partially downloaded for potential resume
        // This avoids network calls and complex validation that could cause instability
        developer.log('📁 File exists, marking as partiallyDownloaded for potential resume', name: 'dyslexic_ai.background_download');
        await _updateState(_currentState.copyWith(
          downloadedBytes: actualFileBytes,
          status: DownloadStatus.partiallyDownloaded,
        ));
      }
    } catch (e) {
      developer.log('❌ Error during simple state validation: $e', name: 'dyslexic_ai.background_download');
      // On error, just reset to initial state for stability
      await _updateState(DownloadState.initial());
    }
  }

  /// Register a background worker to handle download (worker-only, no foreground download)
  Future<void> startBackgroundDownload() async {
    if (await isModelAvailable()) {
      developer.log('✅ Model already downloaded, skipping background download', name: 'dyslexic_ai.background_download');
      await _updateState(_currentState.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
      ));
      return;
    }

    if (await isDownloadInProgress()) {
      developer.log('⚠️ Background download already in progress, not starting new one', name: 'dyslexic_ai.background_download');
      // Make sure progress monitoring is active
      if (_progressTimer == null) {
        _startProgressMonitoring();
      }
      return;
    }

    developer.log('🔧 Registering background download worker (no foreground download)', name: 'dyslexic_ai.background_download');
    
    // Reset progress tracking
    _lastLoggedProgress = -1;
    
    // Only register background task - no foreground download
    await _registerBackgroundTask();
    
    // Set state to show we're waiting for the worker
    await _updateState(_currentState.copyWith(
      status: DownloadStatus.downloading,
      startTime: DateTime.now(),
      error: null,
      progress: 0.0,
    ));
    
    // Start monitoring SharedPreferences for progress updates from background worker
    _startProgressMonitoring();
    
    // Google's approach: Trust WorkManager to handle progress updates
    developer.log('✅ Background worker registered, trusting WorkManager (Google AI Edge approach)', 
                 name: 'dyslexic_ai.background_download');
  }

  /// Monitor SharedPreferences for progress updates from background worker
  void _startProgressMonitoring() {
    developer.log('🔄 Starting file-based progress monitoring', 
                 name: 'dyslexic_ai.background_download');
    
    // Simple file-based progress monitoring every 2 seconds
    _progressTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        if (_currentState.status != DownloadStatus.downloading) {
          timer.cancel();
          _progressTimer = null;
          return;
        }

        final modelPath = await _getModelFilePath();
        final file = File(modelPath);
        
        if (file.existsSync()) {
          final actualSize = await file.length();
          final expectedSize = await _getExpectedModelSize();
          
          if (expectedSize != null && expectedSize > 0) {
            final realProgress = (actualSize / expectedSize).clamp(0.0, 1.0);
            
            // Only update if progress changed meaningfully
            if ((realProgress - _currentState.progress).abs() > 0.01) { // 1% threshold
              _currentState = _currentState.copyWith(
                progress: realProgress,
                downloadedBytes: actualSize,
                totalBytes: expectedSize,
                lastUpdate: DateTime.now(),
              );
              _stateController.add(_currentState);
            }
            
            // Check if download completed - require very close to 100% to ensure file is fully written
            if (realProgress >= 0.9995) {
              developer.log('✅ Download complete', name: 'dyslexic_ai.background_download');
              timer.cancel();
              _progressTimer = null;
              
              // Clear any task locks since download is complete
              try {
                final prefs = await SharedPreferences.getInstance();  
                await prefs.remove(_taskLockKey);
              } catch (e) {
                // Ignore cleanup errors
              }
              
              _currentState = _currentState.copyWith(
                status: DownloadStatus.completed,
                progress: 1.0,
              );
              _stateController.add(_currentState);
            }
          }
        }
      } catch (e) {
        developer.log('❌ Error monitoring progress: $e', name: 'dyslexic_ai.background_download');
      }
    });
    
    ResourceDiagnostics().registerTimer('BackgroundDownloadManager', 'progressTimer', _progressTimer!);
  }

  /// Pure download method for WorkManager - ONLY downloads, no task registration
  Future<void> performActualDownload() async {
    if (await isModelAvailable()) {
      developer.log('✅ Model already available in worker, marking complete', name: 'dyslexic_ai.background_download');
      await _updateState(_currentState.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
      ));
      return;
    }

    developer.log('📥 Worker performing actual model download', name: 'dyslexic_ai.background_download');

    try {
      final modelPath = await _getModelFilePath();
      final file = File(modelPath);
      
      // Ensure directory exists
      await file.parent.create(recursive: true);

      // STEP 1: Get ACTUAL file size (source of truth)
      int actualFileBytes = 0;
      if (file.existsSync()) {
        actualFileBytes = await file.length();
        developer.log('📁 ACTUAL file on disk: ${(actualFileBytes / (1024 * 1024)).toStringAsFixed(1)}MB', name: 'dyslexic_ai.background_download');
      } else {
        developer.log('📁 No existing file found - starting fresh download', name: 'dyslexic_ai.background_download');
      }

      // STEP 2: Get server file size from cache (avoid redundant HEAD requests for stability)
      final serverTotalBytes = await _getExpectedModelSize();
      if (serverTotalBytes == null) {
        developer.log('❌ CRITICAL: Cannot get expected model size from cache', name: 'dyslexic_ai.background_download');
        await _updateState(_currentState.copyWith(
          status: DownloadStatus.failed,
          error: 'Cannot determine expected file size',
        ));
        return;
      }
      
      developer.log('📏 Using cached model size: ${(serverTotalBytes / (1024 * 1024)).toStringAsFixed(1)}MB (avoiding redundant HEAD request)', 
                   name: 'dyslexic_ai.background_download');

      // STEP 3: Simple file check (following Google's approach - trust files more)
      if (actualFileBytes > 0) {
        if (actualFileBytes >= serverTotalBytes) {
          developer.log('🎉 File already complete!', name: 'dyslexic_ai.background_download');
          await _updateState(_currentState.copyWith(
            status: DownloadStatus.completed,
            progress: 1.0,
            downloadedBytes: actualFileBytes,
            totalBytes: serverTotalBytes,
          ));
          return;
        }
        
        developer.log('📁 Partial file found - will resume download', name: 'dyslexic_ai.background_download');
      }

      // STEP 4: Calculate ACTUAL progress based on file reality
      final actualProgress = actualFileBytes > 0 ? actualFileBytes / serverTotalBytes : 0.0;
      
      if (actualFileBytes > 0) {
        developer.log('📊 RESUMING from ${(actualProgress * 100).toInt()}% - File: ${(actualFileBytes / (1024 * 1024)).toStringAsFixed(1)}MB / Server: ${(serverTotalBytes / (1024 * 1024)).toStringAsFixed(1)}MB', 
                     name: 'dyslexic_ai.background_download');
      } else {
        developer.log('📊 STARTING fresh download - Server: ${(serverTotalBytes / (1024 * 1024)).toStringAsFixed(1)}MB', 
                     name: 'dyslexic_ai.background_download');
      }

      // STEP 5: Set session start bytes and reset progress tracking
      _sessionStartBytes = actualFileBytes; // Store the file size at session start
      _lastLoggedProgress = -1;
      
      developer.log('🎯 Session started with ${(actualFileBytes / (1024 * 1024)).toStringAsFixed(1)}MB existing', 
                   name: 'dyslexic_ai.background_download');
      
      await _updateState(_currentState.copyWith(
        status: DownloadStatus.downloading,
        startTime: DateTime.now(),
        error: null,
        progress: actualProgress,
        downloadedBytes: actualFileBytes, // ACTUAL file size, not cached
        totalBytes: serverTotalBytes,     // ACTUAL server size, not cached
      ));

      // STEP 6: Set up range headers for resumable download (if needed)
      _cancelToken = CancelToken();
      final headers = <String, dynamic>{};
      if (actualFileBytes > 0) {
        headers['Range'] = 'bytes=$actualFileBytes-';
        developer.log('📡 Using Range header: bytes=$actualFileBytes-', name: 'dyslexic_ai.background_download');
      }

      // STEP 7: Start the download (PURE DOWNLOAD - no task registration)
      try {
        final response = await _dio.download(
          _modelUrl,
          modelPath,
          cancelToken: _cancelToken,
          options: Options(
            headers: headers,
            validateStatus: (status) {
              // Google accepts both HTTP_OK (200) and HTTP_PARTIAL (206)
              return status == 200 || status == 206;
            },
          ),
          deleteOnError: false, // Google's approach: preserve partial downloads
          onReceiveProgress: _onReceiveProgress,
        );
        
        developer.log('✅ Worker HTTP ${response.statusCode}: Download completed successfully', name: 'dyslexic_ai.background_download');
      } catch (e) {
        if (e is DioException && e.response?.statusCode != null) {
          developer.log('❌ Worker HTTP ${e.response!.statusCode}: ${e.message}', name: 'dyslexic_ai.background_download');
        }
        rethrow;
      }

      // Download completed successfully
      _sessionStartBytes = null; // Reset session tracking
      await _updateState(_currentState.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        lastUpdate: DateTime.now(),
      ));

      developer.log('✅ Worker download completed successfully', name: 'dyslexic_ai.background_download');

    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        developer.log('⏸️ Worker download cancelled', name: 'dyslexic_ai.background_download');
        _sessionStartBytes = null; // Reset session tracking
        await _updateState(_currentState.copyWith(
          status: DownloadStatus.paused,
          lastUpdate: DateTime.now(),
        ));
      } else {
        // Google's approach: Simple binary failure, let WorkManager handle retries
        developer.log('❌ Worker download failed: $e', name: 'dyslexic_ai.background_download');
        _sessionStartBytes = null; // Reset session tracking
        await _updateState(_currentState.copyWith(
          status: DownloadStatus.failed,
          error: 'Download failed: $e',
          lastUpdate: DateTime.now(),
        ));
      }
    }
  }
  
  Future<void> _registerBackgroundTask() async {
    try {
      // Check if task registration is already in progress
      final prefs = await SharedPreferences.getInstance();
      final taskLockTime = prefs.getInt(_taskLockKey);
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // If lock exists and is less than 60 seconds old, don't register
      if (taskLockTime != null && (now - taskLockTime) < 60000) {
        developer.log('🔒 WorkManager task registration locked, skipping duplicate', name: 'dyslexic_ai.workmanager');
        return;
      }
      
      // Set lock to prevent duplicate registrations
      await prefs.setInt(_taskLockKey, now);
      
      // Cancel any existing task with the same name first
      try {
        await Workmanager().cancelByUniqueName(_backgroundTaskName);
        developer.log('🔧 Cancelled existing background task before registering new one', name: 'dyslexic_ai.workmanager');
      } catch (e) {
        // Ignore if no existing task to cancel
        developer.log('ℹ️ No existing task to cancel (this is normal): $e', name: 'dyslexic_ai.workmanager');
      }
      
      await Workmanager().registerOneOffTask(
        _backgroundTaskName,
        _backgroundTaskName,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false,  // Allow on low battery
          requiresCharging: false,       // Don't require charging
          requiresDeviceIdle: false,     // Don't require idle
          requiresStorageNotLow: false,  // Don't check storage
        ),
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: Duration(seconds: 30),
        initialDelay: Duration(seconds: 1),
        // Add this to try to keep task alive longer
        inputData: <String, dynamic>{
          'priority': 'high',
          'keep_alive': true,
        },
      );
      
      developer.log('🔧 Background download task registered with maximum flexibility', name: 'dyslexic_ai.workmanager');
      
      // Clear lock after successful registration
      await prefs.remove(_taskLockKey);
      
    } catch (e) {
      developer.log('❌ Failed to register background task: $e', name: 'dyslexic_ai.workmanager');
      
      // Clear lock on error
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_taskLockKey);
    }
  }
  
  Future<void> _cancelBackgroundTask() async {
    try {
      await Workmanager().cancelByUniqueName(_backgroundTaskName);
      developer.log('🔧 Background download task cancelled', name: 'dyslexic_ai.workmanager');
    } catch (e) {
      developer.log('❌ Failed to cancel background task: $e', name: 'dyslexic_ai.workmanager');
    }
  }



  void dispose() {
    _cancelToken?.cancel();
    _progressTimer?.cancel();
    ResourceDiagnostics().unregisterTimer('BackgroundDownloadManager', 'progressTimer');
    _stateController.close();
    ResourceDiagnostics().unregisterStreamController('BackgroundDownloadManager', 'stateController');
    developer.log('🧹 BackgroundDownloadManager disposed', name: 'dyslexic_ai.background_download');
  }
} 