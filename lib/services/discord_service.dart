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
    Logger.info('Starting token validation...');
    try {
      final response = await http.get(
        Uri.parse('https://discord.com/api/v10/users/@me'),
        headers: {'Authorization': 'Bot $token'},
      );

      Logger.info('HTTP response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        Logger.info('Token is valid');
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
    final String channelToFind =
        'discord-storage-main-shard-persistent-data-9b1e';
    final String desiredTopic =
        'DiscordStorage Storage System | Please do not edit or create duplicates.';

    try {
      // --- 1. ADIM: Kanalın mevcut olup olmadığını kontrol et ---
      Logger.info('Searching for "$channelToFind" channel...');
      final listUrl = Uri.parse(
        'https://discord.com/api/v10/guilds/${SettingsService.guildId}/channels',
      );
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
          Logger.info(
            '"$channelToFind" channel already exists. ID: $channelId',
          );

          // ✅ YENİ: Kanal başlığını kontrol et ve gerekirse ayarla.
          final currentTopic = existingChannel['topic'];
          if (currentTopic == null || currentTopic != desiredTopic) {
            Logger.info(
              'Channel topic is missing or incorrect. Setting it now...',
            );
            await _setChannelTopic(channelId, desiredTopic);
          }

          return channelId; // Kanal zaten var, ID'sini döndür.
        }
      } else {
        Logger.error(
          'Could not fetch channel list: ${listResponse.statusCode}',
        );
      }

      // --- 2. ADIM: Kanal bulunamadıysa oluştur ---
      Logger.info('"$channelToFind" channel not found. Creating a new one...');
      // ... (kanal oluşturma kodunun bu kısmı aynı kalıyor)
      final newChannelId = await createChannel(channelToFind);

      if (newChannelId != null) {
        Logger.info('Channel created: $channelToFind (ID: $newChannelId)');

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
        Logger.info('Channel topic has been set for channel ID: $channelId');
      } else {
        Logger.error('Failed to set channel topic: ${response.body}');
      }
    } catch (e) {
      Logger.error('_setChannelTopic error: $e');
    }
  }

  Future<List<Map<String, String>>> getChannelsInCategory() async {
    final url = Uri.parse(
      'https://discord.com/api/v10/guilds/${SettingsService.guildId}/channels',
    );

    try {
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final List<dynamic> channels = jsonDecode(response.body);

        final filteredChannels = channels.where(
          (channel) =>
              channel['parent_id'] == SettingsService.categoryId &&
              channel['type'] != 4 &&
              channel['name'] !=
                  'discord-storage-main-shard-persistent-data-9b1e',
        );

        Logger.info('Fetched ${filteredChannels.length} channels in category.');
        return filteredChannels.map<Map<String, String>>((channel) {
          return {'id': channel['id'], 'name': channel['name']};
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
        Logger.info('Deleted channel: $channelId');
        return true;
      } else {
        Logger.error(
          'Failed to delete channel: ${response.statusCode} - ${response.body}',
        );
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
      Logger.info('Channel name successfully changed to: $newName');
    } else {
      Logger.error('Failed to change channel name: ${response.statusCode}');
      Logger.error(response.body);
    }
  }

  Future<String> getFileUrl(
    String channelId,
    String messageId, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        Logger.info(
          'Attempt $attempt/$maxRetries: Getting file URL for message $messageId',
        );

        final response = await http
            .get(
              Uri.parse(
                'https://discord.com/api/v10/channels/$channelId/messages/$messageId',
              ),
              headers: _headers,
            )
            .timeout(const Duration(seconds: 15));

        // ✅ Başarılı durum
        if (response.statusCode == 200) {
          final jsonResponse = jsonDecode(response.body);
          if (jsonResponse['attachments'] != null &&
              jsonResponse['attachments'].isNotEmpty) {
            final url = jsonResponse['attachments'][0]['url'];
            Logger.info('Success! File URL retrieved: $url');
            return url;
          } else {
            Logger.error('Logical Error: No attachment found in the message.');
            return '';
          }
        }

        // ❌ Rate Limit (429)
        if (response.statusCode == 429) {
          final data = jsonDecode(response.body);
          final retryAfter = (data['retry_after'] as num?)?.toDouble() ?? 1.0;
          Logger.error(
            'Rate limited! Must wait $retryAfter seconds before retrying...',
          );
          await Future.delayed(
            Duration(milliseconds: (retryAfter * 1000).toInt()),
          );

          attempt--; // denemeyi sayma, tekrar et
          continue;
        }

        // ❌ Tekrar denemeye değmeyen hatalar
        if (response.statusCode == 404 ||
            response.statusCode == 403 ||
            response.statusCode == 401) {
          Logger.error('Client Error: ${response.statusCode}. Not retrying.');
          return '';
        }

        // ❌ Diğer hatalar (5xx vs.)
        Logger.error(
          'Server/Unexpected status ${response.statusCode} on attempt $attempt',
        );
      } on TimeoutException {
        Logger.error('Request timed out on attempt $attempt.');
      } on SocketException {
        Logger.error('Network error (SocketException) on attempt $attempt.');
      } catch (e) {
        Logger.error('Unexpected exception on attempt $attempt: $e');
      }

      // Eğer başarısız olduysak ve hâlâ deneme hakkı varsa -> exponential backoff
      if (attempt < maxRetries) {
        final delay = initialDelay * pow(2, attempt - 1);
        Logger.info('Waiting ${delay.inSeconds}s before retrying...');
        await Future.delayed(delay);
      }
    }

    Logger.error('All $maxRetries attempts failed for message $messageId.');
    return '';
  }

  Future<String?> getLatestFileUrl({required String channelId}) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://discord.com/api/v10/channels/$channelId/messages?limit=1',
        ),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        Logger.error('Son mesaj alınamadı: ${response.body}');
        return null;
      }

      final List<dynamic> messages = jsonDecode(response.body);
      if (messages.isEmpty) {
        Logger.info('Kanaldan hiç mesaj gelmedi.');
        return null;
      }

      final latestMessage = messages.first;
      final attachments = latestMessage['attachments'] as List;
      if (attachments.isNotEmpty) {
        final fileUrl = attachments.first['url'];
        Logger.info('Son dosya bağlantısı bulundu: $fileUrl');
        return fileUrl;
      } else {
        Logger.info('Son mesajda dosya ekleri bulunamadı.');
      }
    } catch (e) {
      Logger.error('getLatestFileUrl hatası: $e');
    }

    return null;
  }

  Future<String?> createWebhook(String channelId, String name) async {
    final url = Uri.parse(
      'https://discord.com/api/v10/channels/$channelId/webhooks',
    );
    final body = jsonEncode({'name': name});

    try {
      final response = await http.post(url, headers: _headers, body: body);
      Logger.info('Webhook creation status code: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        String webhookUrl =
            'https://discord.com/api/webhooks/${data['id']}/${data['token']}';
        Logger.info('Webhook created: $webhookUrl');
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
    final url = Uri.parse(
      'https://discord.com/api/v10/guilds/${SettingsService.guildId}/channels',
    );
    Map<String, dynamic> bodyMap = {'name': channelName, 'type': 0};
    if (SettingsService.categoryId.isNotEmpty) {
      bodyMap['parent_id'] = SettingsService.categoryId;
    }
    final body = jsonEncode(bodyMap);

    try {
      final response = await http.post(url, headers: _headers, body: body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        Logger.info('Channel created: ${data['name']} (ID: ${data['id']})');
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
    final url = Uri.parse(
      'https://discord.com/api/v10/channels/$channelId/messages?limit=$limit',
    );

    try {
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        List<String> messages =
            data.map((m) => m['content'] as String).toList();
        Logger.info(
          'Fetched ${messages.length} messages from channel $channelId',
        );
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
