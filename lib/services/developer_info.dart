import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:DiscordStorage/services/localization_service.dart';

class DeveloperInfo {
  static Future<void> show(BuildContext context) async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final String localVersion = packageInfo.version;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          // Başlıkta uygulama ikonunu kullanmak şık durur.
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.purple),
              SizedBox(width: 10),
              Text(Language.get('about')),
            ],
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                // Uygulama Adı
                const Center(
                  child: Text(
                    'DiscordStorage',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Center(
                  child: Text('${Language.get('version')}: $localVersion'),
                ),
                const Divider(height: 24),
                // Bilgi Satırları
                _buildInfoTile(
                  icon: Icons.person_outline,
                  title: Language.get('developer'),
                  subtitle: 'Kerem Kuyucu',
                  url: 'https://github.com/keremkuyucu',
                ),
                _buildInfoTile(
                  icon: Icons.code,
                  title: Language.get('sourcecode'),
                  subtitle: 'github.com/keremkuyucu/DiscordStorage',
                  url: 'https://github.com/keremkuyucu/DiscordStorage',
                ),
                _buildInfoTile(
                  icon: Icons.email_outlined,
                  title: Language.get('contact'),
                  subtitle: 'contact@keremkk.com.tr',
                  url: 'mailto:contact@keremkk.com.tr',
                ),
                const Divider(height: 24),
                // Uygulama Açıklaması
                Text(
                  Language.get('appDescription'),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 20),
                // "Made with" kısmı
                const Center(
                  child: Text(
                    'Made with ❤️ in Türkiye',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            // Lisansları Görüntüle Butonu
            TextButton(
              child: Text(Language.get('licenses')),
              onPressed: () {
                showLicensePage(
                  context: context,
                  applicationName: 'DiscordStorage',
                  applicationVersion: localVersion,
                );
              },
            ),
            // Kapat Butonu
            TextButton(
              child: Text(Language.get('close')),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// Dialog içindeki tıklanabilir bilgi satırlarını oluşturan yardımcı (private) metot.
  static Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    String? url,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.purple.shade200),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
      onTap: url != null ? () => _launchURL(url) : null,
      trailing: url != null ? const Icon(Icons.open_in_new, size: 18) : null,
      contentPadding: EdgeInsets.zero, // Daha kompakt bir görünüm için
    );
  }

  /// Verilen URL'i cihazın varsayılan uygulamasında açan yardımcı (private) metot.
  static Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
    }
  }
}