import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:discordstorage/services/download.dart';
import 'package:discordstorage/services/fileHash.dart';
import 'package:discordstorage/services/notification.dart';
import 'package:discordstorage/services/discordService.dart';
class Link {
  final int partNumber;
  final String channelId;
  final String messageId;

  Link(this.partNumber, this.channelId, this.messageId);
}

class FileMerger {
  String token = '';
  FileDownloader downloader = FileDownloader();
  final NotificationService notificationService = NotificationService.instance;
  final FileDownloader fileDownloader = FileDownloader();
  final DiscordService discordService = DiscordService();
  final FileHash fileHash = FileHash();
  FileMerger();

  // Async init fonksiyonu, SharedPreferences'tan tokeni okur
  Future<void> init() async {
    await discordService.init();
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('bot_token') ?? '';
  }

  Future<String> getFileHash(String filePath) async {
    return await fileHash.getFileHash(filePath);
  }
  Future<void> mergeFiles(String linksFileName) async {
    if (token.isEmpty) {
      print('Token yok, lütfen init fonksiyonunu çağırın!');
      return;
    }

    final linksFile = File(linksFileName);
    if (!await linksFile.exists()) {
      print('Error: Could not open links file: $linksFileName');
      return;
    }

    final lines = await linksFile.readAsLines();
    if (lines.isEmpty) {
      print('Error: Links file is empty!');
      return;
    }

    final totalParts = int.tryParse(lines[0]) ?? 0;
    if (totalParts <= 0 || lines.length < 4) {
      print('Error: Invalid links file format!');
      return;
    }

    final targetFileName = lines[1];
    final hash = lines[2];
    final webhook = lines[3];

    final List<Link> links = [];

    for (int i = 4; i < lines.length; i++) {
      try {
        final jsonObj = jsonDecode(lines[i]);
        final partNumber = jsonObj['partNo'];
        final channelId = jsonObj['channelId'];
        final messageId = jsonObj['messageId'];
        links.add(Link(partNumber, channelId, messageId));
      } catch (e) {
        print('Error parsing link: ${lines[i]}');
        continue;
      }
    }

    if (links.length != totalParts) {
      print('Error: Number of links does not match total parts!');
      return;
    }

    links.sort((a, b) => a.partNumber.compareTo(b.partNumber));

    final targetFile = File(targetFileName);
    final sink = targetFile.openWrite();

    int downloadedParts = 0;
    final partFiles = <String>[];

    for (final link in links) {
      final newFileName = 'part${link.partNumber}.txt';
      partFiles.add(newFileName);
      final url = await discordService.getFileUrl(link.channelId, link.messageId);
      int result = await fileDownloader.fileDownload(url, newFileName);
      if (result != 0) {
        print('Dosya indirilemedi: $newFileName');
        return;
      }
      downloadedParts++;
      await notificationService.showProgressNotification(downloadedParts, totalParts);
    }

    int mergedParts = 0;
    for (final partFileName in partFiles) {
      final partFile = File(partFileName);
      if (await partFile.exists()) {
        final bytes = await partFile.readAsBytes();
        sink.add(bytes);
        mergedParts++;
        await notificationService.showProgressNotification(mergedParts, totalParts);
        await partFile.delete();
      } else {
        print('Error: Could not open part file: $partFileName');
      }
    }

    await sink.close();

    if (await getFileHash(targetFileName) != hash) {
      print('Error: File hash mismatch! The downloaded file may be corrupted.');
    }
  }

}
