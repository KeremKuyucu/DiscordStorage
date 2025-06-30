import 'dart:convert';
import 'dart:io';
import 'package:DiscordStorage/services/file_hash_service.dart';
import 'package:DiscordStorage/services/path_service.dart';
import 'package:DiscordStorage/services/logger_service.dart';
import 'package:DiscordStorage/services/discord_service.dart';
// Gerekli servisleri import ediyoruz
import 'package:DiscordStorage/services/notification_service.dart';
import 'package:DiscordStorage/services/localization_service.dart';

class FileShare {
  final PathHelper pathHelper = PathHelper();
  final FileHash fileHash = FileHash();
  final DiscordService discordService = DiscordService();
  final NotificationService notificationService = NotificationService.instance;

  Future<void> generateLinkFileAndShare(String filePath) async {
    Logger.log('Creating link file...');

    // --- YENİ EKLENENLER: ID ve Kronometre ---
    final int notificationId = 100;
    final Stopwatch stopwatch = Stopwatch();

    final file = File(filePath);
    if (!await file.exists()) {
      Logger.error('Error: Target file not found!');
      return;
    }

    // try...finally bloğu, bir hata olsa bile kronometrenin durmasını sağlar.
    try {
      stopwatch.start(); // Kronometreyi başlat

      final content = await file.readAsString();
      final lines = LineSplitter.split(content).toList();
      if (lines.isEmpty) { /*...*/ return; }

      final totalParts = int.tryParse(lines[0]) ?? 0;
      if (totalParts <= 0 || lines.length < 4) { /*...*/ return; }

      final downloadsDir = await pathHelper.getDownloadsDirectoryPath();
      final fileName = lines[1];
      final hash = lines[2];

      final buffer = StringBuffer();
      buffer.writeln(totalParts);
      buffer.writeln(fileName);
      buffer.writeln(hash);

      // Toplam işlem sayısı (başlık satırlarını çıkarıyoruz)
      final totalOperations = lines.length - 4;

      for (int i = 4; i < lines.length; i++) {
        // Mevcut ilerleme (1'den başlar)
        final currentProgress = i - 3;

        try {
          final jsonObj = jsonDecode(lines[i]);
          final partNo = jsonObj['partNo'];
          final channelId = jsonObj['channelId'];
          final messageId = jsonObj['messageId'];

          // Discord'dan URL'i al (zaman alan işlem bu)
          final url = await discordService.getFileUrl(channelId, messageId);
          Logger.log('[$partNo] URL: $url');

          final partInfo = {
            'partNo': partNo,
            'partUrl': url,
          };

          buffer.writeln(jsonEncode(partInfo));

          // --- BİLDİRİM GÜNCELLEME ---
          Duration? estimatedTime;
          // Ortalama işlem süresine göre kalan süreyi tahmin et
          if (stopwatch.elapsedMilliseconds > 500) {
            final avgTimePerLink = stopwatch.elapsedMilliseconds / currentProgress;
            final remainingLinks = totalOperations - currentProgress;
            final estimatedMilliseconds = remainingLinks * avgTimePerLink;
            estimatedTime = Duration(milliseconds: estimatedMilliseconds.round());
          }

          await notificationService.showProgressNotification(
            id: notificationId,
            current: currentProgress,
            total: totalOperations,
            fileName: fileName,
            operation: Language.get('creatingShareLink'), // "Paylaşım linki oluşturuluyor"
            estimatedTime: estimatedTime,
          );

        } catch (e) {
          Logger.error('Link parsing error: ${lines[i]}');
          continue;
        }
      }

      final linkFilePath = '$downloadsDir${Platform.pathSeparator}$fileName.links.txt';
      final linkFile = File(linkFilePath);
      await linkFile.writeAsString(buffer.toString());

      Logger.log('Link file created: $linkFilePath');
      // showProgressNotification, işlem bittiğinde otomatik olarak "Tamamlandı" bildirimini gösterecektir.

    } finally {
      stopwatch.stop(); // Kronometreyi her durumda durdur.
    }
  }
}