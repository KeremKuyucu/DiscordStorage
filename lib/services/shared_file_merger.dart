import 'dart:io';
import 'dart:convert';
import 'package:DiscordStorage/services/download_service.dart';
import 'package:DiscordStorage/services/file_hash_service.dart';
import 'package:DiscordStorage/services/notification_service.dart';
import 'package:DiscordStorage/services/discord_service.dart';
import 'package:DiscordStorage/services/path_service.dart';
import 'package:DiscordStorage/services/logger_service.dart';
import 'package:DiscordStorage/services/localization_service.dart'; // Language servisi için eklendi

class Link {
  final int partNumber;
  final String partUrl;

  Link(this.partNumber, this.partUrl);
}

class SharedFileMerger {
  int partSize = 10475274;
  FileDownloader downloader = FileDownloader();
  final NotificationService notificationService = NotificationService.instance;
  final FileDownloader fileDownloader = FileDownloader();
  final DiscordService discordService = DiscordService();
  final FileHash fileHash = FileHash();
  final PathHelper pathHelper = PathHelper();

  SharedFileMerger();

  Future<void> mergeFiles(String filePath) async {
    Logger.log('Starting mergeFiles process');

    // --- YENİ EKLENENLER ---
    // Her birleştirme işlemi için benzersiz bir bildirim ID'si oluştur.
    final int notificationId = DateTime.now().millisecondsSinceEpoch;
    final Stopwatch stopwatch = Stopwatch(); // Süre ölçümü için kronometre.

    final file = File(filePath);
    if (!await file.exists()) {
      Logger.log('Error: File not found: $filePath');
      return;
    }

    final content = await file.readAsString();
    final lines = LineSplitter.split(content).toList();

    if (lines.isEmpty) { /* ... hata kontrolü ... */ return; }

    final totalParts = int.tryParse(lines[0]) ?? 0;
    if (totalParts <= 0 || lines.length < 4) { /* ... hata kontrolü ... */ return; }

    final downloadsDir = await pathHelper.getDownloadsDirectoryPath();
    final targetFileName = lines[1];
    final targetFilePath = '$downloadsDir${Platform.pathSeparator}$targetFileName';
    final expectedHash = lines[2];

    final List<Link> links = [];
    for (int i = 3; i < lines.length; i++) {
      // ... link parse etme işlemi ...
      try {
        final jsonObj = jsonDecode(lines[i]);
        links.add(Link(jsonObj['partNo'], jsonObj['partUrl']));
      } catch (e) { continue; }
    }

    if (links.length != totalParts) { /* ... hata kontrolü ... */ return; }

    links.sort((a, b) => a.partNumber.compareTo(b.partNumber));

    // --- AŞAMA 1: DOSYALARI İNDİRME ---
    Logger.log('--- Starting Download Phase ---');
    stopwatch.start(); // İndirme için kronometreyi başlat.

    int downloadedParts = 0;
    final partFiles = <String>[];
    int totalDownloadedBytes = 0;

    for (final link in links) {
      final newFileName = 'part${link.partNumber}.txt';
      final newFilePath = '$downloadsDir${Platform.pathSeparator}$newFileName';
      partFiles.add(newFilePath);

      int downloadedBytes = await fileDownloader.fileDownload(link.partUrl, newFilePath);
      if (downloadedBytes < 0) { // Hata durumunda fileDownload -1 dönebilir.
        Logger.log('Error: File download failed -> $newFilePath');
        stopwatch.stop();
        return;
      }

      totalDownloadedBytes += downloadedBytes;
      downloadedParts++;

      // Hız ve kalan süre hesabı
      double? speedMbps;
      Duration? estimatedTime;
      if (stopwatch.elapsedMilliseconds > 500) {
        final bytesPerSecond = (totalDownloadedBytes / stopwatch.elapsedMilliseconds) * 1000;
        speedMbps = bytesPerSecond / (1024 * 1024);

        // İndirilecek toplam boyutu tahmin et (ortalama parça boyutu * kalan parça sayısı)
        final averagePartSize = totalDownloadedBytes / downloadedParts;
        final remainingBytes = (totalParts - downloadedParts) * averagePartSize;
        if(bytesPerSecond > 0){
          estimatedTime = Duration(seconds: (remainingBytes / bytesPerSecond).round());
        }
      }

      // Gelişmiş bildirim fonksiyonunu çağır
      await notificationService.showProgressNotification(
        id: notificationId,
        current: downloadedParts*partSize,
        total: totalParts*partSize,
        fileName: targetFileName,
        operation: Language.get('downloading'), // "İndiriliyor"
        speed: speedMbps,
        estimatedTime: estimatedTime,
      );
    }
    stopwatch.stop(); // İndirme bitti, kronometreyi durdur.

    // --- AŞAMA 2: DOSYALARI BİRLEŞTİRME ---
    Logger.log('--- Starting Merge Phase ---');
    final targetFile = File(targetFilePath);
    final sink = targetFile.openWrite();

    stopwatch.reset(); // Birleştirme için kronometreyi sıfırla ve başlat.
    stopwatch.start();

    int mergedParts = 0;
    for (final partFileName in partFiles) {
      final partFile = File(partFileName);

      if (await partFile.exists()) {
        final bytes = await partFile.readAsBytes();
        sink.add(bytes);
        mergedParts++;

        // Hız ve kalan süre hesabı (Burada hız MB/s değil, Parça/saniye olabilir)
        double? partsPerSecond;
        Duration? estimatedTime;
        if(stopwatch.elapsedMilliseconds > 500){
          partsPerSecond = (mergedParts / stopwatch.elapsedMilliseconds) * 1000;
          final remainingParts = totalParts - mergedParts;
          if(partsPerSecond > 0){
            estimatedTime = Duration(milliseconds: (remainingParts / partsPerSecond * 1000).round());
          }
        }

        // Gelişmiş bildirim fonksiyonunu çağır
        await notificationService.showProgressNotification(
            id: notificationId,
            current: mergedParts*partSize,
            total: totalParts*partSize,
            fileName: targetFileName,
            operation: Language.get('merging'), // "Birleştiriliyor"
            // Hız ve süre birimleri farklı olduğu için bu aşamada göstermeyebiliriz.
            // Veya `showSpeed` için yeni birimler ekleyebiliriz. Şimdilik sade tutalım.
            estimatedTime: estimatedTime
        );

        await partFile.delete();
      }
    }
    stopwatch.stop(); // Birleştirme bitti.

    await sink.close();

    // --- SON KONTROLLER ---
    final calculatedHash = await fileHash.getFileHash(targetFilePath);
    if (calculatedHash != expectedHash) {
      Logger.log('Error: File hash mismatch!');
      // TODO: Kullanıcıya hata bildirimi göster.
    } else {
      Logger.log('Success: File verified.');
      // Zaten showProgressNotification işlemi tamamladığında son bildirimi gösterecek.
    }

    Logger.log('mergeFiles process completed.');
  }
}