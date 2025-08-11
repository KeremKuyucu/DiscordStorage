import 'dart:io';
import 'package:DiscordStorage/screens/settings/service.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:convert';
import 'package:DiscordStorage/services/json_functions_service.dart';
import 'package:DiscordStorage/services/path_service.dart';
import 'package:DiscordStorage/services/logger_service.dart';
import 'package:http_parser/http_parser.dart';

bool debugPrint = false;
class FileUploader {
  final PathHelper pathHelper = PathHelper();
  JsonFunctions jsonFunctions = JsonFunctions();

  Future<void> fileUpload(String webhookUrl, String filePath, int partNo, String message, int delete, String linklerDosyasi) async {
    Logger.info('Uploading file: $filePath, Webhook: $webhookUrl, Part: $partNo');

    try {
      var request = http.MultipartRequest('POST', Uri.parse(webhookUrl));
      request.fields['content'] = message;
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        Logger.info('File uploaded successfully: $filePath');

        if (delete == 1) {
          try {
            File(filePath).deleteSync();
            Logger.info('File deleted: $filePath');
          } catch (e) {
            Logger.error('Error deleting file: $e');
          }
        }

        if(debugPrint) {
          Logger.info('Webhook response: $responseData');
        }

        Map<String, String> ids = jsonFunctions.findIds(responseData);
        String channelId2 = ids['channelId'] ?? '';
        String messageId2 = ids['messageId'] ?? '';

        if (messageId2.isNotEmpty) {
          if (delete == 1) {
            try {
              File(linklerDosyasi).writeAsStringSync(
                '${jsonFunctions.writeJson(partNo, channelId2, messageId2)}\n',
                mode: FileMode.append,
              );
              Logger.info('Link info written to file: $linklerDosyasi');
            } catch (e) {
              Logger.error('Failed to write to link file: $e');
            }
          } else {
            // Update global variables
            SettingsService.channelId = channelId2;
            SettingsService.messageId = messageId2;
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
  Future<void> uploadTextAsFileToDiscord({
    required String message,
    required String channelId,
  }) async {
    try {
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/filesystem.txt');
      await tempFile.writeAsString(message);

      final uri = Uri.parse('https://discord.com/api/v10/channels/$channelId/messages');

      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bot ${SettingsService.token}' // global token variable
        ..fields['content'] = ''
        ..files.add(
          await http.MultipartFile.fromPath(
            'files[0]',
            tempFile.path,
            // contentType parameter removed
          ),
        );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        Logger.info('Message successfully uploaded as a file: ${tempFile.path}');
        if(debugPrint){
          Logger.info('Response: $responseBody');
        }
      } else {
        Logger.error('Upload failed. Status code: ${response.statusCode}');
        Logger.error('Response: $responseBody');
      }

      await tempFile.delete();
    } catch (e) {
      Logger.error('Error during upload: $e');
    }
  }
  Future<String> uploadFileFromBytes({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://discordstorage-share.vercel.app/api/upload'),
    );

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
        contentType: MediaType('application', 'octet-stream'),
      ),
    );

    try {
      final response = await request.send();
      final body = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        throw Exception('Yükleme başarısız: ${response.reasonPhrase}');
      }

      final json = jsonDecode(body);

      if (json == null || json['fileId'] == null) {
        throw Exception('Sunucudan beklenen veri gelmedi');
      }

      return json['fileId'] as String;
    } catch (e) {
      throw Exception('Dosya yüklenirken hata oluştu: $e');
    }
  }
}




