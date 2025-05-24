import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:DiscordStorage/services/logger_service.dart';

class Language {
  static Map<String, dynamic> _translations = {};

  static Future<void> load(String languageCode) async {
    try {
      final jsonString = await rootBundle.loadString('assets/lang/$languageCode.json');
      _translations = json.decode(jsonString);
    } catch (e) {
      Logger.log('Language file not found: $languageCode.json');
      rethrow;
    }
  }

  static String get(String key) {
    if (_translations.containsKey(key)) {
      return _translations[key].toString();
    }
    Logger.log('Missing translation key: $key');
    return '[$key]';
  }
}
