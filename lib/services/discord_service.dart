import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:DiscordStorage/utilities.dart';

class DiscordService {
  DiscordService();

  Future<void> init() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    token = prefs.getString('bot_token')!;
    categoryId = prefs.getString('category_id')!;
    guildId = prefs.getString('guild_id')!;
  }

  Map<String, String> get _headers => {
    'Authorization': 'Bot $token',
    'Content-Type': 'application/json',
  };

  Future<List<Map<String, String>>> getChannelsInCategory() async {
    final url = Uri.parse('https://discord.com/api/v10/guilds/$guildId/channels');

    final response = await http.get(
      url, headers: _headers,
    );
    if (response.statusCode == 200) {
      final List<dynamic> channels = jsonDecode(response.body);

      final filteredChannels = channels.where((channel) =>
      channel['parent_id'] == categoryId &&
          channel['type'] != 4 // Kategori olmayanları al
      );

      return filteredChannels.map<Map<String, String>>((channel) {
        return {
          'id': channel['id'],
          'name': channel['name'],
        };
      }).toList();
    } else {
      throw Exception(
          'API hatası: ${response.statusCode} - ${response.body}');
    }
  }

  Future<bool> deleteDiscordChannel({required String channelId}) async {
    final url = Uri.parse('https://discord.com/api/v10/channels/$channelId');

    final response = await http.delete(
      url,
      headers: _headers
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      debugPrint('Failed to delete channel: ${response.statusCode} - ${response.body}');
      return false;
    }
  }
  Future<String> getFileUrl(String channelId, String messageId) async {
    try {
      var response = await http.get(
        Uri.parse('https://discord.com/api/v10/channels/$channelId/messages/$messageId'), headers: _headers,
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        if (jsonResponse.containsKey('attachments') && jsonResponse['attachments'].isNotEmpty) {
          return jsonResponse['attachments'][0]['url'];
        } else {
          debugPrint('No file found in the message!');
        }
      } else {
        debugPrint('Error getting file URL: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error in getFileUrl: $e');
    }

    return '';
  }

  Future<String?> createWebhook(String channelId, String name) async {
    final url = Uri.parse('https://discord.com/api/v10/channels/$channelId/webhooks');
    final body = jsonEncode({'name': name});

    final response = await http.post(url, headers: _headers, body: body);
    debugPrint('webhook status code ${response.statusCode}');
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      String webhookUrl = 'https://discord.com/api/webhooks/${data['id']}/${data['token']}';
      debugPrint('Webhook oluşturuldu: $name, URL: $webhookUrl');
      createdWebhook = webhookUrl;
      return webhookUrl;
    } else {
      debugPrint('Webhook oluşturulamadı: ${response.body}');
      return null;
    }
  }

  Future<String?> createChannel(String channelName) async {
    final url = Uri.parse('https://discord.com/api/v10/guilds/$guildId/channels');
    Map<String, dynamic> bodyMap = {
      'name': channelName,
      'type': 0,
    };
    if (categoryId.isNotEmpty) {
      bodyMap['parent_id'] = categoryId;
    }
    final body = jsonEncode(bodyMap);

    final response = await http.post(url, headers: _headers, body: body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      debugPrint('Kanal oluşturuldu: ${data['name']} (ID: ${data['id']})');
      await createWebhook(data['id'], 'File Uploader');
      return data['id'];
    } else {
      debugPrint('Kanal oluşturulamadı: ${response.body}');
      return null;
    }
  }

  Future<List<String>> getMessages(String channelId, int limit) async {
    final url = Uri.parse('https://discord.com/api/v10/channels/$channelId/messages?limit=$limit');

    final response = await http.get(url, headers: _headers);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      List<String> messages = data.map((m) => m['content'] as String).toList();
      return messages;
    } else {
      debugPrint('Mesajlar alınamadı: ${response.body}');
      return [];
    }
  }
}