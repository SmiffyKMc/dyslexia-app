import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'dart:developer' as developer;
import 'package:flutter_downloader/flutter_downloader.dart';
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
  final String? taskId;
  final String? modelPath;

  const DownloadState({
    required this.status,
    required this.progress,
    this.error,
    this.totalBytes,
    this.downloadedBytes,
    this.startTime,
    this.lastUpdate,
    this.taskId,
    this.modelPath,
  });

  factory DownloadState.initial() {
    return const DownloadState(
      status: DownloadStatus.notStarted,
      progress: 0.0,
      modelPath: null,
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
    String? taskId,
    String? modelPath,
  }) {
    return DownloadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error ?? this.error,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      startTime: startTime ?? this.startTime,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      taskId: taskId ?? this.taskId,
      modelPath: modelPath ?? this.modelPath,
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
      'taskId': taskId,
      'modelPath': modelPath,
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
      taskId: json['taskId'],
      modelPath: json['modelPath'],
    );
  }
}

class FlutterDownloadService {
  static const String _downloadStateKey = 'dyslexic_ai_download_state';
  static const String _modelFileName = 'gemma-3n-E2B-it-int4.task';
  static const String _modelUrl = 'https://kaggle-gemma3.b-cdn.net/gemma-3n-E2B-it-int4.task';
  static const String _isolatePortName = 'downloader_send_port';
  
  static FlutterDownloadService? _instance;
  static FlutterDownloadService get instance => _instance ??= FlutterDownloadService._();
  
  FlutterDownloadService._() {
    ResourceDiagnostics().registerStreamController(
        'FlutterDownloadService', 'stateController', _stateController);
  }

  final _stateController = StreamController<DownloadState>.broadcast();
  DownloadState _currentState = DownloadState.initial();
  ReceivePort? _port;

  Stream<DownloadState> get stateStream => _stateController.stream;
  DownloadState get currentState => _currentState;

  Future<void> initialize() async {
    developer.log('🔄 Initializing FlutterDownloadService', name: 'dyslexic_ai.flutter_download');
    
    // Initialize the isolate port for receiving download callbacks
    _port = ReceivePort();
    IsolateNameServer.registerPortWithName(_port!.sendPort, 'downloader_send_port');
    _port!.listen(_downloadCallback);

    // Load previous download state
    await _loadState();
    
    // Validate state with flutter_downloader
    await _validateStateWithDownloader();

    developer.log('✅ FlutterDownloadService initialized', name: 'dyslexic_ai.flutter_download');
  }



  Future<void> startOrResumeDownload() async {
    if (_currentState.status == DownloadStatus.downloading ||
        _currentState.status == DownloadStatus.completed) {
      developer.log('⚠️ Download is already active or completed. Status: ${_currentState.status}',
          name: 'dyslexic_ai.flutter_download');
      return;
    }

    developer.log('🚀 Starting or resuming download...', name: 'dyslexic_ai.flutter_download');

    await _updateState(_currentState.copyWith(
      status: DownloadStatus.initializing,
      startTime: DateTime.now(),
    ));

    try {
      final downloadPath = await _getDownloadDirectory();
      
      // Check if partial file exists
      final modelPath = await _getModelFilePath();
      final partialFile = File(modelPath);
      final resumeFromByte = partialFile.existsSync() ? await partialFile.length() : 0;

      // Start download with flutter_downloader
      final taskId = await FlutterDownloader.enqueue(
        url: _modelUrl,
        savedDir: downloadPath,
        fileName: _modelFileName,
        headers: resumeFromByte > 0 ? {'Range': 'bytes=$resumeFromByte-'} : {},
        showNotification: true,
        openFileFromNotification: false,
        saveInPublicStorage: false,
        allowCellular: true,
        timeout: 3600000,
      );

      if (taskId != null) {
        await _updateState(_currentState.copyWith(
          status: DownloadStatus.downloading,
          taskId: taskId,
          startTime: DateTime.now(),
          error: null,
        ));
        developer.log('📥 Download started with task ID: $taskId', name: 'dyslexic_ai.flutter_download');
      } else {
        throw Exception('Failed to start download task');
      }
    } catch (e) {
      developer.log('❌ Failed to start download: $e', name: 'dyslexic_ai.flutter_download');
      await _updateState(_currentState.copyWith(
        status: DownloadStatus.failed,
        error: 'Failed to start download: $e',
        lastUpdate: DateTime.now(),
      ));
    }
  }

