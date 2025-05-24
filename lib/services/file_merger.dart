import 'dart:io';
import 'dart:convert';
import 'package:DiscordStorage/services/download_service.dart';
import 'package:DiscordStorage/services/file_hash_service.dart';
import 'package:DiscordStorage/services/notification_service.dart';
import 'package:DiscordStorage/services/discord_service.dart';
import 'package:DiscordStorage/services/path_service.dart';
import 'package:DiscordStorage/services/logger_service.dart';
import 'package:DiscordStorage/services/localization_service.dart';

class Link {
  final int partNumber;
  final String channelId;
  final String messageId;

  Link(this.partNumber, this.channelId, this.messageId);
}

class FileMerger {
  FileDownloader downloader = FileDownloader();
  final NotificationService notificationService = NotificationService.instance;
  final FileDownloader fileDownloader = FileDownloader();
  final DiscordService discordService = DiscordService();
  final FileHash fileHash = FileHash();
  final PathHelper pathHelper = PathHelper();

  FileMerger();

  Future<void> mergeFiles(String filePath) async {
    Logger.log('splitFileAndUpload started');

    // Read file content
    final file = File(filePath);

    if (!await file.exists()) {
      Logger.error('File not found: $filePath');
      return;
    }

    final content = await file.readAsString();

    final lines = LineSplitter.split(content).toList();
    Logger.log('Total number of lines: ${lines.length}');

    if (lines.isEmpty) {
      Logger.error('Links file is empty!');
      return;
    }

    final totalParts = int.tryParse(lines[0]) ?? 0;
    Logger.log('Total parts count: $totalParts');

    if (totalParts <= 0 || lines.length < 4) {
      Logger.error('Invalid links file format!');
      return;
    }

    final downloadsDir = await pathHelper.getDownloadsDirectoryPath();
    final targetFileName = lines[1];
    final targetFilePath = '$downloadsDir${Platform.pathSeparator}$targetFileName';
    final hash = lines[2];
    final webhook = lines[3];
    Logger.log('Target file name: $targetFileName');
    Logger.log('Target file path: $targetFilePath');
    Logger.log('Expected file hash: $hash');
    Logger.log('Webhook URL: $webhook');

    final List<Link> links = [];

    for (int i = 4; i < lines.length; i++) {
      try {
        final jsonObj = jsonDecode(lines[i]);
        final partNumber = jsonObj['partNo'];
        final channelId = jsonObj['channelId'];
        final messageId = jsonObj['messageId'];
        links.add(Link(partNumber, channelId, messageId));
        Logger.log('Link added: partNo=$partNumber, channelId=$channelId, messageId=$messageId');
      } catch (e) {
        Logger.error('Link parsing error: ${lines[i]}');
        continue;
      }
    }

    if (links.length != totalParts) {
      Logger.error('Number of links does not match total parts! (${links.length} != $totalParts)');
      return;
    }

    links.sort((a, b) => a.partNumber.compareTo(b.partNumber));
    Logger.log('Links sorted.');

    final targetFile = File(targetFilePath);
    final sink = targetFile.openWrite();

    int downloadedParts = 0;
    final partFiles = <String>[];

    for (final link in links) {
      final newFileName = 'part${link.partNumber}.txt';
      final newFilePath = '$downloadsDir${Platform.pathSeparator}$newFileName';
      partFiles.add(newFilePath);
      Logger.log('Starting file download: $newFilePath');

      final url = await discordService.getFileUrl(link.channelId, link.messageId);
      Logger.log('File URL retrieved: $url');

      int result = await fileDownloader.fileDownload(url, newFilePath);
      if (result != 0) {
        Logger.error('File could not be downloaded -> $newFilePath');
        return;
      }

      downloadedParts++;
      Logger.log('Downloaded parts count: $downloadedParts/$totalParts');
      await notificationService.showProgressNotification(downloadedParts, totalParts);
    }

    int mergedParts = 0;
    for (final partFileName in partFiles) {
      final partFile = File(partFileName);
      Logger.log('Merging part: $partFileName');

      if (await partFile.exists()) {
        final bytes = await partFile.readAsBytes();
        sink.add(bytes);
        mergedParts++;
        Logger.log('Merged parts count: $mergedParts/$totalParts');
        await notificationService.showProgressNotification(mergedParts, totalParts);
        await partFile.delete();
        Logger.log('Part file deleted: $partFileName');
      } else {
        Logger.error('Part file not found -> $partFileName');
      }
    }

    await sink.close();
    Logger.log('Write operation completed: $targetFilePath');

    final calculatedHash = await fileHash.getFileHash(targetFilePath);
    Logger.log('Calculated hash: $calculatedHash');

    if (calculatedHash != hash) {
      Logger.error('File hash mismatch! The file may be corrupted.');
      await notificationService.showNotification(
        Language.get('hashMismatchTitle'),
        Language.get('hashMismatchBody'),
        id: 1,
        playSound: true,
      );
    } else {
      Logger.log('Successful File verified.');
      await notificationService.showNotification(
        Language.get('verifySuccessTitle'),
        Language.get('verifySuccessBody'),
        id: 2,
        playSound: true,
      );
    }

    Logger.log('mergeFiles operation completed.');
  }
}
