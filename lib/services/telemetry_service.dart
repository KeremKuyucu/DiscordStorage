import 'dart:convert';

import 'package:discord_storage/services/logger_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TelemetryService {
  TelemetryService._();

  static const String _logApiUrl = 'https://keremkk.com.tr/api/logs';
  static const Duration _requestTimeout = Duration(seconds: 5);

  static bool _hasSentEvent = false;

  static Future<String> _getEffectiveUserId(String userId) async {
    if (userId.trim().isNotEmpty) {
      return userId.trim();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      var anonymousId = prefs.getString('telemetry_anonymous_uid');
      if (anonymousId == null || anonymousId.isEmpty) {
        anonymousId = 'anon_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
        await prefs.setString('telemetry_anonymous_uid', anonymousId);
      }
      return anonymousId;
    } catch (_) {
      return 'anon_guest';
    }
  }

  static String get _platform {
    if (kIsWeb) {
      return 'web';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  /// Bu oturum içerisinde yalnızca bir kez event gönderir.
  static Future<bool> sendEventOnce({
    required String appId,
    required String userId,
    required String eventEndpoint,
  }) async {
    if (_hasSentEvent) {
      Logger.info(
        'Telemetry event already sent during this session.',
      );
      return false;
    }

    final success = await sendEvent(
      appId: appId,
      userId: userId,
      eventEndpoint: eventEndpoint,
    );

    // Yalnızca başarılı gönderimde true yapılır.
    if (success) {
      _hasSentEvent = true;
    }

    return success;
  }

  /// Yeni telemetry API'sine event gönderir.
  static Future<bool> sendEvent({
    required String appId,
    required String userId,
    required String eventEndpoint,
    Map<String, dynamic>? additionalData,
  }) async {
    final effectiveUid = await _getEffectiveUserId(userId);

    final bodyData = {
      'uid': effectiveUid,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'app': appId,
      'event': eventEndpoint,
      'platform': _platform,
      if (additionalData != null) ...additionalData,
    };

    try {
      final response = await http
          .post(
            Uri.parse(_logApiUrl),
            headers: const {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(bodyData),
          )
          .timeout(_requestTimeout);

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        Logger.info(
          'Telemetry event sent successfully: '
          '$eventEndpoint ($effectiveUid)',
        );
        return true;
      }

      Logger.error(
        'Failed to send telemetry event. '
        'Status Code: ${response.statusCode}, '
        'Response: ${response.body}',
      );

      return false;
    } catch (e) {
      Logger.error(
        'An exception occurred while sending telemetry event: $e',
      );
      return false;
    }
  }
}