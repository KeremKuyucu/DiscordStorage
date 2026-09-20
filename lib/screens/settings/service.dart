import 'package:discord_storage/services/localization_service.dart';
import 'package:discord_storage/services/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:discord_storage/services/discord_service.dart';

class SettingsService {
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

    final rawToken = prefs.getString('bot_token') ?? '';
    token = SecureStorageService.decrypt(rawToken);
    // Eski düz metin token varsa otomatik olarak DPAPI ile şifrele
    if (rawToken.isNotEmpty && !rawToken.startsWith('dpapi:')) {
      await prefs.setString('bot_token', SecureStorageService.encrypt(token));
    }

    guildId = prefs.getString('guild_id') ?? '';
    categoryId = prefs.getString('category_id') ?? '';
    storageChannelId = prefs.getString('storage_channel') ?? '';
    isDarkMode = prefs.getBool('is_dark_mode') ?? false;
    languageCode = prefs.getString('language_code') ?? 'en';
    if (storageChannelId.isEmpty && token.isNotEmpty && guildId.isNotEmpty) {
      String? tempChannel = await _discordService.getOrCreateMainStorageChannel();
      if (tempChannel.isNotEmpty) {
        await prefs.setString('storage_channel', tempChannel);
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
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Language.get('tokenInvalid'))),
      );
      return false;
    }

    token = newToken;
    guildId = newGuildId;
    categoryId = newCategoryId;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bot_token', SecureStorageService.encrypt(token));
    await prefs.setString('guild_id', guildId);
    await prefs.setString('category_id', categoryId);

    if (!context.mounted) return false;
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