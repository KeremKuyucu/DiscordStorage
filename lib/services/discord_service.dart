import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:DiscordStorage/services/utilities.dart';
import 'package:DiscordStorage/services/logger_service.dart';

class DiscordService {
  DiscordService();

  Map<String, String> get _headers => {
    'Authorization': 'Bot $token',
    'Content-Type': 'application/json',
  };

  Future<void> renameChannel({
    required String channelId,
    required String newName,
  }) async {
    final url = Uri.parse('https://discord.com/api/v10/channels/$channelId');

    final response = await http.patch(
      url,
      headers: _headers,
      body: jsonEncode({'name': newName}),
    );

    if (response.statusCode == 200) {
      Logger.log('Channel name successfully changed to: $newName');
    } else {
      Logger.error('Failed to change channel name: ${response.statusCode}');
      Logger.error(response.body);
    }
  }

  Future<bool> checkAndSaveToken(String token) async {
    Logger.log('Starting token validation...');
    try {
      final response = await http.get(
        Uri.parse('https://discord.com/api/v10/users/@me'),
        headers: {'Authorization': 'Bot $token'},
      );

      Logger.log('HTTP response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        Logger.log('Token is valid');
        return true;
      } else {
        Logger.error('Invalid token. HTTP Code: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      Logger.error('Token validation error: $e');
      return false;
    }
  }

  Future<List<Map<String, String>>> getChannelsInCategory() async {
    final url = Uri.parse('https://discord.com/api/v10/guilds/$guildId/channels');

    try {
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final List<dynamic> channels = jsonDecode(response.body);

        final filteredChannels = channels.where((channel) =>
        channel['parent_id'] == categoryId && channel['type'] != 4
        );

        Logger.log('Fetched ${filteredChannels.length} channels in category.');
        return filteredChannels.map<Map<String, String>>((channel) {
          return {
            'id': channel['id'],
            'name': channel['name'],
          };
        }).toList();
      } else {
        Logger.error('API error: ${response.statusCode} - ${response.body}');
        throw Exception('API error: ${response.statusCode}');
      }
    } catch (e) {
      Logger.error('getChannelsInCategory error: $e');
      rethrow;
    }
  }

  Future<bool> deleteDiscordChannel(String channelId) async {
    final url = Uri.parse('https://discord.com/api/v10/channels/$channelId');

    try {
      final response = await http.delete(url, headers: _headers);

      if (response.statusCode == 200) {
        Logger.log('Deleted channel: $channelId');
        return true;
      } else {
        Logger.error('Failed to delete channel: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      Logger.error('deleteDiscordChannel error: $e');
      return false;
    }
  }

  Future<String> getFileUrl(String channelId, String messageId) async {
    try {
      var response = await http.get(
        Uri.parse('https://discord.com/api/v10/channels/$channelId/messages/$messageId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        if (jsonResponse.containsKey('attachments') && jsonResponse['attachments'].isNotEmpty) {
          String url = jsonResponse['attachments'][0]['url'];
          Logger.log('File URL retrieved: $url');
          return url;
        } else {
          Logger.error('No file found in the message.');
        }
      } else {
        Logger.error('Error getting file URL: ${response.statusCode}');
      }
    } catch (e) {
      Logger.error('getFileUrl exception: $e');
    }

    return '';
  }

  Future<String?> createWebhook(String channelId, String name) async {
    final url = Uri.parse('https://discord.com/api/v10/channels/$channelId/webhooks');
    final body = jsonEncode({'name': name});

    try {
      final response = await http.post(url, headers: _headers, body: body);
      Logger.log('Webhook creation status code: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        String webhookUrl = 'https://discord.com/api/webhooks/${data['id']}/${data['token']}';
        Logger.log('Webhook created: $webhookUrl');
        createdWebhook = webhookUrl;
        return webhookUrl;
      } else {
        Logger.error('Webhook could not be created: ${response.body}');
        return null;
      }
    } catch (e) {
      Logger.error('createWebhook error: $e');
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

    try {
      final response = await http.post(url, headers: _headers, body: body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        Logger.log('Channel created: ${data['name']} (ID: ${data['id']})');
        await createWebhook(data['id'], 'File Uploader');
        return data['id'];
      } else {
        Logger.error('Channel creation failed: ${response.body}');
        return null;
      }
    } catch (e) {
      Logger.error('createChannel error: $e');
      return null;
    }
  }

  Future<List<String>> getMessages(String channelId, int limit) async {
    final url = Uri.parse('https://discord.com/api/v10/channels/$channelId/messages?limit=$limit');

    try {
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        List<String> messages = data.map((m) => m['content'] as String).toList();
        Logger.log('Fetched ${messages.length} messages from channel $channelId');
        return messages;
      } else {
        Logger.error('Failed to get messages: ${response.body}');
        return [];
      }
    } catch (e) {
      Logger.error('getMessages error: $e');
      return [];
    }
  }
}
