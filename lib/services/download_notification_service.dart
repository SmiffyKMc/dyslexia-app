import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'background_download_manager.dart';

class DownloadNotificationService {
  static const String _channelId = 'model_download';
  static const String _channelName = 'Model Downloads';
  static const String _channelDescription = 'AI Model download progress notifications';
  static const int _notificationId = 1001;

  static DownloadNotificationService? _instance;
  static DownloadNotificationService get instance => _instance ??= DownloadNotificationService._();

  DownloadNotificationService._();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  StreamSubscription<DownloadState>? _downloadSubscription;
  bool _isInitialized = false;
  
  // Store current notification state for UI access
  String? _currentNotificationTitle;
  String? _currentNotificationBody;
  
  // Track last notified progress to avoid spam (every 10%)
  double _lastNotifiedProgress = -1;

  // Getters for UI to access current notification state
  String? get currentNotificationTitle => _currentNotificationTitle;
  String? get currentNotificationBody => _currentNotificationBody;
  bool get hasActiveNotification => _currentNotificationTitle != null;

  Future<void> initialize() async {
    if (_isInitialized) return;

    developer.log('🔔 Initializing DownloadNotificationService', name: 'dyslexic_ai.notifications');
    
    // Initialize notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    final initialized = await _notifications.initialize(initSettings);
    
    if (initialized == true) {
      // Request notification permission for Android 13+
      await _requestNotificationPermission();
      
      await _createNotificationChannel();
      _startListeningToDownloads();
      _isInitialized = true;
      developer.log('✅ DownloadNotificationService initialized', name: 'dyslexic_ai.notifications');
    } else {
      developer.log('❌ Failed to initialize notifications', name: 'dyslexic_ai.notifications');
    }
  }

  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.low, // Low importance for progress notifications
      enableLights: false,
      enableVibration: false,
      showBadge: false,
      playSound: false,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  Future<void> _requestNotificationPermission() async {
    try {
      // Request notification permission for Android 13+
      final status = await Permission.notification.request();
      
      switch (status) {
        case PermissionStatus.granted:
          developer.log('✅ Notification permission granted', name: 'dyslexic_ai.notifications');
          break;
        case PermissionStatus.denied:
          developer.log('⚠️ Notification permission denied', name: 'dyslexic_ai.notifications');
          break;
        case PermissionStatus.permanentlyDenied:
          developer.log('❌ Notification permission permanently denied', name: 'dyslexic_ai.notifications');
          break;
        default:
          developer.log('❓ Notification permission status: $status', name: 'dyslexic_ai.notifications');
      }
    } catch (e) {
      developer.log('❌ Error requesting notification permission: $e', name: 'dyslexic_ai.notifications');
    }
  }

  Future<bool> _hasNotificationPermission() async {
    try {
      final status = await Permission.notification.status;
      return status == PermissionStatus.granted;
    } catch (e) {
      developer.log('❌ Error checking notification permission: $e', name: 'dyslexic_ai.notifications');
      return false;
    }
  }

  void _startListeningToDownloads() {
    _downloadSubscription?.cancel();
    _downloadSubscription = BackgroundDownloadManager.instance.stateStream.listen(
      _onDownloadStateChanged,
      onError: (error) {
        developer.log('❌ Error listening to download state: $error', name: 'dyslexic_ai.notifications');
      },
    );
  }

  Future<void> _onDownloadStateChanged(DownloadState state) async {
    switch (state.status) {
      case DownloadStatus.downloading:
        // Reset progress tracking when download starts
        if (state.progress == 0.0) {
          _lastNotifiedProgress = -1;
        }
        await _showProgressNotification(state);
        break;
      case DownloadStatus.partiallyDownloaded:
        await _showPausedNotification(state);
        break;
      case DownloadStatus.completed:
        await _showCompletedNotification();
        break;
      case DownloadStatus.failed:
        await _showErrorNotification(state.error ?? 'Download failed');
        break;
      case DownloadStatus.paused:
        await _showPausedNotification(state);
        break;
      case DownloadStatus.notStarted:
        await _dismissNotification();
        break;
      case DownloadStatus.initializing:
        await _showInitializingNotification();
        break;
    }
  }

