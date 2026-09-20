import 'dart:io';
import 'package:discord_storage/services/logger_service.dart';

class ProtocolService {
  static const String scheme = 'discordstorage';

  /// Windows Kayıt Defterinde (HKCU) discordstorage:// protokolünü kaydeder.
  /// Yönetici ayrıcalığı gerektirmez.
  static Future<void> registerWindowsProtocol() async {
    if (!Platform.isWindows) return;

    try {
      final exePath = Platform.resolvedExecutable;

      // flutter_tester veya benzeri test ortamlarındaysa kaydetme
      if (exePath.contains('flutter_tester')) {
        return;
      }

      await Process.run('reg', [
        'add',
        r'HKCU\Software\Classes\' + scheme,
        '/ve',
        '/t',
        'REG_SZ',
        '/d',
        'URL:DiscordStorage Protocol',
        '/f',
      ]);

      await Process.run('reg', [
        'add',
        r'HKCU\Software\Classes\' + scheme,
        '/v',
        'URL Protocol',
        '/t',
        'REG_SZ',
        '/d',
        '',
        '/f',
      ]);

      await Process.run('reg', [
        'add',
        r'HKCU\Software\Classes\' + scheme + r'\shell\open\command',
        '/ve',
        '/t',
        'REG_SZ',
        '/d',
        '"$exePath" "%1"',
        '/f',
      ]);

      Logger.info('Windows protocol handler registered: $scheme -> $exePath');
    } catch (e, stack) {
      Logger.error('Failed to register Windows protocol: $e\n$stack');
    }
  }

  /// Komut satırı argümanlarından veya URI'den Discord snowflake messageId'sini ayıklar.
  static String? parseMessageIdFromArgs(List<String> args) {
    if (args.isEmpty) return null;

    for (final arg in args) {
      final id = parseMessageId(arg);
      if (id != null) return id;
    }
    return null;
  }

  /// Verilen metinden (URI veya düz metin) 17-20 haneli snowflake ID'sini ayıklar.
  static String? parseMessageId(String input) {
    if (input.isEmpty) return null;

    // Doğrudan regex ile 17-20 haneli Discord snowflake ID'sini ara
    final match = RegExp(r'\b\d{17,20}\b').firstMatch(input);
    if (match != null) {
      return match.group(0);
    }

    return null;
  }
}
