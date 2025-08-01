import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:DiscordStorage/screens/main/screen.dart';
import 'package:DiscordStorage/screens/settings/service.dart';
import 'package:DiscordStorage/services/discord_service.dart';
import 'package:DiscordStorage/services/file_hash_service.dart';
import 'package:DiscordStorage/services/file_system_service.dart';
import 'package:DiscordStorage/services/notification_service.dart';
import 'package:DiscordStorage/services/path_service.dart';
import 'package:DiscordStorage/services/upload_service.dart';
import 'package:DiscordStorage/services/logger_service.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:DiscordStorage/services/localization_service.dart';

class Filespliter {
  int partSize = 10475274;
  final NotificationService notificationService = NotificationService.instance;
  late FileSystemService fileSystemService = FileSystemService();
  final FileUploader fileUploader = FileUploader();
  final DiscordService discordService = DiscordService();
  final FileHash fileHash = FileHash();
  final PathHelper pathHelper = PathHelper();

  Future<void> splitFileAndUpload(String filePath, String linksTxt, BuildContext context) async {
    Logger.log('splitFileAndUpload started for file: $filePath');

    String fileName = path.basename(filePath);
    Directory tempDirectory = await getTemporaryDirectory();
    String tempDir = tempDirectory.path;

    // --- YENİ EKLENENLER: HIZ VE SÜRE HESABI İÇİN ---
    double? speedMbps;
    Duration? estimatedTime;
    final int notificationId = 100;

    try {
      int availablePartNumber = 0;
      String hash = '';

      File file = File(filePath);
      if (!await file.exists()) {
        return;
      }

      int fileSize = await file.length();
      int totalParts = (fileSize + partSize - 1) ~/ partSize;
      Logger.log('Total number of parts: $totalParts');

      File controlFile = File(linksTxt);
      if (await controlFile.exists()) {
        Logger.log('Link file available: $linksTxt');
        List<String> lines = await controlFile.readAsLines();
        if (lines.length >= 3) {
          hash = lines[2];
          SettingsService.createdWebhook = lines.length >= 4 ? lines[3] : '';
          if (hash == await fileHash.getFileHash(filePath)) {
            Logger.log('File hash has matched, upload in progress.');
            for (int i = 4; i < lines.length; i++) {
                Map<String, dynamic> jsonObj = jsonDecode(lines[i]);
                availablePartNumber = jsonObj['partNo'];
            }
          } else {
            return;
          }
        }
      } else {
        Logger.log('Creating new channel: $fileName');
        await discordService.createChannel(fileName);
        await Future.delayed(const Duration(seconds: 3));
        String hashVal = await fileHash.getFileHash(filePath);
        await File(linksTxt).writeAsString(
          '$totalParts\n$fileName\n$hashVal\n$SettingsService.createdWebhook\n',
        );
        Logger.log('Link file created: $linksTxt');
      }

      RandomAccessFile raf = await file.open(mode: FileMode.read);
      final Stopwatch stopwatch = Stopwatch()..start(); // Kronometreyi başlat
      for (int i = availablePartNumber; i < totalParts; i++) {
        int currentPartSize = min(partSize, fileSize - i * partSize);
        await raf.setPosition(i * partSize);
        List<int> buffer = await raf.read(currentPartSize);
        String partFilename = totalParts == 1
            ? path.join(tempDir, fileName)
            : path.join(tempDir, '$fileName.part${i + 1}');

        await File(partFilename).writeAsBytes(buffer);
        Logger.log('Part ${i + 1} has been created: $partFilename');

        String message = 'File Part: ${i + 1}';
        await fileUploader.fileUpload(SettingsService.createdWebhook, partFilename, i + 1, message, 1, linksTxt);

        // --- BİLDİRİM ÇAĞRISININ SON HALİ ---

        // Geçen süreyi ve yüklenen boyutu hesapla
        final int elapsedMilliseconds = stopwatch.elapsedMilliseconds;
        final int uploadedBytes = (i-availablePartNumber + 1) * partSize;

        // Hızı hesapla (byte/saniye), sıfıra bölünmeyi önle
        if (elapsedMilliseconds > 500) { // Hız ölçümü için en az yarım saniye geçsin
          final double bytesPerSecond = (uploadedBytes / elapsedMilliseconds) * 1000;
          speedMbps = bytesPerSecond / (1024 * 1024); // MB/s'ye çevir

          // Kalan süreyi hesapla
          final int remainingBytes = fileSize - uploadedBytes -availablePartNumber*partSize;
          if (bytesPerSecond > 0) {
            final int remainingSeconds = (remainingBytes / bytesPerSecond).round();
            estimatedTime = Duration(seconds: remainingSeconds);
          }
        }

        await notificationService.showProgressNotification(
          id: notificationId,
          current: (i + 1)*partSize,
          total: totalParts*partSize,
          fileName: fileName,
          operation: Language.get('uploading'), // Lokalizasyondan "Yükleniyor" gibi bir metin alabilirsin
          showSpeed: true,
          speed: speedMbps,
          estimatedTime: estimatedTime,
        );
      }
      await raf.close();
      Logger.log('All parts loaded successfully.');
      stopwatch.stop();

    } catch (e) {
      Logger.error('Error loading: $e');
      return;
    }

    try {
      await fileUploader.fileUpload(SettingsService.createdWebhook, linksTxt, 0, '', 0, linksTxt);

      Map<String, dynamic> message2 = {
        'channelId': SettingsService.channelId,
        'fileName': fileName,
        'messageId': SettingsService.messageId
      };
      String messageString = jsonEncode(message2);

      await http.post(
        Uri.parse(SettingsService.createdWebhook),
        body: {'content': messageString},
      );

      await fileSystemService.load().then((_) {
        fileSystemService.createFile([], fileName, SettingsService.channelId);
        fileSystemService.save();
        Logger.log('Saved to the file system: $fileName');
      });
      await fileSystemService.load();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DiscordStorageLobi()),
      );
    } catch (e) {
      Logger.error('Error in last steps: $e');
    }
  }
}
