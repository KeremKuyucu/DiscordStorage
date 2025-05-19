import 'dart:io';
import 'package:DiscordStorage/utilities.dart';
import 'package:http/http.dart' as http;
import 'package:DiscordStorage/services/json_functions_service.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class FileUploader {

  Future<String?> getDownloadsPath() async {
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null) {
      return '$userProfile\\Downloads';
    }
    return null;
  }
  Future<String> getDownloadsDirectoryPath() async {
    if (kIsWeb) {
      throw UnsupportedError("Web platformu desteklenmiyor.");
    }

    if (Platform.isWindows) {
      final downloadsPath = await getDownloadsPath();
      if (downloadsPath != null) {
        return downloadsPath;
      } else {
        // fallback: kullanıcı dizini
        return Platform.environment['USERPROFILE']! + '\\Downloads';
      }
    } else if (Platform.isAndroid) {
      // Android'de dış depolama indirilenler dizini
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        // Genellikle "/storage/emulated/0/Android/data/<package>/files"
        // Android'de doğrudan "Downloads" klasörüne yazmak için farklı izinler gerekebilir
        // Bu yüzden dış depolamadaki 'Download' klasörünü elle oluşturabiliriz
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
        return downloadDir.path;
      } else {
        throw Exception("Dış depolama dizini bulunamadı.");
      }
    } else {
      throw UnsupportedError("Platform desteklenmiyor.");
    }
  }
  JsonFunctions jsonFunctions = JsonFunctions();
  Future<void> fileUpload(String webhookUrl, String filePath, int partNo, String message, int silme, String linklerDosyasi) async {
    final downloadsDir = await getDownloadsDirectoryPath();
    try {
      var request = http.MultipartRequest('POST', Uri.parse(webhookUrl));
      request.fields['content'] = message;
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        if (silme == 1) {
          try {
            File(filePath).deleteSync();
            debugPrint('File deleted successfully: $filePath');
          } catch (e) {
            debugPrint('File deletion error for $filePath: $e');
          }
        }

        if(debugMode){
          try {
            File('$downloadsDir${Platform.pathSeparator}log.txt')
                .writeAsStringSync(
                'Webhook Response: $responseData\n', mode: FileMode.append);
          } catch (e) {
            debugPrint('Error writing to log.txt: $e');
          }
        }

        Map<String, String> ids = jsonFunctions.idBul(responseData);
        String channelId2 = ids['channelId'] ?? '';
        String messageId2 = ids['messageId'] ?? '';

        if (messageId2.isNotEmpty) {
          if (silme == 1) {
            try {
              File(linklerDosyasi).writeAsStringSync(
                  jsonFunctions.jsonWrite(partNo, channelId2, messageId2) + '\n',
                  mode: FileMode.append);
              debugPrint('Link written to $linklerDosyasi');
            } catch (e) {
              debugPrint('Error writing to $linklerDosyasi: $e');
            }
          } else {
            String jsonData = jsonFunctions.jsonWrite(partNo, channelId2, messageId2);
            debugPrint(jsonData);
            // Global değişkenleri güncellemek yerine, bu değerleri döndürmeyi veya
            // sınıfın üye değişkenleri olarak saklamayı düşünebilirsiniz.
            channelId = channelId2;
            messageId = messageId2;
          }
        } else {
          debugPrint('Message ID not found in response. Please check the response data in log.txt.');
          debugPrint('Response data for debugging: $responseData');
        }
      } else {
        debugPrint('File sending error. Status code: ${response.statusCode}');
        debugPrint('Response data: $responseData');
        // Hata durumunda log dosyasına yazmayı düşünebilirsiniz
        try {
          File('$downloadsDir${Platform.pathSeparator}log.txt').writeAsStringSync(
              'File sending error: ${response.statusCode}\nResponse: $responseData\n',
              mode: FileMode.append);
        } catch (e) {
          debugPrint('Error writing to log.txt: $e');
        }
      }
    } catch (e) {
      debugPrint('Error in fileUpload: $e');
      if(debugMode){
        try {
          File('log.txt').writeAsStringSync(
              'Error in fileUpload: $e\n', mode: FileMode.append);
        } catch (logError) {
          debugPrint('Error writing to log.txt: $logError');
        }
      }
    }
  }
}