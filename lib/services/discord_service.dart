import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:DiscordStorage/screens/settings/service.dart';
import 'package:http/http.dart' as http;
import 'package:DiscordStorage/services/logger_service.dart';

class DiscordService {
  DiscordService();

  Map<String, String> get _headers => {
    'Authorization': 'Bot ${SettingsService.token}',
    'Content-Type': 'application/json',
  };

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
  Future<String> getOrCreateMainStorageChannel() async {
    final String channelToFind = 'discord-storage-main-shard-persistent-data-9b1e';
    final String desiredTopic = 'Disbox Storage System | Please do not edit or create duplicates.';

    try {
      // --- 1. ADIM: Kanalın mevcut olup olmadığını kontrol et ---
      Logger.log('Searching for "$channelToFind" channel...');
      final listUrl = Uri.parse('https://discord.com/api/v10/guilds/${SettingsService.guildId}/channels');
      final listResponse = await http.get(listUrl, headers: _headers);

      if (listResponse.statusCode == 200) {
        final List<dynamic> allChannels = jsonDecode(listResponse.body);
        final existingChannel = allChannels.firstWhere(
              (channel) =>
          channel['parent_id'] == SettingsService.categoryId &&
              channel['name'] == channelToFind,
          orElse: () => null,
        );

        if (existingChannel != null) {
          final channelId = existingChannel['id'];
          Logger.log('"$channelToFind" channel already exists. ID: $channelId');

          // ✅ YENİ: Kanal başlığını kontrol et ve gerekirse ayarla.
          final currentTopic = existingChannel['topic'];
          if (currentTopic == null || currentTopic != desiredTopic) {
            Logger.log('Channel topic is missing or incorrect. Setting it now...');
            await _setChannelTopic(channelId, desiredTopic);
          }

          return channelId; // Kanal zaten var, ID'sini döndür.
        }
      } else {
        Logger.error('Could not fetch channel list: ${listResponse.statusCode}');
      }

      // --- 2. ADIM: Kanal bulunamadıysa oluştur ---
      Logger.log('"$channelToFind" channel not found. Creating a new one...');
      // ... (kanal oluşturma kodunun bu kısmı aynı kalıyor)
      final newChannelId = await createChannel(channelToFind);

      if (newChannelId != null) {
        Logger.log('Channel created: $channelToFind (ID: $newChannelId)');

        // ✅ YENİ: Kanal sıfırdan oluşturulduğu için başlığını doğrudan ayarla.
        await _setChannelTopic(newChannelId, desiredTopic);

        await createWebhook(newChannelId, 'File Uploader');
        return newChannelId;
      } else {
        Logger.error('Channel creation failed: $channelToFind');
        return "";
      }

    } catch (e) {
      Logger.error('getOrCreateMainStorageChannel error: $e');
      return "";
    }
  }
  Future<void> _setChannelTopic(String channelId, String topic) async {
    final url = Uri.parse('https://discord.com/api/v10/channels/$channelId');
    final body = jsonEncode({'topic': topic});

    try {
      // Kanal güncellemek için PATCH metodu kullanılır.
      final response = await http.patch(url, headers: _headers, body: body);
      if (response.statusCode == 200) {
        Logger.log('Channel topic has been set for channel ID: $channelId');
      } else {
        Logger.error('Failed to set channel topic: ${response.body}');
      }
    } catch (e) {
      Logger.error('_setChannelTopic error: $e');
    }
  }
  Future<List<Map<String, String>>> getChannelsInCategory() async {
    final url = Uri.parse('https://discord.com/api/v10/guilds/${SettingsService.guildId}/channels');

    try {
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final List<dynamic> channels = jsonDecode(response.body);

        final filteredChannels = channels.where((channel) =>
        channel['parent_id'] == SettingsService.categoryId &&
            channel['type'] != 4 &&
            channel['name'] != 'discord-storage-main-shard-persistent-data-9b1e'
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

  Future<String> getFileUrl(
      String channelId,
      String messageId, {
        int maxRetries = 3, // Toplam deneme sayısı
        Duration initialDelay = const Duration(seconds: 1), // İlk denemeden sonraki bekleme süresi
      }) async {

    // Döngü, ilk deneme dahil olmak üzere 'maxRetries' kadar çalışacak.
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        Logger.log('Attempt $attempt/$maxRetries: Getting file URL for message $messageId');

        var response = await http.get(
          Uri.parse('https://discord.com/api/v10/channels/$channelId/messages/$messageId'),
          headers: _headers,
        ).timeout(const Duration(seconds: 15)); // İsteğin 15 saniyeden uzun sürmesi durumunda hata fırlat

        // 1. Başarılı Durum: URL bulundu, döngüden çık ve URL'i döndür.
        if (response.statusCode == 200) {
          Map<String, dynamic> jsonResponse = jsonDecode(response.body);
          if (jsonResponse.containsKey('attachments') && jsonResponse['attachments'].isNotEmpty) {
            String url = jsonResponse['attachments'][0]['url'];
            Logger.log('Success! File URL retrieved: $url');
            return url;
          } else {
            // Mantıksal Hata: Mesaj var ama içinde ek yok. Tekrar denemek anlamsız.
            Logger.error('Logical Error: No attachment found in the message. Not retrying.');
            return ''; // Boş döndürerek işlemi sonlandır.
          }
        }

        // 2. Tekrar Denenmeyecek Hatalar: 404 (Not Found) gibi.
        if (response.statusCode == 404 || response.statusCode == 403 || response.statusCode == 401) {
          Logger.error('Client Error: ${response.statusCode}. The resource may not exist or you may not have permission. Not retrying.');
          return ''; // Tekrar denemek anlamsız, boş döndür.
        }

        // 3. Diğer Sunucu Hataları (5xx gibi): Bu durumda döngünün sonuna gidip tekrar deneyeceğiz.
        Logger.error('Server or Network Error on attempt $attempt: Status code ${response.statusCode}');

      } on TimeoutException {
        Logger.error('Request timed out on attempt $attempt.');
      } on SocketException {
        Logger.error('Network error (SocketException) on attempt $attempt. Check internet connection.');
      } catch (e) {
        Logger.error('An unexpected exception occurred on attempt $attempt: $e');
      }

      // Başarılı olamadıysak ve son deneme değilse, bekle ve tekrar dene.
      if (attempt < maxRetries) {
        // Her denemede bekleme süresini 2 ile çarp (1s, 2s, 4s...)
        final delay = initialDelay * pow(2, attempt - 1);
        Logger.log('Waiting for ${delay.inSeconds} seconds before retrying...');
        await Future.delayed(delay);
      }
    }

    // Tüm denemeler başarısız olduysa...
    Logger.error('All $maxRetries attempts failed for message $messageId.');
    return '';
  }

  Future<String?> getLatestFileUrl({required String channelId}) async {
    try {
      final response = await http.get(
        Uri.parse('https://discord.com/api/v10/channels/$channelId/messages?limit=1'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        Logger.error('Son mesaj alınamadı: ${response.body}');
        return null;
      }

      final List<dynamic> messages = jsonDecode(response.body);
      if (messages.isEmpty) {
        Logger.log('Kanaldan hiç mesaj gelmedi.');
        return null;
      }

      final latestMessage = messages.first;
      final attachments = latestMessage['attachments'] as List;
      if (attachments.isNotEmpty) {
        final fileUrl = attachments.first['url'];
        Logger.log('Son dosya bağlantısı bulundu: $fileUrl');
        return fileUrl;
      } else {
        Logger.log('Son mesajda dosya ekleri bulunamadı.');
      }
    } catch (e) {
      Logger.error('getLatestFileUrl hatası: $e');
    }

    return null;
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
        SettingsService.createdWebhook = webhookUrl;
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
    final url = Uri.parse('https://discord.com/api/v10/guilds/${SettingsService.guildId}/channels');
    Map<String, dynamic> bodyMap = {
      'name': channelName,
      'type': 0,
    };
    if (SettingsService.categoryId.isNotEmpty) {
      bodyMap['parent_id'] = SettingsService.categoryId;
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
