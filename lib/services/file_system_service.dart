import 'dart:convert';
import 'dart:io';
import 'package:DiscordStorage/services/discord_service.dart';
import 'package:DiscordStorage/services/download_service.dart';
import 'package:DiscordStorage/services/upload_service.dart';
import 'package:DiscordStorage/services/utilities.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:DiscordStorage/services/logger_service.dart';
import 'package:path_provider/path_provider.dart';

class FileSystemService {
  final FileUploader fileUploader = FileUploader();
  final DiscordService discordService = DiscordService();
  Map<String, dynamic> fileSystem = {
    'type': 'folder',
    'children': {},
  };

  Map<String, dynamic>? getNodeAt(List<String> path) {
    Map<String, dynamic> current = fileSystem;
    for (final segment in path) {
      if (current['type'] != 'folder' ||
          !(current['children'] as Map).containsKey(segment)) {
        Logger.error('Node not found: $segment');
        return null;
      }
      current = current['children'][segment];
    }
    return current;
  }

  void createFolder(List<String> path, String name) {
    final node = getNodeAt(path);
    if (node == null || node['type'] != 'folder') {
      Logger.error('Folder creation failed. Invalid path.');
      return;
    }
    node['children'][name] = {
      'type': 'folder',
      'children': <String, dynamic>{},
    };
    Logger.log('Folder created: $name');
  }

  void renameItem(List<String> path, String oldName, String newName) {
    final node = getNodeAt(path);
    if (node == null || node['type'] != 'folder') {
      Logger.error('Rename failed. Invalid path.');
      return;
    }

    final children = node['children'] as Map<String, dynamic>;

    if (!children.containsKey(oldName)) {
      Logger.error('Item to rename not found: $oldName');
      return;
    }

    if (children.containsKey(newName)) {
      Logger.error('New name already in use: $newName');
      return;
    }

    final item = children.remove(oldName)!;
    children[newName] = item;

    // If it's a file, update the internal name as well (optional)
    if (item['type'] == 'file') {
      item['name'] = newName;
    }

    Logger.log('Item renamed: $oldName -> $newName');
  }

  List<String> listItemNames(List<String> path) {
    final node = getNodeAt(path);
    if (node == null || node['type'] != 'folder') {
      Logger.error('Listing failed. Invalid path.');
      return [];
    }
    final children = node['children'] as Map;
    return children.keys.map((e) => e.toString()).toList();
  }

  bool idExistsInTree(Map<String, dynamic> node, String id) {
    if (node['type'] == 'file' && node['id'] == id) {
      return true;
    } else if (node['type'] == 'folder' && node.containsKey('children')) {
      final children = node['children'] as Map<String, dynamic>;
      for (final child in children.values) {
        if (idExistsInTree(child, id)) {
          return true;
        }
      }
    }
    return false;
  }

  void createFile(List<String> path, String name, String id) {
    if (idExistsInTree(fileSystem, id)) {
      Logger.error('A file with the same id already exists, file not created.');
      return;
    }

    final node = getNodeAt(path);
    if (node == null || node['type'] != 'folder') {
      Logger.error('File creation failed. Invalid path.');
      return;
    }

    final children = node['children'] as Map<String, dynamic>;
    if (children.containsKey(name)) {
      Logger.error('A file or folder with the same name already exists.');
      return;
    }

    // Uzantıyı otomatik al
    final extension = name.contains('.') ? name.split('.').last.toLowerCase() : '';

    node['children'][name] = {
      'type': 'file',
      'id': id,
      'name': name,
      'extension': extension,
    };

    Logger.log('File created: $name');
  }

