import 'package:crypto/crypto.dart';
import 'dart:io';

class FileHash{
  Future<String> getFileHash(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return '';

    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}