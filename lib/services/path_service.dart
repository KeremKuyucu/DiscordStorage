import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:DiscordStorage/services/logger_service.dart';

class PathHelper {
  static const String _className = 'PathHelper';

  Future<String?> _getWindowsDownloadsPath() async {
    Logger.log('[$_className] Reading Windows user profile...');
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null) {
      final path = '$userProfile\\Downloads';
      Logger.log('[$_className] Windows Downloads directory: $path');
      return path;
    }
    Logger.error('[$_className] USERPROFILE environment variable not found.');
    return null;
  }

  Future<String> getDownloadsDirectoryPath() async {
    Logger.log('[$_className] Searching Downloads directory...');

    if (kIsWeb) {
      Logger.error('[$_className] Web platform is not supported.');
      throw UnsupportedError("Web platform is not supported.");
    }

    if (Platform.isWindows) {
      Logger.log('[$_className] Windows platform detected.');
      final downloadsPath = await _getWindowsDownloadsPath();
      if (downloadsPath != null) {
        Logger.log('[$_className] Downloads directory: $downloadsPath');
        return downloadsPath;
      } else {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) {
          final fallback = '$userProfile\\Downloads';
          Logger.log('[$_className] Fallback Downloads directory: $fallback');
          return fallback;
        } else {
          Logger.error('[$_className] USERPROFILE environment variable missing.');
          throw Exception("Could not determine Downloads directory on Windows.");
        }
      }
    } else if (Platform.isAndroid) {
      Logger.log('[$_className] Android platform detected.');
      // final directory = await getExternalStorageDirectory();
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (!await downloadDir.exists()) {
        Logger.log('[$_className] Download directory does not exist, creating: ${downloadDir.path}');
        await downloadDir.create(recursive: true);
      }
      Logger.log('[$_className] Downloads directory: ${downloadDir.path}');
      return downloadDir.path;
    } else if (Platform.isLinux || Platform.isMacOS) {
      Logger.log('[$_className] Linux/MacOS platform detected.');
      final home = Platform.environment['HOME'];
      if (home != null) {
        final path = '$home/Downloads';
        Logger.log('[$_className] Downloads directory: $path');
        return path;
      } else {
        Logger.error('[$_className] HOME environment variable not found.');
        throw Exception("Could not determine user home directory.");
      }
    } else {
      Logger.error('[$_className] Unsupported platform: ${Platform.operatingSystem}');
      throw UnsupportedError("Platform not supported.");
    }
  }

}