  Future<void> pauseDownload() async {
    if (_currentState.status != DownloadStatus.downloading || _currentState.taskId == null) {
      return;
    }

    developer.log('⏸️ Pausing download', name: 'dyslexic_ai.flutter_download');
    
    try {
      await FlutterDownloader.pause(taskId: _currentState.taskId!);
      await _updateState(_currentState.copyWith(
        status: DownloadStatus.paused,
        lastUpdate: DateTime.now(),
      ));
    } catch (e) {
      developer.log('❌ Failed to pause download: $e', name: 'dyslexic_ai.flutter_download');
    }
  }

  Future<void> resumeDownload() async {
    if (_currentState.status != DownloadStatus.paused || _currentState.taskId == null) {
      return;
    }

    developer.log('▶️ Resuming download', name: 'dyslexic_ai.flutter_download');
    
    try {
      final newTaskId = await FlutterDownloader.resume(taskId: _currentState.taskId!);
      await _updateState(_currentState.copyWith(
        status: DownloadStatus.downloading,
        taskId: newTaskId,
        lastUpdate: DateTime.now(),
      ));
    } catch (e) {
      developer.log('❌ Failed to resume download: $e', name: 'dyslexic_ai.flutter_download');
    }
  }

  Future<void> cancelDownload() async {
    developer.log('❌ Cancelling download', name: 'dyslexic_ai.flutter_download');
    
    if (_currentState.taskId != null) {
      try {
        await FlutterDownloader.cancel(taskId: _currentState.taskId!);
      } catch (e) {
        developer.log('⚠️ Error cancelling flutter_downloader task: $e', name: 'dyslexic_ai.flutter_download');
      }
    }

    // Delete partial download file
    try {
      final modelPath = await _getModelFilePath();
      final file = File(modelPath);
      if (file.existsSync()) {
        await file.delete();
        developer.log('🗑️ Deleted partial download file', name: 'dyslexic_ai.flutter_download');
      }
    } catch (e) {
      developer.log('⚠️ Error deleting partial file: $e', name: 'dyslexic_ai.flutter_download');
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

      // Simple size check - if file is larger than 100MB, consider it complete
      final actualSize = await file.length();
      return actualSize > 100 * 1024 * 1024;
    } catch (e) {
      developer.log('❌ Error checking model availability: $e', name: 'dyslexic_ai.flutter_download');
      return false;
    }
  }

  DownloadTaskStatus _mapFlutterDownloaderStatus(int status) {
    // Flutter downloader status codes:
    // 0: undefined, 1: enqueued, 2: running, 3: complete, 4: failed, 5: canceled, 6: paused
    switch (status) {
      case 1: return DownloadTaskStatus.enqueued;
      case 2: return DownloadTaskStatus.running;
      case 3: return DownloadTaskStatus.complete;
      case 4: return DownloadTaskStatus.failed;
      case 5: return DownloadTaskStatus.canceled;
      case 6: return DownloadTaskStatus.paused;
      default: return DownloadTaskStatus.undefined;
    }
  }

  void _downloadCallback(dynamic data) {
    if (data is! List || data.length != 3) return;
    
    final id = data[0] as String;
    final statusInt = data[1] as int;
    final progress = data[2] as int;
    
    // Only process callbacks for our current task
    if (_currentState.taskId != id) return;

    final progressDecimal = progress / 100.0;
    final status = _mapFlutterDownloaderStatus(statusInt);
    
    switch (status) {
      case DownloadTaskStatus.running:
        developer.log('📥 Download progress: $progress%', name: 'dyslexic_ai.flutter_download');
        
        _updateState(_currentState.copyWith(
          status: DownloadStatus.downloading,
          progress: progressDecimal,
          lastUpdate: DateTime.now(),
        ));
        break;
      case DownloadTaskStatus.paused:
        _updateState(_currentState.copyWith(
          status: DownloadStatus.paused,
          progress: progressDecimal,
          lastUpdate: DateTime.now(),
        ));
        break;
      case DownloadTaskStatus.complete:
        _getModelFilePath().then((modelPath) {
          developer.log('✅ Download completed successfully', name: 'dyslexic_ai.flutter_download');
            _updateState(_currentState.copyWith(
              status: DownloadStatus.completed,
              progress: 1.0,
              lastUpdate: DateTime.now(),
              modelPath: modelPath,
            ));
        });
        break;
      case DownloadTaskStatus.failed:
        _updateState(_currentState.copyWith(
          status: DownloadStatus.failed,
          error: 'Download task failed',
          lastUpdate: DateTime.now(),
        ));
        developer.log('❌ Download failed', name: 'dyslexic_ai.flutter_download');
        break;
      case DownloadTaskStatus.canceled:
        _updateState(_currentState.copyWith(
          status: DownloadStatus.notStarted,
          progress: 0.0,
          lastUpdate: DateTime.now(),
        ));
        break;
      default:
        break;
    }
  }

