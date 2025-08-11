import 'package:crypto/crypto.dart';
import 'dart:io';
import 'package:DiscordStorage/services/logger_service.dart';

class FileHash {
  Future<String> getFileHash(String filePath) async {
    try {
      Logger.info('Starting hash calculation: $filePath');
      final file = File(filePath);

      if (!await file.exists()) {
        Logger.error('File not found: $filePath');
        return '';
      }

      final bytes = await file.readAsBytes();
      final digest = sha256.convert(bytes);
      Logger.info('Hash calculated successfully: $digest');
      return digest.toString();
    } catch (e) {
      Logger.error('Hash calculation error: $e');
      return '';
    }
  }
}




