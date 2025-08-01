import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:DiscordStorage/services/file_hash_service.dart';
import 'package:DiscordStorage/services/logger_service.dart';
import 'package:DiscordStorage/services/discord_service.dart';
import 'package:DiscordStorage/services/notification_service.dart';
import 'package:DiscordStorage/services/localization_service.dart';
import 'package:DiscordStorage/services/upload_service.dart';

class LinkGenerator {
  final DiscordService _discordService = DiscordService();
  final NotificationService notificationService = NotificationService.instance;
  final FileUploader _fileUploader = FileUploader();

  Future<String?> generateShareLinkFromFile(String filePath) async {
    Logger.log('Creating share link from file...');

    final int notificationId = 100;
    final Stopwatch stopwatch = Stopwatch();
    stopwatch.start();

    final file = File(filePath);
    if (!await file.exists()) {
      Logger.error('Error: Target file not found!');
      stopwatch.stop();
      return null;
    }

    try {
      final content = await file.readAsString();
      final lines = const LineSplitter().convert(content);
      if (lines.isEmpty || lines.length < 4) {
        Logger.error('Error: Link file is invalid or empty.');
        return null;
      }

      final totalParts = int.tryParse(lines[0]) ?? 0;
      if (totalParts <= 0) {
        Logger.error('Error: Total parts count is invalid.');
        return null;
      }

      final fileName = lines[1];
      final hash = lines[2];
      final webhook = lines[3];

      await notificationService.showProgressNotification(
        id: notificationId,
        current: 0,
        total: totalParts,
        fileName: fileName,
        operation: Language.get('creatingShareLink'),
      );

      final buffer = StringBuffer();
      buffer.writeln(totalParts);
      buffer.writeln(fileName);
      buffer.writeln(hash);

      final linkLines = lines.skip(3).toList();
      final totalOperations = linkLines.length;

      for (var i = 0; i < totalOperations; i++) {
        final currentProgress = i + 1;
        try {
          final jsonObj = jsonDecode(linkLines[i]);
          final partNo = jsonObj['partNo'];
          final channelId = jsonObj['channelId'];
          final messageId = jsonObj['messageId'];

          final url = await _discordService.getFileUrl(channelId, messageId);
          if (url == null) {
            throw Exception('Failed to retrieve URL.');
          }

          Logger.log('[$partNo] URL: $url');
          final partInfo = {'partNo': partNo, 'partUrl': url};
          buffer.writeln(jsonEncode(partInfo));

          _updateProgressNotification(
            notificationId,
            currentProgress,
            totalOperations,
            fileName,
            stopwatch,
          );
        } catch (e) {
          Logger.error('Link parsing error: ${linkLines[i]} | Error: $e');
          // We choose to continue on error, but can also stop or notify.
        }
      }

      final linkFileContent = buffer.toString();
      final fileBytes = Uint8List.fromList(utf8.encode(linkFileContent));

      final uploadResult = await _fileUploader.uploadFileFromBytes(
        bytes: fileBytes,
        fileName: '$fileName.links.txt',
      );

      if (uploadResult == null) {
        throw Exception('Discord upload failed.');
      }

      final fileUrl = 'https://discordstorage-share.vercel.app/$uploadResult';
      Logger.log('Share URL created: $fileUrl');

      return fileUrl;
    } catch (e) {
      Logger.error('An unexpected error occurred: $e');
      await notificationService.showErrorNotification(
        'Error Occurred',
        Language.get('linkGenerationFailed'),
        details: 'There was a problem retrieving file URLs.',
      );
      return null;
    } finally {
      stopwatch.stop();
    }
  }

  void _updateProgressNotification(
      int notificationId,
      int current,
      int total,
      String fileName,
      Stopwatch stopwatch,
      ) async {
    Duration? estimatedTime;
    if (stopwatch.elapsedMilliseconds > 500) {
      final avgTimePerLink = stopwatch.elapsedMilliseconds / current;
      final remainingLinks = total - current;
      final estimatedMilliseconds = remainingLinks * avgTimePerLink;
      estimatedTime = Duration(milliseconds: estimatedMilliseconds.round());
    }

    await notificationService.showProgressNotification(
      id: notificationId,
      current: current,
      total: total,
      fileName: fileName,
      operation: Language.get('creatingShareLink'),
      estimatedTime: estimatedTime,
    );
  }
}
