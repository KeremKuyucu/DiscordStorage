import 'package:discordstorage/util.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._privateConstructor();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  NotificationService._privateConstructor();
  Future<void> initialize() async {
    const androidInitialization = AndroidInitializationSettings('@mipmap/ic_launcher');
    final initializationSettings = InitializationSettings(android: androidInitialization);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (_) async {
        // Bildirime tıklanınca yapılacak işlem
      },
    );
  }

  Future<void> showNotification(String title, String body) async {
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'discordstorage_file',
        'File Process',
        channelDescription: 'DiscordStorage',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
      ),
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      notificationDetails,
    );
  }
}
/*
          NotificationService.instance.showNotification(
            'başlık',
            'metin',
          );

 */