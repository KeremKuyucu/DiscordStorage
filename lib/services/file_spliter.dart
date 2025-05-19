import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:DiscordStorage/screens/main/screen.dart';
import 'package:DiscordStorage/services/discord_service.dart';
import 'package:DiscordStorage/services/file_hash_service.dart';
import 'package:DiscordStorage/services/file_system_service.dart';
import 'package:DiscordStorage/services/notification_service.dart';
import 'package:DiscordStorage/services/upload_service.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:DiscordStorage/utilities.dart';
import 'package:http/http.dart' as http;

class Filespliter {
  final BuildContext context;
  int partSize = 8 * 1024 * 1024;
  Filespliter(this.context);
  final NotificationService notificationService = NotificationService.instance;
  late FileSystemService fileSystemService = FileSystemService();
  final FileUploader fileUploader = FileUploader();
  final DiscordService discordService = DiscordService();
  final FileHash fileHash = FileHash();

  void showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hata', style: TextStyle(color: Colors.red)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tamam')),
        ],
      ),
    );
  }

  void showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: Duration(seconds: 3)),
    );
  }

  Future<void> splitFileAndUpload(String filePath,String linksTxt) async {
    String fileName = path.basename(filePath);
    String tempDir = 'C:\\Users\\Public\\Documents\\discordStorage\\temp\\';

    Directory tempDirectory = Directory(tempDir);
    if (!await tempDirectory.exists()) {
      await tempDirectory.create(recursive: true);
    }

    try {
      int availablePartNumber = 0;
      String hash = '';

      File file = File(filePath);
      if (!await file.exists()) {
        showError('Dosya bulunamadı: $filePath');
        return;
      }

      int fileSize = await file.length();
      int totalParts = (fileSize + partSize - 1) ~/ partSize;

      File controlFile = File(linksTxt);
      if (await controlFile.exists()) {
        List<String> lines = await controlFile.readAsLines();
        if (lines.length >= 3) {
          hash = lines[2];
          createdWebhook = lines.length >= 4 ? lines[3] : '';
          if (hash == await fileHash.getFileHash(filePath)) {
            for (int i = 4; i < lines.length; i++) {
              try {
                Map<String, dynamic> jsonObj = jsonDecode(lines[i]);
                availablePartNumber = jsonObj['partNo'];
              } catch (e) {
                showInfo('Link dosyasında JSON hatası: $e');
                continue;
              }
            }
          } else {
            showError('Aynı isimde farklı bir dosya bulundu. Lütfen eski dosyayı taşı veya sil.');
            return;
          }
        }
      } else {
        await discordService.createChannel(fileName);
        await Future.delayed(const Duration(seconds: 3));
        await File(linksTxt).writeAsString(
            '$totalParts\n$fileName\n${await fileHash.getFileHash(filePath)}\n$createdWebhook\n');
      }

      RandomAccessFile raf = await file.open(mode: FileMode.read);
      for (int i = availablePartNumber; i < totalParts; i++) {
        int currentPartSize = min(partSize, fileSize - i * partSize);
        await raf.setPosition(i * partSize);
        List<int> buffer = await raf.read(currentPartSize);
        String partFilename = '$tempDir$fileName.part${i + 1}';

        await File(partFilename).writeAsBytes(buffer);
        String message = 'Dosya parçası: ${i + 1}';
        await fileUploader.fileUpload(createdWebhook, partFilename, i + 1, message, 1, linksTxt);

        notificationService.showProgressNotification(i + 1, totalParts);
      }
      await raf.close();
    } catch (e) {
      showError('Yükleme sırasında hata oluştu: $e');
    }

    String message1 = '$fileName dosyasının link dosyası\n'
        '```\n'
        '1. Satır : Parça Sayısı\n'
        '2. Satır : Dosya Adı\n'
        '3. Satır : Dosya Hash\n'
        '4. Satır : Webhook Linki\n'
        'Sonraki Satırlar: Parça, Kanal Id, Mesaj Id\n'
        '```';
    await fileUploader.fileUpload(createdWebhook, linksTxt, 0, message1, 0, linksTxt);

    Map<String, dynamic> message2 = {
      'channelId': channelId,
      'fileName': fileName,
      'messageId': messageId
    };
    String messageString = jsonEncode(message2);

    // Webhook ile mesaj gönderme
    await http.post(
      Uri.parse(createdWebhook),
      body: {'content': messageString},
    );
    fileSystemService.load().then((_) {
      fileSystemService.createFile([], fileName, channelId);
      fileSystemService.save();
    });
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => DiscordStorageLobi()),
    );
  }
}
