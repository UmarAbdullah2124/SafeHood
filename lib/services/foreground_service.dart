import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Keeps the app process alive. Mic listening runs in the main app, not here.
class ForegroundService {
  static final ForegroundService _instance = ForegroundService._internal();
  factory ForegroundService() => _instance;
  ForegroundService._internal();

  bool _isRunning = false;
  bool _isInitialized = false;

  static const _channelId = 'safehood_keepalive_v1';

  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _channelId,
        channelName: 'Safehood',
        channelDescription: 'Keeps voice commands available',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        enableVibration: false,
        playSound: false,
        showWhen: false,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: false,
      ),
    );
    _isInitialized = true;
  }

  Future<void> _requestPermissions() async {
    final notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (Platform.isAndroid &&
        !await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }

  Future<void> startForegroundService() async {
    if (_isRunning) return;

    await _ensureInitialized();
    await _requestPermissions();

    if (await FlutterForegroundTask.isRunningService) {
      _isRunning = true;
      return;
    }

    final result = await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'Safehood',
      notificationText: 'Say Alert, Help, or Safehood',
      callback: _startCallback,
    );

    if (result is ServiceRequestSuccess) {
      _isRunning = true;
    }
  }

  Future<void> stopForegroundService() async {
    if (!_isRunning) return;
    await FlutterForegroundTask.stopService();
    _isRunning = false;
  }

  bool isRunning() => _isRunning;
}

@pragma('vm:entry-point')
void _startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}
