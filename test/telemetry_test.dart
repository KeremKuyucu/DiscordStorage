import 'package:flutter_test/flutter_test.dart';
import 'package:discord_storage/services/telemetry_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('TelemetryService sends event even with empty userId', () async {
    SharedPreferences.setMockInitialValues({});
    final success = await TelemetryService.sendEvent(
      appId: 'discordstorage',
      userId: '',
      eventEndpoint: 'app_opened',
    );
    expect(success, isTrue);
  });
}
