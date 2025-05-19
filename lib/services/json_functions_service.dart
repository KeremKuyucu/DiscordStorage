import 'dart:convert';
import 'dart:io';
import 'package:DiscordStorage/utilities.dart';
import 'package:flutter/foundation.dart';

class JsonFunctions{
  Map<String, String> idBul(String jsonStr) {
    try {
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
    } catch (e) {
      debugPrint('JSON parse error: $e');
    }

    return {'channelId': channelId, 'messageId': messageId};
  }

  String jsonWrite(int partNo, String channelId, String messageId) {
    Map<String, dynamic> jsonObj = {
      'partNo': partNo,
      'channelId': channelId,
      'messageId': messageId
    };

    return jsonEncode(jsonObj);
  }

  String getSecondLine(String filePath) {
    try {
      List<String> lines = File(filePath).readAsLinesSync();
      if (lines.length >= 2) {
        return lines[1];
      }
    } catch (e) {
      debugPrint('Error reading file: $e');
    }
    return '';
  }
}