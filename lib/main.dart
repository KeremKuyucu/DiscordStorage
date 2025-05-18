import 'package:theme_mode_builder/theme_mode_builder.dart';
import 'package:discordstorage/screens/settings/service.dart';
import 'package:flutter/material.dart';
import 'package:discordstorage/screens/main/screen.dart';

void main() async {
  await SettingsService().init();
  runApp(DiscordStorage());
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

flutter build apk
xcopy /Y /I "build\app\outputs\flutter-apk\app-release.apk" "C:\Users\KeremK\Desktop\DiscordStorage-Mobile.apk"
flutter build windows
xcopy /E /I "build\windows\x64\runner\Release" "C:\Users\KeremK\Desktop\DiscordStorage"
flutter build web


flutter build apk --release --split-per-abi
flutter build windows
xcopy /E /I "build\windows\x64\runner\Release" "C:\Users\KeremK\Desktop\DiscordStorage"

flutter build apk
xcopy /Y /I "build\app\outputs\flutter-apk\app-release.apk" "C:\Users\Kerem\Desktop\DiscordStorage-Mobile.apk"
flutter build windows
xcopy /E /I "build\windows\x64\runner\Release" "C:\Users\Kerem\Desktop\DiscordStorage"

 */