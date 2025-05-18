import 'package:discordstorage/util.dart';
import 'package:http/http.dart' as http;

class FileUploader {
  Future<void> fileUpload(String webhookUrl, String filePath, int partNo, String message, int silme, String linklerDosyasi) async {
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
            print('File deleted successfully: $filePath');
          } catch (e) {
            print('File deletion error for $filePath: $e');
          }
        }

        try {
          File('postlog.txt').writeAsStringSync('Webhook Response: $responseData\n', mode: FileMode.append);
        } catch (e) {
          print('Error writing to postlog.txt: $e');
        }

        Map<String, String> ids = idBul(responseData);
        String channelId2 = ids['channelId'] ?? '';
        String messageId2 = ids['messageId'] ?? '';

        if (messageId2.isNotEmpty) {
          if (silme == 1) {
            try {
              File(linklerDosyasi).writeAsStringSync(
                  jsonWrite(partNo, channelId2, messageId2) + '\n',
                  mode: FileMode.append);
              print('Link written to $linklerDosyasi');
            } catch (e) {
              print('Error writing to $linklerDosyasi: $e');
            }
          } else {
            String jsonData = jsonWrite(partNo, channelId2, messageId2);
            print(jsonData);
            // Global değişkenleri güncellemek yerine, bu değerleri döndürmeyi veya
            // sınıfın üye değişkenleri olarak saklamayı düşünebilirsiniz.
            channelId = channelId2;
            messageId = messageId2;
          }
        } else {
          print('Message ID not found in response. Please check the response data in postlog.txt.');
          print('Response data for debugging: $responseData');
        }
      } else {
        print('File sending error. Status code: ${response.statusCode}');
        print('Response data: $responseData');
        // Hata durumunda log dosyasına yazmayı düşünebilirsiniz
        try {
          File('errorlog.txt').writeAsStringSync(
              'File sending error: ${response.statusCode}\nResponse: $responseData\n',
              mode: FileMode.append);
        } catch (e) {
          print('Error writing to errorlog.txt: $e');
        }
      }
    } catch (e) {
      print('Error in fileUpload: $e');
      // Genel hata durumunda log dosyasına yazmayı düşünebilirsiniz
      try {
        File('errorlog.txt').writeAsStringSync('Error in fileUpload: $e\n', mode: FileMode.append);
      } catch (logError) {
        print('Error writing to errorlog.txt: $logError');
      }
    }
  }
}