  Future<String> _getDownloadDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(path.join(appDir.path, 'models'));
    await modelsDir.create(recursive: true);
    return modelsDir.path;
  }

  Future<String> _getModelFilePath() async {
    final downloadDir = await _getDownloadDirectory();
    return path.join(downloadDir, _modelFileName);
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
      developer.log('❌ Error saving download state: $e', name: 'dyslexic_ai.flutter_download');
    }
  }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateString = prefs.getString(_downloadStateKey);
      
      if (stateString != null) {
        final stateJson = jsonDecode(stateString) as Map<String, dynamic>;
        _currentState = DownloadState.fromJson(stateJson);
        developer.log('📂 Loaded download state: ${_currentState.status}', name: 'dyslexic_ai.flutter_download');
      }
    } catch (e) {
      developer.log('❌ Error loading download state: $e', name: 'dyslexic_ai.flutter_download');
      _currentState = DownloadState.initial();
    }
  }

  Future<void> _validateStateWithDownloader() async {
    developer.log('🔄 Validating state with flutter_downloader...', name: 'dyslexic_ai.flutter_download');
    
    try {
      // Check if model file is complete
      if (await isModelAvailable()) {
        if (_currentState.status != DownloadStatus.completed) {
          developer.log('🔍 Model file is complete, updating state.', name: 'dyslexic_ai.flutter_download');
          await _updateState(_currentState.copyWith(
            status: DownloadStatus.completed,
            progress: 1.0,
          ));
        }
        return;
      }

      // If we have a task ID, check its status with flutter_downloader
      if (_currentState.taskId != null) {
        final tasks = await FlutterDownloader.loadTasksWithRawQuery(
          query: "SELECT * FROM task WHERE task_id = '${_currentState.taskId}'");
        
        if (tasks?.isNotEmpty == true) {
          final task = tasks!.first;
          final status = task.status;
          final progress = task.progress / 100.0;
          
          switch (status) {
            case DownloadTaskStatus.running:
              await _updateState(_currentState.copyWith(
                status: DownloadStatus.downloading,
                progress: progress,
              ));
              break;
            case DownloadTaskStatus.paused:
              await _updateState(_currentState.copyWith(
                status: DownloadStatus.paused,
                progress: progress,
              ));
              break;
            case DownloadTaskStatus.complete:
              await _updateState(_currentState.copyWith(
                status: DownloadStatus.completed,
                progress: 1.0,
              ));
              break;
            case DownloadTaskStatus.failed:
            case DownloadTaskStatus.canceled:
              await _updateState(_currentState.copyWith(
                status: DownloadStatus.failed,
                error: 'Previous download task failed',
              ));
              break;
            default:
              break;
          }
        } else {
          // Task not found, reset state
          await _updateState(DownloadState.initial());
        }
      }
    } catch (e) {
      developer.log('❌ Error during state validation: $e', name: 'dyslexic_ai.flutter_download');
      await _updateState(DownloadState.initial());
    }
  }

  Future<void> updateModelPath(String modelPath) async {
    await _updateState(_currentState.copyWith(
      modelPath: modelPath,
    ));
    developer.log('📝 Updated model path in download state', name: 'dyslexic_ai.flutter_download');
  }

  void dispose() {
    _port?.close();
    IsolateNameServer.removePortNameMapping(_isolatePortName);
    ResourceDiagnostics().unregisterStreamController(
        'FlutterDownloadService', 'stateController');
    _stateController.close();
    developer.log('🧹 FlutterDownloadService disposed', name: 'dyslexic_ai.flutter_download');
  }

  // Static callback for flutter_downloader (must be static)
  static void downloadCallback(String id, DownloadTaskStatus status, int progress) {
    final SendPort? send = IsolateNameServer.lookupPortByName(_isolatePortName);
    send?.send([id, status, progress]);
  }
} 