import 'package:DiscordStorage/services/localization_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:DiscordStorage/services/discord_service.dart';

class SettingsService {
  // Runtime değişkenler
  static String channelId = '';
  static String messageId = '';
  static String createdWebhook = '';

  // Ayarlarla ilgili değişkenler
  static String languageCode = 'en';
  static String guildId = '';
  static String categoryId = '';
  static String token = '';
  static String storageChannelId = '';
  static bool isDarkMode = false;

  // Desteklenen diller
  static const List<String> languageCodes = ['en', 'tr'];

  static final DiscordService _discordService = DiscordService();

  /// Başlangıçta çağrılır, tüm ayarları SharedPreferences'ten yükler
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    token = prefs.getString('bot_token') ?? '';
    guildId = prefs.getString('guild_id') ?? '';
    categoryId = prefs.getString('category_id') ?? '';
    isDarkMode = prefs.getBool('is_dark_mode') ?? false;
    languageCode = prefs.getString('language_code') ?? 'en';

    String? temp = prefs.getString('storage_channel');
    if (temp == null || temp.isEmpty) {
      temp = await _discordService.getOrCreateMainStorageChannel();
      await prefs.setString('storage_channel', temp);
    }
    storageChannelId = temp;
  }

  /// Ayarları kaydeder (token, guildId, categoryId)
  static Future<bool> saveSettings({
    required String newToken,
    required String newGuildId,
    required String newCategoryId,
    required BuildContext context,
  }) async {
    final prefs = await SharedPreferences.getInstance();
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

    await prefs.setString('bot_token', token);
    await prefs.setString('guild_id', guildId);
    await prefs.setString('category_id', categoryId);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(Language.get('tokenValid'))),
    );

    load();
    return true;
  }

  /// Tema ayarını kaydeder
  static Future<void> saveTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    isDarkMode = value;
    await prefs.setBool('is_dark_mode', value);
  }

  /// Dil kodunu kaydeder
  static Future<void> saveLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    languageCode = code;
    await prefs.setString('language_code', code);
  }
}
