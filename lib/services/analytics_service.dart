import 'dart:convert';
import 'package:DiscordStorage/services/logger_service.dart';
import 'package:http/http.dart' as http;

class AnalyticsService {
  AnalyticsService._();

  static final Uri _endpoint = Uri.parse('https://analytics.keremkk.com.tr/api/analytics');
  static const Map<String, String> _headers = {'Content-Type': 'application/json; charset=UTF-8'};
  static bool _hasSentEvent = false;

  static Future<bool> sendEventOnce({
    required String appId,
    required String userId,
    required String eventEndpoint,
  }) async {
    if (_hasSentEvent) {
      Logger.info('Analytics event already sent during this session.');
      return false;
    }

    _hasSentEvent = true;
    return await sendEvent(appId: appId, userId: userId, eventEndpoint: eventEndpoint);
  }
  static Future<bool> sendEvent({
    required String appId,
    required String userId,
    required String eventEndpoint,
  }) async {
    final Map<String, dynamic> data = {
      "appId": appId,
      "userId": userId,
      "endpoint": eventEndpoint,
    };

    try {
      final response = await http.post(
        _endpoint,
        headers: _headers,
        body: jsonEncode(data),
      );

      // 200 (OK) veya 201 (Created) durum kodları başarı olarak kabul edilir.
      if (response.statusCode >= 200 && response.statusCode < 300) {
        Logger.info('Analytics event sent successfully.');
        return true;
      } else {
        // Hata durumunda sunucudan dönen mesajı da loglamak daha faydalıdır.
        Logger.error(
          'Failed to send analytics event. '
              'Status Code: ${response.statusCode}, '
              'Response: ${response.body}',
        );
        return false;
      }
    } catch (e) {
      Logger.error('An exception occurred while sending analytics event: $e');
      return false;
    }
  }
}



