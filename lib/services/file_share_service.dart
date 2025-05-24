import 'dart:convert';
import 'dart:io';
import 'package:DiscordStorage/services/file_hash_service.dart';
import 'package:DiscordStorage/services/path_service.dart';
import 'package:DiscordStorage/services/logger_service.dart';
import 'package:DiscordStorage/services/discord_service.dart';

class FileShare {
  final PathHelper pathHelper = PathHelper();
  final FileHash fileHash = FileHash();
  final DiscordService discordService = DiscordService();

  Future<void> generateLinkFileAndShare(String filePath) async {
    Logger.log('Creating link file...');

    final file = File(filePath);
    if (!await file.exists()) {
      Logger.error('Error: Target file not found!');
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
    if (totalParts <= 0 || lines.length < 4) {
      Logger.error('Invalid links file format!');
      return;
    }

    final downloadsDir = await pathHelper.getDownloadsDirectoryPath();
    final fileName = lines[1];
    final hash = lines[2];

    final buffer = StringBuffer();
    buffer.writeln(totalParts);
    buffer.writeln(fileName);
    buffer.writeln(hash);

    for (int i = 4; i < lines.length; i++) {
      try {
        final jsonObj = jsonDecode(lines[i]);
        final partNo = jsonObj['partNo'];
        final channelId = jsonObj['channelId'];
        final messageId = jsonObj['messageId'];

        final url = await discordService.getFileUrl(channelId, messageId);
        Logger.log('[$partNo] URL: $url');

        final partInfo = {
          'partNo': partNo,
          'partUrl': url,
        };

        buffer.writeln(jsonEncode(partInfo));
      } catch (e) {
        Logger.error('Link parsing error: ${lines[i]}');
        continue;
      }
    }

    final linkFilePath = '$downloadsDir${Platform.pathSeparator}$fileName.links.txt';
    final linkFile = File(linkFilePath);
    await linkFile.writeAsString(buffer.toString());

    Logger.log('Link file created: $linkFilePath');
  }
}
