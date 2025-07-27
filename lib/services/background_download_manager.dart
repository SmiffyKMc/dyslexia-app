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
    } else if (_currentState.status == DownloadStatus.downloading) {
      // Check if there's an incomplete download to resume
      developer.log('🔄 Found incomplete download, checking if resumable', name: 'dyslexic_ai.background_download');
      await _checkResumeDownload();
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
      }

      // Start the download
      await _dio.download(
        _modelUrl,
        modelPath,
        cancelToken: _cancelToken,
        options: Options(headers: headers),
        deleteOnError: false, // Don't delete partial downloads
        onReceiveProgress: _onReceiveProgress,
      );

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
        // Check if this is a network error that should be retried
        final shouldRetry = _shouldRetryError(e);
        
        if (shouldRetry) {
          developer.log('🔄 Network error detected, will retry: $e', name: 'dyslexic_ai.background_download');
          await _updateState(_currentState.copyWith(
            status: DownloadStatus.paused, // Paused state allows resume
            error: 'Connection interrupted, will retry...',
            lastUpdate: DateTime.now(),
          ));
          
          // Trigger retry after a short delay
          Future.delayed(const Duration(seconds: 3), () async {
            if (_currentState.status == DownloadStatus.paused) {
              developer.log('🔄 Retrying download after connection failure', name: 'dyslexic_ai.background_download');
              await startDownload();
            }
          });
        } else {
          developer.log('❌ Background download failed permanently: $e', name: 'dyslexic_ai.background_download');
          await _updateState(_currentState.copyWith(
            status: DownloadStatus.failed,
            error: 'Download failed: $e',
            lastUpdate: DateTime.now(),
          ));
        }
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

  Future<bool> isModelAvailable() async {
    try {
      final modelPath = await _getModelFilePath();
      final file = File(modelPath);
      
      if (!file.existsSync()) {
        return false;
      }

      // Get expected size from server (dynamic validation)
      final expectedSize = await _getExpectedModelSize();
      if (expectedSize == null) {
        developer.log('⚠️ No expected model size available, cannot validate', name: 'dyslexic_ai.background_download');
        return false;
      }

      // Check if file size matches server expectation exactly
      final actualSize = await file.length();
      final sizeMatch = actualSize == expectedSize;
      
      developer.log('📊 Size validation - Expected: ${(expectedSize / (1024 * 1024)).toStringAsFixed(1)}MB, Actual: ${(actualSize / (1024 * 1024)).toStringAsFixed(1)}MB, Match: $sizeMatch', 
                   name: 'dyslexic_ai.background_download');
      
      return sizeMatch;
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

    // CRITICAL FIX: Dio's 'received' is cumulative bytes for THIS download session
    // We need to add it to the bytes that existed BEFORE this session started
    // NOT to the current state (which gets updated during the session)
    
    // Get the file size that existed when this download session started
    final sessionStartBytes = _sessionStartBytes ?? 0;
    
    // Calculate actual total downloaded: pre-existing + this session
    final actualReceived = sessionStartBytes + received;
    
    // Use validated total from HEAD request
    final actualTotal = _currentState.totalBytes!;
    
    final progress = actualReceived / actualTotal;
    final now = DateTime.now();

    // Throttle state updates to every 1% to prevent excessive SharedPreferences writes
    final progressPercent = (progress * 100);
    final lastProgressPercent = (_currentState.progress ?? 0) * 100;
    
    if (progressPercent - lastProgressPercent >= 1.0) {
      _updateState(_currentState.copyWith(
        progress: progress,
        downloadedBytes: actualReceived,
        totalBytes: actualTotal,
        lastUpdate: now,
      ));
    }

    // Log progress only at 10% intervals for clean logs
    final currentTenPercent = (progressPercent / 10).floor() * 10;
    
    if (currentTenPercent > _lastLoggedProgress && currentTenPercent % 10 == 0) {
      _lastLoggedProgress = currentTenPercent.toDouble();
      final receivedMB = (actualReceived / (1024 * 1024)).toStringAsFixed(1);
      final totalMB = (actualTotal / (1024 * 1024)).toStringAsFixed(1);
      
      developer.log('📥 WORKER progress: ${currentTenPercent.toInt()}% ($receivedMB/$totalMB MB)', 
                   name: 'dyslexic_ai.background_download');
    }
  }

  /// Start periodic refresh to check for background worker progress updates
  void _startPeriodicRefresh() {
    _progressTimer?.cancel();
    ResourceDiagnostics().unregisterTimer('BackgroundDownloadManager', 'progressTimer');
    
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        // CRITICAL: Force SharedPreferences reload to sync across isolates
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload(); // Force reload from disk to get worker updates
        final stateString = prefs.getString(_downloadStateKey);
        
        developer.log('🔍 Periodic refresh - SharedPrefs: ${stateString?.length ?? 0} chars (after reload)', 
                     name: 'dyslexic_ai.background_download');
        
        if (stateString != null) {
          final stateJson = jsonDecode(stateString) as Map<String, dynamic>;
          final latestState = DownloadState.fromJson(stateJson);
          
          final currentProgress = (_currentState.progress ?? 0) * 100;
          final latestProgress = (latestState.progress) * 100;
          final progressDiff = (latestState.progress - (_currentState.progress ?? 0)).abs();
          final hasStatusChange = latestState.status != _currentState.status;
          
          developer.log('🔍 RAW JSON: ${stateString.substring(0, stateString.length > 100 ? 100 : stateString.length)}...', 
                       name: 'dyslexic_ai.background_download');
          developer.log('🔍 Progress check - Current: ${currentProgress.toInt()}%, Latest: ${latestProgress.toInt()}%, Diff: ${(progressDiff * 100).toInt()}%, Status change: $hasStatusChange', 
                       name: 'dyslexic_ai.background_download');
          
          // Update every 1% progress change or on any forward progress
          if (hasStatusChange || progressDiff >= 0.01 || latestProgress > currentProgress) {
            developer.log('🚀 Emitting UI update - Progress: ${latestProgress.toInt()}%, Downloaded: ${((latestState.downloadedBytes ?? 0) / (1024 * 1024)).toStringAsFixed(1)}MB', 
                         name: 'dyslexic_ai.background_download');
            
            _currentState = latestState;
            _stateController.add(latestState); // Emit to stream
            
            developer.log('✅ UI progress updated: ${latestProgress.toInt()}%', 
                         name: 'dyslexic_ai.background_download');
            
            // Stop periodic refresh if download is completed or failed
            if (latestState.status == DownloadStatus.completed || 
                latestState.status == DownloadStatus.failed) {
              timer.cancel();
              ResourceDiagnostics().unregisterTimer('BackgroundDownloadManager', 'progressTimer');
              developer.log('🔄 Periodic refresh stopped - download ${latestState.status}', 
                           name: 'dyslexic_ai.background_download');
            }
          } else {
            developer.log('⏸️ No significant change detected - skipping UI update', 
                         name: 'dyslexic_ai.background_download');
          }
        } else {
          developer.log('❌ No state found in SharedPreferences', name: 'dyslexic_ai.background_download');
          // DIAGNOSTIC: Track potential waste scenario
          ResourceDiagnostics().logMemoryPressureEvent('Null SharedPreferences state', 'BackgroundDownloadManager periodic refresh');
        }
      } catch (e) {
        developer.log('❌ Error during periodic refresh: $e', name: 'dyslexic_ai.background_download');
        // DIAGNOSTIC: Track error scenario
        ResourceDiagnostics().logMemoryPressureEvent('Periodic refresh error: $e', 'BackgroundDownloadManager');
      }
    });
    
    // DIAGNOSTIC: Register the timer
    ResourceDiagnostics().registerTimer('BackgroundDownloadManager', 'progressTimer', _progressTimer!);
    
    developer.log('🔄 Started periodic refresh every 1 second for UI updates', 
                 name: 'dyslexic_ai.background_download');
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

  /// CRITICAL: Validate that SharedPreferences state matches actual file reality
  Future<void> _validateStateConsistency() async {
    try {
      final modelPath = await _getModelFilePath();
      final file = File(modelPath);
      
      // Get actual file size (source of truth)
      final actualFileBytes = file.existsSync() ? await file.length() : 0;
      
      // Get cached state
      final cachedBytes = _currentState.downloadedBytes ?? 0;
      final cachedTotal = _currentState.totalBytes ?? 0;
      
      developer.log('🔍 State validation - File: ${(actualFileBytes / (1024 * 1024)).toStringAsFixed(1)}MB, Cached: ${(cachedBytes / (1024 * 1024)).toStringAsFixed(1)}MB', 
                   name: 'dyslexic_ai.background_download');
      
      // If there's a significant mismatch, reset state to match file reality
      final sizeDifference = (actualFileBytes - cachedBytes).abs();
      if (sizeDifference > 1024 * 1024) { // More than 1MB difference
        developer.log('⚠️ State inconsistency detected! Resetting state to match file reality.', name: 'dyslexic_ai.background_download');
        
        if (actualFileBytes == 0) {
          // No file exists, reset to initial state
          await _updateState(DownloadState.initial());
        } else {
          // File exists, need to validate with server
          try {
            final response = await _dio.head(_modelUrl);
            final contentLength = response.headers.value('content-length');
            if (contentLength != null) {
              final serverTotal = int.parse(contentLength);
              final progress = actualFileBytes / serverTotal;
              
              await _updateState(_currentState.copyWith(
                downloadedBytes: actualFileBytes,
                totalBytes: serverTotal,
                progress: progress,
                status: actualFileBytes >= serverTotal ? DownloadStatus.completed : DownloadStatus.paused,
              ));
              
              developer.log('✅ State corrected to match file reality: ${(progress * 100).toInt()}%', 
                           name: 'dyslexic_ai.background_download');
            }
          } catch (e) {
            developer.log('❌ Could not validate with server, keeping file but marking as paused: $e', 
                         name: 'dyslexic_ai.background_download');
            await _updateState(_currentState.copyWith(
              downloadedBytes: actualFileBytes,
              status: DownloadStatus.paused,
            ));
          }
        }
      } else {
        developer.log('✅ State consistency validated - file and cache match', name: 'dyslexic_ai.background_download');
      }
    } catch (e) {
      developer.log('❌ Error during state validation: $e', name: 'dyslexic_ai.background_download');
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

    if (_currentState.status == DownloadStatus.downloading) {
      developer.log('⚠️ Background download already in progress', name: 'dyslexic_ai.background_download');
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
    
    // Start periodic refresh to check for background worker progress
    _startPeriodicRefresh();
    
    // FALLBACK: If WorkManager doesn't start within 10 seconds, check and potentially start manually
    Timer(const Duration(seconds: 10), () async {
      if (_currentState.status == DownloadStatus.downloading && 
          _currentState.progress == 0.0 && 
          _currentState.downloadedBytes == 0) {
        developer.log('⚠️ FALLBACK: WorkManager task not started after 10s, checking manually', 
                     name: 'dyslexic_ai.background_download');
        
        // Check if the actual WorkManager task has started by checking if state has been updated
        if (_currentState.startTime?.isBefore(DateTime.now().subtract(Duration(seconds: 8))) ?? false) {
          developer.log('🚀 FALLBACK: Starting download directly since WorkManager is delayed', 
                       name: 'dyslexic_ai.background_download');
          // Start the download directly as a fallback
          await performActualDownload();
        }
      }
    });
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

      // STEP 2: Get server file size via HEAD request (validate consistency)
      int serverTotalBytes = 0;
      try {
        final response = await _dio.head(_modelUrl);
        final contentLength = response.headers.value('content-length');
        if (contentLength != null) {
          serverTotalBytes = int.parse(contentLength);
          developer.log('📏 SERVER reports total size: ${(serverTotalBytes / (1024 * 1024)).toStringAsFixed(1)}MB', name: 'dyslexic_ai.background_download');
          
          // Cache the expected size for future validation
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('expected_model_size', serverTotalBytes);
          developer.log('💾 Cached expected model size for validation', name: 'dyslexic_ai.background_download');
        } else {
          throw Exception('Server did not provide Content-Length header');
        }
      } catch (e) {
        developer.log('❌ CRITICAL: Cannot get server file size: $e', name: 'dyslexic_ai.background_download');
        await _updateState(_currentState.copyWith(
          status: DownloadStatus.failed,
          error: 'Cannot validate file size with server: $e',
        ));
        return;
      }

      // STEP 3: Validate file integrity (if resuming)
      if (actualFileBytes > 0) {
        if (actualFileBytes >= serverTotalBytes) {
          developer.log('🎉 File already complete! Size matches server.', name: 'dyslexic_ai.background_download');
          await _updateState(_currentState.copyWith(
            status: DownloadStatus.completed,
            progress: 1.0,
            downloadedBytes: actualFileBytes,
            totalBytes: serverTotalBytes,
          ));
          return;
        }
        
        // Validate partial file isn't corrupted (basic size check)
        if (actualFileBytes > serverTotalBytes) {
          developer.log('⚠️ CORRUPTION: File bigger than server expects. Deleting and restarting.', name: 'dyslexic_ai.background_download');
          await file.delete();
          actualFileBytes = 0;
        }
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
      await _dio.download(
        _modelUrl,
        modelPath,
        cancelToken: _cancelToken,
        options: Options(headers: headers),
        deleteOnError: false, // Don't delete partial downloads
        onReceiveProgress: _onReceiveProgress,
      );

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
        // Check if this is a network error that should be retried
        final shouldRetry = _shouldRetryError(e);
        
        if (shouldRetry) {
          developer.log('🔄 Worker network error, will retry: $e', name: 'dyslexic_ai.background_download');
          // DON'T reset _sessionStartBytes here - we want to resume from same point
          await _updateState(_currentState.copyWith(
            status: DownloadStatus.paused,
            error: 'Connection interrupted, will retry...',
            lastUpdate: DateTime.now(),
          ));
          
          // Trigger retry after a short delay
          Future.delayed(const Duration(seconds: 3), () async {
            if (_currentState.status == DownloadStatus.paused) {
              developer.log('🔄 Worker retrying download after connection failure', name: 'dyslexic_ai.background_download');
              await performActualDownload();
            }
          });
        } else {
          developer.log('❌ Worker download failed permanently: $e', name: 'dyslexic_ai.background_download');
          _sessionStartBytes = null; // Reset session tracking
          await _updateState(_currentState.copyWith(
            status: DownloadStatus.failed,
            error: 'Download failed: $e',
            lastUpdate: DateTime.now(),
          ));
        }
      }
    }
  }
  
  Future<void> _registerBackgroundTask() async {
    try {
      await Workmanager().registerOneOffTask(
        _backgroundTaskName,
        _backgroundTaskName,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false,  // Allow on low battery
          requiresCharging: false,       // Don't require charging
          requiresDeviceIdle: false,     // Don't require idle
          requiresStorageNotLow: false,  // CRITICAL: Don't check storage (too restrictive for large downloads)
        ),
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: Duration(seconds: 30), // Reduced from 1 minute
        initialDelay: Duration(seconds: 2),        // Start almost immediately
      );
      
      developer.log('🔧 Background download task registered with relaxed constraints', name: 'dyslexic_ai.workmanager');
    } catch (e) {
      developer.log('❌ Failed to register background task: $e', name: 'dyslexic_ai.workmanager');
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

  bool _shouldRetryError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return true;
        case DioExceptionType.unknown:
          // Check if it's a connection closed error
          if (error.message?.contains('Connection closed') == true ||
              error.message?.contains('HttpException') == true) {
            return true;
          }
          return false;
        default:
          return false;
      }
    }
    return false;
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