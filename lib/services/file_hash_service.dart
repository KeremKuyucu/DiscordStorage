import 'package:crypto/crypto.dart';
import 'dart:io';
import 'dart:async';
import 'package:discord_storage/services/logger_service.dart';

class FileHash {
  /// Dosyayı stream üzerinden okuyarak SHA-256 hash hesaplar.
  /// Bu yöntem tüm dosyayı RAM'e yüklemez, dolayısıyla büyük dosyalarda (GB)
  /// Out-of-Memory (OOM) çökmesi yaşanmaz.
  Future<String> getFileHash(String filePath) async {
    try {
      Logger.info('Starting hash calculation: $filePath');
      final file = File(filePath);

      if (!await file.exists()) {
        Logger.error('File not found: $filePath');
        return '';
      }

      // readAsBytes() yerine stream kullanıyoruz → RAM dostu
      final digest = await sha256.bind(file.openRead()).first;
      Logger.info('Hash calculated successfully: $digest');
      return digest.toString();
    } catch (e) {
      Logger.error('Hash calculation error: $e');
      return '';
    }
  }
}
