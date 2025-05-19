import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:easy_url_launcher/easy_url_launcher.dart';

class UpdateChecker {
  final BuildContext context;
  final String repoOwner;
  final String repoName;

  UpdateChecker({
    required this.context,
    required this.repoOwner,
    required this.repoName,
  });

  Future<void> checkForUpdate() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String localVersion = packageInfo.version;

    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        if (data.isNotEmpty) {
          final latestRelease = data[0];
          String remoteVersion = latestRelease['tag_name'] ?? 'N/A';
          if (remoteVersion.startsWith('v')) {
            remoteVersion = remoteVersion.substring(1);
          }
          String updateNotes = latestRelease['body'] ?? 'Yama notları mevcut değil';
          String html = md.markdownToHtml(updateNotes);
          String releasePageUrl = 'https://github.com/$repoOwner/$repoName/releases';

          if (remoteVersion != localVersion) {
            debugPrint('Yeni sürüm mevcut: $remoteVersion');
            _showUpdateDialog(localVersion, remoteVersion, html, releasePageUrl);
          }
        }
      } else {
        throw Exception('GitHub API hatası: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Güncelleme kontrol hatası: $e');
    }
  }

  void _showUpdateDialog(String localVersion, String remoteVersion, String html, String releaseUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Yeni Sürüm Var'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mevcut Sürüm: $localVersion'),
                  Text('Yeni Sürüm: $remoteVersion'),
                  const SizedBox(height: 10),
                  const Text('Yama Notları:'),
                  const SizedBox(height: 10),
                  Html(data: html),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Güncelle'),
              onPressed: () {
                EasyLauncher.url(url: releaseUrl);
              },
            ),
          ],
        );
      },
    );
  }
}