  Future<void> _showProgressNotification(DownloadState state) async {
    final progress = (state.progress * 100).round();
    
    // Live streaming: Update every 1% to avoid excessive spam but still be responsive
    if (progress <= _lastNotifiedProgress) {
      return;
    }
    
    // Check if we have notification permission
    if (!await _hasNotificationPermission()) {
      developer.log('⚠️ Cannot show notification - permission not granted', name: 'dyslexic_ai.notifications');
      return;
    }
    
    _lastNotifiedProgress = progress.toDouble();
    
    final downloadedMB = state.downloadedBytes != null 
        ? (state.downloadedBytes! / (1024 * 1024)).toStringAsFixed(1)
        : '0.0';
    final totalMB = state.totalBytes != null 
        ? (state.totalBytes! / (1024 * 1024)).toStringAsFixed(1)
        : '???';

    _currentNotificationTitle = 'Downloading AI Model';
    _currentNotificationBody = 'Progress: ${progress}% ($downloadedMB/$totalMB MB)';
    
    // Show actual system notification
    await _notifications.show(
      _notificationId,
      _currentNotificationTitle,
      _currentNotificationBody,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true, // Makes it persistent
          autoCancel: false,
          showProgress: true,
          maxProgress: 100,
          progress: progress,
          icon: '@mipmap/launcher_icon',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: false,
          presentSound: false,
        ),
      ),
    );
    
    developer.log('🔔 Notification: ${progress}% ($downloadedMB/$totalMB MB)', name: 'dyslexic_ai.notifications');
  }

  Future<void> _showPausedNotification(DownloadState state) async {
    final progress = (state.progress * 100).round();
    
    _currentNotificationTitle = 'AI Model Download Paused';
    _currentNotificationBody = 'Progress: $progress% - Tap to resume';
    
    developer.log('🔔 Download paused at $progress%', name: 'dyslexic_ai.notifications');
  }

  Future<void> _showCompletedNotification() async {
    _currentNotificationTitle = 'AI Model Ready! 🎉';
    _currentNotificationBody = 'Your reading assistant is ready to use';
    
    // Check if we have notification permission
    if (!await _hasNotificationPermission()) {
      developer.log('⚠️ Cannot show completion notification - permission not granted', name: 'dyslexic_ai.notifications');
      return;
    }
    
    // Show success notification
    await _notifications.show(
      _notificationId,
      _currentNotificationTitle,
      _currentNotificationBody,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high, // Higher importance for completion
          priority: Priority.high,
          ongoing: false, // Not persistent - can be dismissed
          autoCancel: true,
          icon: '@mipmap/launcher_icon',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: false,
        ),
      ),
    );
    
    developer.log('🔔 Download completed successfully', name: 'dyslexic_ai.notifications');

    // Auto-dismiss completed notification after 10 seconds
    Timer(const Duration(seconds: 10), () async {
      await _dismissNotification();
    });
  }

  Future<void> _showErrorNotification(String error) async {
    _currentNotificationTitle = 'Download Failed';
    _currentNotificationBody = 'AI model download encountered an error. Tap to retry.';
    
    developer.log('🔔 Download failed: $error', name: 'dyslexic_ai.notifications');
  }

  Future<void> _showInitializingNotification() async {
    _currentNotificationTitle = 'Initializing AI Model';
    _currentNotificationBody = 'Setting up your reading assistant...';
    
    developer.log('🔔 Initializing AI model', name: 'dyslexic_ai.notifications');
  }

  Future<void> _dismissNotification() async {
    await _notifications.cancel(_notificationId);
    _currentNotificationTitle = null;
    _currentNotificationBody = null;
    
    developer.log('🔔 Notification dismissed', name: 'dyslexic_ai.notifications');
  }

  void handleNotificationTap() {
    developer.log('🔔 Notification tapped', name: 'dyslexic_ai.notifications');
    
    // Handle notification tap based on current download state
    final currentState = BackgroundDownloadManager.instance.currentState;
    
    switch (currentState.status) {
      case DownloadStatus.paused:
      case DownloadStatus.partiallyDownloaded:
        // Resume download when paused/partially downloaded notification is tapped
        BackgroundDownloadManager.instance.startOrResumeDownload();
        break;
      case DownloadStatus.failed:
        // Retry download when error notification is tapped
        BackgroundDownloadManager.instance.startOrResumeDownload();
        break;
      case DownloadStatus.completed:
        // Open app when completed notification is tapped
        // The app will automatically navigate to the main screen
        break;
      default:
        // For other states, just open the app
        break;
    }
  }

  void dispose() {
    _downloadSubscription?.cancel();
    _dismissNotification();
  }
} 