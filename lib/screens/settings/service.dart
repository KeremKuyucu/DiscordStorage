import 'package:DiscordStorage/services/localization_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:DiscordStorage/services/discord_service.dart';
import 'package:DiscordStorage/services/utilities.dart';

class SettingsService {
  final DiscordService discordService = DiscordService();

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    token = prefs.getString('bot_token') ?? '';
    guildId = prefs.getString('guild_id') ?? '';
    categoryId = prefs.getString('category_id') ?? '';
    isDarkMode = prefs.getBool('is_dark_mode') ?? false;
    languageCode = prefs.getString('language_code') ?? 'en';
    String? temp =prefs.getString('storage_channel');
    if(temp==null || temp.isEmpty) {
      temp = await discordService.getOrCreateMainStorageChannel();
      await prefs.setString('storage_channel',temp );
    }
    storageChannelId = temp;
  }

  // Ayarları kaydet
  Future<bool> saveSettings({
    required String token2,
    required String guildId2,
    required String categoryId2,
    required BuildContext context,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final isValidToken = await discordService.checkAndSaveToken(token2);

    token = token2;
    guildId = guildId2;
    categoryId = categoryId2;

    await prefs.setString('bot_token', token2);
    await prefs.setString('guild_id', guildId2);
    await prefs.setString('category_id', categoryId2);

    if (!isValidToken) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(Language.get('tokenInvalid'))),
      );
      return false;
    }

    ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text(Language.get('tokenValid'))),
    );

    loadSettings();
    return true;
  }

  Future<void> saveThemaMode(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', val);
  }
  Future<void> saveLanguageCode(String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', val);
  }

}
