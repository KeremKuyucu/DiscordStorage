import 'dart:io';
import 'package:flutter/material.dart';
import 'package:theme_mode_builder/theme_mode_builder.dart';
import 'package:discord_storage/screens/main/screen.dart';
import 'package:discord_storage/services/logger_service.dart';
import 'package:discord_storage/services/notification_service.dart';
import 'package:discord_storage/services/localization_service.dart';
import 'package:discord_storage/screens/settings/service.dart';
import 'package:discord_storage/services/protocol_service.dart';


void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  await Logger.init();
  Logger.info('Logger initialized.');
  Logger.info('Application is starting with args: $args');

  // Windows'ta discordstorage:// protokolünü kaydet
  if (Platform.isWindows) {
    ProtocolService.registerWindowsProtocol();
  }

  // Paylaşım linki ile açılmışsa messageId'yi ayıkla
  final String? initialMessageId = ProtocolService.parseMessageIdFromArgs(args);
  if (initialMessageId != null) {
    Logger.info('Initial message ID from deep link: $initialMessageId');
  }

  // Initialize notifications
  NotificationService.init();
  Logger.info('Notifications initialized.');

  await SettingsService.load();
  await Language.load(SettingsService.languageCode);

  runApp(DiscordStorage(initialMessageId: initialMessageId));
  Logger.info('runApp called, application started.');
}

class DiscordStorage extends StatefulWidget {
  final String? initialMessageId;
  const DiscordStorage({super.key, this.initialMessageId});

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
          home: DiscordStorageLobi(initialMessageId: widget.initialMessageId),
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

flutter pub run msix:create

*/


