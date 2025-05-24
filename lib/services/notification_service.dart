import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:DiscordStorage/services/logger_service.dart';
import 'package:DiscordStorage/services/localization_service.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._privateConstructor();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  NotificationService._privateConstructor();

  static Future<void> init() async {
    await instance.initializeNotifications();
  }

  Future<void> initializeNotifications() async {
    Logger.log('Initializing notifications...');

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    final windowsSettings = WindowsInitializationSettings(
      appName: 'DiscordStorage',
      appUserModelId: 'com.kerem.discordstorage',
      guid: '9c9737b1-1f94-4eaa-8a6b-123456789abc',
    );

    final initializationSettings = InitializationSettings(
      android: androidSettings,
      windows: windowsSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    Logger.log('Notifications initialized successfully.');
  }

  Future<void> showNotification(String title, String body, {int id = 0, bool playSound = false}) async {
    Logger.log('Showing notification: $title - $body');
    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'discordstorage_file',
        'File Operations',
        channelDescription: 'DiscordStorage notification channel',
        importance: Importance.high,
        priority: Priority.high,
        playSound: playSound,
      ),
    );

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
    );
    Logger.log('Notification shown (ID: $id)');
  }

  Future<void> showProgressNotification(int current, int total, {int id = 100, int barWidth = 20}) async {
    Logger.log('Updating progress notification: $current / $total');
    double progress = current / total;
    int pos = (barWidth * progress).toInt();

    StringBuffer bar = StringBuffer();
    for (int i = 0; i < barWidth; i++) {
      if (i < pos) {
        bar.write('=');
      } else if (i == pos) {
        bar.write('>');
      } else {
        bar.write(' ');
      }
    }

    final progressPercent = (progress * 100).toInt();
    final title = Language.get('operationInProgress');
    final body = '[$bar] %$progressPercent ($current/$total)';

    final androidDetails = AndroidNotificationDetails(
      'discordstorage_file',
      'File Operations',
      channelDescription: 'DiscordStorage notification channel',
      importance: Importance.high,
      priority: Priority.high,
      playSound: false,
      onlyAlertOnce: true,
      maxProgress: total,
      progress: current,
      showProgress: true,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
    );

    Logger.log('Progress notification shown (ID: $id)');

    if (current >= total) {
      Logger.log('Operation completed, removing progress notification.');
      await flutterLocalNotificationsPlugin.cancel(id);
      await showNotification(Language.get('operationCompletedTitle'), Language.get('operationCompletedBody'), id: id, playSound: true);
    }
  }
}
