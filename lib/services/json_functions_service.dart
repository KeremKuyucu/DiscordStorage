import 'dart:convert';
import 'dart:io';
import 'package:DiscordStorage/services/logger_service.dart';

class JsonFunctions {
  Map<String, String> findIds(String jsonStr) {
    String channelId = '';
    String messageId = '';

    try {
      Logger.log('Starting JSON parsing.');
      Map<String, dynamic> jsonResponse = jsonDecode(jsonStr);

      if (jsonResponse.containsKey('channel_id')) {
        channelId = jsonResponse['channel_id'];
      }

      if (jsonResponse.containsKey('id')) {
        messageId = jsonResponse['id'];
      }

      if (jsonResponse.containsKey('embeds') && jsonResponse['embeds'].isNotEmpty) {
        for (var embed in jsonResponse['embeds']) {
          if (embed.containsKey('id') && embed.containsKey('channel_id')) {
            channelId = embed['channel_id'];
            messageId = embed['id'];
          }
        }
      }
      Logger.log('JSON parsing completed. channelId: $channelId, messageId: $messageId');
    } catch (e) {
      Logger.error('JSON parse error: $e');
    }

    return {'channelId': channelId, 'messageId': messageId};
  }

  String writeJson(int partNo, String channelId, String messageId) {
    Map<String, dynamic> jsonObj = {
      'partNo': partNo,
      'channelId': channelId,
      'messageId': messageId
    };

    String jsonString = jsonEncode(jsonObj);
    Logger.log('JSON written: $jsonString');
    return jsonString;
  }

  String getSecondLine(String filePath) {
    try {
      Logger.log('Reading second line from file: $filePath');
      List<String> lines = File(filePath).readAsLinesSync();
      if (lines.length >= 2) {
        Logger.log('Second line found: ${lines[1]}');
        return lines[1];
      } else {
        Logger.log('Second line not found in the file.');
      }
    } catch (e) {
      Logger.error('File read error: $e');
    }
    return '';
  }
}
