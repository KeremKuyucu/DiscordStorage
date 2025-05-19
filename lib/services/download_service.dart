import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class FileDownloader {
  Future<int> fileDownload(String url, String fileName) async {
    try {
      var response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        File(fileName).writeAsBytesSync(response.bodyBytes);
        return 0;
      } else {
        debugPrint('Download failed with status code: ${response.statusCode}');
        return 1;
      }
    } catch (e) {
      debugPrint('Error downloading file: $e');
      return 1;
    }
  }
}