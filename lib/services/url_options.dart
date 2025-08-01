// FileShare.dart
import 'package:DiscordStorage/services/logger_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:DiscordStorage/services/link_generator.dart';

class FileShare {
  final LinkGenerator _linkGenerator = LinkGenerator();

  Future<void> shareFileLink(String filePath) async {
    Logger.log('Paylaşım işlemi başlatılıyor...');

    final shareUrl = await _linkGenerator.generateShareLinkFromFile(filePath);

    if (shareUrl != null) {
      Logger.log('Paylaşılacak URL: $shareUrl');
      await Share.share(shareUrl);
      Logger.log('Paylaşım ekranı açıldı.');
    } else {
      Logger.error('Paylaşım linki oluşturulamadığı için işlem iptal edildi.');
      // Kullanıcıya bir geri bildirim gösterilebilir.
    }
  }
}