  void deleteItem(List<String> path, String name) {
    // Silme işleminin yapılacağı ana klasörü bul
    final parentNode = getNodeAt(path);
    if (parentNode == null || parentNode['type'] != 'folder') {
      Logger.error('Delete operation failed. Invalid parent path.');
      return;
    }

    final parentChildren = parentNode['children'] as Map<String, dynamic>;
    final itemToDelete = parentChildren[name];

    // Silinecek öğe bulunamadıysa hata ver
    if (itemToDelete == null) {
      Logger.error('Item to delete not found: $name');
      return;
    }

    // --- EĞER SİLİNECEK ÖĞE BİR DOSYA İSE ---
    if (itemToDelete['type'] == 'file') {
      parentChildren.remove(name);
      Logger.log('File deleted: $name');
      return;
    }

    // --- EĞER SİLİNECEK ÖĞE BİR KLASÖR İSE (YENİ MANTIK) ---
    if (itemToDelete['type'] == 'folder') {
      final folderChildren = itemToDelete['children'] as Map<String, dynamic>;

      // Klasörün içi doluysa, içindekileri ana klasöre taşı
      if (folderChildren.isNotEmpty) {
        Logger.log('Folder "$name" is not empty. Moving its contents to the parent directory...');

        // Klasörün içindeki her bir öğe için döngü başlat
        for (var entry in folderChildren.entries) {
          final childName = entry.key;
          final childNode = entry.value;

          // ÖNEMLİ: Ana klasörde aynı isimde bir dosya var mı diye kontrol et
          if (parentChildren.containsKey(childName)) {
            Logger.error('Cannot move "$childName". An item with the same name already exists in the parent directory.');
          } else {
            // İsim çakışması yoksa, öğeyi ana klasörün altına taşı
            parentChildren[childName] = childNode;
            Logger.log('Moved "$childName" to parent directory.');
          }
        }
      }

      // Son olarak, artık içi boş olan klasörü sil
      parentChildren.remove(name);
      Logger.log('Folder deleted: $name');
    }
  }

  void moveItem(List<String> fromPath, String name, List<String> toPath) {
    final fromNode = getNodeAt(fromPath);
    final toNode = getNodeAt(toPath);
    if (fromNode == null || toNode == null) {
      Logger.error('Move operation failed. Invalid path.');
      return;
    }
    final item = fromNode['children'].remove(name);
    if (item != null) {
      toNode['children'][name] = item;
      Logger.log('Item moved: $name');
    } else {
      Logger.error('Item to move not found: $name');
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(fileSystem);
    await prefs.setString('fileSystem', jsonString);
    saveToDiscord();
    Logger.log('File system saved.');
  }

  Future<void> load() async {
    bool discordLoaded = await loadFromDiscord();
    if (discordLoaded) {
      Logger.log('File system loaded from Discord.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('fileSystem');
    if (jsonString != null) {
      fileSystem = jsonDecode(jsonString);
      Logger.log('File system loaded from local storage.');
    } else {
      Logger.error('No saved file system found locally.');
    }
  }
  Future<void> saveToDiscord() async {
    try {
      final jsonString = jsonEncode(fileSystem);

      // Geçici dosyayı Discord'a yükle
      Logger.log('Uploading backup file to Discord...');
      await fileUploader.uploadTextAsFileToDiscord(message: jsonString,channelId: storageChannelId);

    } catch (e) {
      Logger.error('_saveToDiscord error: $e');
    }
  }
  Future<bool> loadFromDiscord() async {
    try {
      final url = await discordService.getLatestFileUrl(channelId: storageChannelId);
      if (url == null) {
        Logger.error('Dosya URL\'si alınamadı.');
        return false;
      }
      Directory tempDirectory = await getTemporaryDirectory();
      String tempDir = tempDirectory.path;
      final fileName = '$tempDir/temp_file.json'; // Geçici ya da kalıcı bir dosya adı belirle
      final downloader = FileDownloader();

      final downloadResult = await downloader.fileDownload(url, fileName);
      if (downloadResult != 0) {
        Logger.error('Dosya indirilemedi.');
        return false;
      }

      final downloadedFile = File(fileName);
      if (await downloadedFile.exists()) {
        final jsonString = await downloadedFile.readAsString();
        fileSystem = jsonDecode(jsonString);

        // İndirilen geçici dosyayı temizle
        await downloadedFile.delete();
        return true;
      } else {
        Logger.error('İndirilen dosya bulunamadı.');
        return false;
      }
    } catch (e) {
      Logger.error('loadFromDiscord error: $e');
      return false;
    }
  }

}
