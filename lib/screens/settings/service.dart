import 'package:DiscordStorage/services/localization_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:DiscordStorage/services/discord_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static String channelId = '';
  static String messageId = '';
  static String createdWebhook = '';

  static String token = '';
  static String guildId = '';
  static String categoryId = '';
  static String storageChannelId = '';

  static String languageCode = 'en';
  static bool isDarkMode = false;

  static const List<String> languageCodes = ['en', 'tr'];

  static final DiscordService _discordService = DiscordService();

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    token = await _secureStorage.read(key: 'bot_token') ?? '';
    guildId = await _secureStorage.read(key: 'guild_id') ?? '';
    categoryId = await _secureStorage.read(key: 'category_id') ?? '';
    storageChannelId = await _secureStorage.read(key: 'storage_channel') ?? '';
    isDarkMode = prefs.getBool('is_dark_mode') ?? false;
    languageCode = prefs.getString('language_code') ?? 'en';
    if (storageChannelId.isEmpty) {
      String? tempChannel = await _discordService.getOrCreateMainStorageChannel();
      if (tempChannel != null && tempChannel.isNotEmpty) {
        await _secureStorage.write(key: 'storage_channel', value: tempChannel);
        storageChannelId = tempChannel;
      }
    }
  }

  static Future<bool> saveSettings({
    required String newToken,
    required String newGuildId,
    required String newCategoryId,
    required BuildContext context,
  }) async {
    final isValid = await _discordService.checkAndSaveToken(newToken);

    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Language.get('tokenInvalid'))),
      );
      return false;
    }

    token = newToken;
    guildId = newGuildId;
    categoryId = newCategoryId;

    await _secureStorage.write(key: 'bot_token', value: token);
    await _secureStorage.write(key: 'guild_id', value: guildId);
    await _secureStorage.write(key: 'category_id', value: categoryId);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(Language.get('tokenValid'))),
    );

    await load();
    return true;
  }

  static Future<void> saveTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    isDarkMode = value;
    await prefs.setBool('is_dark_mode', value);
  }

  static Future<void> saveLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    languageCode = code;
    await prefs.setString('language_code', code);
  }
}