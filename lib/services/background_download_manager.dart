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
  static const String _modelUrl =
      'https://kaggle-gemma3.b-cdn.net/gemma-3n-E2B-it-int4.task';
  static const String _backgroundTaskName = 'model_download_task';
  static const String _taskLockKey = 'dyslexic_ai_workmanager_lock';
  
  // Track last logged progress to avoid spam
  static double _lastLoggedProgress = -1;
  
  static BackgroundDownloadManager? _instance;
  static BackgroundDownloadManager get instance =>
      _instance ??= BackgroundDownloadManager._();
  
  BackgroundDownloadManager._() {
    // DIAGNOSTIC: Register StreamController creation
    ResourceDiagnostics().registerStreamController(
        'BackgroundDownloadManager', 'stateController', _stateController);
  }

  final _dio = Dio();
  final _stateController = StreamController<DownloadState>.broadcast();
  DownloadState _currentState = DownloadState.initial();
  CancelToken? _cancelToken;
  Timer? _progressTimer;
  int?
      _sessionStartBytes; // Bytes that existed when download session started

  Stream<DownloadState> get stateStream => _stateController.stream;
  DownloadState get currentState => _currentState;

  Future<void> initialize() async {
    developer.log('🔄 Initializing BackgroundDownloadManager',
        name: 'dyslexic_ai.background_download');
    
    // Configure Dio for background downloads
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout =
        const Duration(hours: 3); // Long timeout for large files
    _dio.options.sendTimeout = const Duration(minutes: 30);
    _dio.options.headers = {
      'Accept': '*/*',
      'User-Agent': 'Flutter-App-DyslexicAI/1.0',
    };

    // Load previous download state
    await _loadState();
    
    // Always validate state against file system on initialization
    await _validateStateWithFileSystem();

    // If the download is supposedly in progress, start monitoring
    if (_currentState.status == DownloadStatus.downloading) {
      developer.log(
          '🔄 Download in progress, resuming progress monitoring...',
          name: 'dyslexic_ai.background_download');
      _startProgressMonitoring();
    } else if (await isModelAvailable()) {
      developer.log('✅ Model already available, cleaning up background tasks', name: 'dyslexic_ai.background_download');
      await _cancelBackgroundTask();
      if (_currentState.status != DownloadStatus.completed) {
        await _updateState(_currentState.copyWith(
          status: DownloadStatus.completed,
          progress: 1.0,
        ));
      }
    }

    developer.log('✅ BackgroundDownloadManager initialized',
        name: 'dyslexic_ai.background_download');
  }

  Future<void> startOrResumeDownload() async {
    if (_currentState.status == DownloadStatus.downloading ||
        _currentState.status == DownloadStatus.completed) {
      developer.log(
          '⚠️ Download is already active or completed. Status: ${_currentState.status}',
          name: 'dyslexic_ai.background_download');
      // If already downloading, ensure monitoring is active
    if (_currentState.status == DownloadStatus.downloading) {
        _startProgressMonitoring();
      }
      return;
    }

    developer.log('🚀 Starting or resuming download...',
        name: 'dyslexic_ai.background_download');

    await _updateState(_currentState.copyWith(status: DownloadStatus.downloading));

    // Register background task for native download continuation
    await _registerBackgroundTask();

    // Start monitoring progress via file size
    _startProgressMonitoring();
  }

  Future<void> pauseDownload() async {
    if (_currentState.status != DownloadStatus.downloading) {
      return;
    }

    developer.log('⏸️ Pausing download',
        name: 'dyslexic_ai.background_download');
    _cancelToken?.cancel('User paused download');
    _progressTimer?.cancel();
    _progressTimer = null;
    
    await _updateState(_currentState.copyWith(
      status: DownloadStatus.paused,
      lastUpdate: DateTime.now(),
    ));
  }

  Future<void> cancelDownload() async {
    developer.log('❌ Cancelling download',
        name: 'dyslexic_ai.background_download');
    
    // Cancel background task
    await _cancelBackgroundTask();
    
    _cancelToken?.cancel('User cancelled download');
    _progressTimer?.cancel();
    _progressTimer = null;

    // Delete partial download file and cached expected size
    try {
      final modelPath = await _getModelFilePath();
      final file = File(modelPath);
      if (file.existsSync()) {
        await file.delete();
        developer.log('🗑️ Deleted partial download file',
            name: 'dyslexic_ai.background_download');
      }
      
      // Clear cached expected size so it gets re-fetched
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('expected_model_size');
      developer.log('🧹 Cleared cached expected model size',
          name: 'dyslexic_ai.background_download');
    } catch (e) {
      developer.log('⚠️ Error deleting partial file: $e',
          name: 'dyslexic_ai.background_download');
    }

    await _updateState(DownloadState.initial());
  }

  Future<bool> isDownloadInProgress() async {
    return _currentState.status == DownloadStatus.downloading;
  }

  Future<bool> isModelAvailable() async {
    try {
      final modelPath = await _getModelFilePath();
      final file = File(modelPath);
      
      if (!file.existsSync()) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final expectedSize = prefs.getInt('expected_model_size');
      
      if (expectedSize == null) {
        final actualSize = await file.length();
        return actualSize > 1024 * 1024; // At least 1MB
      }

      final actualSize = await file.length();
      return actualSize >= (expectedSize * 0.99);
    } catch (e) {
      developer.log('❌ Error checking model availability: $e',
          name: 'dyslexic_ai.background_download');
      return false;
    }
  }

  Future<int?> _getExpectedModelSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedSize = prefs.getInt('expected_model_size');
      if (cachedSize != null) {
        return cachedSize;
      }

      final response = await _dio.head(_modelUrl);
      final contentLength = response.headers.value('content-length');
      
      if (contentLength != null) {
        final serverSize = int.parse(contentLength);
        await prefs.setInt('expected_model_size', serverSize);
        return serverSize;
      } else {
        return null;
      }
    } catch (e) {
      developer.log('❌ Error getting expected model size: $e',
          name: 'dyslexic_ai.background_download');
      return null;
    }
  }

  void _onReceiveProgress(int received, int total) {
    if (total <= 0) return;

    final sessionStartBytes = _sessionStartBytes ?? 0;
    final actualReceived = sessionStartBytes + received;
    final actualTotal = _currentState.totalBytes!;
    final progress = actualReceived / actualTotal;
    final progressPercent = (progress * 100).toInt();

    if (progressPercent > _lastLoggedProgress && progressPercent % 1 == 0) {
      _lastLoggedProgress = progressPercent.toDouble();
      if (progressPercent % 5 == 0) {
        final receivedMB =
            (actualReceived / (1024 * 1024)).toStringAsFixed(1);
        final totalMB = (actualTotal / (1024 * 1024)).toStringAsFixed(1);
        developer.log(
            '📥 Download: ${progressPercent}% (${receivedMB}/${totalMB}MB)',
                     name: 'dyslexic_ai.background_download');
      }
    }
  }

  Future<String> _getModelFilePath() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(path.join(appDir.path, 'models'));
    return path.join(modelsDir.path, _modelFileName);
  }

  Future<void> _updateState(DownloadState newState) async {
    _currentState = newState;
    if (!_stateController.isClosed) {
    _stateController.add(newState);
    }
    await _saveState();
  }

  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateJson = jsonEncode(_currentState.toJson());
      await prefs.setString(_downloadStateKey, stateJson);
    } catch (e) {
      developer.log('❌ Error saving download state: $e',
          name: 'dyslexic_ai.background_download');
    }
  }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateString = prefs.getString(_downloadStateKey);
      
      if (stateString != null) {
        final stateJson = jsonDecode(stateString) as Map<String, dynamic>;
        _currentState = DownloadState.fromJson(stateJson);
        developer.log('📂 Loaded download state: ${_currentState.status}',
            name: 'dyslexic_ai.background_download');
      }
    } catch (e) {
      developer.log('❌ Error loading download state: $e',
          name: 'dyslexic_ai.background_download');
      _currentState = DownloadState.initial();
    }
  }

  Future<void> _validateStateWithFileSystem() async {
    developer.log('🔄 Validating state with file system...',
        name: 'dyslexic_ai.background_download');
    try {
      final modelPath = await _getModelFilePath();
      final file = File(modelPath);

      if (!file.existsSync()) {
        if (_currentState.status != DownloadStatus.notStarted) {
           developer.log('🔍 No file found, resetting state.', name: 'dyslexic_ai.background_download');
           await _updateState(DownloadState.initial());
        }
        return;
      }

      final expectedSize = await _getExpectedModelSize();
      final actualSize = await file.length();

      // If we have a file but can't get the expected size (e.g., no network),
      // we must not delete the file. Instead, we pause the download.
      if (expectedSize == null) {
        developer.log('⚠️ Could not get expected size, pausing download to preserve partial file.', name: 'dyslexic_ai.background_download');
        await _updateState(_currentState.copyWith(
          status: DownloadStatus.paused,
          downloadedBytes: actualSize,
          error: 'Network connection needed to verify and resume download.'
        ));
        return;
      }
      
      final progress = (actualSize / expectedSize).clamp(0.0, 1.0);

      if (progress >= 0.999) {
        if (_currentState.status != DownloadStatus.completed) {
          developer.log('🔍 File is complete, updating state.', name: 'dyslexic_ai.background_download');
          await _updateState(_currentState.copyWith(
            status: DownloadStatus.completed,
            progress: 1.0,
            downloadedBytes: actualSize,
            totalBytes: expectedSize,
          ));
        }
      } else if (actualSize > 0) {
        if (_currentState.status != DownloadStatus.downloading) {
           developer.log('🔍 Found partial file, ensuring state is set to downloading.', name: 'dyslexic_ai.background_download');
        await _updateState(_currentState.copyWith(
            status: DownloadStatus.downloading,
            progress: progress,
            downloadedBytes: actualSize,
            totalBytes: expectedSize,
          ));
        }
      } else { // actualSize is 0
        if (_currentState.status != DownloadStatus.notStarted) {
          developer.log('🔍 File is empty, resetting state.', name: 'dyslexic_ai.background_download');
          await _updateState(DownloadState.initial());
        }
      }
    } catch (e) {
      developer.log('❌ Error during state validation: $e',
          name: 'dyslexic_ai.background_download');
      await _updateState(DownloadState.initial());
    }
  }

  void _startProgressMonitoring() {
    if (_progressTimer?.isActive ?? false) return;
    
    developer.log('🔄 Starting file-based progress monitoring', 
                 name: 'dyslexic_ai.background_download');
    
    _progressTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        if (_currentState.status != DownloadStatus.downloading) {
          timer.cancel();
          _progressTimer = null;
          return;
        }

        final modelPath = await _getModelFilePath();
        final file = File(modelPath);
        final expectedSize = await _getExpectedModelSize();
        
        if (file.existsSync() && expectedSize != null && expectedSize > 0) {
          final actualSize = await file.length();
            final realProgress = (actualSize / expectedSize).clamp(0.0, 1.0);
            
          if ((realProgress - _currentState.progress).abs() > 0.005 || realProgress == 1.0) {
            await _updateState(_currentState.copyWith(
                progress: realProgress,
                downloadedBytes: actualSize,
                totalBytes: expectedSize,
                lastUpdate: DateTime.now(),
            ));
            }
            
          if (realProgress >= 0.999) {
            developer.log('✅ Download complete (via file monitoring)',
                name: 'dyslexic_ai.background_download');
              timer.cancel();
              _progressTimer = null;
              
            await _updateState(_currentState.copyWith(
                status: DownloadStatus.completed,
                progress: 1.0,
            ));
            
            await _cancelBackgroundTask();
          }
        }
      } catch (e) {
        developer.log('❌ Error monitoring progress: $e',
            name: 'dyslexic_ai.background_download');
        timer.cancel();
        _progressTimer = null;
        await _updateState(_currentState.copyWith(
            status: DownloadStatus.failed, error: 'Monitoring failed: $e'));
      }
    });
    
    ResourceDiagnostics().registerTimer(
        'BackgroundDownloadManager', 'progressTimer', _progressTimer!);
  }

  Future<bool> performActualDownload() async {
    if (await isModelAvailable()) {
      developer.log('✅ Model already available in worker, marking complete',
          name: 'dyslexic_ai.background_download');
      await _updateState(
          _currentState.copyWith(status: DownloadStatus.completed, progress: 1.0));
      return true;
    }

    developer.log('📥 Worker performing actual model download',
        name: 'dyslexic_ai.background_download');

    try {
      final modelPath = await _getModelFilePath();
      final file = File(modelPath);
      await file.parent.create(recursive: true);

      int actualFileBytes = 0;
      if (file.existsSync()) {
        actualFileBytes = await file.length();
      }

      final serverTotalBytes = await _getExpectedModelSize();
      if (serverTotalBytes == null) {
        throw Exception('Cannot determine expected file size');
      }
      
      if (actualFileBytes >= serverTotalBytes) {
        developer.log('🎉 File already complete!',
                   name: 'dyslexic_ai.background_download');
          await _updateState(_currentState.copyWith(
            status: DownloadStatus.completed,
            progress: 1.0,
            downloadedBytes: actualFileBytes,
            totalBytes: serverTotalBytes,
          ));
        return true;
      }

      _sessionStartBytes = actualFileBytes;
      _lastLoggedProgress = -1;
      
      await _updateState(_currentState.copyWith(
        status: DownloadStatus.downloading,
        startTime: DateTime.now(),
        error: null,
        progress: actualFileBytes / serverTotalBytes,
        downloadedBytes: actualFileBytes,
        totalBytes: serverTotalBytes,
      ));

      _cancelToken = CancelToken();
      final headers = <String, dynamic>{
        'Range': 'bytes=$actualFileBytes-',
      };
      
        final response = await _dio.download(
          _modelUrl,
          modelPath,
          cancelToken: _cancelToken,
          options: Options(
            headers: headers,
            validateStatus: (status) {
              return status == 200 || status == 206;
            },
          ),
        deleteOnError: false,
          onReceiveProgress: _onReceiveProgress,
        );
        
      developer.log(
          '✅ Worker HTTP ${response.statusCode}: Download completed successfully',
          name: 'dyslexic_ai.background_download');

      _sessionStartBytes = null;
      await _updateState(_currentState.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        lastUpdate: DateTime.now(),
      ));

      return true;

    } catch (e) {
       _sessionStartBytes = null;
      if (e is DioException && e.type == DioExceptionType.cancel) {
        await _updateState(_currentState.copyWith(
          status: DownloadStatus.paused,
          lastUpdate: DateTime.now(),
        ));
      } else {
        await _updateState(_currentState.copyWith(
          status: DownloadStatus.failed,
          error: 'Download failed: $e',
          lastUpdate: DateTime.now(),
        ));
      }
      return false;
    }
  }
  
  Future<void> _registerBackgroundTask() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final taskLockTime = prefs.getInt(_taskLockKey);
      final now = DateTime.now().millisecondsSinceEpoch;
      
      if (taskLockTime != null && (now - taskLockTime) < 60000) {
        return;
      }
      
      await prefs.setInt(_taskLockKey, now);
      
      try {
        await Workmanager().cancelByUniqueName(_backgroundTaskName);
      } catch (e) {
        // Ignore
      }
      
      await Workmanager().registerOneOffTask(
        _backgroundTaskName,
        _backgroundTaskName,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(seconds: 30),
        initialDelay: const Duration(seconds: 1),
        inputData: <String, dynamic>{
          'priority': 'high',
          'keep_alive': true,
        },
      );
      
      developer.log('🔧 Background download task registered',
          name: 'dyslexic_ai.workmanager');
      
      await prefs.remove(_taskLockKey);
    } catch (e) {
      developer.log('❌ Failed to register background task: $e',
          name: 'dyslexic_ai.workmanager');
      try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_taskLockKey);
      } catch (e) {
        // Ignore
      }
    }
  }
  
  Future<void> _cancelBackgroundTask() async {
    try {
      await Workmanager().cancelByUniqueName(_backgroundTaskName);
    } catch (e) {
      developer.log('❌ Failed to cancel background task: $e',
          name: 'dyslexic_ai.workmanager');
    }
  }

  void dispose() {
    _cancelToken?.cancel();
    _progressTimer?.cancel();
    ResourceDiagnostics()
        .unregisterTimer('BackgroundDownloadManager', 'progressTimer');
    _stateController.close();
    ResourceDiagnostics().unregisterStreamController(
        'BackgroundDownloadManager', 'stateController');
    developer.log('🧹 BackgroundDownloadManager disposed',
        name: 'dyslexic_ai.background_download');
  }
} 