import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:DiscordStorage/services/logger_service.dart';

class PermissionService {
  static final PermissionService instance = PermissionService._privateConstructor();

  PermissionService._privateConstructor();

  static Future<void> init() async {
    await instance.requestPermissions();
  }

  Future<void> requestPermissions() async {
    Logger.info('Checking permissions...');

    if (!Platform.isAndroid) {
      Logger.info('Not Android platform, skipping permissions.');
      return;
    }

    final sdkInt = await _getAndroidSdkInt();

    if (sdkInt == null) {
      Logger.error('Failed to get Android SDK version!');
      return;
    }

    Logger.info('Android SDK version: $sdkInt');

    if (sdkInt >= 33) {
      if (await Permission.photos.isDenied) {
        final result = await Permission.photos.request();
        if (!result.isGranted) Logger.error('Photo access permission denied!');
      }

      if (await Permission.videos.isDenied) {
        final result = await Permission.videos.request();
        if (!result.isGranted) Logger.error('Video access permission denied!');
      }

      if (await Permission.notification.isDenied) {
        final result = await Permission.notification.request();
        if (!result.isGranted) Logger.error('Notification permission denied!');
      }

      if (await Permission.manageExternalStorage.isDenied) {
        final result = await Permission.manageExternalStorage.request();
        if (!result.isGranted) Logger.error('File access permission denied!');
      }
    } else if (sdkInt >= 30) {
      if (await Permission.manageExternalStorage.isDenied) {
        final result = await Permission.manageExternalStorage.request();
        if (!result.isGranted) Logger.error('File access permission denied!');
      }
    } else {
      if (await Permission.storage.isDenied) {
        final result = await Permission.storage.request();
        if (!result.isGranted) Logger.error('Storage permission denied!');
      }
    }

    Logger.info('Permission check completed.');
  }

  Future<int?> _getAndroidSdkInt() async {
    try {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      return deviceInfo.version.sdkInt;
    } catch (e) {
      Logger.error('Error getting SDK version: $e');
      return null;
    }
  }
}




