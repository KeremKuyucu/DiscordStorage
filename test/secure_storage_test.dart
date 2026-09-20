import 'package:flutter_test/flutter_test.dart';
import 'package:discord_storage/services/secure_storage_service.dart';

void main() {
  test('SecureStorageService encrypts and decrypts with Windows DPAPI', () {
    const originalToken = 'MTIzNDU2Nzg5MDEyMzQ1Njc4.GaBcDe.AbCdEfGhIjKlMnOpQrStUvWxYz';
    final encrypted = SecureStorageService.encrypt(originalToken);

    expect(encrypted.startsWith('dpapi:'), isTrue);
    expect(encrypted, isNot(equals(originalToken)));

    final decrypted = SecureStorageService.decrypt(encrypted);
    expect(decrypted, equals(originalToken));
  });

  test('SecureStorageService seamlessly handles legacy plain text', () {
    const plainToken = 'legacy_plain_token';
    final result = SecureStorageService.decrypt(plainToken);
    expect(result, equals(plainToken));
  });
}
