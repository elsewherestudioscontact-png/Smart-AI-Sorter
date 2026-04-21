import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static const int _progressId = 0;
  static const int _statusId = 1;
  static const int _completeId = 2;

  static Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notifications.initialize(initSettings);
  }

  static Future<void> showProgress({
    required String title,
    required String body,
    required int progress,
    required int maxProgress,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'smart_sorter_progress',
      'Smart AI Sorter Progress',
      channelDescription: 'File organization progress',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: maxProgress,
      progress: progress,
      onlyAlertOnce: true,
      ongoing: true,
      autoCancel: false,
    );
    await _notifications.show(
      _progressId,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> showStatus(String title, String body) async {
    final androidDetails = AndroidNotificationDetails(
      'smart_sorter_status',
      'Smart AI Sorter',
      channelDescription: 'Status updates',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      onlyAlertOnce: true,
    );
    await _notifications.show(
      _statusId,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> complete(String message) async {
    // Cancel the ongoing progress notification first
    await _notifications.cancel(_progressId);

    final androidDetails = AndroidNotificationDetails(
      'smart_sorter_complete',
      'Smart AI Sorter',
      channelDescription: 'Completion alerts',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _notifications.show(
      _completeId,
      '✅ Organization Complete',
      message,
      NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
