import 'package:flutter/material.dart';
import 'package:theme_mode_builder/theme_mode_builder.dart';
import 'package:DiscordStorage/screens/main/screen.dart';
import 'package:DiscordStorage/services/logger_service.dart';
import 'package:DiscordStorage/services/notification_service.dart';
import 'package:DiscordStorage/services/permission_service.dart';
import 'package:DiscordStorage/services/localization_service.dart';
import 'package:DiscordStorage/screens/settings/service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Logger.init();
  Logger.log('Application is starting...');

  // Initialize notifications
  NotificationService.init();
  Logger.log('Notifications initialized.');

  // Check permissions
  PermissionService.init();
  Logger.log('Permissions checked.');

  await SettingsService.load();
  await Language.load(SettingsService.languageCode);

  runApp(DiscordStorage());
  Logger.log('runApp called, application started.');
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
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              brightness: Brightness.light,
              seedColor: Colors.deepPurple,
            ),
          ),
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
flutter build windows

*/
