import 'dart:io';
import 'dart:convert';
import 'package:DiscordStorage/services/download_service.dart';
import 'package:DiscordStorage/services/file_hash_service.dart';
import 'package:DiscordStorage/services/notification_service.dart';
import 'package:DiscordStorage/services/discord_service.dart';
import 'package:DiscordStorage/services/path_service.dart';
import 'package:DiscordStorage/services/logger_service.dart';

class Link {
  final int partNumber;
  final String partUrl;

  Link(this.partNumber, this.partUrl);
}

class SharedFileMerger {
  FileDownloader downloader = FileDownloader();
  final NotificationService notificationService = NotificationService.instance;
  final FileDownloader fileDownloader = FileDownloader();
  final DiscordService discordService = DiscordService();
  final FileHash fileHash = FileHash();
  final PathHelper pathHelper = PathHelper();

  SharedFileMerger();

  Future<void> mergeFiles(String filePath) async {
    Logger.log('Starting mergeFiles process');

    // Read the content of the file
    final file = File(filePath);

    if (!await file.exists()) {
      Logger.log('Error: File not found: $filePath');
      return;
    }

    final content = await file.readAsString();

    final lines = LineSplitter.split(content).toList();
    Logger.log('Total lines count: ${lines.length}');

    if (lines.isEmpty) {
      Logger.log('Error: Links file is empty!');
      return;
    }

    final totalParts = int.tryParse(lines[0]) ?? 0;
    Logger.log('Total number of parts: $totalParts');

    if (totalParts <= 0 || lines.length < 4) {
      Logger.log('Error: Invalid links file format!');
      return;
    }

    final downloadsDir = await pathHelper.getDownloadsDirectoryPath();
    final targetFileName = lines[1];
    final targetFilePath = '$downloadsDir${Platform.pathSeparator}$targetFileName';
    final expectedHash = lines[2];
    Logger.log('Target file name: $targetFileName');
    Logger.log('Target file path: $targetFilePath');
    Logger.log('Expected file hash: $expectedHash');

    final List<Link> links = [];

    for (int i = 3; i < lines.length; i++) {
      try {
        final jsonObj = jsonDecode(lines[i]);
        final partNumber = jsonObj['partNo'];
        final partUrl = jsonObj['partUrl'];
        links.add(Link(partNumber, partUrl));
        Logger.log('Link added: partNo=$partNumber, partUrl=$partUrl');
      } catch (e) {
        Logger.log('Link parsing error: ${lines[i]}');
        continue;
      }
    }

    if (links.length != totalParts) {
      Logger.log('Error: Number of links does not match total parts! (${links.length} != $totalParts)');
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
      Logger.log('Starting download: $newFilePath');

      int result = await fileDownloader.fileDownload(link.partUrl, newFilePath);
      if (result != 0) {
        Logger.log('Error: File download failed -> $newFilePath');
        return;
      }

      downloadedParts++;
      Logger.log('Downloaded parts count: $downloadedParts/$totalParts');
      await notificationService.showProgressNotification(downloadedParts, totalParts);
    }

    int mergedParts = 0;
    for (final partFileName in partFiles) {
      final partFile = File(partFileName);
      Logger.log('Merging part file: $partFileName');

      if (await partFile.exists()) {
        final bytes = await partFile.readAsBytes();
        sink.add(bytes);
        mergedParts++;
        Logger.log('Merged parts count: $mergedParts/$totalParts');
        await notificationService.showProgressNotification(mergedParts, totalParts);
        await partFile.delete();
        Logger.log('Deleted part file: $partFileName');
      } else {
        Logger.log('Error: Part file not found -> $partFileName');
      }
    }

    await sink.close();
    Logger.log('Write operation completed: $targetFilePath');

    final calculatedHash = await fileHash.getFileHash(targetFilePath);
    Logger.log('Calculated hash: $calculatedHash');

    if (calculatedHash != expectedHash) {
      Logger.log('Error: File hash mismatch! The file may be corrupted.');
    } else {
      Logger.log('Success: File verified.');
    }

    Logger.log('mergeFiles process completed.');
  }
}
