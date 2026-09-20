import 'dart:io';
import 'package:discord_storage/services/path_service.dart';
import 'package:http/http.dart' as http;
import 'package:discord_storage/services/logger_service.dart';
import 'dart:convert';

class FileDownloader {
  /// Verilen URL'den dosyayı indirir.
  ///
  /// Döndürülen değer:
  ///  - Başarılıysa: indirilen gerçek byte sayısı (>= 0)
  ///  - Hata durumunda: -1
  ///
  /// Not: Eski sürüm başarıda 0, hatada 1 döndürüyordu. Bu hatalıydı;
  /// file_merger.dart `downloadedBytes < 0` ile hata kontrolü yapıyor, dolayısıyla
  /// 1 döndürüldüğünde hata yakalanmıyordu. Ayrıca hız hesabı için gerçek
  /// byte sayısına ihtiyaç var.
  Future<int> fileDownload(String url, String fileName) async {
    Logger.info('Downloading file: $url');
    try {
      var response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await File(fileName).writeAsBytes(response.bodyBytes);
        Logger.info('File downloaded successfully: $fileName (${response.bodyBytes.length} bytes)');
        return response.bodyBytes.length; // gerçek byte sayısı
      } else {
        Logger.error('Download failed, status code: ${response.statusCode}');
        return -1; // hata göstergesi
      }
    } catch (e) {
      Logger.error('Error downloading file: $e');
      return -1; // hata göstergesi
    }
  }

  final PathHelper pathHelper = PathHelper();

  Future<String?> sharedFileDownload(String messageId) async {
    final String baseUrl =
        'https://discordstorage-share.vercel.app/api/download/';

    final url = Uri.parse('$baseUrl$messageId');

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) {
        Logger.error('HTTP error: ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body);
      if (data['error'] != null) {
        Logger.error('API error: ${data['error']}');
        return null;
      }

      final content = data['content'] as String;
      final lines =
          content
              .split('\n')
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .toList();

      final directory = await pathHelper.getDownloadsDirectoryPath();
      final filePath = '$directory/$messageId.txt';

      final file = File(filePath);
      await file.writeAsString(lines.join('\n'));

      Logger.info('File downloaded and saved: $filePath');
      return filePath;
    } catch (e, stack) {
      Logger.error('File download error: $e\n$stack');
      return null;
    }
  }
}
