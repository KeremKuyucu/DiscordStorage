import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:discordstorage/services/tokenCheck.dart';


class DiscordService {
  String? _token;

  DiscordService();

  Future<void> init() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('bot_token');

    final tokenChecker = TokenCheckerService();
    if (token == null) {
      print("Token null, işlem iptal edildi.");
      return;
    }
    bool isValid = await tokenChecker.checkAndSaveToken(token);

    if (!isValid) {
      throw Exception('❌ Bot token geçersiz!');
    }

    _token = token;
  }

  Map<String, String> get _headers => {
    'Authorization': 'Bot $_token',
    'Content-Type': 'application/json',
  };

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
          print('No file found in the message!');
        }
      } else {
        print('Error getting file URL: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getFileUrl: $e');
    }

    return '';
  }

  Future<String?> createWebhook(String channelId, String name) async {
    final url = Uri.parse('https://discord.com/api/v10/channels/$channelId/webhooks');
    final body = jsonEncode({'name': name});

    final response = await http.post(url, headers: _headers, body: body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      String webhookUrl = 'https://discord.com/api/webhooks/${data['id']}/${data['token']}';
      print('Webhook oluşturuldu: $name, URL: $webhookUrl');
      return webhookUrl;
    } else {
      print('Webhook oluşturulamadı: ${response.body}');
      return null;
    }
  }

  Future<String?> createChannel(String guildId, String channelName, {String? categoryId}) async {
    final url = Uri.parse('https://discord.com/api/v10/guilds/$guildId/channels');
    Map<String, dynamic> bodyMap = {
      'name': channelName,
      'type': 0, // text channel
    };
    if (categoryId != null && categoryId.isNotEmpty) {
      bodyMap['parent_id'] = categoryId;
    }
    final body = jsonEncode(bodyMap);

    final response = await http.post(url, headers: _headers, body: body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      print('Kanal oluşturuldu: ${data['name']} (ID: ${data['id']})');
      return data['id'];
    } else {
      print('Kanal oluşturulamadı: ${response.body}');
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
      print('Mesajlar alınamadı: ${response.body}');
      return [];
    }
  }
}