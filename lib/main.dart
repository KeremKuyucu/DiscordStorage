import 'package:theme_mode_builder/theme_mode_builder.dart';
import 'package:flutter/material.dart';
import 'package:DiscordStorage/screens/main/screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeNotifications();
  await requestPermissions();

  runApp(DiscordStorage());
}
Future<void> initializeNotifications() async {
  const AndroidInitializationSettings androidSettings =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  final WindowsInitializationSettings windowsSettings = WindowsInitializationSettings(
    appName: 'DiscordStorage',
    appUserModelId: 'com.kerem.discordstorage',
    guid: '9c9737b1-1f94-4eaa-8a6b-123456789abc',
  );

  final InitializationSettings initializationSettings = InitializationSettings(
    android: androidSettings,
    windows: windowsSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}
Future<void> requestPermissions() async {
  if (Platform.isAndroid) {
    var storageStatus = await Permission.storage.status;
    if (!storageStatus.isGranted) {
      storageStatus = await Permission.storage.request();
      if (!storageStatus.isGranted) {
        debugPrint('Storage izni reddedildi!');
      }
    }

    var notificationStatus = await Permission.notification.status;
    if (!notificationStatus.isGranted) {
      notificationStatus = await Permission.notification.request();
      if (!notificationStatus.isGranted) {
        debugPrint('Bildirim izni reddedildi!');
      }
    }
  } else if (Platform.isIOS) {
    var notificationStatus = await Permission.notification.status;
    if (!notificationStatus.isGranted) {
      notificationStatus = await Permission.notification.request();
      if (!notificationStatus.isGranted) {
        debugPrint('Bildirim izni reddedildi!');
      }
    }
  }
}


class DiscordStorage extends StatefulWidget {
  @override
  State<DiscordStorage> createState() => DiscordStorageState();
}

class DiscordStorageState extends State<DiscordStorage> {
  @override
  Widget build(BuildContext context) {
    return ThemeModeBuilder(
      builder: (BuildContext context, ThemeMode themeMode) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: "DiscordStorage",
          themeMode: themeMode,
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              brightness: Brightness.dark,
              seedColor: Colors.deepPurple,
            ),
          ),
          home: DiscordStorageLobi(),
        );
      },
    );
  }
}


/*
flutter pub run flutter_launcher_icons:main


adb install build\app\outputs\flutter-apk\app-release.apk

flutter build apk --release
xcopy /Y /I "build\app\outputs\flutter-apk\app-release.apk" "C:\Users\KeremK\Desktop\DiscordStorage-Mobile.apk"
flutter build windows
xcopy /E /I "build\windows\x64\runner\Release" "C:\Users\KeremK\Desktop\DiscordStorage"


flutter build apk --release
flutter build windows


 */