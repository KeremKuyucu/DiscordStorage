import 'dart:io';
import 'package:DiscordStorage/services/utilities.dart';
import 'package:http/http.dart' as http;
import 'package:DiscordStorage/services/json_functions_service.dart';
import 'package:DiscordStorage/services/path_service.dart';
import 'package:DiscordStorage/services/logger_service.dart';


class FileUploader {
  final PathHelper pathHelper = PathHelper();
  JsonFunctions jsonFunctions = JsonFunctions();

  Future<void> fileUpload(String webhookUrl, String filePath, int partNo, String message, int silme, String linklerDosyasi) async {
    Logger.log('Uploading file: $filePath, Webhook: $webhookUrl, Part: $partNo');

    try {
      var request = http.MultipartRequest('POST', Uri.parse(webhookUrl));
      request.fields['content'] = message;
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        Logger.log('File uploaded successfully: $filePath');

        if (silme == 1) {
          try {
            File(filePath).deleteSync();
            Logger.log('File deleted: $filePath');
          } catch (e) {
            Logger.error('Error deleting file: $e');
          }
        }

        Logger.log('Webhook response: $responseData');

        Map<String, String> ids = jsonFunctions.findIds(responseData);
        String channelId2 = ids['channelId'] ?? '';
        String messageId2 = ids['messageId'] ?? '';

        if (messageId2.isNotEmpty) {
          if (silme == 1) {
            try {
              File(linklerDosyasi).writeAsStringSync(
                '${jsonFunctions.writeJson(partNo, channelId2, messageId2)}\n',
                mode: FileMode.append,
              );
              Logger.log('Link info written to file: $linklerDosyasi');
            } catch (e) {
              Logger.error('Failed to write to link file: $e');
            }
          } else {
            // Update global variables
            channelId = channelId2;
            messageId = messageId2;
          }
        } else {
          Logger.error('messageId not found in response. Response: $responseData');
        }

      } else {
        Logger.error('File upload failed. Status code: ${response.statusCode}');
        Logger.error('Response: $responseData');
      }

    } catch (e) {
      Logger.error('Error during fileUpload: $e');
    }
  }
}
