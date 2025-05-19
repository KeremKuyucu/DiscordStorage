import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:DiscordStorage/services/download_service.dart';
import 'package:DiscordStorage/services/file_hash_service.dart';
import 'package:DiscordStorage/services/notification_service.dart';
import 'package:DiscordStorage/services/discord_service.dart';
import 'package:flutter/foundation.dart';

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
  FileMerger();


  Future<String?> getDownloadsPath() async {
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null) {
      return '$userProfile\\Downloads';
    }
    return null;
  }
  Future<String> getDownloadsDirectoryPath() async {
    if (kIsWeb) {
      throw UnsupportedError("Web platformu desteklenmiyor.");
    }

    if (Platform.isWindows) {
      final downloadsPath = await getDownloadsPath();
      if (downloadsPath != null) {
        return downloadsPath;
      } else {
        // fallback: kullanıcı dizini
        return Platform.environment['USERPROFILE']! + '\\Downloads';
      }
    } else if (Platform.isAndroid) {
      // Android'de dış depolama indirilenler dizini
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        // Genellikle "/storage/emulated/0/Android/data/<package>/files"
        // Android'de doğrudan "Downloads" klasörüne yazmak için farklı izinler gerekebilir
        // Bu yüzden dış depolamadaki 'Download' klasörünü elle oluşturabiliriz
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
        return downloadDir.path;
      } else {
        throw Exception("Dış depolama dizini bulunamadı.");
      }
    } else {
      throw UnsupportedError("Platform desteklenmiyor.");
    }
  }

  Future<void> mergeFiles(String linksFileName) async {
    final linksFile = File(linksFileName);
    if (!await linksFile.exists()) {
      debugPrint('Error: Could not open links file: $linksFileName');
      return;
    }

    final lines = await linksFile.readAsLines();
    if (lines.isEmpty) {
      debugPrint('Error: Links file is empty!');
      return;
    }

    final totalParts = int.tryParse(lines[0]) ?? 0;
    if (totalParts <= 0 || lines.length < 4) {
      debugPrint('Error: Invalid links file format!');
      return;
    }

    final downloadsDir = await getDownloadsDirectoryPath();
    final targetFileName = lines[1];
    final targetFilePath = '$downloadsDir${Platform.pathSeparator}$targetFileName';
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
        debugPrint('Error parsing link: ${lines[i]}');
        continue;
      }
    }

    if (links.length != totalParts) {
      debugPrint('Error: Number of links does not match total parts!');
      return;
    }

    links.sort((a, b) => a.partNumber.compareTo(b.partNumber));

    final targetFile = File(targetFilePath);
    final sink = targetFile.openWrite();

    int downloadedParts = 0;
    final partFiles = <String>[];

    for (final link in links) {
      final newFileName = 'part${link.partNumber}.txt';
      partFiles.add(newFileName);
      final url = await discordService.getFileUrl(link.channelId, link.messageId);
      int result = await fileDownloader.fileDownload(url, newFileName);
      if (result != 0) {
        debugPrint('Dosya indirilemedi: $newFileName');
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
        debugPrint('Error: Could not open part file: $partFileName');
      }
    }

    await sink.close();

    if (await fileHash.getFileHash(targetFileName) != hash) {
      debugPrint('Error: File hash mismatch! The downloaded file may be corrupted.');
    }
  }

}
