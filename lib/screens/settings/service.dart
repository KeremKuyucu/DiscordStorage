import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  late SharedPreferences _prefs;

  factory SettingsService() => _instance;

  SettingsService._internal();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String get botToken => _prefs.getString('bot_token') ?? '';
  set botToken(String value) => _prefs.setString('bot_token', value);

  String get guildId => _prefs.getString('guild_id') ?? '';
  set guildId(String value) => _prefs.setString('guild_id', value);

  String get categoryId => _prefs.getString('category_id') ?? '';
  set categoryId(String value) => _prefs.setString('category_id', value);

  // Ekstra: tümünü silmek istersen
  Future<void> clear() async {
    await _prefs.remove('bot_token');
    await _prefs.remove('guild_id');
    await _prefs.remove('category_id');
  }
}

