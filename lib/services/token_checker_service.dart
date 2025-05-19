import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class TokenCheckerService {
  late SharedPreferences _prefs;

  /// SharedPreferences başlat
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Token'ı kontrol eder ve geçerliyse kaydeder
  Future<bool> checkAndSaveToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse('https://discord.com/api/v10/users/@me'),
        headers: {'Authorization': 'Bot $token'},
      );

      if (response.statusCode == 200) {
        await _prefs.setString('bot_token', token);
        return true;
      } else {
        debugPrint('Token geçersiz. HTTP Kod: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Token kontrol hatası: $e');
      return false;
    }
  }

  /// Kaydedilen token'ı getirir
  String get savedToken => _prefs.getString('bot_token') ?? '';

  /// Token'ı temizler
  Future<void> clearToken() async {
    await _prefs.remove('bot_token');
  }
}
