import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:DiscordStorage/services/logger_service.dart';

class FileDownloader {
  Future<int> fileDownload(String url, String fileName) async {
    Logger.log('Downloading file: $url');
    try {
      var response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await File(fileName).writeAsBytes(response.bodyBytes);
        Logger.log('File downloaded successfully: $fileName');
        return 0;
      } else {
        Logger.error('Download failed, status code: ${response.statusCode}');
        return 1;
      }
    } catch (e) {
      Logger.error('Error downloading file: $e');
      return 1;
    }
  }
}
