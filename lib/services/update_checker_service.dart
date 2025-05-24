import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:easy_url_launcher/easy_url_launcher.dart';
import 'package:DiscordStorage/services/logger_service.dart';

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
    Logger.log('Update check started...');
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String localVersion = packageInfo.version;
    Logger.log('Local version: $localVersion');

    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases'),
      );

      Logger.log('GitHub API response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        Logger.log('Number of releases: ${data.length}');

        if (data.isNotEmpty) {
          final latestRelease = data[0];
          String remoteVersion = latestRelease['tag_name'] ?? 'N/A';
          if (remoteVersion.startsWith('v')) {
            remoteVersion = remoteVersion.substring(1);
          }
          Logger.log('Remote version: $remoteVersion');

          String updateNotes = latestRelease['body'] ?? 'No release notes available';
          String html = md.markdownToHtml(updateNotes);
          String releasePageUrl = 'https://github.com/$repoOwner/$repoName/releases';

          if (remoteVersion != localVersion) {
            Logger.log('New version found: $remoteVersion');
            _showUpdateDialog(localVersion, remoteVersion, html, releasePageUrl);
          } else {
            Logger.log('You are already on the latest version.');
          }
        } else {
          Logger.log('Release data is empty.');
        }
      } else {
        Logger.error('GitHub API error: ${response.statusCode}');
      }
    } catch (e) {
      Logger.error('Error during update check: $e');
    }
  }

  void _showUpdateDialog(String localVersion, String remoteVersion, String html, String releaseUrl) {
    Logger.log('Showing update dialog.');
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('New Version Available'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current Version: $localVersion'),
                  Text('New Version: $remoteVersion'),
                  const SizedBox(height: 10),
                  const Text('Release Notes:'),
                  const SizedBox(height: 10),
                  Html(data: html),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Update'),
              onPressed: () {
                Logger.log('Update link clicked: $releaseUrl');
                EasyLauncher.url(url: releaseUrl);
              },
            ),
          ],
        );
      },
    );
  }
}
