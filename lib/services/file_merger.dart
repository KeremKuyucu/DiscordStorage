import 'dart:io';
import 'dart:convert';
import 'package:DiscordStorage/services/download_service.dart';
import 'package:DiscordStorage/services/file_hash_service.dart';
import 'package:DiscordStorage/services/notification_service.dart';
import 'package:DiscordStorage/services/discord_service.dart';
import 'package:DiscordStorage/services/path_service.dart';
import 'package:DiscordStorage/services/logger_service.dart';
import 'package:DiscordStorage/services/localization_service.dart'; // Eklendi

// Link sınıfını URL'i de içerecek şekilde güncelleyelim.
class RichLink {
  final int partNumber;
  final String url;

  RichLink(this.partNumber, this.url);
}

class FileMerger {
  int partSize = 8 * 1024 * 1024;
  FileDownloader downloader = FileDownloader();
  final NotificationService notificationService = NotificationService.instance;
  final FileDownloader fileDownloader = FileDownloader();
  final DiscordService discordService = DiscordService();
  final FileHash fileHash = FileHash();
  final PathHelper pathHelper = PathHelper();

  FileMerger();

  Future<void> mergeFiles(String filePath) async {
    Logger.log('mergeFiles process started');

    // --- YENİ EKLENENLER: ID ve Kronometre ---
    final int notificationId = DateTime.now().millisecondsSinceEpoch;
    final Stopwatch stopwatch = Stopwatch();

    // ... dosya okuma ve temel kontroller ...
    final file = File(filePath);
    if (!await file.exists()) { /*...*/ return; }
    final content = await file.readAsString();
    final lines = LineSplitter.split(content).toList();
    if (lines.isEmpty) { /*...*/ return; }
    final totalParts = int.tryParse(lines[0]) ?? 0;
    if (totalParts <= 0 || lines.length < 4) { /*...*/ return; }

    final downloadsDir = await pathHelper.getDownloadsDirectoryPath();
    final targetFileName = lines[1];
    final targetFilePath = '$downloadsDir${Platform.pathSeparator}$targetFileName';
    final expectedHash = lines[2];

    Logger.log('--- Phase 1: Fetching all part URLs ---');
    final List<RichLink> richLinks = [];
    for (int i = 4; i < lines.length; i++) {
      try {
        final jsonObj = jsonDecode(lines[i]);
        final url = await discordService.getFileUrl(jsonObj['channelId'], jsonObj['messageId']);
        richLinks.add(RichLink(jsonObj['partNo'], url));
        // URL'leri toplarken de kullanıcıya bir "hazırlanıyor" bildirimi gösterebiliriz.
        await notificationService.showProgressNotification(
          id: notificationId,
          current: (i - 3)*partSize, // (i-4+1)
          total: (lines.length - 4)*partSize,
          fileName: targetFileName,
          operation: Language.get('preparing'), // "Hazırlanıyor"
        );
      } catch (e) {
        Logger.error('URL fetching error for line: ${lines[i]} - $e');
        continue;
      }
    }

    if (richLinks.length != totalParts) { /*...*/ return; }

    richLinks.sort((a, b) => a.partNumber.compareTo(b.partNumber));
    Logger.log('Links sorted.');

    // --- AŞAMA 2: DOSYALARI İNDİRME ---
    Logger.log('--- Phase 2: Downloading all parts ---');
    stopwatch.start();
    int downloadedParts = 0;
    final partFiles = <String>[];
    int totalDownloadedBytes = 0;

    for (final link in richLinks) {
      final newFileName = 'part${link.partNumber}.txt';
      final newFilePath = '$downloadsDir${Platform.pathSeparator}$newFileName';
      partFiles.add(newFilePath);

      final downloadedBytes = await fileDownloader.fileDownload(link.url, newFilePath);
      if (downloadedBytes < 0) { /*...*/ stopwatch.stop(); return; }

      totalDownloadedBytes += downloadedBytes;
      downloadedParts++;

      // Hız ve süre hesabı
      double? speedMbps;
      Duration? estimatedTime;
      if (stopwatch.elapsedMilliseconds > 500) {
        final bytesPerSecond = (totalDownloadedBytes / stopwatch.elapsedMilliseconds) * 1000;
        speedMbps = bytesPerSecond / (1024 * 1024);
        final averagePartSize = totalDownloadedBytes / downloadedParts;
        final remainingBytes = (totalParts - downloadedParts) * averagePartSize;
        if (bytesPerSecond > 0) {
          estimatedTime = Duration(seconds: (remainingBytes / bytesPerSecond).round());
        }
      }

      await notificationService.showProgressNotification(
        id: notificationId,
        current: downloadedParts*partSize,
        total: totalParts*partSize,
        fileName: targetFileName,
        operation: Language.get('downloading'),
        speed: speedMbps,
        estimatedTime: estimatedTime,
      );
    }
    stopwatch.stop();

    // --- AŞAMA 3: DOSYALARI BİRLEŞTİRME ---
    Logger.log('--- Phase 3: Merging all parts ---');
    final targetFile = File(targetFilePath);
    final sink = targetFile.openWrite();
    stopwatch.reset();
    stopwatch.start();
    int mergedParts = 0;

    for (final partFileName in partFiles) {
      final partFile = File(partFileName);
      if (await partFile.exists()) {
        sink.add(await partFile.readAsBytes());
        mergedParts++;
        await notificationService.showProgressNotification(
          id: notificationId,
          current: mergedParts*partSize,
          total: totalParts*partSize,
          fileName: targetFileName,
          operation: Language.get('merging'),
        );
        await partFile.delete();
      }
    }
    stopwatch.stop();
    await sink.close();

    await notificationService.cancelNotification(notificationId); // İlerleme bildirimini temizle
    final calculatedHash = await fileHash.getFileHash(targetFilePath);

    if (calculatedHash != expectedHash) {
      Logger.error('File hash mismatch!');
      await notificationService.showNotification(
        Language.get('hashMismatchTitle'), // "Hash Uyuşmazlığı"
        Language.get('hashMismatchBody'),  // "Dosya bozuk olabilir..."
        playSound: true,
      );
    } else {
      Logger.log('Successful File verified.');
      await notificationService.showNotification(
        Language.get('verifySuccessTitle'), // "İndirme Tamamlandı"
        '$targetFileName ${Language.get('verifySuccessBody')}', // "... başarıyla indirildi."
        playSound: true,
      );
    }
  }
}