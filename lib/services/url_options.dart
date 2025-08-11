import 'package:DiscordStorage/services/logger_service.dart';
import 'package:DiscordStorage/services/link_generator.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class UrlOptions {
  final LinkGenerator _linkGenerator = LinkGenerator();

  Future<void> share(String filePath) async {
    Logger.info('Starting share process...');

    final shareUrl = await _linkGenerator.generateShareLinkFromFile(filePath);

    if (shareUrl != null) {
      Logger.info('URL to share: $shareUrl');
      await Share.share(shareUrl);
      Logger.info('Share screen opened.');
    } else {
      Logger.error('Share link could not be generated, process cancelled.');
    }
  }
  Future<String?> fetchContentAndSaveFile(String messageId) async {
    final url = Uri.parse('https://discordstorage-share.vercel.app/api/discord/message/$messageId');

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) {
        Logger.error('HTTP Hatası: ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body);
      if (data['error'] != null) {
        Logger.error('API Hatası: ${data['error']}');
        return null;
      }

      final content = data['content'] as String;

      // Satır satır ayır (isteğe bağlı trim ve boşları çıkarabilirsin)
      final lines = content.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList();

      // Dosya yolu hazırla (örneğin app documents dizini)
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$messageId.txt';

      // Dosyaya yaz
      final file = File(filePath);
      await file.writeAsString(lines.join('\n'));

      return filePath;
    } catch (e) {
      Logger.error('Hata: $e');
      return null;
    }
  }
}


