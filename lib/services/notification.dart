import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._privateConstructor();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  NotificationService._privateConstructor();

  Future<void> initialize() async {
    const androidInitialization = AndroidInitializationSettings('@mipmap/ic_launcher');

    final initializationSettings = InitializationSettings(
      android: androidInitialization,
      // iOS eklemek istersen buraya ekleyebilirsin
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) async {
        print('Bildirime tıklandı: ${details.payload}');
      },
    );
  }

  Future<void> showNotification(String title, String body, {int id = 0}) async {
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'discordstorage_file', // kanal ID
        'File Process',         // kanal adı
        channelDescription: 'DiscordStorage',
        importance: Importance.high,
        priority: Priority.high,
        playSound: false,
      ),
    );

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
    );
  }

  Future<void> showProgressNotification(int current, int total, {int id = 100, int barWidth = 20}) async {
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
    final title = 'İşlem devam ediyor';
    final body = '[$bar] %$progressPercent ($current/$total)';

    final androidDetails = AndroidNotificationDetails(
      'discordstorage_file',
      'File Process',
      channelDescription: 'DiscordStorage',
      importance: Importance.high,
      priority: Priority.high,
      playSound: false,
      onlyAlertOnce: true, // Bildirim sadece ilk seferde ses çıkarır
      // progress bar desteği için
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

    if (current == total) {
      await flutterLocalNotificationsPlugin.cancel(id); // İşlem bittiğinde bildirimi kaldır
      await showNotification('İşlem tamamlandı', 'Dosya işlemi tamamlandı.', id: id);
    }
  }
}
